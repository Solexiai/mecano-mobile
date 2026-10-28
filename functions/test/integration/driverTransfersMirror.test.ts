// ---------------------------------------------------------------------------
// Option A (2026-10-27) — miroir driver_transfers/{paymentId} et solde de
// mission : la part virée par Stripe Connect à la capture est visible par le
// chauffeur et comptée comme payée dans mission_financial_balance.
// ---------------------------------------------------------------------------
import { admin, db } from "../../src/lib/admin";
import { PaymentDoc, PaymentStatuses } from "../../src/lib/types";
import { mirrorDriverTransfer } from "../../src/functions/onPaymentWrittenMirrorDriverTransfer";
import { recalculateMissionFinancialBalance } from "../../src/lib/missionFinancialBalance";

const DRIVER_ID = "dtm_driver_001";
const CUSTOMER_ID = "dtm_customer_001";

function payment(id: string, missionId: string, overrides: Partial<PaymentDoc> = {}): PaymentDoc {
  const now = admin.firestore.Timestamp.now();
  return {
    payment_id: id,
    mission_id: missionId,
    customer_id: CUSTOMER_ID,
    driver_id: DRIVER_ID,
    status: PaymentStatuses.CAPTURED,
    currency: "CAD",
    amount_authorized_minor: 10000,
    amount_captured_minor: 10000,
    amount_refunded_minor: 0,
    application_fee_minor: 1500,
    provider: "stripe",
    provider_customer_id: null,
    provider_payment_method_id: null,
    provider_payment_intent_id: `pi_${id}`,
    provider_charge_id: `ch_${id}`,
    connected_account_id: "acct_fake_dtm",
    idempotency_key: `createPayment:${id}`,
    captured_at: now,
    created_at: now,
    updated_at: now,
    stripe_environment: "test",
    ...overrides,
  };
}

async function cleanup(missionIds: string[], paymentIds: string[]): Promise<void> {
  const batch = db.batch();
  paymentIds.forEach((id) => {
    batch.delete(db.collection("payments").doc(id));
    batch.delete(db.collection("driver_transfers").doc(id));
  });
  for (const missionId of missionIds) {
    batch.delete(db.collection("mission_financial_balance").doc(missionId));
    const snaps = await db.collection("financial_snapshots").where("mission_id", "==", missionId).get();
    snaps.docs.forEach((d) => batch.delete(d.ref));
  }
  await batch.commit();
}

describe("driver_transfers — miroir de la part virée par Stripe Connect", () => {
  afterEach(async () => {
    await cleanup(["dtm_mission_1", "dtm_mission_2", "dtm_mission_3"], ["dtm_pay_1", "dtm_pay_2", "dtm_pay_3"]);
  });

  it("paiement capturé avec compte connecté -> driver_transfers/{paymentId} (capturé moins frais)", async () => {
    const written = await mirrorDriverTransfer("dtm_pay_1", payment("dtm_pay_1", "dtm_mission_1"));
    expect(written).toBe(true);
    const doc = (await db.collection("driver_transfers").doc("dtm_pay_1").get()).data()!;
    expect(doc).toMatchObject({
      payment_id: "dtm_pay_1",
      mission_id: "dtm_mission_1",
      driver_id: DRIVER_ID,
      connected_account_id: "acct_fake_dtm",
      amount_minor: 8500,
      reversed_minor: 0,
      net_minor: 8500,
      status: "transferred",
      capture_purpose: null,
      stripe_environment: "test",
    });
    // Jamais de données client ni de références fournisseur dans le miroir.
    expect(doc.customer_id).toBeUndefined();
    expect(doc.provider_payment_intent_id).toBeUndefined();
  });

  it("remboursement partiel -> partially_reversed au prorata ; total -> reversed", async () => {
    await mirrorDriverTransfer(
      "dtm_pay_2",
      payment("dtm_pay_2", "dtm_mission_2", { status: PaymentStatuses.PARTIALLY_REFUNDED, amount_refunded_minor: 2500 })
    );
    expect((await db.collection("driver_transfers").doc("dtm_pay_2").get()).data()).toMatchObject({
      amount_minor: 8500, reversed_minor: 2125, net_minor: 6375, status: "partially_reversed",
    });
    await mirrorDriverTransfer(
      "dtm_pay_2",
      payment("dtm_pay_2", "dtm_mission_2", { status: PaymentStatuses.REFUNDED, amount_refunded_minor: 10000 })
    );
    expect((await db.collection("driver_transfers").doc("dtm_pay_2").get()).data()).toMatchObject({
      reversed_minor: 8500, net_minor: 0, status: "reversed",
    });
  });

  it("sans compte connecté, non capturé ou paiement supprimé : aucun miroir", async () => {
    expect(await mirrorDriverTransfer("dtm_pay_3", payment("dtm_pay_3", "dtm_mission_3", { connected_account_id: null }))).toBe(false);
    expect(
      await mirrorDriverTransfer("dtm_pay_3", payment("dtm_pay_3", "dtm_mission_3", { status: PaymentStatuses.AUTHORIZED, amount_captured_minor: 0 }))
    ).toBe(false);
    expect(await mirrorDriverTransfer("dtm_pay_3", undefined)).toBe(false);
    expect((await db.collection("driver_transfers").doc("dtm_pay_3").get()).exists).toBe(false);
  });

  it("mission_financial_balance : la part virée compte comme payée au chauffeur", async () => {
    await db.collection("payments").doc("dtm_pay_1").set(payment("dtm_pay_1", "dtm_mission_1"));
    await db.collection("financial_snapshots").doc("dtm_snap_1").set({
      snapshot_id: "dtm_snap_1",
      mission_id: "dtm_mission_1",
      driver_id: DRIVER_ID,
      customer_id: CUSTOMER_ID,
      status: "confirmed",
      driver_net_mission_earnings: 85,
      platform_commission_amount: 12,
      customer_service_fee: 3,
      created_at: admin.firestore.Timestamp.now(),
    });
    const balance = await recalculateMissionFinancialBalance("dtm_mission_1");
    expect(balance.driver_earned_minor).toBe(8500);
    expect(balance.driver_transferred_minor).toBe(8500);
    expect(balance.driver_paid_minor).toBe(8500);
    expect(balance.outstanding_driver_balance_minor).toBe(0);
  });
});
