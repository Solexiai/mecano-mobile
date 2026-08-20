// ---------------------------------------------------------------------------
// Test d'intégration — recalculateMissionFinancialBalance (Phase 6,
// directive 38 points, point 7 : "mission_financial_balance").
//
// 🔒 Cette fonction est un ÉTAT SYNTHÉTIQUE DÉRIVÉ (voir
// missionFinancialBalance.ts) — elle ne fait QUE relire payments/refunds/
// transaction_ledger/financial_snapshots/driver_payouts pour UNE mission et
// recalculer un document résumé. Elle est déjà appelée par
// captureMissionPayment/submitDriverPayout/recordTip/createLedgerEntry/
// refundPayment/transitionDisputeStatus — CE fichier teste directement la
// fonction de calcul elle-même, avec un contrôle total sur les données
// sources (seed manuel), plutôt que de repasser par chaque Cloud Function
// appelante (déjà couvertes ailleurs pour leur propre logique métier).
//
// Couvre :
//   1. capture seule
//   2. capture + tip
//   3. capture + refund partiel
//   4. capture + payout
//   5. capture + ajustement admin (manuel, ledger DRIVER_ADJUSTMENT)
//   6. plusieurs snapshots (donc plusieurs missions) inclus dans UN MÊME
//      payout PAID — vérifie que driver_paid_minor est correctement
//      attribué à CHAQUE mission concernée
//   7. recalcul idempotent (rejouer plusieurs fois => même résultat)
//   8. le ledger historique n'est JAMAIS modifié par un recalcul (lecture
//      seule des collections sources)
//   9. toutes les valeurs *_minor sont des entiers stricts (cents)
//  10. mission inexistante / aucune donnée source => document "zéro" propre
//      (pas d'exception, pas de NaN, pas de champ manquant)
// ---------------------------------------------------------------------------

import { recalculateMissionFinancialBalance } from "../../src/lib/missionFinancialBalance";
import { admin, db } from "../../src/lib/admin";
import {
  LedgerDirections,
  LedgerEntryStatuses,
  LedgerEntryTypes,
  LedgerParties,
  MissionFinancialBalanceDoc,
  PaymentStatuses,
  RefundReasons,
  RefundStatuses,
} from "../../src/lib/types";

const CUSTOMER_ID = "mfb_customer_001";
const DRIVER_ID = "mfb_driver_001";

// ---------------------------------------------------------------------------
// Helpers de seed — écrivent DIRECTEMENT les collections sources (sans
// passer par les Cloud Functions), pour isoler précisément le calcul de
// recalculateMissionFinancialBalance() de toute autre logique métier.
// ---------------------------------------------------------------------------

async function seedPayment(
  paymentId: string,
  missionId: string,
  opts: { amountCapturedMinor: number; amountRefundedMinor?: number; status?: string }
): Promise<void> {
  const now = admin.firestore.Timestamp.now();
  await db.collection("payments").doc(paymentId).set({
    payment_id: paymentId,
    mission_id: missionId,
    customer_id: CUSTOMER_ID,
    driver_id: DRIVER_ID,
    status: opts.status ?? PaymentStatuses.CAPTURED,
    currency: "CAD",
    amount_authorized_minor: opts.amountCapturedMinor,
    amount_captured_minor: opts.amountCapturedMinor,
    amount_refunded_minor: opts.amountRefundedMinor ?? 0,
    application_fee_minor: Math.round(opts.amountCapturedMinor * 0.15),
    provider: "stripe",
    provider_customer_id: `fake_cus_${CUSTOMER_ID}`,
    provider_payment_method_id: `fake_pm_${CUSTOMER_ID}`,
    provider_payment_intent_id: `fake_pi_${paymentId}`,
    provider_charge_id: `fake_ch_${paymentId}`,
    connected_account_id: null,
    idempotency_key: `createPayment:${paymentId}`,
    captured_at: now,
    created_at: now,
    updated_at: now,
  });
}

