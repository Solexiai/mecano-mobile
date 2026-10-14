// 1.3M-H — non-régression de la compensation GPS ; reprises G et nouveaux cas ciblés.
// Firestore Emulator réel ; FakePaymentProvider existant ; aucun provider externe.
import * as fs from "fs";
import type { CallableRequest, Request } from "firebase-functions/v2/https";
import type { DecodedIdToken } from "firebase-admin/auth";
import type { Change, FirestoreEvent, QueryDocumentSnapshot } from "firebase-functions/v2/firestore";
import type { AuthorizePaymentParams, AuthorizePaymentResult } from "../../src/payment/paymentProvider";
import { admin, db } from "../../src/lib/admin";
import { acceptDelivery } from "../../src/functions/acceptDelivery";
import { adminAssignDelivery } from "../../src/functions/adminAssignDelivery";
import { completeDelivery } from "../../src/functions/completeDelivery";
import { recordTrackingPoint } from "../../src/functions/recordTrackingPoint";
import { onMissionEndedClearTracking } from "../../src/functions/onMissionEndedClearTracking";
import { setPaymentProviderForTesting } from "../../src/payment/paymentProviderFactory";
import { FakePaymentProvider, buildFakePaymentProfile } from "../testUtils/fakePaymentProvider";
import { seedOfficialLegacyQuote } from "../testUtils/officialQuoteFixture";
import { seedDefaultRuntimeFlagsEnabled } from "../testUtils/runtimeFlagsFixture";
import { buildPricingConfig } from "../unit/fixtures";
import { assertIsolatedFirebaseTests } from "../testUtils/emulatorSafety";
assertIsolatedFirebaseTests(process.env);

const D="g_gps_driver", A="g_gps_A", B="g_gps_B", C="g_gps_customer", PV="g_gps_pricing";
const profile=db.doc("driver_profiles/"+D), location=db.doc("driver_locations/"+D);
const a=db.doc("delivery_requests/"+A), b=db.doc("delivery_requests/"+B);
function req<T>(data:T,uid=D,role="driver"):CallableRequest<T>{
 return {data,auth:{uid,token:{role} as unknown as DecodedIdToken,rawToken:"fictitious"},
 rawRequest:{} as Request,acceptsStreaming:false};
}
const gps=()=>recordTrackingPoint.run(req({latitude:45.5,longitude:-72.5}));
const assign=(id:string,actor:"driver"|"admin"="driver")=>actor==="driver"
 ?acceptDelivery.run(req({missionId:id}))
 :adminAssignDelivery.run(req({missionId:id,driverId:D,assignmentMode:"standard"},"g_gps_admin","admin"));
