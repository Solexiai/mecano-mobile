// ---------------------------------------------------------------------------
// Test d'intégration — Bloc G (Réconciliation), Phase 6, point 27.
//
// Vérifie que `runReconciliation()` détecte chacune des 11 anomalies
// demandées SANS jamais corriger silencieusement les données sous-jacentes
// (voir reconciliationEngine.ts), en injectant un `FakePaymentProvider`
// configuré pour simuler un état "Provider" divergent du monde Movi-K.
//
// Couvre :
//   1. payment_missing_in_movik   — paiement provider absent de Movi-K
//   2. payment_missing_in_provider— paiement Movi-K absent du provider
//   3. payment_amount_mismatch    — montant capturé différent
//   4. refund_missing_in_ledger   — refund provider absent de Movi-K
//   5. refund_missing_in_provider — refund Movi-K absent du provider
//   6. duplicate_refund           — somme des refunds > montant capturé
//   7. payout_missing             — snapshot confirmed ancien jamais payé
//   8. payout_amount_mismatch     — montant payout Movi-K != provider
//   9. tip_mismatch               — cache mission_financial_balance désynchronisé (tip)
//  10. commission_ledger_inconsistency — cache désynchronisé (commission)
//  11. webhook_unprocessed        — webhook reçu, jamais passé à 'processed'
//  + aucune anomalie sur un scénario parfaitement cohérent (status: 'ok')
//  + permissions : admin/super_admin autorisés, customer/driver refusés
//  + resolveReconciliationAnomaly : marque le statut SANS jamais modifier
//    les montants sous-jacents
// ---------------------------------------------------------------------------

import type { CallableRequest, Request } from "firebase-functions/v2/https";
import type { DecodedIdToken } from "firebase-admin/auth";
import { runReconciliationNow, RunReconciliationNowRequest } from "../../src/functions/runReconciliation";
import {
  resolveReconciliationAnomaly,
  ResolveReconciliationAnomalyRequest,
} from "../../src/functions/resolveReconciliationAnomaly";
import { runReconciliation, ReconciliationAnomalyTypes } from "../../src/lib/reconciliationEngine";
import { recalculateMissionFinancialBalance } from "../../src/lib/missionFinancialBalance";
import { admin, db } from "../../src/lib/admin";
import {
  LedgerDirections,
  LedgerEntryStatuses,
  LedgerEntryTypes,
  LedgerParties,
  PaymentStatuses,
  RefundReasons,
  RefundStatuses,
  WebhookProcessingStatuses,
} from "../../src/lib/types";
import { setPaymentProviderForTesting } from "../../src/payment/paymentProviderFactory";
import { FakePaymentProvider } from "../testUtils/fakePaymentProvider";

const ADMIN_ID = "recon_admin_001";
const SUPER_ADMIN_ID = "recon_super_admin_001";
const NON_ADMIN_ID = "recon_stranger_001";
const CUSTOMER_ID = "recon_customer_001";
const DRIVER_ID = "recon_driver_001";

function buildRequest<T>(uid: string, role: string, data: T): CallableRequest<T> {
  return {
    data,
    auth: { uid, token: { role } as unknown as DecodedIdToken, rawToken: "fake-raw-token" },
    rawRequest: {} as Request,
    acceptsStreaming: false,
  };
}

// ---------------------------------------------------------------------------
// Helpers de seed — identiques dans l'esprit à missionFinancialBalance.test.ts
// (écriture directe des collections sources, hors Cloud Functions, pour
// isoler précisément le comportement du moteur de réconciliation).
// ---------------------------------------------------------------------------