async function seedRefund(
  refundId: string,
  paymentId: string,
  missionId: string,
  amountMinor: number,
  status: string = RefundStatuses.SUCCEEDED
): Promise<void> {
  const now = admin.firestore.Timestamp.now();
  await db.collection("refunds").doc(refundId).set({
    refund_id: refundId,
    mission_id: missionId,
    payment_id: paymentId,
    amount_minor: amountMinor,
    reason: RefundReasons.GOODWILL,
    initiated_by_user_id: CUSTOMER_ID,
    initiated_by_role: "customer",
    is_admin_initiated: false,
    status,
    is_post_payout: false,
    related_payout_id: null,
    provider_refund_id: `fake_re_${refundId}`,
    idempotency_key: `refund_${paymentId}_${refundId}`,
    request_key: `refund_${paymentId}_${refundId}`,
    created_at: now,
    updated_at: now,
  });
}

/**
 * 🔒 IMPORTANT : `financial_snapshots` (Phase 1-5, moteur de pricing legacy)
 * stocke ses montants en DOLLARS (virgule flottante), PAS en cents — voir
 * money.ts et le commentaire de tête de missionFinancialBalance.ts.
 * `recalculateMissionFinancialBalance()` applique `toMinorUnits()` (×100)
 * sur `driver_net_mission_earnings`/`platform_commission_amount`/
 * `customer_service_fee` pour les convertir en cents. Les paramètres de CE
 * helper sont donc exprimés en CENTS ATTENDUS EN SORTIE (`*_minor`), et
 * convertis ICI en dollars (÷100) pour correspondre au format réel du
 * document source — évite toute confusion d'unité côté test.
 */
async function seedSnapshot(
  snapshotId: string,
  missionId: string,
  opts: {
    driverNetMissionEarningsMinor: number;
    platformCommissionAmountMinor?: number;
    customerServiceFeeMinor?: number;
    status?: string;
  }
): Promise<void> {
  await db.collection("financial_snapshots").doc(snapshotId).set({
    snapshot_id: snapshotId,
    mission_id: missionId,
    customer_id: CUSTOMER_ID,
    driver_id: DRIVER_ID,
    pricing_version: "TEST-PRICING-MFB",
    mission_base_value: 100,
    driver_net_mission_earnings: opts.driverNetMissionEarningsMinor / 100,
    platform_commission_amount: (opts.platformCommissionAmountMinor ?? 1200) / 100,
    customer_service_fee: (opts.customerServiceFeeMinor ?? 300) / 100,
    status: opts.status ?? "confirmed",
    created_at: admin.firestore.Timestamp.now(),
    confirmed_at: admin.firestore.Timestamp.now(),
  });
}

async function seedLedgerEntry(
  missionId: string,
  type: string,
  amountMinor: number,
  opts: { status?: string; direction?: string; party?: string; id?: string } = {}
): Promise<string> {
  const ref = opts.id
    ? db.collection("transaction_ledger").doc(opts.id)
    : db.collection("transaction_ledger").doc();
  await ref.set({
    ledger_entry_id: ref.id,
    mission_id: missionId,
    transaction_id: null,
    type,
    amount_minor: amountMinor,
    currency: "CAD",
    direction: opts.direction ?? LedgerDirections.CREDIT,
    party: opts.party ?? LedgerParties.DRIVER,
    created_at: admin.firestore.Timestamp.now(),
    created_by: "test-seed",
    source_event: "test_seed",
    status: opts.status ?? LedgerEntryStatuses.CONFIRMED,
    reference_id: null,
  });
  return ref.id;
}

async function seedPaidPayout(
  payoutId: string,
  snapshotIds: string[],
  amountMinor: number
): Promise<void> {
  await db.collection("driver_payouts").doc(payoutId).set({
    driver_id: DRIVER_ID,
    financial_snapshot_ids: snapshotIds,
    amount_minor: amountMinor,
    currency: "CAD",
    status: "paid",
    payout_hold_period_hours: 0,
    payout_eligible_at: admin.firestore.Timestamp.now(),
    provider_payout_id: `fake_po_${payoutId}`,
    connected_account_id: `fake_acct_${DRIVER_ID}`,
    created_at: admin.firestore.Timestamp.now(),
    paid_at: admin.firestore.Timestamp.now(),
    idempotency_key: `submitDriverPayout:${payoutId}`,
  });
}

