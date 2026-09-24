// Runs only behind setupSafety.ts against demo-movik-test emulators.
import { admin, db } from "../../src/lib/admin";
import { createTestEnv } from "./setup";
import type { RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { onMissionCreatedDispatch, onDriverBecameAvailableDispatch, onMissionReopenedDispatch,
  processDeliveryOfferExpirations } from "../../src/functions/dispatchMissionToDrivers";
import { deliveryOfferId } from "../../src/lib/dispatchEligibility";
import { acceptDelivery } from "../../src/functions/acceptDelivery";
import { declineDeliveryOffer } from "../../src/functions/declineDeliveryOffer";
import * as push from "../../src/lib/pushNotifications";
let env: RulesTestEnvironment;
beforeAll(async () => { env = await createTestEnv(); });
beforeEach(async () => { await env.clearFirestore(); jest.spyOn(push, "sendDeliveryOfferPush").mockResolvedValue({attempted:0,sent:0}); });
afterEach(async () => { jest.restoreAllMocks(); await env.clearFirestore(); });
afterAll(async () => { await env.cleanup(); });
const point = { lat: 45.5, lng: -73.6 };
async function driver(id: string, changes: Record<string, unknown> = {}) {
  const data = { full_name: id, status: "approved", online_status: "online", documents_all_valid: true,
    accepted_vehicle_categories: ["car"], service_radius_km: 5, base_lat: point.lat, base_lng: point.lng, ...changes };
  await db.collection("driver_profiles").doc(id).set(data); return data;
}
async function mission(id: string, pickup = point) {
  const data = { customer_id: "test-customer", status: "searching_driver", driver_id: null,
    required_vehicle_category: "car", pickup_address: pickup,
    assignment_mode: "internal_test", internal_test_authorized: true };
  await db.collection("delivery_requests").doc(id).set(data); return data;
}
const createdEvent = (id: string, data: Record<string, unknown>) => ({params:{missionId:id},data:{data:()=>data}}) as Parameters<typeof onMissionCreatedDispatch.run>[0];
const req = (uid: string, data: { missionId: string }) => ({ auth:{uid,token:{},rawToken:"test"},data,rawRequest:{},acceptsStreaming:false }) as Parameters<typeof acceptDelivery.run>[0];
const offerRef = (m: string, d: string) => db.collection("delivery_offers").doc(deliveryOfferId(m,d));
async function dispatch(m = "mission") { const data=(await db.collection("delivery_requests").doc(m).get()).data()!; await onMissionCreatedDispatch.run(createdEvent(m,data)); }

test("real radius includes adjacent cells and excludes far drivers in the same cell", async () => {
  await driver("near", {base_lng:-73.1251}); await driver("far");
  await mission("mission", {lat:45.5,lng:-73.1249}); await dispatch();
  const offers=await db.collection("delivery_offers").get();
  expect(offers.docs.map(d=>d.data().driver_id)).toEqual(["near"]);
});
test("duplicate and concurrent delivery events create one offer and one push per driver", async () => {
  await driver("one"); const data=await mission("mission");
  await Promise.all([onMissionCreatedDispatch.run(createdEvent("mission",data)),onMissionCreatedDispatch.run(createdEvent("mission",data))]);
  await onMissionCreatedDispatch.run(createdEvent("mission",data));
  expect((await db.collection("delivery_offers").get()).size).toBe(1);
  expect(push.sendDeliveryOfferPush).toHaveBeenCalledTimes(1);
  expect((await offerRef("mission","one").get()).data()?.dispatch_version).toBe(2);
});
test("stale creation event cannot reopen an assigned mission", async () => {
  await driver("one"); const data=await mission("mission");
  await db.collection("delivery_requests").doc("mission").update({driver_id:"other",status:"assigned"});
  await onMissionCreatedDispatch.run(createdEvent("mission",data));
  expect((await db.collection("delivery_offers").get()).empty).toBe(true);
  expect((await db.collection("delivery_requests").doc("mission").get()).data()?.status).toBe("assigned");
});
test("only the offered available driver can accept, and losing offers close atomically", async () => {
  await driver("one"); await driver("two"); await driver("not-offered",{online_status:"offline"});
  await mission("mission"); await dispatch();
  await expect(acceptDelivery.run(req("not-offered",{missionId:"mission"}))).rejects.toMatchObject({code:"failed-precondition"});
  const results=await Promise.allSettled([acceptDelivery.run(req("one",{missionId:"mission"})),acceptDelivery.run(req("two",{missionId:"mission"}))]);
  expect(results.filter(r=>r.status==="fulfilled")).toHaveLength(1);
  const offers=(await db.collection("delivery_offers").get()).docs.map(d=>d.data().status).sort();
  expect(offers).toEqual(["accepted","superseded"]);
  expect((await db.collection("payments").get()).empty).toBe(true);
});
test.each(["expired","declined","busy","out-of-radius"])("rejects %s before assignment", async (reason) => {
  await driver("one"); await mission("mission"); await dispatch();
  if(reason==="expired") await offerRef("mission","one").update({expires_at:admin.firestore.Timestamp.fromMillis(1)});
  if(reason==="declined") await declineDeliveryOffer.run({auth:{uid:"one"},data:{offerId:deliveryOfferId("mission","one")}} as Parameters<typeof declineDeliveryOffer.run>[0]);
  if(reason==="busy") await db.collection("driver_profiles").doc("one").update({online_status:"on_mission"});
  if(reason==="out-of-radius") await db.collection("driver_profiles").doc("one").update({base_lat:46.5});
  await expect(acceptDelivery.run(req("one",{missionId:"mission"}))).rejects.toMatchObject({code:"failed-precondition"});
  expect((await db.collection("delivery_requests").doc("mission").get()).data()?.driver_id).toBeNull();
});
test("driver cannot accept two missions concurrently", async () => {
  await driver("one"); await mission("a"); await mission("b"); await dispatch("a"); await dispatch("b");
  const results=await Promise.allSettled([acceptDelivery.run(req("one",{missionId:"a"})),acceptDelivery.run(req("one",{missionId:"b"}))]);
  expect(results.filter(r=>r.status==="fulfilled")).toHaveLength(1);
});
test("expired offers reopen waiting and a newly available driver gets the same mission", async () => {
  await driver("one"); await mission("mission"); await dispatch();
  const past=admin.firestore.Timestamp.fromMillis(1);
  await offerRef("mission","one").update({expires_at:past});
  await db.collection("delivery_requests").doc("mission").update({dispatch_offer_expires_at:past});
  await processDeliveryOfferExpirations.run({} as Parameters<typeof processDeliveryOfferExpirations.run>[0]);
  expect((await offerRef("mission","one").get()).data()?.status).toBe("expired");
  expect((await db.collection("delivery_requests").doc("mission").get()).data()?.status).toBe("searching_driver");
  const available=await driver("two");
  await onDriverBecameAvailableDispatch.run({params:{driverId:"two"},data:{before:{data:()=>({...available,online_status:"on_mission"})},after:{data:()=>available}}} as unknown as Parameters<typeof onDriverBecameAvailableDispatch.run>[0]);
  expect((await offerRef("mission","two").get()).data()?.status).toBe("pending");
  expect((await db.collection("delivery_requests").get()).size).toBe(1);
});
test("cancelled mission closes outstanding offers", async () => {
  await driver("one"); await mission("mission"); await dispatch();
  await db.collection("delivery_requests").doc("mission").update({status:"cancelled"});
  await onMissionReopenedDispatch.run({params:{missionId:"mission"},data:{before:{data:()=>({status:"offered"})},after:{data:()=>({status:"cancelled"})}}} as unknown as Parameters<typeof onMissionReopenedDispatch.run>[0]);
  expect((await offerRef("mission","one").get()).data()?.status).toBe("superseded");
});
test("search continues past fifty ineligible drivers", async () => {
  await Promise.all(Array.from({length:50},(_,i)=>driver(`a-${String(i).padStart(3,'0')}`,{base_lat:50})));
  await driver("z-near"); await mission("mission"); await dispatch();
  expect((await offerRef("mission","z-near").get()).exists).toBe(true);
});
