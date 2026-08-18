// ---------------------------------------------------------------------------
// Test d'intégration — updateMissionTrackingStatus (Phase 4, point 6/7).
//
// Couvre :
// - Les 4 transitions valides (assigned->driver_to_pickup->arrived_at_pickup,
//   picked_up->in_transit->arrived_at_dropoff).
// - Les sauts de statut EXPLICITEMENT interdits par le cahier des charges :
//   assigned->completed, searching_driver->picked_up, completed->in_transit.
// - Le refus pour un chauffeur qui n'est PAS celui assigné à la mission
//   (permission-denied), y compris un chauffeur "légitime" par ailleurs.
// - Le refus d'un targetStatus qui n'appartient pas au domaine géré par
//   cette fonction (ex: 'completed', 'cancelled' — gérés par d'autres
//   Cloud Functions, jamais par updateMissionTrackingStatus).
//
// Même approche que acceptDeliveryConcurrency.test.ts : invocation directe
// de `updateMissionTrackingStatus.run(request)` (vrai handler, vraie
// transaction Firestore contre l'émulateur), sans passer par la couche HTTP.
// ---------------------------------------------------------------------------

import type { CallableRequest, Request } from "firebase-functions/v2/https";
import { HttpsError } from "firebase-functions/v2/https";
import type { DecodedIdToken } from "firebase-admin/auth";
import {
  updateMissionTrackingStatus,
  UpdateMissionTrackingStatusRequest,
} from "../../src/functions/updateMissionTrackingStatus";
import { admin, db } from "../../src/lib/admin";
import { MissionStatuses } from "../../src/lib/types";

const MISSION_ID = "tracking_mission_001";
const DRIVER_ID = "tracking_driver_a";
const OTHER_DRIVER_ID = "tracking_driver_b";

function buildRequest(
  driverId: string,
  data: UpdateMissionTrackingStatusRequest
): CallableRequest<UpdateMissionTrackingStatusRequest> {
  return {
    data,
    auth: {
      uid: driverId,
      token: {} as DecodedIdToken,
      rawToken: "fake-raw-token-for-emulator-test",
    },
    rawRequest: {} as Request,
    acceptsStreaming: false,
  };
}

async function seedMission(status: string, driverId: string | null = DRIVER_ID): Promise<void> {
  await db.collection("delivery_requests").doc(MISSION_ID).set({
    customer_id: "tracking_customer_001",
    driver_id: driverId,
    status,
    item_category_key: "furniture",
    description: "Test transitions de trajet.",
    required_vehicle_category: "cargoVan",
    driver_offer_amount: 85,
    customer_total: 100,
    created_at: admin.firestore.Timestamp.now(),
  });
}

async function cleanup(): Promise<void> {
  await db.collection("delivery_requests").doc(MISSION_ID).delete();
  const [events, auditLogs] = await Promise.all([
    db.collection("delivery_requests").doc(MISSION_ID).collection("tracking_events").get(),
    db.collection("audit_logs").where("target_id", "==", MISSION_ID).get(),
  ]);
  await Promise.all([
    ...events.docs.map((d) => d.ref.delete()),
    ...auditLogs.docs.map((d) => d.ref.delete()),
  ]);
}