async function cleanupAll(missionIds: string[]): Promise<void> {
  const batch = db.batch();

  for (const missionId of missionIds) {
    const [paymentsSnap, refundsSnap, ledgerSnap, snapshotsSnap] = await Promise.all([
      db.collection("payments").where("mission_id", "==", missionId).get(),
      db.collection("refunds").where("mission_id", "==", missionId).get(),
      db.collection("transaction_ledger").where("mission_id", "==", missionId).get(),
      db.collection("financial_snapshots").where("mission_id", "==", missionId).get(),
    ]);
    paymentsSnap.docs.forEach((d) => batch.delete(d.ref));
    refundsSnap.docs.forEach((d) => batch.delete(d.ref));
    ledgerSnap.docs.forEach((d) => batch.delete(d.ref));
    snapshotsSnap.docs.forEach((d) => batch.delete(d.ref));
    batch.delete(db.collection("mission_financial_balance").doc(missionId));
  }

  const payoutsSnap = await db.collection("driver_payouts").where("driver_id", "==", DRIVER_ID).get();
  payoutsSnap.docs.forEach((d) => batch.delete(d.ref));

  await batch.commit();
}

/** Vérifie qu'un champ *_minor est bien un entier strict (aucun flottant). */
function expectIntegerMinor(value: number, label: string): void {
  expect(Number.isInteger(value)).toBe(true);
  expect(value).not.toBeNaN();
  // eslint-disable-next-line no-unused-expressions
  label; // (label conservé pour lisibilité des assertions ci-dessus dans les diffs de test)
}

