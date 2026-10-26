// GAP-S-04: ordinary vs urgent suspension authority, tested against
// Firestore/Auth emulators. All missions here are internal-test only:
// no Stripe authorization, ledger, or live provider activity.
import type { CallableRequest, Request } from "firebase-functions/v2/https";
import type { DecodedIdToken } from "firebase-admin/auth";
import { admin, db } from "../../src/lib/admin";
import { MissionStatuses } from "../../src/lib/types";
import { suspendDriver } from "../../src/functions/suspendDriver";
import { reactivateDriver } from "../../src/functions/reactivateDriver";
import { completePickup } from "../../src/functions/completePickup";
import { completeDelivery } from "../../src/functions/completeDelivery";
import { updateMissionTrackingStatus } from "../../src/functions/updateMissionTrackingStatus";
import { recordTrackingPoint } from "../../src/functions/recordTrackingPoint";

const DRIVER = "gap_s04_driver";
const ADMIN = "gap_s04_admin";
const MISSION = "gap_s04_mission";
const profileRef = db.collection("driver_profiles").doc(DRIVER);
const missionRef = db.collection("delivery_requests").doc(MISSION);
const locationRef = db.collection("driver_locations").doc(DRIVER);

function request<T>(uid: string, data: T, role: "driver" | "admin" = "driver"): CallableRequest<T> {
  return {
    data,
    auth: { uid, token: { role, roles: [role] } as unknown as DecodedIdToken, rawToken: "emulator-only" },
    rawRequest: {} as Request,
    acceptsStreaming: false,
  };
}

async function seed(status: string = MissionStatuses.ASSIGNED): Promise<void> {
  await Promise.all([
    profileRef.set({
      uid: DRIVER, status: "approved", online_status: "on_mission",
      completed_missions: 0,
    }),
    missionRef.set({
      customer_id: "gap_s04_customer",
      driver_id: DRIVER,
      status,
      assignment_mode: "internal_test",
      active_financial_snapshot_id: null,
      active_payment_id: null,
      created_at: admin.firestore.Timestamp.now(),
    }),
    locationRef.set({ driver_id: DRIVER, active_delivery_id: MISSION }),
  ]);
}

async function suspend(mode: "ordinary" | "urgent"): Promise<void> {
  await suspendDriver.run(request(ADMIN, {
    driverId: DRIVER,
    reason: "Contrôle administratif autorisé pour ce test.",
    suspensionMode: mode,
  }, "admin"));
}

async function cleanup(): Promise<void> {
  const [events, stops, history, audit] = await Promise.all([
    missionRef.collection("tracking_events").get(),
    missionRef.collection("stops").get(),
    locationRef.collection("history").get(),
    db.collection("audit_logs").where("target_id", "in", [MISSION, DRIVER]).get(),
  ]);
  await Promise.all([
    ...events.docs.map((x) => x.ref.delete()),
    ...stops.docs.map((x) => x.ref.delete()),
    ...history.docs.map((x) => x.ref.delete()),
    ...audit.docs.map((x) => x.ref.delete()),
    profileRef.delete(),
    missionRef.delete(),
    locationRef.delete(),
  ]);
}