function event(before:Record<string,unknown>,after:Record<string,unknown>,id=A){
 return {params:{missionId:id},data:{before:{data:()=>before},after:{data:()=>after}}} as unknown as FirestoreEvent<Change<QueryDocumentSnapshot>,{missionId:string}>;
}
async function seedOpen(id:string){
 const pricing=buildPricingConfig({pricing_version:PV});
 const {quoteId,pricingResult}=await seedOfficialLegacyQuote({missionId:id,customerId:C,
 pricingConfig:pricing,distanceKm:10,estimatedDurationMinutes:20});
 await db.doc("delivery_requests/"+id).set({customer_id:C,driver_id:null,status:"searching_driver",
 required_vehicle_category:"cargoVan",pricing_version:PV,customer_total:pricingResult.customerTotal,
 customer_total_minor:Math.round(pricingResult.customerTotal*100),quote_breakdown:pricingResult,
 active_quote_id:quoteId,active_financial_snapshot_id:null,active_payment_id:null,assignment_mode:"standard"});
}
async function finalState(){
 const [p,l,ma,mb,h,pay]=await Promise.all([profile.get(),location.get(),a.get(),b.get(),
 location.collection("history").get(),db.collection("payments").where("customer_id","==",C).get()]);
 return {profile:p.data()??null,location:l.data()??null,A:ma.data()??null,B:mb.data()??null,
 history:h.docs.map(d=>({id:d.id,...d.data()})),payments:pay.docs.map(d=>({id:d.id,...d.data()}))};
}
beforeEach(async()=>{
 setPaymentProviderForTesting(new FakePaymentProvider());
 await seedDefaultRuntimeFlagsEnabled();
 await profile.set({uid:D,full_name:"Chauffeur fictif",status:"approved",online_status:"online",
 documents_all_valid:true,accepted_vehicle_categories:["cargoVan"],completed_missions:2});
 await db.doc("payment_profiles/"+C).set(buildFakePaymentProfile(C));
 await db.doc("pricing_versions/"+PV).set(buildPricingConfig({pricing_version:PV}));
 await seedOpen(A);await seedOpen(B);
});
afterEach(async()=>{
 jest.restoreAllMocks();
 const state=await finalState();
 if(process.env.MOVIK_GPS_STATE_LOG)fs.appendFileSync(process.env.MOVIK_GPS_STATE_LOG,
 JSON.stringify({test:expect.getState().currentTestName,state})+"\n");
 setPaymentProviderForTesting(null);
 for(const ref of [a,b]){
  await db.recursiveDelete(ref);
  await db.doc("delivery_quotes/quote_"+ref.id).delete();
  for(const name of ["financial_snapshots","transaction_ledger","payments","audit_logs"]){
   const docs=await db.collection(name).where("mission_id","==",ref.id).get();
   await Promise.all(docs.docs.map(d=>d.ref.delete()));
  }
 }
 await Promise.all([profile.delete(),db.recursiveDelete(location),db.doc("payment_profiles/"+C).delete(),
 db.doc("pricing_versions/"+PV).delete()]);
});

describe("R-K-03-B — reprises exactes des deux tests rouges 1.3M-G",()=>{
 it.each(["driver","admin"] as const)("échec d'autorisation A tardif après B — assignation A via %s",async actor=>{
  let entered!:()=>void,release!:()=>void;
  const inside=new Promise<void>(r=>{entered=r;});
  const barrier=new Promise<void>(r=>{release=r;});
  class DelayedFailure extends FakePaymentProvider{
   private first=true;
   async authorizePayment(params:AuthorizePaymentParams):Promise<AuthorizePaymentResult>{
    if(this.first){this.first=false;entered();await barrier;return {success:false,status:"failed",
      authorizationExpiresAt:null,failureCode:"SIMULATED_DELAYED_FAILURE",failureMessage:"Échec fictif tardif de A"};}
    return super.authorizePayment(params);
   }
  }
  setPaymentProviderForTesting(new DelayedFailure());
  const first=assign(A,actor).then((value:unknown)=>({value,error:null}), (e:{code:string})=>({value:null,error:e.code}));
  try{
   await Promise.race([inside,first.then(()=>{throw Error("A finished before authorization barrier");})]);
   expect((await location.get()).get("active_delivery_id")).toBe(A);
   await assign(B);
   expect((await b.get()).get("status")).toBe("assigned");
   expect((await location.get()).get("active_delivery_id")).toBe(B);
  }finally{release();}
  const outcome=await first;
  expect(outcome.error).toBe("failed-precondition");
  const s=await finalState();
  expect(s.A?.status).toBe("payment_failed");
  expect(s.B?.status).toBe("assigned");
  expect(s.location?.active_delivery_id).toBe(B);
  expect(s.profile?.online_status).toBe("on_mission");
 });
});

