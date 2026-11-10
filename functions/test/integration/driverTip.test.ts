// -----------------------------------------------------------------------------
// tipDriver — pourboire au chauffeur (décision Daniel, 2026-11-09).
//
// Débit réel de la carte enregistrée, viré à 100 % au chauffeur (destination
// charge sans frais de plateforme), un seul par livraison, registre + bilan
// de mission + miroir chauffeur cohérents.
// -----------------------------------------------------------------------------
import type { CallableRequest, Request } from "firebase-functions/v2/https";
import type { DecodedIdToken } from "firebase-admin/auth";
import { tipDriver, TipDriverRequest } from "../../src/functions/tipDriver";
import { getPaymentReceipt } from "../../src/functions/getPaymentReceipt";
import { buildDriverTransferDoc } from "../../src/functions/onPaymentWrittenMirrorDriverTransfer";
import { admin, db } from "../../src/lib/admin";
import { tipPaymentId } from "../../src/lib/driverTip";
import { computeMissionFinancialBalance } from "../../src/lib/missionFinancialBalance";
import { PaymentDoc } from "../../src/lib/types";
import { setPaymentProviderForTesting } from "../../src/payment/paymentProviderFactory";
import { FakePaymentProvider, buildFakePaymentProfile } from "../testUtils/fakePaymentProvider";
import { seedDefaultRuntimeFlagsEnabled, seedRuntimeFlags } from "../testUtils/runtimeFlagsFixture";

const MISSION = "tip_mission_001";
const CUSTOMER = "tip_customer_a";
const OTHER = "tip_customer_b";
const DRIVER = "tip_driver_a";
const ACCOUNT = "acct_tip_driver_test";

function req(uid: string, data: unknown): CallableRequest<TipDriverRequest> {
  return {
    data: data as TipDriverRequest,
    auth: { uid, token: {} as DecodedIdToken, rawToken: "fake-raw-token-for-emulator-test" },
    rawRequest: {} as Request,
    acceptsStreaming: false,
  };
}

async function seedMission(overrides: Record<string, unknown> = {}): Promise<void> {
  await db.collection("delivery_requests").doc(MISSION).set({
    customer_id: CUSTOMER, driver_id: DRIVER, status: "completed",
    assignment_mode: "standard", internal_test_authorized: false,
    customer_total: 72.43, customer_total_minor: 7243,
    quote_breakdown: { taxAmount: 9.43, customerTotal: 72.43 },
    completed_at: admin.firestore.Timestamp.now(),
    created_at: admin.firestore.Timestamp.now(),
    ...overrides,
  });
}

let provider: FakePaymentProvider;

beforeEach(async () => {
  provider = new FakePaymentProvider();
  setPaymentProviderForTesting(provider);
  await seedDefaultRuntimeFlagsEnabled();
  await db.doc(`payment_profiles/${CUSTOMER}`).set(buildFakePaymentProfile(CUSTOMER));
  await db.doc(`driver_profiles/${DRIVER}`).set({
    user_id: DRIVER, stripe_connected_account_id: ACCOUNT, stripe_connected_account_environment: "test",
    stripe_charges_enabled: true, stripe_payouts_enabled: true,
  });
  await seedMission();
});

afterEach(async () => {
  setPaymentProviderForTesting(null);
  for (const path of [`payment_profiles/${CUSTOMER}`, `driver_profiles/${DRIVER}`, `mission_financial_balance/${MISSION}`, `payments/${MISSION}_pay`]) {
    await db.doc(path).delete();
  }
  await db.recursiveDelete(db.collection("delivery_requests").doc(MISSION));
  await db.recursiveDelete(db.collection("users").doc(DRIVER));
  for (const collection of ["payments", "transaction_ledger"]) {
    const rows = await db.collection(collection).where("mission_id", "==", MISSION).get();
    for (const r of rows.docs) await r.ref.delete();
  }
});

