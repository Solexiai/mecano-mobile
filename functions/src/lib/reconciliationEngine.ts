// -----------------------------------------------------------------------------
// reconciliationEngine.ts — Moteur de réconciliation financière RÉEL
// (Phase 6, directive 38 points, Bloc G / point 27).
//
// PRINCIPE NON NÉGOCIABLE : « Ne jamais corriger silencieusement une
// anomalie financière. » Ce moteur ne fait QUE COMPARER et RAPPORTER — il
// n'écrit JAMAIS dans payments/refunds/driver_payouts/transaction_ledger/
// mission_financial_balance. La SEULE écriture qu'il produit est un nouveau
// document `reconciliation_reports/{reportId}` (append-only, jamais
// modifié après création — voir firestore.rules `allow write: if false`
// déjà en place).
//
// SOURCES COMPARÉES (7 axes explicitement demandés) :
//   Provider (Stripe, via PaymentProvider.list*/reconcileTransaction)
//     ↕ payments (Firestore)
//     ↕ refunds (Firestore)
//     ↕ driver_payouts (Firestore)
//     ↕ transaction_ledger (Firestore)
//     ↕ mission_financial_balance (Firestore, cache dérivé — voir
//       computeMissionFinancialBalance(), jamais lu comme source de vérité
//       seule, toujours recalculé à la volée pour la comparaison)
//     ↕ provider_webhook_events (Firestore)
//
// 12 TYPES D'ANOMALIES DÉTECTÉS (énumération stable, voir
// ReconciliationAnomalyTypes ci-dessous) :
//   1. payment_missing_in_movik       — paiement provider absent de Movi-K
//   2. payment_missing_in_provider    — paiement Movi-K absent du provider
//   3. payment_amount_mismatch        — montant capturé différent
//   4. refund_missing_in_ledger       — refund provider absent du ledger Movi-K
//   5. refund_missing_in_provider     — refund Movi-K absent du provider
//   6. duplicate_refund               — double refund SUCCEEDED pour le même paiement au-delà du capturé
//   7. payout_missing                 — payout manquant (snapshot confirmed jamais inclus, ancien)
//   8. payout_amount_mismatch         — montant payout incorrect (Movi-K vs provider)
//   9. tip_mismatch                   — pourboire incohérent (ledger vs mission_financial_balance)
//  10. commission_ledger_inconsistency — incohérence commission/ledger
//  11. webhook_unprocessed            — webhook reçu mais jamais passé à `processed`
//  12. environment_mismatch          — référence Movi-K (stripe_environment) incompatible avec
//                                       l'environnement Stripe actif (Phase 8B item 3) : émise à la
//                                       place d'un faux *_missing_in_provider/payout_missing quand une
//                                       comparaison test/live serait dangereuse (voir
//                                       isEnvironmentComparisonSafe() ci-dessous)
//
// SCOPE D'EXÉCUTION : `runReconciliation(periodStart, periodEnd)` opère sur
// une fenêtre temporelle explicite (jamais "tout l'historique" par défaut,
// pour rester borné en coût/latence) — voir reconciliationJob.ts pour le
// point d'entrée Cloud Function (callable admin + cron quotidien).
// -----------------------------------------------------------------------------

import { admin, db } from "./admin";
import { getPaymentProvider } from "../payment/paymentProviderFactory";
import { computeMissionFinancialBalance } from "./missionFinancialBalance";
import { subtractMinor, toMinorUnits, DEFAULT_CURRENCY } from "./money";
import {
  logFinancialFailure,
  logFinancialSuccess,
  resolveCorrelationId,
  startFinancialOperationTimer,
} from "./observability";
import { assertStripeReferenceEnvironmentConsistency, StripeEnvironment } from "./stripeEnvironment";
import {
  DriverPayoutDoc,
  PaymentDoc,
  PayoutStatuses,
  ReconciliationAnomaly,
  ReconciliationReportDoc,
  ReconciliationStatuses,
  RefundDoc,
  RefundStatuses,
  WebhookProcessingStatuses,
} from "./types";

