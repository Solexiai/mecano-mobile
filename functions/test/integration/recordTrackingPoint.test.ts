// ---------------------------------------------------------------------------
// Test d'intégration — recordTrackingPoint (Phase 5, tracking GPS temps réel).
//
// Couvre :
// - L'écriture (merge) de la position courante dans driver_locations/{uid}.
// - La dénormalisation driver_profiles.current_geohash.
// - Le NON-écriture dans l'historique quand aucune mission active réelle
//   n'existe (active_delivery_id absent ou mission introuvable/pas au bon
//   chauffeur) — protection contre la pollution de l'historique.
// - L'écriture dans l'historique UNIQUEMENT quand active_delivery_id
//   pointe vers une mission réelle avec driver_id == ctx.uid.
// - Les cas négatifs : latitude/longitude manquants ou invalides, profil
//   chauffeur introuvable, appel non authentifié.
// ---------------------------------------------------------------------------

import type { CallableRequest, Request } from "firebase-functions/v2/https";
import { HttpsError } from "firebase-functions/v2/https";
import type { DecodedIdToken } from "firebase-admin/auth";
import {
  recordTrackingPoint,
  RecordTrackingPointRequest,
} from "../../src/functions/recordTrackingPoint";
import { admin, db } from "../../src/lib/admin";

const DRIVER_ID = "tracking_point_driver_a";
const MISSION_ID = "tracking_point_mission_001";
const OTHER_DRIVER_MISSION_ID = "tracking_point_mission_002";

function buildRequest(
  driverId: string | undefined,
  data: RecordTrackingPointRequest
): CallableRequest<RecordTrackingPointRequest> {
  return {
    data,
    auth: driverId
      ? { uid: driverId, token: {} as DecodedIdToken, rawToken: "fake-raw-token-for-emulator-test" }
      : undefined,
    rawRequest: {} as Request,
    acceptsStreaming: false,
  };
}

async function seedDriverProfile(): Promise<void> {
  await db.collection("driver_profiles").doc(DRIVER_ID).set({
    uid: DRIVER_ID,
    full_name: "Chauffeur Tracking",
    status: "approved",
    online_status: "on_mission",
  });
}

async function cleanup(): Promise<void> {
  const historySnap = await db
    .collection("driver_locations")
    .doc(DRIVER_ID)
    .collection("history")
    .get();
  await Promise.all(historySnap.docs.map((d) => d.ref.delete()));
  await Promise.all([
    db.collection("driver_locations").doc(DRIVER_ID).delete(),
    db.collection("driver_profiles").doc(DRIVER_ID).delete(),
    db.collection("delivery_requests").doc(MISSION_ID).delete(),
    db.collection("delivery_requests").doc(OTHER_DRIVER_MISSION_ID).delete(),
  ]);
}

describe("recordTrackingPoint — écriture de la position courante", () => {
  beforeEach(seedDriverProfile);
  afterEach(cleanup);

  it("écrit latitude/longitude/accuracy/heading/speed et merge sans écraser active_delivery_id", async () => {
    // Un active_delivery_id est déjà présent (écrit précédemment par
    // acceptDelivery) — recordTrackingPoint ne doit PAS l'effacer.
    await db
      .collection("driver_locations")
      .doc(DRIVER_ID)
      .set({ active_delivery_id: MISSION_ID }, { merge: true });

    const result = await recordTrackingPoint.run(
      buildRequest(DRIVER_ID, {
        latitude: 45.5017,
        longitude: -73.5673,
        accuracy: 12.5,
        heading: 90,
        speed: 8.3,
      })
    );
    expect(result).toEqual({ success: true });

    const locationSnap = await db.collection("driver_locations").doc(DRIVER_ID).get();
    const data = locationSnap.data()!;
    expect(data.latitude).toBe(45.5017);
    expect(data.longitude).toBe(-73.5673);
    expect(data.accuracy).toBe(12.5);
    expect(data.heading).toBe(90);
    expect(data.speed).toBe(8.3);
    expect(data.driver_id).toBe(DRIVER_ID);
    expect(data.active_delivery_id).toBe(MISSION_ID);
    expect(data.updated_at).toBeDefined();
  });

  it("accuracy/heading/speed sont optionnels (null si absents)", async () => {
    await recordTrackingPoint.run(
      buildRequest(DRIVER_ID, { latitude: 45.5, longitude: -73.5 })
    );
    const locationSnap = await db.collection("driver_locations").doc(DRIVER_ID).get();
    const data = locationSnap.data()!;
    expect(data.accuracy).toBeNull();
    expect(data.heading).toBeNull();
    expect(data.speed).toBeNull();
  });

  it("dénormalise driver_profiles.current_geohash", async () => {
    await recordTrackingPoint.run(
      buildRequest(DRIVER_ID, { latitude: 45.5017, longitude: -73.5673 })
    );
    const driverSnap = await db.collection("driver_profiles").doc(DRIVER_ID).get();
    expect(typeof driverSnap.data()!.current_geohash).toBe("string");
    expect(driverSnap.data()!.current_geohash.length).toBe(6);
  });
});