async function seedPayment(
  paymentId: string,
  missionId: string,
  opts: {
    amountCapturedMinor: number;
    amountRefundedMinor?: number;
    providerPaymentIntentId?: string;
    createdAt?: FirebaseFirestore.Timestamp;
  }
): Promise<void> {
  const now = opts.createdAt ?? admin.firestore.Timestamp.now();
  await db.collection("payments").doc(paymentId).set({
    payment_id: paymentId,
    mission_id: missionId,
    customer_id: CUSTOMER_ID,
    driver_id: DRIVER_ID,
    status: PaymentStatuses.CAPTURED,
    currency: "CAD",
    amount_authorized_minor: opts.amountCapturedMinor,
    amount_captured_minor: opts.amountCapturedMinor,
    amount_refunded_minor: opts.amountRefundedMinor ?? 0,
    application_fee_minor: Math.round(opts.amountCapturedMinor * 0.15),
    provider: "stripe",
    provider_customer_id: `fake_cus_${CUSTOMER_ID}`,
    provider_payment_method_id: `fake_pm_${CUSTOMER_ID}`,
    provider_payment_intent_id: opts.providerPaymentIntentId ?? `fake_pi_${paymentId}`,
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
  opts: {
    status?: string;
    providerRefundId?: string | null;
    createdAt?: FirebaseFirestore.Timestamp;
  } = {}
): Promise<void> {
  const now = opts.createdAt ?? admin.firestore.Timestamp.now();
  await db.collection("refunds").doc(refundId).set({
    refund_id: refundId,
    mission_id: missionId,
    payment_id: paymentId,
    amount_minor: amountMinor,
    reason: RefundReasons.GOODWILL,
    initiated_by_user_id: CUSTOMER_ID,
    initiated_by_role: "customer",
    is_admin_initiated: false,
    status: opts.status ?? RefundStatuses.SUCCEEDED,
    is_post_payout: false,
    related_payout_id: null,
    provider_refund_id: opts.providerRefundId === undefined ? `fake_re_${refundId}` : opts.providerRefundId,
    idempotency_key: `refund_${paymentId}_${refundId}`,
    created_at: now,
    updated_at: now,
  });
}

async function seedPayout(
  payoutId: string,
  opts: {
    amountMinor: number;
    status?: string;
    providerPayoutId?: string | null;
    createdAt?: FirebaseFirestore.Timestamp;
  }
): Promise<void> {
  const now = opts.createdAt ?? admin.firestore.Timestamp.now();
  await db.collection("driver_payouts").doc(payoutId).set({
    driver_id: DRIVER_ID,
    financial_snapshot_ids: [],
    amount_minor: opts.amountMinor,
    currency: "CAD",
    status: opts.status ?? "paid",
    payout_hold_period_hours: 0,
    payout_eligible_at: now,
    provider_payout_id: opts.providerPayoutId === undefined ? `fake_po_${payoutId}` : opts.providerPayoutId,
    connected_account_id: `fake_acct_${DRIVER_ID}`,
    created_at: now,
    paid_at: now,
    idempotency_key: `submitDriverPayout:${payoutId}`,
  });
}

async function seedSnapshot(
  snapshotId: string,
  missionId: string,
  opts: {
    driverNetMissionEarningsMinor: number;
    includedInPayoutId?: string | null;
    createdAt?: FirebaseFirestore.Timestamp;
  }
): Promise<void> {
  const now = opts.createdAt ?? admin.firestore.Timestamp.now();
  await db.collection("financial_snapshots").doc(snapshotId).set({
    snapshot_id: snapshotId,
    mission_id: missionId,
    customer_id: CUSTOMER_ID,
    driver_id: DRIVER_ID,
    pricing_version: "TEST-PRICING-RECON",
    mission_base_value: 100,
    driver_net_mission_earnings: opts.driverNetMissionEarningsMinor / 100,
    platform_commission_amount: 12,
    customer_service_fee: 3,
    status: "confirmed",
    included_in_payout_id: opts.includedInPayoutId ?? null,
    created_at: now,
    confirmed_at: now,
  });
}

async function seedLedgerEntry(
  missionId: string,
  type: string,
  amountMinor: number,
  opts: { direction?: string; party?: string } = {}
): Promise<void> {
  const ref = db.collection("transaction_ledger").doc();
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
    status: LedgerEntryStatuses.CONFIRMED,
    reference_id: null,
  });
}

async function seedWebhookEvent(
  eventId: string,
  opts: {
    status: string;
    receivedAt: FirebaseFirestore.Timestamp;
    eventType?: string;
  }
): Promise<void> {
  await db.collection("provider_webhook_events").doc(eventId).set({
    provider: "stripe",
    provider_event_id: eventId,
    event_type: opts.eventType ?? "payment_intent.succeeded",
    received_at: opts.receivedAt,
    processed_at: opts.status === WebhookProcessingStatuses.PROCESSED ? opts.receivedAt : null,
    processing_status: opts.status,
    attempt_count: 1,
    related_payment_id: null,
    related_payout_id: null,
    related_refund_id: null,
    related_dispute_id: null,
    related_mission_id: null,
  });
}