export const ReconciliationAnomalyTypes = {
  PAYMENT_MISSING_IN_MOVIK: "payment_missing_in_movik",
  PAYMENT_MISSING_IN_PROVIDER: "payment_missing_in_provider",
  PAYMENT_AMOUNT_MISMATCH: "payment_amount_mismatch",
  REFUND_MISSING_IN_LEDGER: "refund_missing_in_ledger",
  REFUND_MISSING_IN_PROVIDER: "refund_missing_in_provider",
  DUPLICATE_REFUND: "duplicate_refund",
  PAYOUT_MISSING: "payout_missing",
  PAYOUT_AMOUNT_MISMATCH: "payout_amount_mismatch",
  TIP_MISMATCH: "tip_mismatch",
  COMMISSION_LEDGER_INCONSISTENCY: "commission_ledger_inconsistency",
  WEBHOOK_UNPROCESSED: "webhook_unprocessed",
  /**
   * 🔒 Phase 8B (item 3, réconciliation environment-aware). Émise à la
   * place de PAYMENT_MISSING_IN_PROVIDER / REFUND_MISSING_IN_PROVIDER /
   * PAYOUT_MISSING dès qu'une référence Movi-K (`stripe_environment` stocké
   * sur le document) est incohérente avec l'environnement Stripe ACTUELLEMENT
   * ACTIF (`PaymentProvider.environment`) — voir isEnvironmentComparisonSafe()
   * ci-dessous. Une telle référence n'est JAMAIS comparée au provider actif
   * (elle appartient structurellement à l'AUTRE mode Stripe) : un
   * `reconcileTransaction()` dans ce cas produirait TOUJOURS `found: false`
   * (Stripe rejette nativement l'accès cross-mode), ce qui serait
   * FAUSSEMENT interprété comme une transaction manquante/perdue alors
   * qu'il s'agit d'une anomalie de CONFIGURATION/ENVIRONNEMENT (clé active
   * incohérente avec le moment de création de la référence) — jamais une
   * vraie divergence financière.
   */
  ENVIRONMENT_MISMATCH: "environment_mismatch",
} as const;
export type ReconciliationAnomalyType =
  (typeof ReconciliationAnomalyTypes)[keyof typeof ReconciliationAnomalyTypes];

/**
 * Détermine si une référence Movi-K taguée `storedEnvironment` peut être
 * comparée SANS DANGER à l'environnement Stripe actuellement actif — variante
 * NON-LEVANTE (jamais d'exception) de `assertStripeReferenceEnvironmentConsistency()`
 * (lib/stripeEnvironment.ts), réutilisant EXACTEMENT la même table de vérité
 * fail-closed (single source of truth : absence de tag tolérée uniquement en
 * environnement actif TEST, jamais en LIVE — voir la doc de la fonction
 * source pour la justification complète). La réconciliation ne doit JAMAIS
 * lever d'exception sur une donnée incohérente (principe non négociable
 * "ne jamais corriger silencieusement, mais aussi ne jamais planter" — une
 * anomalie de données doit produire une ANOMALIE RAPPORTÉE, jamais un crash
 * du job de réconciliation entier).
 */
function isEnvironmentComparisonSafe(params: {
  activeEnvironment: StripeEnvironment;
  storedEnvironment: StripeEnvironment | null | undefined;
}): boolean {
  try {
    assertStripeReferenceEnvironmentConsistency(params);
    return true;
  } catch {
    return false;
  }
}

export interface RunReconciliationParams {
  periodStartMillis: number;
  periodEndMillis: number;
  /**
   * Identifiant de corrélation optionnel, propagé depuis l'appelant
   * (runReconciliationNow/runDailyReconciliation). Purement traçabilité
   * (BLOC I observabilité) — jamais utilisé pour la logique métier.
   */
  correlationId?: string;
}

export interface RunReconciliationResult {
  reportId: string;
  report: ReconciliationReportDoc;
}

function newAnomaly(
  now: FirebaseFirestore.Timestamp,
  partial: Omit<ReconciliationAnomaly, "detected_at" | "status">
): ReconciliationAnomaly {
  return {
    ...partial,
    detected_at: now,
    status: "open",
  };
}

/**
 * Point d'entrée principal — exécute les 11 vérifications sur la fenêtre
 * temporelle donnée et écrit UN SEUL `reconciliation_reports/{id}`.
 *
 * 🔒 Aucune écriture autre que ce rapport. Si le PaymentProvider actif ne
 * supporte pas le listing (ex: `NotConfiguredPaymentProvider` en l'absence
 * de clé Stripe), les vérifications 1/2/3/4/5/8 basées sur le provider sont
 * marquées comme non exécutées (`provider_checks_skipped: true` dans le
 * rapport) plutôt que de lever une exception — les vérifications purement
 * internes (6, 7, 9, 10, 11) restent exécutées.
 */
