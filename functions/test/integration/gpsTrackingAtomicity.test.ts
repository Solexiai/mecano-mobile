// Transactions réelles sur Firestore Emulator. Les conflits déterministes sont
// injectés avec ABORTED après le premier callback : aucun commit de cet essai.
// La mutation concurrente est committée avant la reprise, puis l'état réel est lu.
// Paiement exclusivement simulé ; aucune fonction de provider n'est importée.
jest.mock("../../src/payment/paymentOrchestration", () => ({
  cancelMissionPaymentAuthorization: jest.fn(),
  captureMissionPayment: jest.fn(),
  createAndAuthorizeMissionPayment: jest.fn(() => { throw new Error("Payment forbidden in GPS tests"); }),
}));
import type { CallableRequest, Request } from "firebase-functions/v2/https";
import type { DecodedIdToken } from "firebase-admin/auth";
import type { Change, FirestoreEvent, QueryDocumentSnapshot } from "firebase-functions/v2/firestore";
import { admin, db } from "../../src/lib/admin";
import { recordTrackingPoint } from "../../src/functions/recordTrackingPoint";
import { onMissionEndedClearTracking } from "../../src/functions/onMissionEndedClearTracking";
import { completeDelivery } from "../../src/functions/completeDelivery";
import { acceptDelivery } from "../../src/functions/acceptDelivery";
import { adminAssignDelivery } from "../../src/functions/adminAssignDelivery";
import { cancelMissionPaymentAuthorization, captureMissionPayment, createAndAuthorizeMissionPayment } from "../../src/payment/paymentOrchestration";
import { assertIsolatedFirebaseTests } from "../testUtils/emulatorSafety";

assertIsolatedFirebaseTests(process.env);
const DRIVER = "rkf_race_driver", A = "rkf_race_A", B = "rkf_race_B", SNAP = "rkf_race_snapshot";
const profile = db.doc("driver_profiles/" + DRIVER);
const location = db.doc("driver_locations/" + DRIVER);
const missionA = db.doc("delivery_requests/" + A), missionB = db.doc("delivery_requests/" + B);
function request<T>(data: T, uid = DRIVER, role = "driver"): CallableRequest<T> {
  return { data, auth: { uid, token: { role } as unknown as DecodedIdToken, rawToken: "fictitious" },
    rawRequest: {} as Request, acceptsStreaming: false };
}
const report = () => recordTrackingPoint.run(request({ latitude: 45.5, longitude: -72.5 }));
const finish = () => completeDelivery.run(request({ missionId: A, proofOfDeliveryUrl: "https://example.invalid/fictitious.jpg" }));
function ended(status = "cancelled", paymentId: string | null = null, before = "in_transit") {
  return { params: { missionId: A }, data: {
    before: { data: () => ({ status: before, driver_id: DRIVER }) },
    after: { data: () => ({ status, driver_id: DRIVER, active_payment_id: paymentId }) },
  } } as unknown as FirestoreEvent<Change<QueryDocumentSnapshot>, { missionId: string }>;
}
const clean = () => onMissionEndedClearTracking.run(ended());
const cancelled = jest.mocked(cancelMissionPaymentAuthorization);
const captured = jest.mocked(captureMissionPayment);