describe("recordTrackingPoint — historique conditionnel (protection contre pollution)", () => {
  beforeEach(seedDriverProfile);
  afterEach(cleanup);

  it("n'écrit RIEN dans l'historique quand active_delivery_id est absent", async () => {
    await recordTrackingPoint.run(
      buildRequest(DRIVER_ID, { latitude: 45.5, longitude: -73.5 })
    );
    const historySnap = await db
      .collection("driver_locations")
      .doc(DRIVER_ID)
      .collection("history")
      .get();
    expect(historySnap.empty).toBe(true);
  });

  it("n'écrit RIEN dans l'historique quand active_delivery_id pointe vers une mission introuvable", async () => {
    await db
      .collection("driver_locations")
      .doc(DRIVER_ID)
      .set({ active_delivery_id: "mission_qui_nexiste_pas" }, { merge: true });

    await recordTrackingPoint.run(
      buildRequest(DRIVER_ID, { latitude: 45.5, longitude: -73.5 })
    );
    const historySnap = await db
      .collection("driver_locations")
      .doc(DRIVER_ID)
      .collection("history")
      .get();
    expect(historySnap.empty).toBe(true);
  });

  it("n'écrit RIEN dans l'historique quand la mission référencée appartient à un AUTRE chauffeur", async () => {
    await db.collection("delivery_requests").doc(OTHER_DRIVER_MISSION_ID).set({
      customer_id: "some_customer",
      driver_id: "un_autre_chauffeur",
      status: "in_transit",
      created_at: admin.firestore.Timestamp.now(),
    });
    await db
      .collection("driver_locations")
      .doc(DRIVER_ID)
      .set({ active_delivery_id: OTHER_DRIVER_MISSION_ID }, { merge: true });

    await recordTrackingPoint.run(
      buildRequest(DRIVER_ID, { latitude: 45.5, longitude: -73.5 })
    );
    const historySnap = await db
      .collection("driver_locations")
      .doc(DRIVER_ID)
      .collection("history")
      .get();
    expect(historySnap.empty).toBe(true);
  });

  it("écrit un point d'historique quand active_delivery_id pointe vers une mission réelle du bon chauffeur", async () => {
    await db.collection("delivery_requests").doc(MISSION_ID).set({
      customer_id: "some_customer",
      driver_id: DRIVER_ID,
      status: "in_transit",
      created_at: admin.firestore.Timestamp.now(),
    });
    await db
      .collection("driver_locations")
      .doc(DRIVER_ID)
      .set({ active_delivery_id: MISSION_ID }, { merge: true });

    await recordTrackingPoint.run(
      buildRequest(DRIVER_ID, { latitude: 45.51, longitude: -73.56 })
    );

    const historySnap = await db
      .collection("driver_locations")
      .doc(DRIVER_ID)
      .collection("history")
      .get();
    expect(historySnap.size).toBe(1);
    const point = historySnap.docs[0].data();
    expect(point.delivery_id).toBe(MISSION_ID);
    expect(point.latitude).toBe(45.51);
    expect(point.longitude).toBe(-73.56);
    expect(point.recorded_at).toBeDefined();
  });

  it("accumule plusieurs points d'historique au fil d'appels successifs pendant une mission active", async () => {
    await db.collection("delivery_requests").doc(MISSION_ID).set({
      customer_id: "some_customer",
      driver_id: DRIVER_ID,
      status: "in_transit",
      created_at: admin.firestore.Timestamp.now(),
    });
    await db
      .collection("driver_locations")
      .doc(DRIVER_ID)
      .set({ active_delivery_id: MISSION_ID }, { merge: true });

    await recordTrackingPoint.run(buildRequest(DRIVER_ID, { latitude: 45.50, longitude: -73.50 }));
    await recordTrackingPoint.run(buildRequest(DRIVER_ID, { latitude: 45.51, longitude: -73.51 }));
    await recordTrackingPoint.run(buildRequest(DRIVER_ID, { latitude: 45.52, longitude: -73.52 }));

    const historySnap = await db
      .collection("driver_locations")
      .doc(DRIVER_ID)
      .collection("history")
      .get();
    expect(historySnap.size).toBe(3);
  });
});

describe("recordTrackingPoint — cas négatifs", () => {
  afterEach(cleanup);

  it("latitude manquante échoue avec invalid-argument", async () => {
    await seedDriverProfile();
    await expect(
      recordTrackingPoint.run(
        // @ts-expect-error test volontaire d'un payload invalide
        buildRequest(DRIVER_ID, { longitude: -73.5 })
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("longitude manquante échoue avec invalid-argument", async () => {
    await seedDriverProfile();
    await expect(
      recordTrackingPoint.run(
        // @ts-expect-error test volontaire d'un payload invalide
        buildRequest(DRIVER_ID, { latitude: 45.5 })
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("latitude/longitude de type incorrect échouent avec invalid-argument", async () => {
    await seedDriverProfile();
    await expect(
      recordTrackingPoint.run(
        // @ts-expect-error test volontaire d'un payload invalide
        buildRequest(DRIVER_ID, { latitude: "45.5", longitude: -73.5 })
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("profil chauffeur introuvable échoue avec permission-denied", async () => {
    // Pas de seedDriverProfile() ici — le profil n'existe pas.
    await expect(
      recordTrackingPoint.run(
        buildRequest("chauffeur_sans_profil", { latitude: 45.5, longitude: -73.5 })
      )
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("un appel NON authentifié échoue avec unauthenticated", async () => {
    await expect(
      recordTrackingPoint.run(buildRequest(undefined, { latitude: 45.5, longitude: -73.5 }))
    ).rejects.toBeInstanceOf(HttpsError);
    await expect(
      recordTrackingPoint.run(buildRequest(undefined, { latitude: 45.5, longitude: -73.5 }))
    ).rejects.toMatchObject({ code: "unauthenticated" });
  });
});