export async function runReconciliation(
  params: RunReconciliationParams
): Promise<RunReconciliationResult> {
  const { periodStartMillis, periodEndMillis } = params;
  const correlationId = resolveCorrelationId(params.correlationId);
  const operationStartedAt = startFinancialOperationTimer();

  if (!Number.isFinite(periodStartMillis) || !Number.isFinite(periodEndMillis)) {
    const err = new Error("periodStartMillis/periodEndMillis doivent être des nombres valides.");
    logFinancialFailure(
      "reconciliation_run",
      operationStartedAt,
      "invalid_period",
      {},
      { correlationId, message: err.message }
    );
    throw err;
  }
  if (periodEndMillis <= periodStartMillis) {
    const err = new Error("periodEndMillis doit être strictement supérieur à periodStartMillis.");
    logFinancialFailure(
      "reconciliation_run",
      operationStartedAt,
      "invalid_period",
      {},
      { correlationId, message: err.message }
    );
    throw err;
  }

  const now = admin.firestore.Timestamp.now();
  const periodStart = admin.firestore.Timestamp.fromMillis(periodStartMillis);
  const periodEnd = admin.firestore.Timestamp.fromMillis(periodEndMillis);

  // 🔒 BLOC I (observabilité) — tout le corps de la réconciliation est
  // enveloppé pour garantir un log `reconciliation_run` de failure en cas
  // d'erreur inattendue (ex: PaymentProvider indisponible), en plus du
  // log final success/anomaly ci-dessous en cas de complétion normale.
  try {
  const anomalies: ReconciliationAnomaly[] = [];
  let totalPaymentsChecked = 0;
  let totalPayoutsChecked = 0;
  let totalRefundsChecked = 0;
  let providerChecksSkipped = false;

  // ---- Charge l'état Movi-K de la fenêtre (une seule fois, réutilisé par
  // plusieurs vérifications) ----
  const [paymentsQuery, refundsQuery, payoutsQuery, webhookEventsQuery] = await Promise.all([
    db
      .collection("payments")
      .where("created_at", ">=", periodStart)
      .where("created_at", "<=", periodEnd)
      .get(),
    db
      .collection("refunds")
      .where("created_at", ">=", periodStart)
      .where("created_at", "<=", periodEnd)
      .get(),
    db
      .collection("driver_payouts")
      .where("created_at", ">=", periodStart)
      .where("created_at", "<=", periodEnd)
      .get(),
    db
      .collection("provider_webhook_events")
      .where("received_at", ">=", periodStart)
      .where("received_at", "<=", periodEnd)
      .get(),
  ]);

  const payments = paymentsQuery.docs.map((d) => ({ id: d.id, data: d.data() as PaymentDoc }));
  const refunds = refundsQuery.docs.map((d) => ({ id: d.id, data: d.data() as RefundDoc }));
  const payouts = payoutsQuery.docs.map((d) => ({ id: d.id, data: d.data() as DriverPayoutDoc }));

  totalPaymentsChecked = payments.length;
  totalRefundsChecked = refunds.length;
  totalPayoutsChecked = payouts.length;

  // ---- Vérification 11 : webhook_unprocessed ----------------------------
  // Un évènement reçu depuis plus de 15 minutes et toujours RECEIVED (ou
  // FAILED) n'a jamais été mené à bien — signale une anomalie plutôt que de
  // le laisser silencieusement bloqué (voir processStripeWebhook.ts, qui
  // peut légitimement laisser un évènement `received` le temps d'un retry
  // Stripe normal — 15 min est une marge de sécurité raisonnable, pas une
  // règle fiscale/financière donc pas soumise à la contrainte "jamais
  // hardcodé" du Bloc E, qui concerne exclusivement les taux fiscaux).
  const STALE_WEBHOOK_THRESHOLD_MS = 15 * 60 * 1000;
  for (const doc of webhookEventsQuery.docs) {
    const evt = doc.data();
    const status = evt.processing_status as string;
    if (status === WebhookProcessingStatuses.PROCESSED || status === WebhookProcessingStatuses.IGNORED) {
      continue;
    }
    const receivedAtMillis = (evt.received_at as FirebaseFirestore.Timestamp)?.toMillis?.() ?? 0;
    if (now.toMillis() - receivedAtMillis >= STALE_WEBHOOK_THRESHOLD_MS) {
      anomalies.push(
        newAnomaly(now, {
          severity: "critical",
          type: ReconciliationAnomalyTypes.WEBHOOK_UNPROCESSED,
          mission_id: (evt.related_mission_id as string | null) ?? null,
          payment_id: (evt.related_payment_id as string | null) ?? null,
          payout_id: (evt.related_payout_id as string | null) ?? null,
          refund_id: (evt.related_refund_id as string | null) ?? null,
          expected_amount_minor: null,
          actual_amount_minor: null,
          description:
            `Webhook ${doc.id} (${evt.event_type}) reçu à ${new Date(receivedAtMillis).toISOString()} ` +
            `mais jamais passé à 'processed' (statut actuel: ${status}).`,
          resolution_notes: null,
        })
      );
    }
  }

  // ---- Vérification 6 : duplicate_refund ---------------------------------
  // Somme des refunds SUCCEEDED d'un même paiement > montant capturé =
  // remboursement en trop (double refund ou incohérence de validation).
  const refundsByPaymentId = new Map<string, { id: string; data: RefundDoc }[]>();
  for (const r of refunds) {
    const list = refundsByPaymentId.get(r.data.payment_id) ?? [];
    list.push(r);
    refundsByPaymentId.set(r.data.payment_id, list);
  }
  for (const payment of payments) {
    const relatedRefunds = refundsByPaymentId.get(payment.id) ?? [];
    const succeededTotal = relatedRefunds
      .filter((r) => r.data.status === RefundStatuses.SUCCEEDED)
      .reduce((sum, r) => sum + (r.data.amount_minor ?? 0), 0);
    if (succeededTotal > payment.data.amount_captured_minor) {
      anomalies.push(
        newAnomaly(now, {
          severity: "critical",
          type: ReconciliationAnomalyTypes.DUPLICATE_REFUND,
          mission_id: payment.data.mission_id,
          payment_id: payment.id,
          payout_id: null,
          refund_id: relatedRefunds.map((r) => r.id).join(","),
          expected_amount_minor: payment.data.amount_captured_minor,
          actual_amount_minor: succeededTotal,
          description:
            `Somme des remboursements SUCCEEDED (${succeededTotal}) supérieure au montant ` +
            `capturé (${payment.data.amount_captured_minor}) pour payments/${payment.id}.`,
          resolution_notes: null,
        })
      );
    }
    // 🔒 Cohérence interne payments.amount_refunded_minor vs somme réelle
    // des refunds SUCCEEDED — un écart signale un bug d'agrégation Movi-K
    // (jamais un problème provider), distinct de la vérification 5 ci-après.
    if (payment.data.amount_refunded_minor !== succeededTotal) {
      anomalies.push(
        newAnomaly(now, {
          severity: "warning",
          type: ReconciliationAnomalyTypes.COMMISSION_LEDGER_INCONSISTENCY,
          mission_id: payment.data.mission_id,
          payment_id: payment.id,
          payout_id: null,
          refund_id: null,
          expected_amount_minor: succeededTotal,
          actual_amount_minor: payment.data.amount_refunded_minor,
          description:
            `payments/${payment.id}.amount_refunded_minor (${payment.data.amount_refunded_minor}) ` +
            `ne correspond pas à la somme des refunds SUCCEEDED liés (${succeededTotal}).`,
          resolution_notes: null,
        })
      );
    }
  }

  // ---- Vérification 5 : refund_missing_in_provider -----------------------
  // Un RefundDoc marqué SUCCEEDED côté Movi-K DOIT exister chez le provider.
  const provider = getPaymentProvider();
  const activeEnvironment = provider.environment;
  let providerSupportsListing = true;
  try {
    for (const r of refunds) {
      if (r.data.status !== RefundStatuses.SUCCEEDED || !r.data.provider_refund_id) continue;
      // 🔒 Phase 8B item 3 — jamais comparer une référence TEST à un
      // provider LIVE (ou l'inverse) : produit une anomalie SPÉCIFIQUE
      // d'environnement, jamais un faux refund_missing_in_provider.
      if (
        !isEnvironmentComparisonSafe({
          activeEnvironment,
          storedEnvironment: r.data.stripe_environment,
        })
      ) {
        anomalies.push(
          newAnomaly(now, {
            severity: "critical",
            type: ReconciliationAnomalyTypes.ENVIRONMENT_MISMATCH,
            mission_id: r.data.mission_id,
            payment_id: r.data.payment_id,
            payout_id: null,
            refund_id: r.id,
            expected_amount_minor: null,
            actual_amount_minor: null,
            description:
              `refunds/${r.id} : stripe_environment stocké ("${r.data.stripe_environment ?? "absent"}") ` +
              `incompatible avec l'environnement Stripe actif ("${activeEnvironment}") — comparaison ` +
              `avec le provider IGNORÉE (jamais de faux refund_missing_in_provider sur un mélange ` +
              `test/live).`,
            resolution_notes: null,
          })
        );
        continue;
      }
      const result = await provider.reconcileTransaction({
        providerRefundId: r.data.provider_refund_id,
      });
      if (!result.found) {
        anomalies.push(
          newAnomaly(now, {
            severity: "critical",
            type: ReconciliationAnomalyTypes.REFUND_MISSING_IN_PROVIDER,
            mission_id: r.data.mission_id,
            payment_id: r.data.payment_id,
            payout_id: null,
            refund_id: r.id,
            expected_amount_minor: r.data.amount_minor,
            actual_amount_minor: null,
            description:
              `refunds/${r.id} (provider_refund_id=${r.data.provider_refund_id}) marqué ` +
              `SUCCEEDED côté Movi-K mais introuvable chez le fournisseur.`,
            resolution_notes: null,
          })
        );
      } else if (result.providerAmountMinor !== null && result.providerAmountMinor !== r.data.amount_minor) {
        anomalies.push(
          newAnomaly(now, {
            severity: "critical",
            type: ReconciliationAnomalyTypes.PAYMENT_AMOUNT_MISMATCH,
            mission_id: r.data.mission_id,
            payment_id: r.data.payment_id,
            payout_id: null,
            refund_id: r.id,
            expected_amount_minor: r.data.amount_minor,
            actual_amount_minor: result.providerAmountMinor,
            description:
              `refunds/${r.id} : montant Movi-K (${r.data.amount_minor}) différent du montant ` +
              `provider (${result.providerAmountMinor}).`,
            resolution_notes: null,
          })
        );
      }
    }
  } catch (err) {
    providerSupportsListing = false;
    void err; // fournisseur non configuré (ex: tests sans Stripe réel) — voir provider_checks_skipped
  }

  // ---- Vérification 2/3 : payment_missing_in_provider / amount_mismatch --
  try {
    for (const payment of payments) {
      if (!payment.data.provider_payment_intent_id) continue;
      // Statuts jamais autorisés/capturés côté provider : rien à vérifier.
      if (payment.data.amount_captured_minor <= 0) continue;
      // 🔒 Phase 8B item 3 — voir vérification 5 ci-dessus pour la
      // justification complète : jamais de faux payment_missing_in_provider
      // sur une référence appartenant structurellement à l'autre mode Stripe.
      if (
        !isEnvironmentComparisonSafe({
          activeEnvironment,
          storedEnvironment: payment.data.stripe_environment,
        })
      ) {
        anomalies.push(
          newAnomaly(now, {
            severity: "critical",
            type: ReconciliationAnomalyTypes.ENVIRONMENT_MISMATCH,
            mission_id: payment.data.mission_id,
            payment_id: payment.id,
            payout_id: null,
            refund_id: null,
            expected_amount_minor: null,
            actual_amount_minor: null,
            description:
              `payments/${payment.id} : stripe_environment stocké ` +
              `("${payment.data.stripe_environment ?? "absent"}") incompatible avec l'environnement ` +
              `Stripe actif ("${activeEnvironment}") — comparaison avec le provider IGNORÉE (jamais ` +
              `de faux payment_missing_in_provider sur un mélange test/live).`,
            resolution_notes: null,
          })
        );
        continue;
      }
      const result = await provider.reconcileTransaction({
        providerPaymentIntentId: payment.data.provider_payment_intent_id,
      });
      if (!result.found) {
        anomalies.push(
          newAnomaly(now, {
            severity: "critical",
            type: ReconciliationAnomalyTypes.PAYMENT_MISSING_IN_PROVIDER,
            mission_id: payment.data.mission_id,
            payment_id: payment.id,
            payout_id: null,
            refund_id: null,
            expected_amount_minor: payment.data.amount_captured_minor,
            actual_amount_minor: null,
            description:
              `payments/${payment.id} (provider_payment_intent_id=` +
              `${payment.data.provider_payment_intent_id}) capturé côté Movi-K mais introuvable ` +
              `chez le fournisseur.`,
            resolution_notes: null,
          })
        );
      } else if (
        result.providerAmountMinor !== null &&
        result.providerAmountMinor !== payment.data.amount_captured_minor
      ) {
        anomalies.push(
          newAnomaly(now, {
            severity: "critical",
            type: ReconciliationAnomalyTypes.PAYMENT_AMOUNT_MISMATCH,
            mission_id: payment.data.mission_id,
            payment_id: payment.id,
            payout_id: null,
            refund_id: null,
            expected_amount_minor: payment.data.amount_captured_minor,
            actual_amount_minor: result.providerAmountMinor,
            description:
              `payments/${payment.id} : montant capturé Movi-K (${payment.data.amount_captured_minor}) ` +
              `différent du montant provider (${result.providerAmountMinor}).`,
            resolution_notes: null,
          })
        );
      }
    }
  } catch {
    providerSupportsListing = false;
  }

  // ---- Vérification 8 : payout_amount_mismatch ---------------------------
  try {
    for (const payout of payouts) {
      if (payout.data.status !== PayoutStatuses.PAID || !payout.data.provider_payout_id) continue;
      // 🔒 Phase 8B item 3 — voir vérification 5 pour la justification
      // complète : jamais de faux payout_missing sur un mélange test/live.
      if (
        !isEnvironmentComparisonSafe({
          activeEnvironment,
          storedEnvironment: payout.data.stripe_environment,
        })
      ) {
        anomalies.push(
          newAnomaly(now, {
            severity: "critical",
            type: ReconciliationAnomalyTypes.ENVIRONMENT_MISMATCH,
            mission_id: null,
            payment_id: null,
            payout_id: payout.id,
            refund_id: null,
            expected_amount_minor: null,
            actual_amount_minor: null,
            description:
              `driver_payouts/${payout.id} : stripe_environment stocké ` +
              `("${payout.data.stripe_environment ?? "absent"}") incompatible avec l'environnement ` +
              `Stripe actif ("${activeEnvironment}") — comparaison avec le provider IGNORÉE (jamais ` +
              `de faux payout_missing sur un mélange test/live).`,
            resolution_notes: null,
          })
        );
        continue;
      }
      const result = await provider.reconcileTransaction({
        providerPayoutId: payout.data.provider_payout_id,
      });
      if (!result.found) {
        anomalies.push(
          newAnomaly(now, {
            severity: "critical",
            type: ReconciliationAnomalyTypes.PAYOUT_MISSING,
            mission_id: null,
            payment_id: null,
            payout_id: payout.id,
            refund_id: null,
            expected_amount_minor: payout.data.amount_minor,
            actual_amount_minor: null,
            description:
              `driver_payouts/${payout.id} (provider_payout_id=${payout.data.provider_payout_id}) ` +
              `marqué PAID côté Movi-K mais introuvable chez le fournisseur.`,
            resolution_notes: null,
          })
        );
      } else if (
        result.providerAmountMinor !== null &&
        result.providerAmountMinor !== payout.data.amount_minor
      ) {
        anomalies.push(
          newAnomaly(now, {
            severity: "critical",
            type: ReconciliationAnomalyTypes.PAYOUT_AMOUNT_MISMATCH,
            mission_id: null,
            payment_id: null,
            payout_id: payout.id,
            refund_id: null,
            expected_amount_minor: payout.data.amount_minor,
            actual_amount_minor: result.providerAmountMinor,
            description:
              `driver_payouts/${payout.id} : montant Movi-K (${payout.data.amount_minor}) différent ` +
              `du montant provider (${result.providerAmountMinor}).`,
            resolution_notes: null,
          })
        );
      }
    }
  } catch {
    providerSupportsListing = false;
  }

  // ---- Vérification 1 & 4 : listing provider -> absent de Movi-K --------
  // Nécessite `listProviderPayments`/`listProviderRefunds` — capacité de
  // listing (voir paymentProvider.ts, extension Bloc G). Si le provider ne
  // le supporte pas (ex: NotConfiguredPaymentProvider), ces vérifications
  // sont marquées SKIPPED plutôt que de faire échouer tout le rapport.
  try {
    const knownPaymentIntentIds = new Set(
      payments.map((p) => p.data.provider_payment_intent_id).filter((v): v is string => !!v)
    );
    const providerPaymentsPage = await provider.listProviderPayments({
      sinceMillis: periodStartMillis,
      untilMillis: periodEndMillis,
    });
    for (const pp of providerPaymentsPage.payments) {
      if (pp.amountMinor <= 0) continue; // intent créé mais jamais capturé côté provider
      if (!knownPaymentIntentIds.has(pp.providerPaymentIntentId)) {
        anomalies.push(
          newAnomaly(now, {
            severity: "critical",
            type: ReconciliationAnomalyTypes.PAYMENT_MISSING_IN_MOVIK,
            mission_id: null,
            payment_id: null,
            payout_id: null,
            refund_id: null,
            expected_amount_minor: pp.amountMinor,
            actual_amount_minor: null,
            description:
              `Paiement provider ${pp.providerPaymentIntentId} (${pp.amountMinor} cents, statut ` +
              `${pp.status}) introuvable dans payments/ Movi-K.`,
            resolution_notes: null,
          })
        );
      }
    }

    const knownRefundIds = new Set(
      refunds.map((r) => r.data.provider_refund_id).filter((v): v is string => !!v)
    );
    const providerRefundsPage = await provider.listProviderRefunds({
      sinceMillis: periodStartMillis,
      untilMillis: periodEndMillis,
    });
    for (const pr of providerRefundsPage.refunds) {
      if (!knownRefundIds.has(pr.providerRefundId)) {
        anomalies.push(
          newAnomaly(now, {
            severity: "critical",
            type: ReconciliationAnomalyTypes.REFUND_MISSING_IN_LEDGER,
            mission_id: null,
            payment_id: null,
            payout_id: null,
            refund_id: null,
            expected_amount_minor: pr.amountMinor,
            actual_amount_minor: null,
            description:
              `Remboursement provider ${pr.providerRefundId} (${pr.amountMinor} cents, statut ` +
              `${pr.status}) introuvable dans refunds/ Movi-K.`,
            resolution_notes: null,
          })
        );
      }
    }
  } catch {
    providerSupportsListing = false;
  }

  providerChecksSkipped = !providerSupportsListing;

  // ---- Vérification 9 & 10 : tip_mismatch / commission_ledger_inconsistency
  // Recalcule mission_financial_balance À LA VOLÉE (jamais depuis le cache
  // stocké) pour chaque mission touchée par un paiement de la fenêtre, et
  // compare au cache actuellement PERSISTÉ — un écart signale soit un
  // recalcul manquant (bug d'appel), soit une incohérence ledger réelle.
  const missionIdsInWindow = new Set(payments.map((p) => p.data.mission_id).filter(Boolean));
  for (const missionId of missionIdsInWindow) {
    const [freshBalance, storedSnap] = await Promise.all([
      computeMissionFinancialBalance(missionId),
      db.collection("mission_financial_balance").doc(missionId).get(),
    ]);
    const stored = storedSnap.exists ? storedSnap.data() : null;

    if (stored && stored.driver_tip_minor !== freshBalance.driver_tip_minor) {
      anomalies.push(
        newAnomaly(now, {
          severity: "warning",
          type: ReconciliationAnomalyTypes.TIP_MISMATCH,
          mission_id: missionId,
          payment_id: null,
          payout_id: null,
          refund_id: null,
          expected_amount_minor: freshBalance.driver_tip_minor,
          actual_amount_minor: stored.driver_tip_minor as number,
          description:
            `mission_financial_balance/${missionId}.driver_tip_minor (${stored.driver_tip_minor}) ` +
            `ne correspond pas au recalcul à partir du ledger (${freshBalance.driver_tip_minor}) — ` +
            `un recalcul (recalculateMissionFinancialBalance) a probablement été omis après un ` +
            `mouvement récent du transaction_ledger.`,
          resolution_notes: null,
        })
      );
    }

    if (
      stored &&
      stored.platform_commission_minor !== freshBalance.platform_commission_minor
    ) {
      anomalies.push(
        newAnomaly(now, {
          severity: "warning",
          type: ReconciliationAnomalyTypes.COMMISSION_LEDGER_INCONSISTENCY,
          mission_id: missionId,
          payment_id: null,
          payout_id: null,
          refund_id: null,
          expected_amount_minor: freshBalance.platform_commission_minor,
          actual_amount_minor: stored.platform_commission_minor as number,
          description:
            `mission_financial_balance/${missionId}.platform_commission_minor ` +
            `(${stored.platform_commission_minor}) ne correspond pas au recalcul depuis les ` +
            `financial_snapshots (${freshBalance.platform_commission_minor}).`,
          resolution_notes: null,
        })
      );
    }
  }

  // ---- Vérification 7 : payout_missing (snapshots confirmed jamais payés)
  // Un financial_snapshot CONFIRMED, non inclus dans un payout, dont la
  // mission a été complétée depuis plus de PAYOUT_STALE_THRESHOLD_MS,
  // signale un versement chauffeur jamais déclenché (bug de scheduling ou
  // d'agrégation) — jamais silencieusement corrigé ici.
  const PAYOUT_STALE_THRESHOLD_MS = 30 * 24 * 3600 * 1000; // 30 jours, seuil opérationnel (pas fiscal)
  const staleSnapshotsQuery = await db
    .collection("financial_snapshots")
    .where("status", "==", "confirmed")
    .where("created_at", ">=", periodStart)
    .where("created_at", "<=", periodEnd)
    .get();
  for (const snapDoc of staleSnapshotsQuery.docs) {
    const snap = snapDoc.data();
    if (snap.included_in_payout_id) continue;
    const createdAtMillis = (snap.created_at as FirebaseFirestore.Timestamp)?.toMillis?.() ?? 0;
    if (now.toMillis() - createdAtMillis >= PAYOUT_STALE_THRESHOLD_MS) {
      anomalies.push(
        newAnomaly(now, {
          severity: "warning",
          type: ReconciliationAnomalyTypes.PAYOUT_MISSING,
          mission_id: (snap.mission_id as string) ?? null,
          payment_id: null,
          payout_id: null,
          refund_id: null,
          expected_amount_minor: toMinorUnits(
            (snap.driver_net_mission_earnings as number) ?? 0,
            DEFAULT_CURRENCY
          ),
          actual_amount_minor: 0,
          description:
            `financial_snapshots/${snapDoc.id} confirmé depuis plus de 30 jours mais jamais ` +
            `inclus dans un driver_payouts — versement chauffeur potentiellement manquant.`,
          resolution_notes: null,
        })
      );
    }
  }

  const status = anomalies.length === 0 ? ReconciliationStatuses.OK : ReconciliationStatuses.ANOMALY;
  const reconciliationDifferenceMinor = anomalies.reduce((sum, a) => {
    if (a.expected_amount_minor === null || a.expected_amount_minor === undefined) return sum;
    if (a.actual_amount_minor === null || a.actual_amount_minor === undefined) return sum;
    return sum + Math.abs(subtractMinor(a.expected_amount_minor, a.actual_amount_minor));
  }, 0);

  const reportRef = db.collection("reconciliation_reports").doc();
  const report: ReconciliationReportDoc = {
    report_id: reportRef.id,
    period_start: periodStart,
    period_end: periodEnd,
    status,
    anomalies,
    total_payments_checked: totalPaymentsChecked,
    total_payouts_checked: totalPayoutsChecked,
    total_refunds_checked: totalRefundsChecked,
    reconciliation_difference_minor: reconciliationDifferenceMinor,
    created_at: now,
    last_reconciled_at: now,
  };

  await reportRef.set({
    ...report,
    // 🔒 Champ additionnel de traçabilité (hors du schéma minimal demandé,
    // strictement informatif — n'affecte aucune comparaison/anomalie).
    provider_checks_skipped: providerChecksSkipped,
  });

  // 🔒 BLOC I (observabilité) — log de synthèse structuré, jamais un log
  // par anomalie (resterait lisible même avec des dizaines d'anomalies).
  // result=success si 0 anomalie, sinon failure avec error_code dédié —
  // le détail complet des anomalies reste dans reconciliation_reports/{id}
  // (jamais dupliqué intégralement dans les logs).
  if (anomalies.length === 0) {
    logFinancialSuccess(
      "reconciliation_run",
      operationStartedAt,
      {},
      {
        correlationId,
        metadata: {
          reportId: reportRef.id,
          periodStartMillis,
          periodEndMillis,
          totalPaymentsChecked,
          totalPayoutsChecked,
          totalRefundsChecked,
        },
      }
    );
  } else {
    logFinancialFailure(
      "reconciliation_anomaly_detected",
      operationStartedAt,
      "anomalies_detected",
      {},
      {
        correlationId,
        metadata: {
          reportId: reportRef.id,
          periodStartMillis,
          periodEndMillis,
          anomalyCount: anomalies.length,
          anomalyTypes: [...new Set(anomalies.map((a) => a.type))],
        },
      }
    );
  }

  return { reportId: reportRef.id, report };
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    logFinancialFailure(
      "reconciliation_run",
      operationStartedAt,
      "reconciliation_failed",
      {},
      { correlationId, message, metadata: { periodStartMillis, periodEndMillis } }
    );
    throw err;
  }
}

