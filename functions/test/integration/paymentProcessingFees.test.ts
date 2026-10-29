// ---------------------------------------------------------------------------
// 2026-10-29 (recette avec Daniel) — bilan de mission d'un paiement Stripe
// Connect remboursé en partie, et frais Stripe réels.
//
// Cas réel reproduit : 94,00 $ encaissés, frais de plateforme 14,10 $,
// remboursement de 10,00 $, frais Stripe 3,78 $. Attendu :
//   chauffeur 79,90 − 8,50 = 71,40 $ ; rien ne lui est dû ;
//   commission 14,10 − 1,50 = 12,60 $ ; marge 12,60 − 3,78 = 8,82 $.
// ---------------------------------------------------------------------------
import { admin, db } from "../../src/lib/admin";
import { LedgerEntryTypes, PaymentDoc, PaymentStatuses, RefundStatuses } from "../../src/lib/types";
import { recalculateMissionFinancialBalance } from "../../src/lib/missionFinancialBalance";
import {
  needsProcessingFee,
  processingFeeLedgerId,
  recordMissingProcessingFees,
  recordPaymentProcessingFee,
} from "../../src/functions/paymentProcessingFees";
import { FakePaymentProvider } from "../testUtils/fakePaymentProvider";

const PREFIX = "ppf_";
const DRIVER_ID = PREFIX + "driver";
const CUSTOMER_ID = PREFIX + "customer";

function payment(id: string, missionId: string, overrides: Partial<PaymentDoc> = {}): PaymentDoc {
  const now = admin.firestore.Timestamp.now();
  return {
    payment_id: id,
    mission_id: missionId,
    customer_id: CUSTOMER_ID,
    driver_id: DRIVER_ID,
    status: PaymentStatuses.CAPTURED,
    currency: "CAD",
    amount_authorized_minor: 9400,
    amount_captured_minor: 9400,
    amount_refunded_minor: 0,
    application_fee_minor: 1410,
    provider: "stripe",
    provider_customer_id: null,
    provider_payment_method_id: null,
    provider_payment_intent_id: `pi_${id}`,
    provider_charge_id: `ch_${id}`,
    connected_account_id: "acct_fake_ppf",
    idempotency_key: `createPayment:${id}`,
    captured_at: now,
    created_at: now,
    updated_at: now,
    stripe_environment: "test",
    ...overrides,
  };
}

async function seedMission(missionId: string, paymentId: string, overrides: Partial<PaymentDoc> = {}) {
  await db.collection("payments").doc(paymentId).set(payment(paymentId, missionId, overrides));
  await db.collection("financial_snapshots").doc(PREFIX + "snap_" + missionId).set({
    snapshot_id: PREFIX + "snap_" + missionId,
    mission_id: missionId,
    driver_id: DRIVER_ID,
    customer_id: CUSTOMER_ID,
    status: "confirmed",
    driver_net_mission_earnings: 79.9,
    platform_commission_amount: 14.1,
    customer_service_fee: 0,
    created_at: admin.firestore.Timestamp.now(),
  });
}

async function seedSucceededRefund(missionId: string, paymentId: string, amountMinor: number) {
  await db.collection("refunds").doc(PREFIX + "refund_" + missionId).set({
    refund_id: PREFIX + "refund_" + missionId,
    mission_id: missionId,
    payment_id: paymentId,
    amount_minor: amountMinor,
    reason: "goodwill",
    status: RefundStatuses.SUCCEEDED,
    reverse_transfer: true,
    refund_application_fee: true,
    created_at: admin.firestore.Timestamp.now(),
  });
}

async function cleanup() {
  for (const c of ["payments", "financial_snapshots", "refunds", "transaction_ledger", "mission_financial_balance"]) {
    const docs = await db.collection(c).get();
    await Promise.all(docs.docs
      .filter((d) => d.id.startsWith(PREFIX) || d.id.startsWith("processing_fee_" + PREFIX) || String(d.data().mission_id ?? "").startsWith(PREFIX))
      .map((d) => d.ref.delete()));
  }
}

beforeEach(cleanup);
afterAll(cleanup);

describe("bilan de mission — remboursement partiel d'un paiement Stripe Connect", () => {
  it("la part reprise au chauffeur n'est plus « due » ; la commission est nette de la part rendue", async () => {
    const missionId = PREFIX + "mission_refund";
    const paymentId = PREFIX + "pay_refund";
    await seedMission(missionId, paymentId, { status: PaymentStatuses.PARTIALLY_REFUNDED, amount_refunded_minor: 1000 });
    await seedSucceededRefund(missionId, paymentId, 1000);

    const b = await recalculateMissionFinancialBalance(missionId);
    expect(b).toMatchObject({
      customer_charged_minor: 9400,
      customer_refunded_minor: 1000,
      outstanding_customer_balance_minor: 8400,
      driver_earned_minor: 7990,
      driver_refund_reversed_minor: 850,
      driver_transferred_minor: 7140,
      driver_paid_minor: 7140,
      outstanding_driver_balance_minor: 0,
      platform_commission_refunded_minor: 150,
      platform_commission_minor: 1260,
      contribution_margin_minor: 1260,
    });
    // Le remboursement client = part reprise au chauffeur + part rendue par Movi-K.
    expect(b.driver_refund_reversed_minor! + b.platform_commission_refunded_minor!).toBe(b.customer_refunded_minor);
  });

  it("sans remboursement : rien ne change (commission brute, rien de dû)", async () => {
    const missionId = PREFIX + "mission_plain";
    await seedMission(missionId, PREFIX + "pay_plain");
    const b = await recalculateMissionFinancialBalance(missionId);
    expect(b).toMatchObject({
      driver_refund_reversed_minor: 0,
      platform_commission_refunded_minor: 0,
      platform_commission_minor: 1410,
      driver_paid_minor: 7990,
      outstanding_driver_balance_minor: 0,
    });
  });

  it("remboursement total : chauffeur et commission à zéro", async () => {
    const missionId = PREFIX + "mission_full";
    const paymentId = PREFIX + "pay_full";
    await seedMission(missionId, paymentId, { status: PaymentStatuses.REFUNDED, amount_refunded_minor: 9400 });
    await seedSucceededRefund(missionId, paymentId, 9400);
    const b = await recalculateMissionFinancialBalance(missionId);
    expect(b).toMatchObject({
      driver_refund_reversed_minor: 7990,
      driver_paid_minor: 0,
      outstanding_driver_balance_minor: 0,
      platform_commission_refunded_minor: 1410,
      platform_commission_minor: 0,
      outstanding_customer_balance_minor: 0,
    });
  });
});