async function cleanupAll(prefix: string): Promise<void> {
  const collections = [
    "payments",
    "refunds",
    "driver_payouts",
    "financial_snapshots",
    "transaction_ledger",
    "provider_webhook_events",
    "mission_financial_balance",
    "reconciliation_reports",
  ];
  for (const col of collections) {
    const snap = await db.collection(col).get();
    const toDelete = snap.docs.filter((d) => d.id.startsWith(prefix) || d.data().mission_id?.startsWith?.(prefix));
    const batch = db.batch();
    toDelete.forEach((d) => batch.delete(d.ref));
    if (toDelete.length > 0) await batch.commit();
  }
}

describe("reconciliationEngine — détection des 11 anomalies (Bloc G, point 27)", () => {
  const PERIOD_START = Date.now() - 3600 * 1000;
  const PERIOD_END = Date.now() + 3600 * 1000;

  beforeEach(() => {
    setPaymentProviderForTesting(new FakePaymentProvider());
  });

  afterEach(async () => {
    setPaymentProviderForTesting(null);
    await cleanupAll("recon_");
  });

  it("scénario parfaitement cohérent : aucune anomalie, status 'ok'", async () => {
    const missionId = "recon_mission_clean_1";
    setPaymentProviderForTesting(
      new FakePaymentProvider({
        providerPayments: [
          {
            providerPaymentIntentId: "fake_pi_recon_pay_clean_1",
            amountMinor: 5000,
            status: "succeeded",
            createdAtMillis: Date.now(),
          },
        ],
      })
    );
    await seedPayment("recon_pay_clean_1", missionId, { amountCapturedMinor: 5000 });

    const { report } = await runReconciliation({
      periodStartMillis: PERIOD_START,
      periodEndMillis: PERIOD_END,
    });

    const relevant = report.anomalies.filter(
      (a) => a.payment_id === "recon_pay_clean_1" || a.mission_id === missionId
    );
    expect(relevant).toHaveLength(0);
  });

  it("(1) payment_missing_in_movik : paiement listé chez le provider mais absent de payments/", async () => {
    setPaymentProviderForTesting(
      new FakePaymentProvider({
        providerPayments: [
          {
            providerPaymentIntentId: "fake_pi_orphan_001",
            amountMinor: 7500,
            status: "succeeded",
            createdAtMillis: Date.now(),
          },
        ],
      })
    );

    const { report } = await runReconciliation({
      periodStartMillis: PERIOD_START,
      periodEndMillis: PERIOD_END,
    });

    const found = report.anomalies.find(
      (a) =>
        a.type === ReconciliationAnomalyTypes.PAYMENT_MISSING_IN_MOVIK &&
        a.expected_amount_minor === 7500
    );
    expect(found).toBeTruthy();
    expect(found?.severity).toBe("critical");
  });

  it("(2) payment_missing_in_provider : payments/ capturé mais introuvable chez le provider", async () => {
    const missionId = "recon_mission_missing_provider_1";
    await seedPayment("recon_pay_missing_provider_1", missionId, {
      amountCapturedMinor: 3000,
      providerPaymentIntentId: "fake_pi_ghost_001",
    });
    // FakePaymentProvider par défaut (providerPayments vide) => introuvable.

    const { report } = await runReconciliation({
      periodStartMillis: PERIOD_START,
      periodEndMillis: PERIOD_END,
    });

    const found = report.anomalies.find(
      (a) =>
        a.type === ReconciliationAnomalyTypes.PAYMENT_MISSING_IN_PROVIDER &&
        a.payment_id === "recon_pay_missing_provider_1"
    );
    expect(found).toBeTruthy();
    expect(found?.expected_amount_minor).toBe(3000);
  });

  it("(3) payment_amount_mismatch : montant capturé Movi-K différent du montant provider", async () => {
    const missionId = "recon_mission_amount_mismatch_1";
    setPaymentProviderForTesting(
      new FakePaymentProvider({
        providerPayments: [
          {
            providerPaymentIntentId: "fake_pi_mismatch_001",
            amountMinor: 4200, // différent du montant Movi-K
            status: "succeeded",
            createdAtMillis: Date.now(),
          },
        ],
      })
    );
    await seedPayment("recon_pay_mismatch_1", missionId, {
      amountCapturedMinor: 4000,
      providerPaymentIntentId: "fake_pi_mismatch_001",
    });

    const { report } = await runReconciliation({
      periodStartMillis: PERIOD_START,
      periodEndMillis: PERIOD_END,
    });

    const found = report.anomalies.find(
      (a) =>
        a.type === ReconciliationAnomalyTypes.PAYMENT_AMOUNT_MISMATCH &&
        a.payment_id === "recon_pay_mismatch_1"
    );
    expect(found).toBeTruthy();
    expect(found?.expected_amount_minor).toBe(4000);
    expect(found?.actual_amount_minor).toBe(4200);
  });

  it("(4) refund_missing_in_ledger : remboursement listé chez le provider mais absent de refunds/", async () => {
    setPaymentProviderForTesting(
      new FakePaymentProvider({
        providerRefunds: [
          {
            providerRefundId: "fake_re_orphan_001",
            providerPaymentIntentId: "fake_pi_whatever",
            amountMinor: 1500,
            status: "succeeded",
            createdAtMillis: Date.now(),
          },
        ],
      })
    );

    const { report } = await runReconciliation({
      periodStartMillis: PERIOD_START,
      periodEndMillis: PERIOD_END,
    });

    const found = report.anomalies.find(
      (a) =>
        a.type === ReconciliationAnomalyTypes.REFUND_MISSING_IN_LEDGER &&
        a.expected_amount_minor === 1500
    );
    expect(found).toBeTruthy();
  });

  it("(5) refund_missing_in_provider : refund SUCCEEDED Movi-K introuvable chez le provider", async () => {
    const missionId = "recon_mission_refund_missing_1";
    await seedPayment("recon_pay_refmissing_1", missionId, { amountCapturedMinor: 5000, amountRefundedMinor: 2000 });
    await seedRefund("recon_ref_missing_1", "recon_pay_refmissing_1", missionId, 2000, {
      providerRefundId: "fake_re_ghost_001",
    });
    // FakePaymentProvider par défaut (providerRefunds vide) => introuvable.

    const { report } = await runReconciliation({
      periodStartMillis: PERIOD_START,
      periodEndMillis: PERIOD_END,
    });

    const found = report.anomalies.find(
      (a) =>
        a.type === ReconciliationAnomalyTypes.REFUND_MISSING_IN_PROVIDER &&
        a.refund_id === "recon_ref_missing_1"
    );
    expect(found).toBeTruthy();
    expect(found?.expected_amount_minor).toBe(2000);
  });

  it("(6) duplicate_refund : somme des refunds SUCCEEDED > montant capturé", async () => {
    const missionId = "recon_mission_dup_refund_1";
    await seedPayment("recon_pay_dup_1", missionId, { amountCapturedMinor: 3000, amountRefundedMinor: 4000 });
    await seedRefund("recon_ref_dup_a", "recon_pay_dup_1", missionId, 3000);
    await seedRefund("recon_ref_dup_b", "recon_pay_dup_1", missionId, 1000);

    const { report } = await runReconciliation({
      periodStartMillis: PERIOD_START,
      periodEndMillis: PERIOD_END,
    });

    const found = report.anomalies.find(
      (a) => a.type === ReconciliationAnomalyTypes.DUPLICATE_REFUND && a.payment_id === "recon_pay_dup_1"
    );
    expect(found).toBeTruthy();
    expect(found?.expected_amount_minor).toBe(3000); // montant capturé
    expect(found?.actual_amount_minor).toBe(4000); // somme des refunds
  });

  it("(7) payout_missing : snapshot confirmed ancien (>30j) jamais inclus dans un payout", async () => {
    const missionId = "recon_mission_payout_missing_1";
    const oldTimestamp = admin.firestore.Timestamp.fromMillis(Date.now() - 40 * 24 * 3600 * 1000);
    await seedSnapshot("recon_snap_stale_1", missionId, {
      driverNetMissionEarningsMinor: 6000,
      createdAt: oldTimestamp,
    });

    const { report } = await runReconciliation({
      periodStartMillis: oldTimestamp.toMillis() - 3600 * 1000,
      periodEndMillis: oldTimestamp.toMillis() + 3600 * 1000,
    });

    const found = report.anomalies.find(
      (a) => a.type === ReconciliationAnomalyTypes.PAYOUT_MISSING && a.mission_id === missionId
    );
    expect(found).toBeTruthy();
    expect(found?.expected_amount_minor).toBe(6000);
  });

  it("(8) payout_amount_mismatch : montant payout Movi-K différent du montant provider", async () => {
    setPaymentProviderForTesting(
      new FakePaymentProvider({
        providerPayouts: [
          {
            providerPayoutId: "fake_po_mismatch_001",
            connectedAccountId: null,
            amountMinor: 9000,
            status: "paid",
            createdAtMillis: Date.now(),
          },
        ],
      })
    );
    await seedPayout("recon_payout_mismatch_1", { amountMinor: 8500, providerPayoutId: "fake_po_mismatch_001" });

    const { report } = await runReconciliation({
      periodStartMillis: PERIOD_START,
      periodEndMillis: PERIOD_END,
    });

    const found = report.anomalies.find(
      (a) =>
        a.type === ReconciliationAnomalyTypes.PAYOUT_AMOUNT_MISMATCH &&
        a.payout_id === "recon_payout_mismatch_1"
    );
    expect(found).toBeTruthy();
    expect(found?.expected_amount_minor).toBe(8500);
    expect(found?.actual_amount_minor).toBe(9000);
  });

  it("(8b) payout_missing (via provider) : payout PAID Movi-K introuvable chez le provider", async () => {
    await seedPayout("recon_payout_ghost_1", { amountMinor: 4000, providerPayoutId: "fake_po_ghost_001" });
    // FakePaymentProvider par défaut (providerPayouts vide) => introuvable.

    const { report } = await runReconciliation({
      periodStartMillis: PERIOD_START,
      periodEndMillis: PERIOD_END,
    });

    const found = report.anomalies.find(
      (a) => a.type === ReconciliationAnomalyTypes.PAYOUT_MISSING && a.payout_id === "recon_payout_ghost_1"
    );
    expect(found).toBeTruthy();
  });

  it("(9) tip_mismatch : cache mission_financial_balance désynchronisé après un nouveau tip", async () => {
    const missionId = "recon_mission_tip_mismatch_1";
    await seedPayment("recon_pay_tip_1", missionId, { amountCapturedMinor: 5000 });
    await seedSnapshot("recon_snap_tip_1", missionId, { driverNetMissionEarningsMinor: 4000 });

    // 1er recalcul : cache cohérent, AUCUN tip pour l'instant.
    await recalculateMissionFinancialBalance(missionId);

    // Un tip est ajouté DIRECTEMENT au ledger (simulateur d'un recalcul
    // manqué) SANS rappeler recalculateMissionFinancialBalance ensuite —
    // le cache stocké reste donc figé sur l'ancienne valeur (tip=0) alors
    // que le recalcul à la volée du moteur de réconciliation verra le tip.
    await seedLedgerEntry(missionId, LedgerEntryTypes.DRIVER_TIP, 500);

    const { report } = await runReconciliation({
      periodStartMillis: PERIOD_START,
      periodEndMillis: PERIOD_END,
    });

    const found = report.anomalies.find(
      (a) => a.type === ReconciliationAnomalyTypes.TIP_MISMATCH && a.mission_id === missionId
    );
    expect(found).toBeTruthy();
    expect(found?.expected_amount_minor).toBe(500); // recalcul frais (avec le tip)
    expect(found?.actual_amount_minor).toBe(0); // cache stocké (sans le tip)
  });

  it("(10) commission_ledger_inconsistency : cache platform_commission_minor désynchronisé", async () => {
    const missionId = "recon_mission_commission_mismatch_1";
    await seedPayment("recon_pay_comm_1", missionId, { amountCapturedMinor: 5000 });
    await seedSnapshot("recon_snap_comm_1", missionId, { driverNetMissionEarningsMinor: 4000 });
    await recalculateMissionFinancialBalance(missionId);

    // Force artificiellement une valeur stockée incohérente (simulateur
    // d'une écriture concurrente/bug plutôt qu'un vrai recalcul manqué).
    await db.collection("mission_financial_balance").doc(missionId).update({
      platform_commission_minor: 999999,
    });

    const { report } = await runReconciliation({
      periodStartMillis: PERIOD_START,
      periodEndMillis: PERIOD_END,
    });

    const found = report.anomalies.find(
      (a) =>
        a.type === ReconciliationAnomalyTypes.COMMISSION_LEDGER_INCONSISTENCY &&
        a.mission_id === missionId
    );
    expect(found).toBeTruthy();
    expect(found?.actual_amount_minor).toBe(999999);
    expect(found?.expected_amount_minor).toBe(1200); // recalcul frais depuis le snapshot (12$ -> 1200 cents)
  });

  it("(11) webhook_unprocessed : évènement reçu depuis >15 min jamais passé à 'processed'", async () => {
    const staleReceivedAt = admin.firestore.Timestamp.fromMillis(Date.now() - 20 * 60 * 1000);
    await seedWebhookEvent("recon_evt_stale_1", {
      status: WebhookProcessingStatuses.RECEIVED,
      receivedAt: staleReceivedAt,
    });

    const { report } = await runReconciliation({
      periodStartMillis: PERIOD_START,
      periodEndMillis: PERIOD_END,
    });

    const found = report.anomalies.find(
      (a) =>
        a.type === ReconciliationAnomalyTypes.WEBHOOK_UNPROCESSED &&
        a.description.includes("recon_evt_stale_1")
    );
    expect(found).toBeTruthy();
    expect(found?.severity).toBe("critical");
  });

  it("webhook 'processed' récent : AUCUNE anomalie (comportement normal, pas un faux positif)", async () => {
    await seedWebhookEvent("recon_evt_ok_1", {
      status: WebhookProcessingStatuses.PROCESSED,
      receivedAt: admin.firestore.Timestamp.now(),
    });

    const { report } = await runReconciliation({
      periodStartMillis: PERIOD_START,
      periodEndMillis: PERIOD_END,
    });

    const found = report.anomalies.find((a) => a.description?.includes("recon_evt_ok_1"));
    expect(found).toBeFalsy();
  });

  it("ne corrige JAMAIS silencieusement : les documents sources restent inchangés après le rapport", async () => {
    const missionId = "recon_mission_no_silent_fix_1";
    await seedPayment("recon_pay_nosilent_1", missionId, {
      amountCapturedMinor: 3000,
      providerPaymentIntentId: "fake_pi_nosilent_001",
    });

    await runReconciliation({ periodStartMillis: PERIOD_START, periodEndMillis: PERIOD_END });

    const paymentAfter = await db.collection("payments").doc("recon_pay_nosilent_1").get();
    // Le document payment n'a SUBI AUCUNE modification (montant, statut
    // identiques) malgré l'anomalie détectée (payment_missing_in_provider).
    expect(paymentAfter.data()!.amount_captured_minor).toBe(3000);
    expect(paymentAfter.data()!.status).toBe(PaymentStatuses.CAPTURED);
  });
});