/**
 * Marque une anomalie comme reconnue/résolue (jamais une correction
 * automatique de l'anomalie financière sous-jacente — uniquement le statut
 * administratif de suivi de l'anomalie ELLE-MÊME dans le rapport). Toute
 * correction financière réelle doit passer par les primitives dédiées
 * (createLedgerEntry, refundPayment, etc.), jamais par cette fonction.
 */
export async function resolveReconciliationAnomaly(params: {
  reportId: string;
  anomalyIndex: number;
  newStatus: "acknowledged" | "resolved";
  resolutionNotes: string;
  resolvedByUserId: string;
}): Promise<void> {
  const { reportId, anomalyIndex, newStatus, resolutionNotes } = params;
  const reportRef = db.collection("reconciliation_reports").doc(reportId);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(reportRef);
    if (!snap.exists) {
      throw new Error(`reconciliation_reports/${reportId} introuvable.`);
    }
    const data = snap.data() as ReconciliationReportDoc;
    if (!data.anomalies[anomalyIndex]) {
      throw new Error(`Anomalie d'index ${anomalyIndex} introuvable dans le rapport ${reportId}.`);
    }
    const updatedAnomalies = [...data.anomalies];
    updatedAnomalies[anomalyIndex] = {
      ...updatedAnomalies[anomalyIndex],
      status: newStatus,
      resolution_notes: resolutionNotes,
    };
    tx.update(reportRef, { anomalies: updatedAnomalies });
  });
}
