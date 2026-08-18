// ---------------------------------------------------------------------------
// Test d'intégration — completePickup (Phase 4, point 6/7).
//
// Couvre les 3 prédécesseurs valides (assigned, driver_to_pickup,
// arrived_at_pickup) -> picked_up, le marquage du stop pickup (sequence 0),
// l'écriture du tracking_event, et les cas négatifs : mauvais chauffeur,
// transition invalide (mission pas encore assignée / déjà terminée),
// mission introuvable.
// ---------------------------------------------------------------------------

import type { CallableRequest, Request } from "firebase-functions/v2/https";
import type { DecodedIdToken } from "firebase-admin/auth";
import { completePickup, CompletePickupRequest } from "../../src/functions/completePickup";
import { admin, db } from "../../src/lib/admin";
import { MissionStatuses } from "../../src/lib/types";

const MISSION_ID = "pickup_mission_001";
const DRIVER_ID = "pickup_driver_a";
const OTHER_DRIVER_ID = "pickup_driver_b";

function buildRequest(driverId: string, data: CompletePickupRequest): CallableRequest<CompletePickupRequest> {
  return {
    data,
    auth: { uid: driverId, token: {} as DecodedIdToken, rawToken: "fake-raw-token-for-emulator-test" },
    rawRequest: {} as Request,
    acceptsStreaming: false,
  };
}

async function seedMission(status: string, driverId: string | null = DRIVER_ID): Promise<void> {
  await db.collection("delivery_requests").doc(MISSION_ID).set({
    customer_id: "pickup_customer_001",
    driver_id: driverId,
    status,
    item_category_key: "furniture",
    description: "Test completePickup.",
    required_vehicle_category: "cargoVan",
    driver_offer_amount: 85,
    customer_total: 100,
    created_at: admin.firestore.Timestamp.now(),
  });
  await db.collection("delivery_requests").doc(MISSION_ID).collection("stops").doc("stop_pickup").set({
    sequence: 0,
    type: "pickup",
    address: { line1: "123 rue Test", city: "Montréal" },
    completed_at: null,
  });
}

async function cleanup(): Promise<void> {
  const stops = await db.collection("delivery_requests").doc(MISSION_ID).collection("stops").get();
  await Promise.all(stops.docs.map((d) => d.ref.delete()));
  const events = await db.collection("delivery_requests").doc(MISSION_ID).collection("tracking_events").get();
  await Promise.all(events.docs.map((d) => d.ref.delete()));
  await db.collection("delivery_requests").doc(MISSION_ID).delete();
}

describe("completePickup — transitions valides depuis les 3 prédécesseurs autorisés", () => {
  afterEach(cleanup);

  it.each([MissionStatuses.ASSIGNED, MissionStatuses.DRIVER_TO_PICKUP, MissionStatuses.ARRIVED_AT_PICKUP])(
    "depuis '%s' -> picked_up réussit, marque le stop pickup complété et écrit un tracking_event",
    async (fromStatus) => {
      await seedMission(fromStatus);

      const result = await completePickup.run(buildRequest(DRIVER_ID, { missionId: MISSION_ID }));
      expect(result).toMatchObject({ success: true, missionId: MISSION_ID });

      const missionSnap = await db.collection("delivery_requests").doc(MISSION_ID).get();
      expect(missionSnap.data()!.status).toBe(MissionStatuses.PICKED_UP);

      const stopSnap = await db
        .collection("delivery_requests")
        .doc(MISSION_ID)
        .collection("stops")
        .doc("stop_pickup")
        .get();
      expect(stopSnap.data()!.completed_at).not.toBeNull();

      const events = await db
        .collection("delivery_requests")
        .doc(MISSION_ID)
        .collection("tracking_events")
        .where("event_type", "==", "picked_up")
        .get();
      expect(events.size).toBe(1);
    }
  );
});

describe("completePickup — cas négatifs", () => {
  afterEach(cleanup);

  it("un chauffeur qui n'est pas celui assigné ne peut PAS confirmer le ramassage", async () => {
    await seedMission(MissionStatuses.ASSIGNED, DRIVER_ID);
    await expect(
      completePickup.run(buildRequest(OTHER_DRIVER_ID, { missionId: MISSION_ID }))
    ).rejects.toMatchObject({ code: "permission-denied" });

    const missionSnap = await db.collection("delivery_requests").doc(MISSION_ID).get();
    expect(missionSnap.data()!.status).toBe(MissionStatuses.ASSIGNED);
  });

  it("depuis 'searching_driver' (pas encore assignée) échoue avec failed-precondition", async () => {
    await seedMission(MissionStatuses.SEARCHING_DRIVER);
    await expect(
      completePickup.run(buildRequest(DRIVER_ID, { missionId: MISSION_ID }))
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("depuis 'picked_up' (déjà ramassé, appel en double) échoue avec failed-precondition", async () => {
    await seedMission(MissionStatuses.PICKED_UP);
    await expect(
      completePickup.run(buildRequest(DRIVER_ID, { missionId: MISSION_ID }))
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("depuis 'completed' échoue avec failed-precondition (aucune régression possible)", async () => {
    await seedMission(MissionStatuses.COMPLETED);
    await expect(
      completePickup.run(buildRequest(DRIVER_ID, { missionId: MISSION_ID }))
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("mission introuvable échoue avec not-found", async () => {
    await expect(
      completePickup.run(buildRequest(DRIVER_ID, { missionId: "mission_inexistante" }))
    ).rejects.toMatchObject({ code: "not-found" });
  });

  it("missionId manquant échoue avec invalid-argument", async () => {
    await expect(
      // @ts-expect-error payload volontairement invalide
      completePickup.run(buildRequest(DRIVER_ID, {}))
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });
});