async function assignB(mode: "driver" | "admin" = "driver") {
  await missionB.set({ customer_id: "rkf_client_B", status: "searching_driver", driver_id: null,
    required_vehicle_category: "van", assignment_mode: "internal_test", internal_test_authorized: true });
  if (mode === "admin") {
    await profile.update({ online_status: "online" });
    await adminAssignDelivery.run(request({ missionId: B, driverId: DRIVER, assignmentMode: "internal_test" }, "rkf_admin", "super_admin"));
  } else {
    await acceptDelivery.run(request({ missionId: B }));
  }
  expect((await location.get()).get("active_delivery_id")).toBe(B);
}
type TransactionBody = (tx: FirebaseFirestore.Transaction) => Promise<unknown>;
function interleave(mutate: () => Promise<void>) {
  let legacyInjected = false, retries = 0, transactionSeen = false, mutating = false;
  const originalRun = db.runTransaction.bind(db) as (fn: TransactionBody) => Promise<unknown>;
  const runSpy = jest.spyOn(db, "runTransaction").mockImplementation(((fn: TransactionBody) => {
    if (mutating) return originalRun(fn);
    transactionSeen = true;
    return originalRun(async tx => {
      retries++;
      if (retries === 2) { mutating = true; try { await mutate(); } finally { mutating = false; } }
      const result = await fn(tx);
      if (retries === 1) throw Object.assign(new Error("Injected ABORTED, retry against committed concurrent state"), { code: 10 });
      return result;
    });
  }) as typeof db.runTransaction);
  // Reproduction de l'ancien chemin non transactionnel, avant correction.
  const proto = admin.firestore.DocumentReference.prototype;
  const originalGet = proto.get;
  const getSpy = jest.spyOn(proto, "get").mockImplementation(async function (this: FirebaseFirestore.DocumentReference) {
    const snap = await originalGet.call(this);
    if (!transactionSeen && !mutating && !legacyInjected && this.path === location.path) {
      legacyInjected = true; mutating = true;
      try { await mutate(); } finally { mutating = false; }
    }
    return snap;
  });
  return {
    verify: () => { expect(legacyInjected || retries >= 2).toBe(true); },
    restore: () => { runSpy.mockRestore(); getSpy.mockRestore(); },
  };
}
async function state() {
  const [l, p, a, b, h] = await Promise.all([location.get(), profile.get(), missionA.get(), missionB.get(), location.collection("history").get()]);
  return { location: l.data(), profile: p.data(), a: a.data(), b: b.data(), history: h.docs.map(d => d.data()) };
}
beforeEach(async () => {
  jest.clearAllMocks();
  cancelled.mockResolvedValue({ success: true } as Awaited<ReturnType<typeof cancelMissionPaymentAuthorization>>);
  captured.mockResolvedValue({ success: true } as Awaited<ReturnType<typeof captureMissionPayment>>);
  await profile.set({ status: "approved", online_status: "on_mission", current_geohash: "unchanged",
    full_name: "Chauffeur fictif", documents_all_valid: true, accepted_vehicle_categories: ["van"], completed_missions: 2 });
  await missionA.set({ driver_id: DRIVER, customer_id: "rkf_client_A", status: "in_transit",
    assignment_mode: "internal_test", active_financial_snapshot_id: null, active_payment_id: null });
  await location.set({ driver_id: DRIVER, active_delivery_id: A, latitude: 1, longitude: 2 });
});
afterEach(async () => {
  jest.restoreAllMocks();
  const history = await location.collection("history").get();
  const ledger = await db.collection("transaction_ledger").where("mission_id", "==", A).get();
  for (const doc of [...history.docs, ...ledger.docs]) await doc.ref.delete();
  for (const ref of [missionA, missionB]) {
    const events = await ref.collection("tracking_events").get();
    await Promise.all(events.docs.map(d => d.ref.delete()));
    await ref.delete();
  }
  await Promise.all([profile.delete(), location.delete(), db.doc("financial_snapshots/" + SNAP).delete()]);
});
afterAll(async () => { await Promise.all(admin.apps.map(app => app!.delete())); });
describe("R-K-03-B — concurrence GPS, état Firestore final", () => {
  it.each(["driver", "admin"] as const)("ancien rapport A refusé après assignation B par %s", async mode => {
    const race = interleave(() => assignB(mode));
    try {
      await expect(report()).rejects.toMatchObject({ code: "failed-precondition" });
      race.verify();
    } finally { race.restore(); }
    const s = await state();
    expect(s.location?.active_delivery_id).toBe(B);
    expect(s.location?.latitude).toBe(1);
    expect(s.history).toHaveLength(0);
    expect(s.profile?.online_status).toBe("on_mission");
    expect(s.b?.driver_id).toBe(DRIVER);
    expect(createAndAuthorizeMissionPayment).not.toHaveBeenCalled();
  });
  it("nettoyage A intercalé avec assignation B conserve le lien B", async () => {
    const race = interleave(() => assignB());
    try { await clean(); race.verify(); } finally { race.restore(); }
    const s = await state();
    expect(s.location?.active_delivery_id).toBe(B);
    expect(s.b?.status).toBe("assigned");
  });
  it("nettoyage tardif A après assignation B ne touche pas B", async () => {
    await assignB(); const before = await state();
    await clean(); expect(await state()).toEqual(before);
  });
  it("mission A terminée pendant le rapport : aucun point ni écriture partielle", async () => {
    const race = interleave(async () => { await missionA.update({ status: "completed" }); });
    try { await expect(report()).rejects.toMatchObject({ code: "failed-precondition" }); race.verify(); }
    finally { race.restore(); }
    const s = await state();
    expect(s.history).toHaveLength(0);
    expect(s.location?.latitude).toBe(1);
    expect(s.profile?.current_geohash).toBe("unchanged");
    expect(s.a?.status).toBe("completed");
  });
  it("profil suspendu pendant le rapport : aucun point ni écriture partielle", async () => {
    const race = interleave(async () => { await profile.update({ status: "suspended" }); });
    try { await expect(report()).rejects.toMatchObject({ code: "permission-denied" }); race.verify(); }
    finally { race.restore(); }
    const s = await state();
    expect(s.history).toHaveLength(0);
    expect(s.location?.latitude).toBe(1);
    expect(s.profile?.status).toBe("suspended");
    expect(s.profile?.current_geohash).toBe("unchanged");
  });
  it("deux rapports réellement concurrents : deux points, lien intact", async () => {
    const results = await Promise.all([report(), recordTrackingPoint.run(request({ latitude: 46, longitude: -73 }))]);
    expect(results).toEqual([{ success: true }, { success: true }]);
    const s = await state();
    expect(s.history).toHaveLength(2);
    expect(s.history.every(p => p.delivery_id === A)).toBe(true);
    expect(s.history.map(p => p.latitude).sort()).toEqual([45.5, 46]);
    expect([45.5, 46]).toContain(s.location?.latitude);
    expect(s.location?.active_delivery_id).toBe(A);
  });
  it("rapport et assignation réellement concurrents : état final B", async () => {
    const [gps] = await Promise.all([report().catch((e: { code: string }) => ({ error: e.code })), assignB()]);
    if ("error" in gps) expect(gps.error).toBe("failed-precondition");
    const s = await state();
    expect(s.location?.active_delivery_id).toBe(B);
    expect(s.b?.driver_id).toBe(DRIVER);
    expect(s.history.length).toBeLessThanOrEqual(1);
    // Sans missionId dans la requête, la première lecture peut déjà voir B.
    expect(s.history.every(p => p.delivery_id === A || p.delivery_id === B)).toBe(true);
  });
  it("fin tardive A ne libère pas le chauffeur ni le GPS de B", async () => {
    await assignB();
    await finish();
    const s = await state();
    expect(s.a?.status).toBe("completed");
    expect(s.location?.active_delivery_id).toBe(B);
    expect(s.profile?.online_status).toBe("on_mission");
    expect(s.profile?.completed_missions).toBe(2);
    expect((await db.collection("transaction_ledger").where("mission_id", "==", A).get()).size).toBe(0);
    expect(captured).not.toHaveBeenCalled();
  });
  it("fin standard A reprise après B : comptabilité unique inchangée, capture hors transaction", async () => {
    await missionA.update({ assignment_mode: "standard", active_financial_snapshot_id: SNAP, active_payment_id: "rkf_fake_payment" });
    await db.doc("financial_snapshots/" + SNAP).set({ status: "pending", customer_total: 100,
      platform_commission_amount: 12, customer_service_fee: 3, driver_offer_amount: 85, customer_tax: 5 });
    captured.mockImplementation(async () => {
      expect((await missionA.get()).get("status")).toBe("completed");
      expect((await location.get()).get("active_delivery_id")).toBe(B);
      return { success: true } as Awaited<ReturnType<typeof captureMissionPayment>>;
    });
    const race = interleave(() => assignB());
    try { await finish(); race.verify(); } finally { race.restore(); }
    const s = await state();
    expect(s.location?.active_delivery_id).toBe(B);
    expect(s.profile?.online_status).toBe("on_mission");
    expect(s.profile?.completed_missions).toBe(3);
    const ledger = await db.collection("transaction_ledger").where("mission_id", "==", A).get();
    expect(ledger.size).toBe(5);
    expect(Object.fromEntries(ledger.docs.map(d => [d.get("type"), d.get("amount")]))).toEqual({
      customer_charge: 100, platform_commission: 12, customer_service_fee: 3, driver_earning: 85, tax: 5 });
    expect(captured).toHaveBeenCalledTimes(1);
    expect(captured).toHaveBeenCalledWith(A, "rkf_fake_payment");
  });
});
describe("R-K-03-B — effets financiers du trigger préservés, doublures uniquement", () => {
  it("annulation libérée une fois avant nettoyage, même après retry GPS", async () => {
    const race = interleave(async () => {
      // L'effet financier précède le nettoyage transactionnel et ne se répète pas.
      expect(cancelled).toHaveBeenCalledTimes(1);
      await assignB();
    });
    try { await onMissionEndedClearTracking.run(ended("cancelled", "rkf_fake_payment")); race.verify(); }
    finally { race.restore(); }
    expect(cancelled).toHaveBeenCalledTimes(1);
    expect(cancelled).toHaveBeenCalledWith(A, "rkf_fake_payment");
    expect((await location.get()).get("active_delivery_id")).toBe(B);
  });
  it("erreur de libération propagée, aucun nettoyage anticipé", async () => {
    cancelled.mockRejectedValue(new Error("SIMULATED_CANCELLATION_FAILURE"));
    await expect(onMissionEndedClearTracking.run(ended("cancelled", "rkf_fake_payment"))).rejects.toThrow("SIMULATED_CANCELLATION_FAILURE");
    expect((await location.get()).get("active_delivery_id")).toBe(A);
  });
  it.each(["disputed", "refunded"])("nettoyage %s sans libération d'autorisation", async status => {
    await onMissionEndedClearTracking.run(ended(status, "rkf_fake_payment"));
    expect(cancelled).not.toHaveBeenCalled();
    expect((await location.get()).get("active_delivery_id")).toBeNull();
  });
});