describe("runReconciliationNow — Cloud Function callable (permissions)", () => {
  afterEach(async () => {
    setPaymentProviderForTesting(null);
    await cleanupAll("recon_");
  });

  beforeEach(() => {
    setPaymentProviderForTesting(new FakePaymentProvider());
  });

  it("admin autorisé : exécute la réconciliation et renvoie un reportId", async () => {
    const result = await runReconciliationNow.run(
      buildRequest<RunReconciliationNowRequest>(ADMIN_ID, "admin", {
        periodStartMillis: Date.now() - 3600 * 1000,
        periodEndMillis: Date.now() + 3600 * 1000,
      })
    );
    expect(result.success).toBe(true);
    expect(result.reportId).toBeTruthy();

    const reportSnap = await db.collection("reconciliation_reports").doc(result.reportId).get();
    expect(reportSnap.exists).toBe(true);
  });

  it("super_admin autorisé", async () => {
    const result = await runReconciliationNow.run(
      buildRequest<RunReconciliationNowRequest>(SUPER_ADMIN_ID, "super_admin", {
        periodStartMillis: Date.now() - 3600 * 1000,
        periodEndMillis: Date.now() + 3600 * 1000,
      })
    );
    expect(result.success).toBe(true);
  });

  it("refuse (permission-denied) customer", async () => {
    await expect(
      runReconciliationNow.run(
        buildRequest<RunReconciliationNowRequest>(NON_ADMIN_ID, "customer", {
          periodStartMillis: Date.now() - 3600 * 1000,
          periodEndMillis: Date.now() + 3600 * 1000,
        })
      )
    ).rejects.toThrow();
  });

  it("refuse (permission-denied) driver", async () => {
    await expect(
      runReconciliationNow.run(
        buildRequest<RunReconciliationNowRequest>(NON_ADMIN_ID, "driver", {
          periodStartMillis: Date.now() - 3600 * 1000,
          periodEndMillis: Date.now() + 3600 * 1000,
        })
      )
    ).rejects.toThrow();
  });

  it("refuse (invalid-argument) une fenêtre temporelle invalide (end <= start)", async () => {
    await expect(
      runReconciliationNow.run(
        buildRequest<RunReconciliationNowRequest>(ADMIN_ID, "admin", {
          periodStartMillis: Date.now(),
          periodEndMillis: Date.now() - 1000,
        })
      )
    ).rejects.toThrow();
  });
});

