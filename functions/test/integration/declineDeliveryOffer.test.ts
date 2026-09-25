import { randomUUID } from "crypto";
import type { CallableRequest, Request } from "firebase-functions/v2/https";
import type { DecodedIdToken } from "firebase-admin/auth";
import { admin, db } from "../../src/lib/admin";
import { declineDeliveryOffer } from "../../src/functions/declineDeliveryOffer";

// setupSafety runs BEFORE imports; all documents live in demo emulators only.
// Unique fixtures require no destructive cleanup and never invoke payments.
function request(uid: string | undefined, offerId: string): CallableRequest<{ offerId: string }> {
  return { data: { offerId }, auth: uid ? { uid, token: {} as DecodedIdToken, rawToken: "emulator-only" } : undefined,
    rawRequest: {} as Request, acceptsStreaming: false };
}
async function fixture(expired = false, assigned = false) {
  const uid = `offer-driver-${randomUUID()}`;
  const offerId = randomUUID(); const missionId = randomUUID();
  const mission = db.collection("delivery_requests").doc(missionId);
  const offer = db.collection("delivery_offers").doc(offerId);
  await mission.set({ status: assigned ? "assigned" : "offered", driver_id: assigned ? "another-driver" : null });
  await offer.set({ mission_id: missionId, driver_id: uid, status: "pending",
    expires_at: admin.firestore.Timestamp.fromMillis(Date.now() + (expired ? -1000 : 60000)) });
  return { uid, offerId, mission, offer };
}

test("requires authentication and a valid offer identifier", async () => {
  await expect(declineDeliveryOffer.run(request(undefined, "test"))).rejects.toMatchObject({ code: "unauthenticated" });
  await expect(declineDeliveryOffer.run(request("driver", "bad/path"))).rejects.toMatchObject({ code: "invalid-argument" });
});
test("another driver cannot decline the offer", async () => {
  const f = await fixture();
  await expect(declineDeliveryOffer.run(request("other-driver", f.offerId))).rejects.toMatchObject({ code: "permission-denied" });
  expect((await f.offer.get()).data()!.status).toBe("pending");
});
test("repeated concurrent declines are idempotent and never alter the mission", async () => {
  const f = await fixture(); const before = (await f.mission.get()).data();
  await Promise.all(Array.from({ length: 5 }, () => declineDeliveryOffer.run(request(f.uid, f.offerId))));
  const first = await f.offer.get();
  expect(first.data()!.status).toBe("declined");
  await declineDeliveryOffer.run(request(f.uid, f.offerId));
  expect((await f.offer.get()).updateTime!.isEqual(first.updateTime!)).toBe(true);
  expect((await f.mission.get()).data()).toEqual(before);
});
test("an expired offer is not recorded as a fresh decline", async () => {
  const f = await fixture(true);
  await declineDeliveryOffer.run(request(f.uid, f.offerId));
  expect((await f.offer.get()).data()!.status).toBe("expired");
});
test("an already assigned mission is not reopened", async () => {
  const f = await fixture(false, true);
  await declineDeliveryOffer.run(request(f.uid, f.offerId));
  expect((await f.offer.get()).data()!.status).toBe("superseded");
  expect((await f.mission.get()).data()!.driver_id).toBe("another-driver");
});