function deferredFailure() {
  let entered!: () => void, release!: () => void;
  const waiting = new Promise<void>(resolve => { entered = resolve; });
  const barrier = new Promise<void>(resolve => { release = resolve; });
  class DeferredProvider extends FakePaymentProvider {
    private first = true;
    async authorizePayment(params: AuthorizePaymentParams): Promise<AuthorizePaymentResult> {
      if (!this.first) return super.authorizePayment(params);
      this.first = false;
      entered();
      await barrier;
      return { success: false, status: "failed", authorizationExpiresAt: null,
        failureCode: "SIMULATED_DELAYED_FAILURE", failureMessage: "Échec fictif différé" };
    }
  }
  const provider = new DeferredProvider();
  const calls = { create: jest.spyOn(provider, "createPayment"),
    authorize: jest.spyOn(provider, "authorizePayment"), capture: jest.spyOn(provider, "capturePayment"),
    cancel: jest.spyOn(provider, "cancelAuthorization"), refund: jest.spyOn(provider, "refundPayment") };
  setPaymentProviderForTesting(provider);
  return { provider, calls, release, wait: async (started: Promise<unknown>) => {
    await Promise.race([waiting, started.then(() => { throw Error("Assignment finished before barrier"); })]);
  } };
}
function startA(actor: "driver" | "admin" = "driver") {
  return assign(A, actor).then(
    (value: unknown) => ({ value, error: null }),
    (e: {code: string}) => ({ value: null, error: e.code }));
}
async function assertOneFailure(provider: FakePaymentProvider) {
  const mission = await a.get();
  expect(mission.get("status")).toBe("payment_failed");
  expect(mission.get("driver_id")).toBeNull();
  const payments = await db.collection("payments").where("mission_id", "==", A).get();
  expect(payments.size).toBe(1);
  const payment = payments.docs[0];
  expect(payment.get("status")).toBe("failed");
  expect(payment.get("amount_captured_minor")).toBe(0);
  expect(payment.get("amount_refunded_minor")).toBe(0);
  expect(payment.get("amount_requested_minor")).toBe(mission.get("customer_total_minor"));
  const requests = provider.createdPaymentParams.filter(p => p.metadata?.movik_mission_id === A);
  expect(requests).toHaveLength(1);
  expect(requests[0].amountMinor).toBe(payment.get("amount_requested_minor"));
  const events = await a.collection("tracking_events").where("event_type", "==", "payment_failed").get();
  expect(events.size).toBe(1);
  expect(events.docs[0].get("metadata.failure_code")).toBe("SIMULATED_DELAYED_FAILURE");
  expect((await db.collection("transaction_ledger").where("mission_id", "==", A).get()).size).toBe(0);
}
async function snapshotA() {
  const snapId = (await a.get()).get("active_financial_snapshot_id") as string;
  return (await db.doc("financial_snapshots/" + snapId).get()).data();
}
// Reprise réelle par le SDK après ABORTED injecté : première tentative annulée,
// mutation concurrente committée avant la deuxième tentative, jamais un faux résultat.
function retryCompensation(mutate: () => Promise<void>) {
  type Body = (tx: FirebaseFirestore.Transaction) => Promise<unknown>;
  const original = db.runTransaction.bind(db) as (fn: Body) => Promise<unknown>;
  let firstTransaction = true, attempts = 0, sawActiveRead = false;
  const spy = jest.spyOn(db, "runTransaction").mockImplementation(((fn: Body) => {
    if (!firstTransaction) return original(fn);
    firstTransaction = false;
    return original(async tx => {
      attempts++;
      if (attempts === 2) await mutate();
      const get = tx.get.bind(tx);
      tx.get = (async (ref: FirebaseFirestore.DocumentReference) => {
        if (ref.path === location.path) sawActiveRead = true;
        return get(ref);
      }) as typeof tx.get;
      const result = await fn(tx);
      if (attempts === 1) throw Object.assign(new Error("SIMULATED_ABORTED_COMPENSATION"), { code: 10 });
      return result;
    });
  }) as typeof db.runTransaction);
  return { restore: () => spy.mockRestore(),
    verify: () => { expect(attempts).toBeGreaterThanOrEqual(2); expect(sawActiveRead).toBe(true); } };
}