describe("updateMissionTrackingStatus — transitions valides (chaîne complète)", () => {
  afterEach(cleanup);

  it("assigned -> driver_to_pickup réussit et écrit un tracking_event", async () => {
    await seedMission(MissionStatuses.ASSIGNED);

    const result = await updateMissionTrackingStatus.run(
      buildRequest(DRIVER_ID, { missionId: MISSION_ID, targetStatus: MissionStatuses.DRIVER_TO_PICKUP })
    );
    expect(result).toMatchObject({ success: true, status: MissionStatuses.DRIVER_TO_PICKUP });

    const missionSnap = await db.collection("delivery_requests").doc(MISSION_ID).get();
    expect(missionSnap.data()!.status).toBe(MissionStatuses.DRIVER_TO_PICKUP);

    const events = await db
      .collection("delivery_requests")
      .doc(MISSION_ID)
      .collection("tracking_events")
      .where("event_type", "==", "driver_to_pickup")
      .get();
    expect(events.size).toBe(1);
  });

  it("driver_to_pickup -> arrived_at_pickup réussit", async () => {
    await seedMission(MissionStatuses.DRIVER_TO_PICKUP);

    const result = await updateMissionTrackingStatus.run(
      buildRequest(DRIVER_ID, { missionId: MISSION_ID, targetStatus: MissionStatuses.ARRIVED_AT_PICKUP })
    );
    expect(result.status).toBe(MissionStatuses.ARRIVED_AT_PICKUP);
  });

  it("picked_up -> in_transit réussit", async () => {
    await seedMission(MissionStatuses.PICKED_UP);

    const result = await updateMissionTrackingStatus.run(
      buildRequest(DRIVER_ID, { missionId: MISSION_ID, targetStatus: MissionStatuses.IN_TRANSIT })
    );
    expect(result.status).toBe(MissionStatuses.IN_TRANSIT);
  });

  it("in_transit -> arrived_at_dropoff réussit", async () => {
    await seedMission(MissionStatuses.IN_TRANSIT);

    const result = await updateMissionTrackingStatus.run(
      buildRequest(DRIVER_ID, { missionId: MISSION_ID, targetStatus: MissionStatuses.ARRIVED_AT_DROPOFF })
    );
    expect(result.status).toBe(MissionStatuses.ARRIVED_AT_DROPOFF);
  });

  it("écrit une entrée audit_logs pour chaque transition", async () => {
    await seedMission(MissionStatuses.ASSIGNED);
    await updateMissionTrackingStatus.run(
      buildRequest(DRIVER_ID, { missionId: MISSION_ID, targetStatus: MissionStatuses.DRIVER_TO_PICKUP })
    );
    const logs = await db
      .collection("audit_logs")
      .where("target_id", "==", MISSION_ID)
      .where("action", "==", "mission_status_updated")
      .get();
    expect(logs.size).toBe(1);
    expect(logs.docs[0].data().actor_user_id).toBe(DRIVER_ID);
  });
});