describe("GAP-S-04 suspension policy for assigned missions", () => {
  afterEach(cleanup);

  it("ordinary suspension permits assigned pickup while keeping driver offline", async () => {
    await seed();
    await suspend("ordinary");
    const profile = (await profileRef.get()).data()!;
    expect(profile.status).toBe("suspended");
    expect(profile.suspension_mode).toBe("ordinary");
    expect(profile.online_status).toBe("offline");
    await completePickup.run(request(DRIVER, { missionId: MISSION, proofOfPickupUrl: "https://storage.example.test/delivery_proofs/pickup_proof.jpg" }));
    expect((await missionRef.get()).data()?.status).toBe(MissionStatuses.PICKED_UP);
    expect((await profileRef.get()).data()?.online_status).toBe("offline");
  });

  it("ordinary suspension permits delivery completion but never restores online availability", async () => {
    await seed(MissionStatuses.PICKED_UP);
    await suspend("ordinary");
    const result = await completeDelivery.run(request(DRIVER, {
      missionId: MISSION, proofOfDeliveryUrl: "https://example.invalid/only-test-proof",
    }));
    expect(result.success).toBe(true);
    expect(result.internalTest).toBe(true);
    expect((await missionRef.get()).data()?.status).toBe(MissionStatuses.COMPLETED);
    expect((await profileRef.get()).data()?.online_status).toBe("offline");
    const ledgers = await db.collection("transaction_ledger").where("mission_id", "==", MISSION).get();
    expect(ledgers.empty).toBe(true);
  });

  it("urgent suspension blocks pickup without mission or tracking side effects", async () => {
    await seed();
    await suspend("urgent");
    await expect(completePickup.run(request(DRIVER, { missionId: MISSION, proofOfPickupUrl: "https://storage.example.test/delivery_proofs/pickup_proof.jpg" })))
      .rejects.toMatchObject({ code: "permission-denied" });
    expect((await missionRef.get()).data()?.status).toBe(MissionStatuses.ASSIGNED);
    expect((await missionRef.collection("tracking_events").get()).empty).toBe(true);
  });

  it("urgent suspension blocks delivery before confirmation or ledger writes", async () => {
    await seed(MissionStatuses.PICKED_UP);
    await suspend("urgent");
    await expect(completeDelivery.run(request(DRIVER, {
      missionId: MISSION, proofOfDeliveryUrl: "https://example.invalid/only-test-proof",
    }))).rejects.toMatchObject({ code: "permission-denied" });
    expect((await missionRef.get()).data()?.status).toBe(MissionStatuses.PICKED_UP);
    expect((await db.collection("transaction_ledger").where("mission_id", "==", MISSION).get()).empty)
      .toBe(true);
  });

  it("urgent suspension blocks intermediate status and GPS", async () => {
    await seed();
    await suspend("urgent");
    await expect(updateMissionTrackingStatus.run(request(DRIVER, {
      missionId: MISSION, targetStatus: MissionStatuses.DRIVER_TO_PICKUP,
    }))).rejects.toMatchObject({ code: "permission-denied" });
    await expect(recordTrackingPoint.run(request(DRIVER, {
      latitude: 45.5, longitude: -73.5,
    }))).rejects.toMatchObject({ code: "permission-denied" });
    expect((await missionRef.get()).data()?.status).toBe(MissionStatuses.ASSIGNED);
  });

  it("ordinary suspension permits intermediate status and GPS for the existing mission only", async () => {
    await seed();
    await suspend("ordinary");
    await updateMissionTrackingStatus.run(request(DRIVER, {
      missionId: MISSION, targetStatus: MissionStatuses.DRIVER_TO_PICKUP,
    }));
    await expect(recordTrackingPoint.run(request(DRIVER, {
      latitude: 45.5, longitude: -73.5,
    }))).resolves.toMatchObject({ success: true });
    expect((await missionRef.get()).data()?.status).toBe(MissionStatuses.DRIVER_TO_PICKUP);
    await locationRef.update({ active_delivery_id: null });
    await expect(recordTrackingPoint.run(request(DRIVER, {
      latitude: 45.5, longitude: -73.5,
    }))).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("legacy suspended profile without a mode is urgent by default", async () => {
    await seed();
    await profileRef.update({ status: "suspended", online_status: "offline" });
    await expect(completePickup.run(request(DRIVER, { missionId: MISSION, proofOfPickupUrl: "https://storage.example.test/delivery_proofs/pickup_proof.jpg" })))
      .rejects.toMatchObject({ code: "permission-denied" });
    await expect(recordTrackingPoint.run(request(DRIVER, {
      latitude: 45.5, longitude: -73.5,
    }))).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("administrator may escalate ordinary suspension without reactivating", async () => {
    await seed();
    await suspend("ordinary");
    await suspend("urgent");
    expect((await profileRef.get()).data()?.suspension_mode).toBe("urgent");
    await expect(completePickup.run(request(DRIVER, { missionId: MISSION, proofOfPickupUrl: "https://storage.example.test/delivery_proofs/pickup_proof.jpg" })))
      .rejects.toMatchObject({ code: "permission-denied" });
    await expect(suspendDriver.run(request(ADMIN, {
      driverId: DRIVER, reason: "No second urgent suspension.", suspensionMode: "urgent",
    }, "admin"))).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("reactivation clears suspension mode and restores mission progress permission", async () => {
    await seed();
    await suspend("urgent");
    await reactivateDriver.run(request(ADMIN, { driverId: DRIVER }, "admin"));
    const profile = (await profileRef.get()).data()!;
    expect(profile.status).toBe("approved");
    expect(profile.suspension_mode).toBeNull();
    await completePickup.run(request(DRIVER, { missionId: MISSION, proofOfPickupUrl: "https://storage.example.test/delivery_proofs/pickup_proof.jpg" }));
    expect((await missionRef.get()).data()?.status).toBe(MissionStatuses.PICKED_UP);
  });

  it("suspension mode is admin-only and rejects unsupported values", async () => {
    await seed();
    await expect(suspendDriver.run(request(DRIVER, {
      driverId: DRIVER, reason: "Invalid driver attempt", suspensionMode: "urgent",
    }))).rejects.toMatchObject({ code: "permission-denied" });
    await expect(suspendDriver.run(request(ADMIN, {
      driverId: DRIVER, reason: "Invalid suspension value",
      suspensionMode: "auto" as "urgent",
    }, "admin"))).rejects.toMatchObject({ code: "invalid-argument" });
    expect((await profileRef.get()).data()?.status).toBe("approved");
  });
});