it("15 % du prix avant taxes, débité une seule fois et viré à 100 % au chauffeur", async () => {
  const first = await tipDriver.run(req(CUSTOMER, { missionId: MISSION, percent: 15 }));
  expect(first).toMatchObject({ success: true, amountMinor: 945, paymentId: tipPaymentId(MISSION), reused: false });

  // Destination charge vers le chauffeur, aucun frais de plateforme.
  expect(provider.chargedSavedMethodParams).toHaveLength(1);
  expect(provider.chargedSavedMethodParams[0]).toMatchObject({
    amountMinor: 945, connectedAccountId: ACCOUNT, applicationFeeMinor: 0,
    providerCustomerId: `fake_cus_${CUSTOMER}`, providerPaymentMethodId: `fake_pm_${CUSTOMER}`,
  });

  const payment = (await db.doc(`payments/${tipPaymentId(MISSION)}`).get()).data() as PaymentDoc;
  expect(payment).toMatchObject({
    purpose: "tip", tip_percent: 15, status: "captured", amount_captured_minor: 945,
    application_fee_minor: 0, connected_account_id: ACCOUNT, driver_id: DRIVER, mission_id: MISSION,
  });

  const mission = (await db.doc(`delivery_requests/${MISSION}`).get()).data()!;
  expect(mission.tip).toMatchObject({ amount_minor: 945, percent: 15, status: "paid", payment_id: tipPaymentId(MISSION) });

  const ledger = await db.collection("transaction_ledger").where("mission_id", "==", MISSION).get();
  expect(ledger.docs.map((d) => d.data())).toEqual([
    expect.objectContaining({ type: "driver_tip", amount_minor: 945, party: "driver", direction: "credit", status: "confirmed" }),
  ]);

  // Bilan de mission : pourboire compté et déjà viré (rien dû au chauffeur).
  const balance = (await db.doc(`mission_financial_balance/${MISSION}`).get()).data()!;
  expect(balance).toMatchObject({ driver_tip_minor: 945, driver_transferred_minor: 945, outstanding_driver_balance_minor: 0 });
  expect(await computeMissionFinancialBalance(MISSION)).toMatchObject({ driver_tip_minor: balance.driver_tip_minor });

  // Le chauffeur voit le virement étiqueté « pourboire » et une cloche.
  expect(buildDriverTransferDoc(tipPaymentId(MISSION), payment)).toMatchObject({ purpose: "tip", amount_minor: 945, net_minor: 945 });
  const bell = await db.collection("users").doc(DRIVER).collection("notifications").get();
  expect(bell.docs.map((d) => d.data().type)).toEqual(["driver_tip_received"]);

  // Deuxième appel (double appui, autre montant) : rien de plus n'est débité.
  const second = await tipDriver.run(req(CUSTOMER, { missionId: MISSION, amountMinor: 5000 }));
  expect(second).toMatchObject({ success: true, amountMinor: 945, reused: true });
  expect(provider.chargedSavedMethodParams).toHaveLength(1);
});

it("montant au choix", async () => {
  const result = await tipDriver.run(req(CUSTOMER, { missionId: MISSION, amountMinor: 1200 }));
  expect(result).toMatchObject({ success: true, amountMinor: 1200 });
  expect((await db.doc(`payments/${tipPaymentId(MISSION)}`).get()).data()).toMatchObject({ tip_percent: null });
});

it("carte refusée : rien d'inscrit, et le prochain essai est un nouveau paiement", async () => {
  setPaymentProviderForTesting(new FakePaymentProvider({ forceChargeFailure: true }));
  await expect(tipDriver.run(req(CUSTOMER, { missionId: MISSION, percent: 10 })))
    .rejects.toMatchObject({ code: "failed-precondition" });
  expect((await db.doc(`payments/${tipPaymentId(MISSION)}`).get()).data()).toMatchObject({ status: "failed", amount_captured_minor: 0 });
  expect((await db.collection("transaction_ledger").where("mission_id", "==", MISSION).get()).empty).toBe(true);
  expect((await db.doc(`delivery_requests/${MISSION}`).get()).data()!.tip).toBeUndefined();

  setPaymentProviderForTesting(provider);
  const retry = await tipDriver.run(req(CUSTOMER, { missionId: MISSION, percent: 10 }));
  expect(retry).toMatchObject({ success: true, amountMinor: 630, paymentId: tipPaymentId(MISSION, 2) });
});