describe("recalculateMissionFinancialBalance — état synthétique dérivé de mission_financial_balance", () => {
  it("1. capture SEULE : customer_charged/driver_earned/platform_commission/customer_service_fee corrects, reste à 0", async () => {
    const missionId = "mfb_mission_capture_only";
    const paymentId = "mfb_pay_capture_only";
    const snapshotId = "mfb_snap_capture_only";
    await Promise.all([
      seedPayment(paymentId, missionId, { amountCapturedMinor: 10000 }),
      seedSnapshot(snapshotId, missionId, {
        driverNetMissionEarningsMinor: 8500,
        platformCommissionAmountMinor: 1200,
        customerServiceFeeMinor: 300,
      }),
    ]);

    const balance = await recalculateMissionFinancialBalance(missionId);

    expect(balance.mission_id).toBe(missionId);
    expect(balance.customer_charged_minor).toBe(10000);
    expect(balance.customer_refunded_minor).toBe(0);
    expect(balance.platform_commission_minor).toBe(1200);
    expect(balance.customer_service_fee_minor).toBe(300);
    expect(balance.driver_earned_minor).toBe(8500);
    expect(balance.driver_paid_minor).toBe(0);
    expect(balance.driver_tip_minor).toBe(0);
    expect(balance.driver_bonus_minor).toBe(0);
    expect(balance.adjustments_minor).toBe(0);
    expect(balance.provider_processing_cost_minor).toBe(0);
    // outstanding_driver = earned+tip+bonus+adjustments - paid = 8500 - 0
    expect(balance.outstanding_driver_balance_minor).toBe(8500);
    // outstanding_customer = charged - refunded = 10000 - 0
    expect(balance.outstanding_customer_balance_minor).toBe(10000);
    // contribution_margin = commission + service_fee - processing_cost = 1200+300-0
    expect(balance.contribution_margin_minor).toBe(1500);

    // Le document persisté en Firestore doit être identique à la valeur renvoyée.
    const persisted = (
      await db.collection("mission_financial_balance").doc(missionId).get()
    ).data() as MissionFinancialBalanceDoc;
    expect(persisted.customer_charged_minor).toBe(10000);
    expect(persisted.driver_earned_minor).toBe(8500);

    await cleanupAll([missionId]);
  });

  it("2. capture + TIP : driver_tip_minor pris en compte dans outstanding_driver_balance", async () => {
    const missionId = "mfb_mission_capture_tip";
    const paymentId = "mfb_pay_capture_tip";
    const snapshotId = "mfb_snap_capture_tip";
    await Promise.all([
      seedPayment(paymentId, missionId, { amountCapturedMinor: 10000 }),
      seedSnapshot(snapshotId, missionId, { driverNetMissionEarningsMinor: 8500 }),
    ]);
    await seedLedgerEntry(missionId, LedgerEntryTypes.DRIVER_TIP, 500);

    const balance = await recalculateMissionFinancialBalance(missionId);

    expect(balance.driver_tip_minor).toBe(500);
    expect(balance.driver_earned_minor).toBe(8500);
    // outstanding_driver = 8500 (earned) + 500 (tip) + 0 (bonus) + 0 (adj) - 0 (paid)
    expect(balance.outstanding_driver_balance_minor).toBe(9000);

    await cleanupAll([missionId]);
  });

  it("3. capture + REFUND PARTIEL : customer_refunded_minor exact, outstanding_customer_balance réduit", async () => {
    const missionId = "mfb_mission_capture_refund";
    const paymentId = "mfb_pay_capture_refund";
    const snapshotId = "mfb_snap_capture_refund";
    const refundId = "mfb_refund_partial_1";
    await Promise.all([
      seedPayment(paymentId, missionId, { amountCapturedMinor: 10000, amountRefundedMinor: 3000 }),
      seedSnapshot(snapshotId, missionId, { driverNetMissionEarningsMinor: 8500 }),
    ]);
    await seedRefund(refundId, paymentId, missionId, 3000, RefundStatuses.SUCCEEDED);
    // Un refund FAILED ne doit JAMAIS compter comme argent rendu.
    await seedRefund("mfb_refund_failed_1", paymentId, missionId, 999, RefundStatuses.FAILED);

    const balance = await recalculateMissionFinancialBalance(missionId);

    expect(balance.customer_charged_minor).toBe(10000);
    expect(balance.customer_refunded_minor).toBe(3000); // le FAILED (999) est exclu
    expect(balance.outstanding_customer_balance_minor).toBe(7000);

    await cleanupAll([missionId]);
  });

  it("4. capture + PAYOUT payé : driver_paid_minor = driver_earned, outstanding_driver_balance retombe à 0", async () => {
    const missionId = "mfb_mission_capture_payout";
    const paymentId = "mfb_pay_capture_payout";
    const snapshotId = "mfb_snap_capture_payout";
    const payoutId = "mfb_payout_single_1";
    await Promise.all([
      seedPayment(paymentId, missionId, { amountCapturedMinor: 10000 }),
      seedSnapshot(snapshotId, missionId, { driverNetMissionEarningsMinor: 8500 }),
    ]);
    await seedPaidPayout(payoutId, [snapshotId], 8500);

    const balance = await recalculateMissionFinancialBalance(missionId);

    expect(balance.driver_earned_minor).toBe(8500);
    expect(balance.driver_paid_minor).toBe(8500);
    expect(balance.outstanding_driver_balance_minor).toBe(0);

    await cleanupAll([missionId]);
  });

  it("5. capture + AJUSTEMENT ADMIN (ledger DRIVER_ADJUSTMENT) : adjustments_minor reflété", async () => {
    const missionId = "mfb_mission_capture_adjustment";
    const paymentId = "mfb_pay_capture_adjustment";
    const snapshotId = "mfb_snap_capture_adjustment";
    await Promise.all([
      seedPayment(paymentId, missionId, { amountCapturedMinor: 10000 }),
      seedSnapshot(snapshotId, missionId, { driverNetMissionEarningsMinor: 8500 }),
    ]);
    await seedLedgerEntry(missionId, LedgerEntryTypes.DRIVER_ADJUSTMENT, 700, {
      party: LedgerParties.DRIVER,
    });
    // Un ajustement REVERSED ne doit JAMAIS être compté.
    await seedLedgerEntry(missionId, LedgerEntryTypes.DRIVER_ADJUSTMENT, 4242, {
      status: LedgerEntryStatuses.REVERSED,
    });

    const balance = await recalculateMissionFinancialBalance(missionId);

    expect(balance.adjustments_minor).toBe(700);
    expect(balance.outstanding_driver_balance_minor).toBe(8500 + 700);

    await cleanupAll([missionId]);
  });

  it("6. PLUSIEURS missions/snapshots dans UN MÊME payout : driver_paid_minor correctement attribué à CHACUNE", async () => {
    const missionA = "mfb_mission_multi_a";
    const missionB = "mfb_mission_multi_b";
    const paymentA = "mfb_pay_multi_a";
    const paymentB = "mfb_pay_multi_b";
    const snapshotA = "mfb_snap_multi_a";
    const snapshotB = "mfb_snap_multi_b";
    const payoutId = "mfb_payout_multi_1";

    await Promise.all([
      seedPayment(paymentA, missionA, { amountCapturedMinor: 6000 }),
      seedPayment(paymentB, missionB, { amountCapturedMinor: 9000 }),
      seedSnapshot(snapshotA, missionA, { driverNetMissionEarningsMinor: 5000 }),
      seedSnapshot(snapshotB, missionB, { driverNetMissionEarningsMinor: 7500 }),
    ]);
    // Un SEUL payout PAID regroupant les deux snapshots (agrégation réelle,
    // voir calculateDriverPayout.ts) — driver_earned de CHAQUE mission doit
    // être marqué payé indépendamment (voir missionFinancialBalance.ts,
    // hypothèse documentée : un payout PAID paie l'intégralité des
    // snapshots qu'il inclut).
    await seedPaidPayout(payoutId, [snapshotA, snapshotB], 12500);

    const balanceA = await recalculateMissionFinancialBalance(missionA);
    const balanceB = await recalculateMissionFinancialBalance(missionB);

    expect(balanceA.driver_earned_minor).toBe(5000);
    expect(balanceA.driver_paid_minor).toBe(5000);
    expect(balanceA.outstanding_driver_balance_minor).toBe(0);

    expect(balanceB.driver_earned_minor).toBe(7500);
    expect(balanceB.driver_paid_minor).toBe(7500);
    expect(balanceB.outstanding_driver_balance_minor).toBe(0);

    await cleanupAll([missionA, missionB]);
  });

  it("7. RECALCUL IDEMPOTENT : rejouer plusieurs fois produit EXACTEMENT le même résultat", async () => {
    const missionId = "mfb_mission_idempotent";
    const paymentId = "mfb_pay_idempotent";
    const snapshotId = "mfb_snap_idempotent";
    await Promise.all([
      seedPayment(paymentId, missionId, { amountCapturedMinor: 10000 }),
      seedSnapshot(snapshotId, missionId, { driverNetMissionEarningsMinor: 8500 }),
    ]);
    await seedLedgerEntry(missionId, LedgerEntryTypes.DRIVER_TIP, 500);

    const first = await recalculateMissionFinancialBalance(missionId);
    const second = await recalculateMissionFinancialBalance(missionId);
    const third = await recalculateMissionFinancialBalance(missionId);

    // On compare tout SAUF updated_at (qui change nécessairement à chaque appel).
    const strip = (b: MissionFinancialBalanceDoc) => {
      const { updated_at: _updatedAt, ...rest } = b;
      return rest;
    };
    expect(strip(second)).toEqual(strip(first));
    expect(strip(third)).toEqual(strip(first));

    await cleanupAll([missionId]);
  });

  it("8. LEDGER HISTORIQUE INCHANGÉ après recalcul : aucune écriture/suppression dans transaction_ledger", async () => {
    const missionId = "mfb_mission_ledger_untouched";
    const paymentId = "mfb_pay_ledger_untouched";
    const snapshotId = "mfb_snap_ledger_untouched";
    await Promise.all([
      seedPayment(paymentId, missionId, { amountCapturedMinor: 10000 }),
      seedSnapshot(snapshotId, missionId, { driverNetMissionEarningsMinor: 8500 }),
    ]);
    const tipEntryId = await seedLedgerEntry(missionId, LedgerEntryTypes.DRIVER_TIP, 500);

    const beforeSnap = await db.collection("transaction_ledger").doc(tipEntryId).get();
    const beforeData = beforeSnap.data();

    await recalculateMissionFinancialBalance(missionId);
    await recalculateMissionFinancialBalance(missionId); // rejoué deux fois pour être sûr

    const afterSnap = await db.collection("transaction_ledger").doc(tipEntryId).get();
    const afterData = afterSnap.data();

    expect(afterData).toEqual(beforeData);

    // Le NOMBRE d'entrées ledger pour cette mission ne doit pas non plus
    // avoir changé (le recalcul est purement une LECTURE, jamais une écriture
    // dans transaction_ledger).
    const ledgerCountSnap = await db
      .collection("transaction_ledger")
      .where("mission_id", "==", missionId)
      .get();
    expect(ledgerCountSnap.size).toBe(1);

    await cleanupAll([missionId]);
  });

  it("9. valeurs amount_minor STRICTEMENT ENTIÈRES sur TOUS les champs dérivés, scénario combiné complet", async () => {
    const missionId = "mfb_mission_all_fields";
    const paymentId = "mfb_pay_all_fields";
    const snapshotId = "mfb_snap_all_fields";
    const payoutId = "mfb_payout_all_fields";
    const refundId = "mfb_refund_all_fields";

    await Promise.all([
      seedPayment(paymentId, missionId, { amountCapturedMinor: 20000, amountRefundedMinor: 1500 }),
      seedSnapshot(snapshotId, missionId, {
        driverNetMissionEarningsMinor: 15000,
        platformCommissionAmountMinor: 2500,
        customerServiceFeeMinor: 600,
      }),
    ]);
    await seedRefund(refundId, paymentId, missionId, 1500, RefundStatuses.SUCCEEDED);
    await seedLedgerEntry(missionId, LedgerEntryTypes.DRIVER_TIP, 400);
    await seedLedgerEntry(missionId, LedgerEntryTypes.DRIVER_BONUS, 250);
    await seedLedgerEntry(missionId, LedgerEntryTypes.DRIVER_ADJUSTMENT, 100);
    await seedLedgerEntry(missionId, LedgerEntryTypes.PAYMENT_PROCESSING_FEE, 180, {
      party: LedgerParties.PLATFORM,
      direction: LedgerDirections.DEBIT,
    });
    await seedPaidPayout(payoutId, [snapshotId], 15000);

    const balance = await recalculateMissionFinancialBalance(missionId);

    const fields: Array<keyof MissionFinancialBalanceDoc> = [
      "customer_charged_minor",
      "customer_refunded_minor",
      "platform_commission_minor",
      "customer_service_fee_minor",
      "driver_earned_minor",
      "driver_paid_minor",
      "driver_tip_minor",
      "driver_bonus_minor",
      "adjustments_minor",
      "outstanding_driver_balance_minor",
      "outstanding_customer_balance_minor",
      "provider_processing_cost_minor",
      "contribution_margin_minor",
    ];
    for (const field of fields) {
      const value = balance[field] as number;
      expectIntegerMinor(value, field);
    }

    // Valeurs exactes (calcul manuel de référence).
    expect(balance.customer_charged_minor).toBe(20000);
    expect(balance.customer_refunded_minor).toBe(1500);
    expect(balance.platform_commission_minor).toBe(2500);
    expect(balance.customer_service_fee_minor).toBe(600);
    expect(balance.driver_earned_minor).toBe(15000);
    expect(balance.driver_paid_minor).toBe(15000);
    expect(balance.driver_tip_minor).toBe(400);
    expect(balance.driver_bonus_minor).toBe(250);
    expect(balance.adjustments_minor).toBe(100);
    expect(balance.provider_processing_cost_minor).toBe(180);
    // outstanding_driver = (15000+400+250+100) - 15000 = 750
    expect(balance.outstanding_driver_balance_minor).toBe(750);
    // outstanding_customer = 20000 - 1500 = 18500
    expect(balance.outstanding_customer_balance_minor).toBe(18500);
    // contribution_margin = (2500+600) - 180 = 2920
    expect(balance.contribution_margin_minor).toBe(2920);

    await cleanupAll([missionId]);
  });

  it("10. mission INEXISTANTE / aucune donnée source : document 'zéro' propre, aucune exception, aucun NaN", async () => {
    const missionId = "mfb_mission_does_not_exist_at_all";

    // Aucun seed — la mission n'existe dans AUCUNE collection source.
    await expect(recalculateMissionFinancialBalance(missionId)).resolves.toBeDefined();

    const balance = await recalculateMissionFinancialBalance(missionId);

    expect(balance.mission_id).toBe(missionId);
    expect(balance.customer_charged_minor).toBe(0);
    expect(balance.customer_refunded_minor).toBe(0);
    expect(balance.platform_commission_minor).toBe(0);
    expect(balance.customer_service_fee_minor).toBe(0);
    expect(balance.driver_earned_minor).toBe(0);
    expect(balance.driver_paid_minor).toBe(0);
    expect(balance.driver_tip_minor).toBe(0);
    expect(balance.driver_bonus_minor).toBe(0);
    expect(balance.adjustments_minor).toBe(0);
    expect(balance.outstanding_driver_balance_minor).toBe(0);
    expect(balance.outstanding_customer_balance_minor).toBe(0);
    expect(balance.provider_processing_cost_minor).toBe(0);
    expect(balance.contribution_margin_minor).toBe(0);

    // Aucun champ ne doit être NaN/undefined — vérification exhaustive.
    for (const [key, value] of Object.entries(balance)) {
      if (typeof value === "number") {
        expect(value).not.toBeNaN();
      } else {
        expect(value).toBeDefined();
      }
    }

    await cleanupAll([missionId]);
  });
});
