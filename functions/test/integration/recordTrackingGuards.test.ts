// R-K-03-A : vérification serveur atomique, uniquement Firestore Emulator demo-*.
import type { CallableRequest, Request } from "firebase-functions/v2/https";
import type { DecodedIdToken } from "firebase-admin/auth";
import { recordTrackingPoint, RecordTrackingPointRequest } from "../../src/functions/recordTrackingPoint";
import { admin, db } from "../../src/lib/admin";
import { assertIsolatedFirebaseTests } from "../testUtils/emulatorSafety";

assertIsolatedFirebaseTests(process.env);
const DRIVER = "rkf_guard_driver";
const MISSION = "rkf_guard_mission";
const profile = db.doc("driver_profiles/" + DRIVER);
const location = db.doc("driver_locations/" + DRIVER);
const mission = db.doc("delivery_requests/" + MISSION);
const request: CallableRequest<RecordTrackingPointRequest> = {
  data: { latitude: 45.5, longitude: -72.5 },
  auth: { uid: DRIVER, token: { role: "driver" } as unknown as DecodedIdToken, rawToken: "fictitious" },
  rawRequest: {} as Request, acceptsStreaming: false,
};
async function seed(status: string, approval = "approved", owner = DRIVER) {
  await profile.set({ status: approval, current_geohash: "unchanged" });
  await mission.set({ driver_id: owner, customer_id: "rkf_guard_client", status });
  await location.set({ active_delivery_id: MISSION, latitude: 1, longitude: 2 });
}
async function unchanged() {
  expect((await location.get()).data()).toEqual({ active_delivery_id: MISSION, latitude: 1, longitude: 2 });
  expect((await profile.get()).get("current_geohash")).toBe("unchanged");
  expect((await location.collection("history").get()).size).toBe(0);
}
afterEach(async () => {
  const h = await location.collection("history").get();
  await Promise.all(h.docs.map(d => d.ref.delete()));
  await Promise.all([profile.delete(), location.delete(), mission.delete()]);
});
afterAll(async () => { await Promise.all(admin.apps.map(app => app!.delete())); });
describe("R-K-03-A/B — gardes serveur", () => {
  it.each(["completed", "cancelled", "disputed", "refunded", "delivered", "payment_failed"])(
    "refuse mission terminale %s sans aucune mutation GPS", async status => {
      await seed(status);
      await expect(recordTrackingPoint.run(request)).rejects.toMatchObject({ code: "failed-precondition" });
      await unchanged();
    });
  it.each(["suspended", "rejected", "pending_review", "registration_incomplete", "documents_required", "inactive"])(
    "refuse profil non approuvé %s sans aucune mutation GPS", async status => {
      await seed("in_transit", status);
      await expect(recordTrackingPoint.run(request)).rejects.toMatchObject({ code: "permission-denied" });
      await unchanged();
    });
  it.each(["draft", "quoted", "searching_driver", "offered"])(
    "refuse mission non active %s", async status => {
      await seed(status);
      await expect(recordTrackingPoint.run(request)).rejects.toMatchObject({ code: "failed-precondition" });
      await unchanged();
    });
  it.each(["assigned", "driver_to_pickup", "arrived_at_pickup", "picked_up", "in_transit", "arrived_at_dropoff"])(
    "autorise chauffeur approuvé sur mission %s", async status => {
      await seed(status);
      await expect(recordTrackingPoint.run(request)).resolves.toEqual({ success: true });
      const h = await location.collection("history").get();
      expect(h.size).toBe(1);
      expect(h.docs[0].get("delivery_id")).toBe(MISSION);
      expect((await location.get()).get("active_delivery_id")).toBe(MISSION);
    });
  it("refuse le lien à une mission appartenant à un autre chauffeur", async () => {
    await seed("in_transit", "approved", "rkf_other_driver");
    await expect(recordTrackingPoint.run(request)).rejects.toMatchObject({ code: "permission-denied" });
    await unchanged();
  });
  it("refuse une mission référencée inexistante sans écriture partielle", async () => {
    await seed("in_transit");
    await mission.delete();
    await expect(recordTrackingPoint.run(request)).rejects.toMatchObject({ code: "failed-precondition" });
    await unchanged();
  });
  it.each([null, "absent"])("sans assignation (%s), actualise la position sans historique", async active => {
    await profile.set({ status: "approved" });
    if (active === null) await location.set({ active_delivery_id: null });
    await expect(recordTrackingPoint.run(request)).resolves.toEqual({ success: true });
    expect((await location.get()).get("latitude")).toBe(45.5);
    expect((await location.collection("history").get()).size).toBe(0);
  });
});