describe("frais Stripe réels — lus après l'encaissement, inscrits une seule fois", () => {
  it("inscrit les frais au ledger et au paiement, puis la marge du bilan = 8,82 $", async () => {
    const missionId = PREFIX + "mission_fee";
    const paymentId = PREFIX + "pay_fee";
    await seedMission(missionId, paymentId, { status: PaymentStatuses.PARTIALLY_REFUNDED, amount_refunded_minor: 1000 });
    await seedSucceededRefund(missionId, paymentId, 1000);
    const provider = new FakePaymentProvider({ processingFeeMinor: 378 });

    expect(await recordPaymentProcessingFee(paymentId, provider)).toBe("recorded");
    expect(provider.processingFeeLookups).toEqual([`ch_${paymentId}`]);

    const ledger = (await db.collection("transaction_ledger").doc(processingFeeLedgerId(paymentId)).get()).data()!;
    expect(ledger).toMatchObject({
      type: LedgerEntryTypes.PAYMENT_PROCESSING_FEE,
      amount_minor: 378,
      party: "platform",
      mission_id: missionId,
      transaction_id: paymentId,
      currency: "CAD",
    });
    expect((await db.collection("payments").doc(paymentId).get()).data()!.processing_fee_minor).toBe(378);

    const stored = (await db.collection("mission_financial_balance").doc(missionId).get()).data()!;
    expect(stored).toMatchObject({
      provider_processing_cost_minor: 378,
      platform_commission_minor: 1260,
      contribution_margin_minor: 882,
      outstanding_driver_balance_minor: 0,
    });

    // Rejoué (déclencheur at-least-once, balayage) : aucun second appel Stripe, aucune seconde entrée.
    expect(await recordPaymentProcessingFee(paymentId, provider)).toBe("already_recorded");
    expect(provider.processingFeeLookups).toHaveLength(1);
    const entries = await db.collection("transaction_ledger").where("mission_id", "==", missionId).get();
    expect(entries.docs.filter((d) => d.data().type === LedgerEntryTypes.PAYMENT_PROCESSING_FEE)).toHaveLength(1);
  });

  it("Stripe injoignable ou frais indisponibles : rien n'est inscrit, le paiement reste « à lire »", async () => {
    const missionId = PREFIX + "mission_unavail";
    const paymentId = PREFIX + "pay_unavail";
    await seedMission(missionId, paymentId);

    expect(await recordPaymentProcessingFee(paymentId, new FakePaymentProvider({ forceProcessingFeeError: true }))).toBe("unavailable");
    expect(await recordPaymentProcessingFee(paymentId, new FakePaymentProvider())).toBe("unavailable");
    const p = (await db.collection("payments").doc(paymentId).get()).data() as PaymentDoc;
    expect(needsProcessingFee(p)).toBe(true);
    expect((await db.collection("transaction_ledger").doc(processingFeeLedgerId(paymentId)).get()).exists).toBe(false);
  });

  it("ne lit rien pour un paiement non encaissé, sans charge, ou d'un autre environnement Stripe", async () => {
    const provider = new FakePaymentProvider({ processingFeeMinor: 100 });
    await seedMission(PREFIX + "m_auth", PREFIX + "pay_auth", { status: PaymentStatuses.AUTHORIZED, amount_captured_minor: 0, provider_charge_id: null });
    await seedMission(PREFIX + "m_live", PREFIX + "pay_live", { stripe_environment: "live" });
    expect(await recordPaymentProcessingFee(PREFIX + "pay_auth", provider)).toBe("not_applicable");
    expect(await recordPaymentProcessingFee(PREFIX + "pay_live", provider)).toBe("not_applicable");
    expect(await recordPaymentProcessingFee(PREFIX + "pay_missing", provider)).toBe("not_applicable");
    expect(provider.processingFeeLookups).toHaveLength(0);
  });

  it("le balayage rattrape les paiements récents sans frais (ex. le paiement de test du 29 octobre)", async () => {
    await seedMission(PREFIX + "m_sweep", PREFIX + "pay_sweep");
    const old = admin.firestore.Timestamp.fromMillis(Date.now() - 40 * 86_400_000);
    await seedMission(PREFIX + "m_old", PREFIX + "pay_old", { captured_at: old });
    const provider = new FakePaymentProvider({ processingFeeMinor: 303 });

    const counts = await recordMissingProcessingFees(provider, 500);
    expect(counts.recorded).toBeGreaterThanOrEqual(1);
    expect((await db.collection("payments").doc(PREFIX + "pay_sweep").get()).data()!.processing_fee_minor).toBe(303);
    // Hors fenêtre de 30 jours : laissé tel quel.
    expect((await db.collection("payments").doc(PREFIX + "pay_old").get()).data()!.processing_fee_minor).toBeUndefined();
    expect(provider.processingFeeLookups).not.toContain(`ch_${PREFIX}pay_old`);
  });
});
