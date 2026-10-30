// Admin: cancel a mission and remove it from the lists (2026-10-30).
import { db } from "../../src/lib/admin";
import { adminMissionActions } from "../../src/functions/adminMissionActions";

const call = (data: unknown, uid = "missions_admin", roles = ["admin"]) =>
  ({ data, auth: { uid, token: { roles, role: roles[0] } }, rawRequest: {}, acceptsStreaming: false } as any);

const MISSION = "admin_actions_mission_001";
const DRIVER = "admin_actions_driver_001";

async function seed(status: string, extra: Record<string, unknown> = {}) {
  await db.collection("delivery_requests").doc(MISSION).set({
    customer_id: "admin_actions_customer", status, created_at: new Date(), ...extra,
  });
}

afterEach(async () => {
  if (process.env.GCLOUD_PROJECT !== "demo-movik-test" || process.env.FIRESTORE_EMULATOR_HOST !== "127.0.0.1:8080") throw Error("cleanup isolation");
  for (const c of ["delivery_requests", "delivery_offers", "driver_profiles", "audit_logs"]) {
    await db.recursiveDelete(db.collection(c));
  }
});

test("admins only", async () => {
  await seed("searching_driver");
  await expect(adminMissionActions.run(call({ action: "cancel", missionId: MISSION }, "x", ["customer"])))
    .rejects.toMatchObject({ code: "permission-denied" });
  await expect(adminMissionActions.run(call({ action: "cancel", missionId: MISSION }, "x", ["analyst"])))
    .rejects.toMatchObject({ code: "permission-denied" });
});

test("cancel: no fee, offers closed, driver back online, audited", async () => {
  await seed("assigned", { driver_id: DRIVER, active_payment_id: "pay_1" });
  await db.collection("driver_profiles").doc(DRIVER).set({ online_status: "on_mission" });
  await db.collection("delivery_offers").doc("o1").set({ mission_id: MISSION, driver_id: DRIVER, status: "pending" });
  await db.collection("delivery_offers").doc("o2").set({ mission_id: MISSION, driver_id: "other", status: "declined" });

  const r = (await adminMissionActions.run(call({ action: "cancel", missionId: MISSION, reason: "Test interne" }))) as any;
  expect(r).toMatchObject({ success: true, previousStatus: "assigned" });

  const m = (await db.collection("delivery_requests").doc(MISSION).get()).data()!;
  expect(m).toMatchObject({
    status: "cancelled", cancelled_by: "admin", cancellation_reason: "admin_cancelled",
    admin_cancellation_note: "Test interne", cancellation_fee: null, cancelled_by_user_id: "missions_admin",
  });
  expect((await db.collection("delivery_offers").doc("o1").get()).data()!.status).toBe("expired");
  expect((await db.collection("delivery_offers").doc("o2").get()).data()!.status).toBe("declined");
  expect((await db.collection("driver_profiles").doc(DRIVER).get()).data()!.online_status).toBe("online");
  const logs = await db.collection("audit_logs").where("action", "==", "mission_cancelled_by_admin").get();
  expect(logs.size).toBe(1);
});

test("cancel: a finished mission is refused", async () => {
  await seed("completed");
  await expect(adminMissionActions.run(call({ action: "cancel", missionId: MISSION })))
    .rejects.toMatchObject({ code: "failed-precondition" });
  await seed("cancelled");
  await expect(adminMissionActions.run(call({ action: "cancel", missionId: MISSION })))
    .rejects.toMatchObject({ code: "failed-precondition" });
});

test("delete: only a finished mission, hidden but kept", async () => {
  await seed("searching_driver");
  await expect(adminMissionActions.run(call({ action: "delete", missionId: MISSION })))
    .rejects.toMatchObject({ code: "failed-precondition" });

  await seed("cancelled");
  const r = (await adminMissionActions.run(call({ action: "delete", missionId: MISSION }))) as any;
  expect(r).toMatchObject({ success: true });
  const m = await db.collection("delivery_requests").doc(MISSION).get();
  expect(m.exists).toBe(true);
  expect(m.data()).toMatchObject({ status: "cancelled", admin_archived: true, admin_archived_by: "missions_admin" });

  const again = (await adminMissionActions.run(call({ action: "delete", missionId: MISSION }))) as any;
  expect(again).toMatchObject({ success: true, alreadyDeleted: true });
});

test("invalid input", async () => {
  await expect(adminMissionActions.run(call({ action: "cancel", missionId: "a/b" })))
    .rejects.toMatchObject({ code: "invalid-argument" });
  await seed("cancelled");
  await expect(adminMissionActions.run(call({ action: "nope", missionId: MISSION })))
    .rejects.toMatchObject({ code: "invalid-argument" });
  await expect(adminMissionActions.run(call({ action: "cancel", missionId: "missing" })))
    .rejects.toMatchObject({ code: "not-found" });
});