describe("updateMissionTrackingStatus — sauts de statut INTERDITS (machine à états stricte)", () => {
  afterEach(cleanup);

  it("assigned -> completed est REJETÉ (targetStatus hors domaine de cette fonction)", async () => {
    await seedMission(MissionStatuses.ASSIGNED);
    await expect(
      updateMissionTrackingStatus.run(
        buildRequest(DRIVER_ID, {
          missionId: MISSION_ID,
          targetStatus: MissionStatuses.COMPLETED,
        })
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });

    const missionSnap = await db.collection("delivery_requests").doc(MISSION_ID).get();
    expect(missionSnap.data()!.status).toBe(MissionStatuses.ASSIGNED);
  });

  it("searching_driver -> picked_up est REJETÉ (predecessor invalide : picked_up exige arrived_at_pickup via completePickup, jamais cette fonction depuis searching_driver)", async () => {
    await seedMission(MissionStatuses.SEARCHING_DRIVER);
    await expect(
      updateMissionTrackingStatus.run(
        buildRequest(DRIVER_ID, {
          missionId: MISSION_ID,
          targetStatus: MissionStatuses.PICKED_UP,
        })
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("completed -> in_transit est REJETÉ (targetStatus hors domaine + mission déjà terminée)", async () => {
    await seedMission(MissionStatuses.COMPLETED);
    await expect(
      updateMissionTrackingStatus.run(
        buildRequest(DRIVER_ID, { missionId: MISSION_ID, targetStatus: MissionStatuses.IN_TRANSIT })
      )
    ).rejects.toMatchObject({ code: "failed-precondition" });

    const missionSnap = await db.collection("delivery_requests").doc(MISSION_ID).get();
    expect(missionSnap.data()!.status).toBe(MissionStatuses.COMPLETED);
  });

  it("driver_to_pickup -> in_transit (saut d'étape) est REJETÉ avec failed-precondition", async () => {
    await seedMission(MissionStatuses.DRIVER_TO_PICKUP);
    await expect(
      updateMissionTrackingStatus.run(
        buildRequest(DRIVER_ID, { missionId: MISSION_ID, targetStatus: MissionStatuses.IN_TRANSIT })
      )
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("arrived_at_pickup -> arrived_at_dropoff (saut d'étape) est REJETÉ avec failed-precondition", async () => {
    await seedMission(MissionStatuses.ARRIVED_AT_PICKUP);
    await expect(
      updateMissionTrackingStatus.run(
        buildRequest(DRIVER_ID, {
          missionId: MISSION_ID,
          targetStatus: MissionStatuses.ARRIVED_AT_DROPOFF,
        })
      )
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("une transition RÉGRESSIVE (arrived_at_dropoff -> in_transit, retour en arrière) est REJETÉE avec failed-precondition (in_transit exige picked_up comme prédécesseur)", async () => {
    await seedMission(MissionStatuses.ARRIVED_AT_DROPOFF);
    await expect(
      updateMissionTrackingStatus.run(
        buildRequest(DRIVER_ID, { missionId: MISSION_ID, targetStatus: MissionStatuses.IN_TRANSIT })
      )
    ).rejects.toMatchObject({ code: "failed-precondition" });

    const missionSnap = await db.collection("delivery_requests").doc(MISSION_ID).get();
    expect(missionSnap.data()!.status).toBe(MissionStatuses.ARRIVED_AT_DROPOFF);
  });
});

describe("updateMissionTrackingStatus — cas négatifs (mauvais chauffeur / mission introuvable)", () => {
  afterEach(cleanup);

  it("un chauffeur qui n'est PAS celui assigné à la mission ne peut PAS modifier son statut", async () => {
    await seedMission(MissionStatuses.ASSIGNED, DRIVER_ID);

    await expect(
      updateMissionTrackingStatus.run(
        buildRequest(OTHER_DRIVER_ID, {
          missionId: MISSION_ID,
          targetStatus: MissionStatuses.DRIVER_TO_PICKUP,
        })
      )
    ).rejects.toMatchObject({ code: "permission-denied" });

    const missionSnap = await db.collection("delivery_requests").doc(MISSION_ID).get();
    expect(missionSnap.data()!.status).toBe(MissionStatuses.ASSIGNED);
  });

  it("un client (uid = customer_id) ne peut évidemment pas non plus modifier le statut chauffeur", async () => {
    await seedMission(MissionStatuses.ASSIGNED, DRIVER_ID);

    await expect(
      updateMissionTrackingStatus.run(
        buildRequest("tracking_customer_001", {
          missionId: MISSION_ID,
          targetStatus: MissionStatuses.DRIVER_TO_PICKUP,
        })
      )
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("mission introuvable échoue avec not-found", async () => {
    await expect(
      updateMissionTrackingStatus.run(
        buildRequest(DRIVER_ID, {
          missionId: "mission_qui_nexiste_pas",
          targetStatus: MissionStatuses.DRIVER_TO_PICKUP,
        })
      )
    ).rejects.toMatchObject({ code: "not-found" });
  });

  it("missionId manquant échoue avec invalid-argument", async () => {
    await expect(
      updateMissionTrackingStatus.run(
        // @ts-expect-error test volontaire d'un payload invalide
        buildRequest(DRIVER_ID, { targetStatus: MissionStatuses.DRIVER_TO_PICKUP })
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("un appel NON authentifié échoue avec unauthenticated", async () => {
    const request: CallableRequest<UpdateMissionTrackingStatusRequest> = {
      data: { missionId: MISSION_ID, targetStatus: MissionStatuses.DRIVER_TO_PICKUP },
      auth: undefined,
      rawRequest: {} as Request,
      acceptsStreaming: false,
    };
    await expect(updateMissionTrackingStatus.run(request)).rejects.toBeInstanceOf(HttpsError);
    await expect(updateMissionTrackingStatus.run(request)).rejects.toMatchObject({
      code: "unauthenticated",
    });
  });
});