describe("resolveReconciliationAnomaly — suivi administratif SANS correction financière", () => {
  afterEach(async () => {
    setPaymentProviderForTesting(null);
    await cleanupAll("recon_");
  });

  it("admin peut marquer une anomalie 'resolved' avec des notes, sans toucher aux montants", async () => {
    setPaymentProviderForTesting(new FakePaymentProvider());
    await seedPayment("recon_pay_resolve_1", "recon_mission_resolve_1", {
      amountCapturedMinor: 2000,
      providerPaymentIntentId: "fake_pi_resolve_ghost",
    });

    const { report } = await runReconciliation({
      periodStartMillis: Date.now() - 3600 * 1000,
      periodEndMillis: Date.now() + 3600 * 1000,
    });
    const idx = report.anomalies.findIndex((a) => a.payment_id === "recon_pay_resolve_1");
    expect(idx).toBeGreaterThanOrEqual(0);

    const result = await resolveReconciliationAnomaly.run(
      buildRequest<ResolveReconciliationAnomalyRequest>(ADMIN_ID, "admin", {
        reportId: report.report_id,
        anomalyIndex: idx,
        newStatus: "resolved",
        resolutionNotes: "Vérifié manuellement avec le support Stripe — faux positif de test.",
      })
    );
    expect(result.success).toBe(true);

    const reportAfter = await db.collection("reconciliation_reports").doc(report.report_id).get();
    const anomalyAfter = reportAfter.data()!.anomalies[idx];
    expect(anomalyAfter.status).toBe("resolved");
    expect(anomalyAfter.resolution_notes).toContain("Vérifié manuellement");
    // Le montant/l'anomalie elle-même reste inchangée (traçabilité) —
    // seul le statut administratif change.
    expect(anomalyAfter.expected_amount_minor).toBe(2000);

    // Le paiement sous-jacent lui-même n'a SUBI AUCUNE correction.
    const paymentAfter = await db.collection("payments").doc("recon_pay_resolve_1").get();
    expect(paymentAfter.data()!.amount_captured_minor).toBe(2000);
  });

  it("refuse (permission-denied) un non-admin", async () => {
    await expect(
      resolveReconciliationAnomaly.run(
        buildRequest<ResolveReconciliationAnomalyRequest>(NON_ADMIN_ID, "customer", {
          reportId: "does_not_matter",
          anomalyIndex: 0,
          newStatus: "resolved",
          resolutionNotes: "test",
        })
      )
    ).rejects.toThrow();
  });

  it("refuse (invalid-argument) sans resolutionNotes", async () => {
    await expect(
      resolveReconciliationAnomaly.run(
        buildRequest<ResolveReconciliationAnomalyRequest>(ADMIN_ID, "admin", {
          reportId: "does_not_matter",
          anomalyIndex: 0,
          newStatus: "resolved",
          resolutionNotes: "",
        })
      )
    ).rejects.toThrow();
  });
});
