import type { CallableRequest, Request } from "firebase-functions/v2/https";
import type { DecodedIdToken } from "firebase-admin/auth";
import { recordTrackingPoint, RecordTrackingPointRequest } from "../../src/functions/recordTrackingPoint";
import { admin, db } from "../../src/lib/admin";

const DRIVER = "rka_callable_driver";
const MISSION = "rka_callable_mission";
function request(claims: Record<string, unknown>): CallableRequest<RecordTrackingPointRequest> {
  return { data: { latitude: 45.5, longitude: -72.5 },
    auth: { uid: DRIVER, token: claims as DecodedIdToken, rawToken: "fictitious-emulator-token" },
    rawRequest: {} as Request, acceptsStreaming: false };
}
async function seed() {
  await db.collection("driver_profiles").doc(DRIVER).set({ status: "approved", current_geohash: "unchanged" });
  await db.collection("delivery_requests").doc(MISSION).set({ driver_id: DRIVER, customer_id: "rka_client", status: "in_transit" });
  await db.collection("driver_locations").doc(DRIVER).set({ active_delivery_id: MISSION, latitude: 0, longitude: 0 });
}
afterEach(async () => {
  const history = await db.collection("driver_locations").doc(DRIVER).collection("history").get();
  await Promise.all(history.docs.map(d => d.ref.delete()));
  await Promise.all([
    db.collection("driver_profiles").doc(DRIVER).delete(),
    db.collection("driver_locations").doc(DRIVER).delete(),
    db.collection("delivery_requests").doc(MISSION).delete(),
  ]);
});
afterAll(async () => { await Promise.all(admin.apps.map(app => app!.delete())); });

describe("R-K-03-A — rôle du callable", () => {
  it.each([{}, {role: "customer"}, {role: "analyst"}, {role: "admin"}, {role: "super_admin"}])(
    "refuse un appel sans rôle chauffeur : %j", async claims => {
      await seed();
      await expect(recordTrackingPoint.run(request(claims))).rejects.toMatchObject({code: "permission-denied"});
      expect((await db.collection("driver_locations").doc(DRIVER).get()).data()?.latitude).toBe(0);
      expect((await db.collection("driver_profiles").doc(DRIVER).get()).data()?.current_geohash).toBe("unchanged");
      expect((await db.collection("driver_locations").doc(DRIVER).collection("history").get()).empty).toBe(true);
    });
  it.each([{role: "driver"}, {role: "customer", roles: ["customer", "driver"]}])(
    "conserve le chauffeur approuvé et les comptes multirôles : %j", async claims => {
      await seed();
      await expect(recordTrackingPoint.run(request(claims))).resolves.toEqual({success: true});
      const location = (await db.collection("driver_locations").doc(DRIVER).get()).data()!;
      expect(location.active_delivery_id).toBe(MISSION);
      expect(location.latitude).toBe(45.5);
      expect((await db.collection("driver_locations").doc(DRIVER).collection("history").get()).size).toBe(1);
    });
});