it("réponse Stripe perdue : le nouvel essai reprend le même montant et la même clé", async () => {
  const now = admin.firestore.Timestamp.now();
  await db.doc(`payments/${tipPaymentId(MISSION)}`).set({
    payment_id: tipPaymentId(MISSION), mission_id: MISSION, customer_id: CUSTOMER, driver_id: DRIVER,
    status: "capture_pending", currency: "CAD", amount_authorized_minor: 0, amount_requested_minor: 777,
    service_amount_minor: 777, amount_captured_minor: 0, amount_refunded_minor: 0, application_fee_minor: 0,
    purpose: "tip", tip_percent: null, provider: "stripe", provider_customer_id: `fake_cus_${CUSTOMER}`,
    provider_payment_method_id: `fake_pm_${CUSTOMER}`, provider_payment_intent_id: null, provider_charge_id: null,
    connected_account_id: ACCOUNT, idempotency_key: `driverTip:${tipPaymentId(MISSION)}`, capture_attempt_count: 1,
    created_at: now, updated_at: now, stripe_environment: "test",
  });
  const result = await tipDriver.run(req(CUSTOMER, { missionId: MISSION, percent: 20 }));
  expect(result).toMatchObject({ success: true, amountMinor: 777, paymentId: tipPaymentId(MISSION) });
  expect(provider.chargedSavedMethodParams[0]).toMatchObject({ amountMinor: 777, idempotencyKey: `driverTip:${tipPaymentId(MISSION)}:1` });
});

it("le reçu de la livraison reste celui du paiement de la livraison", async () => {
  const past = admin.firestore.Timestamp.fromMillis(Date.now() - 60_000);
  await db.doc(`payments/${MISSION}_pay`).set({
    payment_id: `${MISSION}_pay`, mission_id: MISSION, customer_id: CUSTOMER, driver_id: DRIVER, status: "captured",
    currency: "CAD", amount_authorized_minor: 7243, amount_captured_minor: 7243, amount_refunded_minor: 0,
    application_fee_minor: 1500, provider: "stripe", provider_charge_id: "ch_delivery_001", stripe_environment: "test",
    captured_at: past, created_at: past, updated_at: past,
  });
  await tipDriver.run(req(CUSTOMER, { missionId: MISSION, percent: 10 }));
  await expect(getPaymentReceipt.run(req(CUSTOMER, { missionId: MISSION }) as never))
    .resolves.toEqual({ url: "https://pay.stripe.test/receipts/ch_delivery_001" });
});

describe("refus sans aucun débit", () => {
  afterEach(() => expect(provider.chargedSavedMethodParams).toHaveLength(0));

  it("un autre client", async () => {
    await expect(tipDriver.run(req(OTHER, { missionId: MISSION, percent: 10 })))
      .rejects.toMatchObject({ code: "permission-denied" });
  });

  it.each(["searching_driver", "in_transit", "cancelled"])("livraison pas terminée (%s)", async (status) => {
    await seedMission({ status });
    await expect(tipDriver.run(req(CUSTOMER, { missionId: MISSION, percent: 10 })))
      .rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("livraison de test interne", async () => {
    await seedMission({ assignment_mode: "internal_test", internal_test_authorized: true });
    await expect(tipDriver.run(req(CUSTOMER, { missionId: MISSION, percent: 10 })))
      .rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("plus de 30 jours après la livraison", async () => {
    await seedMission({ completed_at: admin.firestore.Timestamp.fromMillis(Date.now() - 31 * 24 * 3600 * 1000) });
    await expect(tipDriver.run(req(CUSTOMER, { missionId: MISSION, percent: 10 })))
      .rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("chauffeur sans compte Stripe de l'environnement actif", async () => {
    await db.doc(`driver_profiles/${DRIVER}`).set({ user_id: DRIVER, stripe_connected_account_id: "acct_live_only", stripe_connected_account_environment: "live" });
    await expect(tipDriver.run(req(CUSTOMER, { missionId: MISSION, percent: 10 })))
      .rejects.toMatchObject({ code: "failed-precondition" });
  });

  it.each([{ percent: 50 }, { amountMinor: 50 }, { amountMinor: 20000 }, { percent: 10, amountMinor: 500 }, {}])(
    "choix invalide %p", async (choice) => {
      await expect(tipDriver.run(req(CUSTOMER, { missionId: MISSION, ...choice })))
        .rejects.toMatchObject({ code: "invalid-argument" });
    }
  );

  it("paiements coupés (interrupteur)", async () => {
    await seedRuntimeFlags({ payments_enabled: false });
    await expect(tipDriver.run(req(CUSTOMER, { missionId: MISSION, percent: 10 })))
      .rejects.toMatchObject({ code: "failed-precondition" });
  });
});