describe("R-K-03-B — compensation tardive, régressions 1.3M-H", () => {
  it.each(["current", "null", "missing"] as const)("échec normal A : lien %s, libération unique, finance préservée", async link => {
    const fake = deferredFailure(), pending = startA();
    await fake.wait(pending);
    const financialBefore = await snapshotA();
    if (link === "null") await location.update({ active_delivery_id: null });
    if (link === "missing") await location.delete();
    fake.release();
    expect((await pending).error).toBe("failed-precondition");
    expect((await location.get()).get("active_delivery_id")).toBeNull();
    expect((await profile.get()).get("online_status")).toBe("online");
    expect(await snapshotA()).toEqual(financialBefore);
    await assertOneFailure(fake.provider);
    const locBeforeRetry = await location.get(), profileBeforeRetry = await profile.get();
    await expect(assign(A)).rejects.toMatchObject({ code: "failed-precondition" });
    expect((await location.get()).updateTime).toEqual(locBeforeRetry.updateTime);
    expect((await profile.get()).updateTime).toEqual(profileBeforeRetry.updateTime);
    await assertOneFailure(fake.provider);
    expect(fake.calls.create).toHaveBeenCalledTimes(1);
    expect(fake.calls.authorize).toHaveBeenCalledTimes(1);
    for (const call of [fake.calls.capture, fake.calls.cancel, fake.calls.refund]) expect(call).not.toHaveBeenCalled();
  });
  it.each(["driver", "admin"] as const)("retry de compensation A via %s après assignation B conserve B et les effets uniques", async actor => {
    const fake = deferredFailure(), pending = startA(actor);
    await fake.wait(pending);
    const financialBefore = await snapshotA();
    let bBefore: FirebaseFirestore.DocumentData | undefined;
    const retry = retryCompensation(async () => { await assign(B); bBefore = (await b.get()).data(); });
    fake.release();
    try { expect((await pending).error).toBe("failed-precondition"); retry.verify(); }
    finally { retry.restore(); }
    expect((await location.get()).get("active_delivery_id")).toBe(B);
    expect((await profile.get()).get("online_status")).toBe("on_mission");
    expect((await b.get()).data()).toEqual(bBefore);
    expect(await snapshotA()).toEqual(financialBefore);
    await assertOneFailure(fake.provider);
    expect(fake.calls.create).toHaveBeenCalledTimes(2);
    expect(fake.calls.authorize).toHaveBeenCalledTimes(2);
    for (const call of [fake.calls.capture, fake.calls.cancel, fake.calls.refund]) expect(call).not.toHaveBeenCalled();
  });
  it("retry sans B : une seule libération committée et aucun effet financier répété", async () => {
    const fake = deferredFailure(), pending = startA();
    await fake.wait(pending);
    const retry = retryCompensation(async () => { /* aucune mutation concurrente */ });
    fake.release();
    try { expect((await pending).error).toBe("failed-precondition"); retry.verify(); }
    finally { retry.restore(); }
    expect((await location.get()).get("active_delivery_id")).toBeNull();
    expect((await profile.get()).get("online_status")).toBe("online");
    await assertOneFailure(fake.provider);
    expect(fake.calls.create).toHaveBeenCalledTimes(1);
    expect(fake.calls.authorize).toHaveBeenCalledTimes(1);
    for (const call of [fake.calls.capture, fake.calls.cancel, fake.calls.refund]) expect(call).not.toHaveBeenCalled();
  });
  it("l'échec A ne modifie ni la mission B ni le GPS/disponibilité de son autre chauffeur", async () => {
    const fake = deferredFailure(), pending = startA();
    await fake.wait(pending);
    const other = "h_other_driver";
    const otherProfile = db.doc("driver_profiles/" + other), otherLocation = db.doc("driver_locations/" + other);
    try {
      await otherProfile.set({ ...(await profile.get()).data(), uid: other, online_status: "online" });
      await acceptDelivery.run(req({ missionId: B }, other));
      const before = { b: (await b.get()).data(), p: (await otherProfile.get()).data(),
        l: (await otherLocation.get()).data() };
      fake.release();
      expect((await pending).error).toBe("failed-precondition");
      expect((await b.get()).data()).toEqual(before.b);
      expect((await otherProfile.get()).data()).toEqual(before.p);
      expect((await otherLocation.get()).data()).toEqual(before.l);
      expect((await b.get()).get("driver_id")).toBe(other);
      expect((await otherLocation.get()).get("active_delivery_id")).toBe(B);
      expect((await otherProfile.get()).get("online_status")).toBe("on_mission");
      expect((await location.get()).get("active_delivery_id")).toBeNull();
      expect((await profile.get()).get("online_status")).toBe("online");
      await assertOneFailure(fake.provider);
    } finally {
      fake.release(); await pending;
      await Promise.all([otherProfile.delete(), db.recursiveDelete(otherLocation)]);
    }
  });
});
