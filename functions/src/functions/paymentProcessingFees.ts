// -----------------------------------------------------------------------------
// paymentProcessingFees — frais Stripe réels dans le bilan (2026-10-29).
//
// Recette du 29 oct. : le bilan de mission (mission_financial_balance)
// affichait une marge de 14,10 $ sur un paiement de 94 $ alors que Stripe
// avait prélevé 3,78 $ de frais : `provider_processing_cost_minor` restait à 0
// parce qu'aucune entrée `payment_processing_fee` n'était jamais écrite.
//
// Ici, après l'encaissement, on LIT les frais sur la balance transaction de
// la charge (lecture seule : rien n'est créé, capturé ni remboursé) et on les
// inscrit une fois :
//   - transaction_ledger/processing_fee_{paymentId} (type payment_processing_fee,
//     partie plateforme) — la source historique ;
//   - payments/{id}.processing_fee_minor — repère « déjà lu » ;
// puis le bilan de la mission est recalculé.
//
// Deux chemins, tous deux sans effet sur l'argent :
//   - déclencheur sur l'écriture d'un paiement qui vient d'être encaissé ;
//   - balayage horaire des paiements des 30 derniers jours sans frais lus
//     (Stripe indisponible au moment de l'encaissement, paiements anciens).
// Une erreur Stripe n'est jamais propagée au paiement : les frais restent
// simplement « à lire » pour le prochain balayage.
// -----------------------------------------------------------------------------

import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { admin, db } from "../lib/admin";
import { DEFAULT_CURRENCY } from "../lib/money";
import { recalculateMissionFinancialBalance } from "../lib/missionFinancialBalance";
import { STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET } from "../lib/secrets";
import {
  LedgerDirections,
  LedgerEntryStatuses,
  LedgerEntryTypes,
  LedgerParties,
  PaymentDoc,
} from "../lib/types";
import { ChargeProcessingFee, PaymentProvider } from "../payment/paymentProvider";
import { getPaymentProvider } from "../payment/paymentProviderFactory";

export const PROCESSING_FEE_LOOKBACK_DAYS = 30;
export const PROCESSING_FEE_BATCH = 25;

export type ProcessingFeeOutcome = "recorded" | "already_recorded" | "not_applicable" | "unavailable";

export function processingFeeLedgerId(paymentId: string): string {
  return `processing_fee_${paymentId}`;
}

/** Un paiement dont les frais restent à lire : encaissé, charge connue, frais absents. */
export function needsProcessingFee(payment: Partial<PaymentDoc> | undefined): boolean {
  return !!payment &&
    typeof payment.provider_charge_id === "string" && payment.provider_charge_id.length > 0 &&
    typeof payment.amount_captured_minor === "number" && payment.amount_captured_minor > 0 &&
    typeof payment.processing_fee_minor !== "number";
}

export async function recordPaymentProcessingFee(
  paymentId: string,
  provider: PaymentProvider = getPaymentProvider()
): Promise<ProcessingFeeOutcome> {
  const paymentRef = db.collection("payments").doc(paymentId);
  const payment = (await paymentRef.get()).data() as PaymentDoc | undefined;
  if (!payment) return "not_applicable";
  if (typeof payment.processing_fee_minor === "number") return "already_recorded";
  if (!needsProcessingFee(payment)) return "not_applicable";
  // Une charge de test ne se lit pas avec la clé live (et inversement).
  if (payment.stripe_environment && payment.stripe_environment !== provider.environment) return "not_applicable";

  let fee: ChargeProcessingFee | null;
  try {
    fee = await provider.getChargeProcessingFee(payment.provider_charge_id as string);
  } catch (error) {
    console.warn("[processing-fee] lecture impossible", paymentId, error instanceof Error ? error.message : String(error));
    return "unavailable";
  }
  const currency = (payment.currency ?? DEFAULT_CURRENCY).toUpperCase();
  if (!fee || !Number.isInteger(fee.feeMinor) || fee.feeMinor < 0) return "unavailable";
  if (fee.currency.toUpperCase() !== currency) {
    console.warn("[processing-fee] devise différente, frais non inscrits", paymentId, fee.currency, currency);
    return "unavailable";
  }
  const feeMinor = fee.feeMinor;

  const ledgerRef = db.collection("transaction_ledger").doc(processingFeeLedgerId(paymentId));
  const written = await db.runTransaction(async (tx) => {
    const [current, existing] = await Promise.all([tx.get(paymentRef), tx.get(ledgerRef)]);
    const p = current.data() as PaymentDoc | undefined;
    if (!p || typeof p.processing_fee_minor === "number") return false;
    const now = admin.firestore.Timestamp.now();
    if (!existing.exists) {
      tx.set(ledgerRef, {
        ledger_entry_id: ledgerRef.id,
        mission_id: p.mission_id,
        transaction_id: paymentId,
        type: LedgerEntryTypes.PAYMENT_PROCESSING_FEE,
        amount: feeMinor / 100, // 🔒 legacy ledger en dollars, voir money.ts
        amount_minor: feeMinor,
        currency,
        direction: LedgerDirections.DEBIT,
        party: LedgerParties.PLATFORM,
        created_at: now,
        created_by: "recordPaymentProcessingFee",
        source_event: "provider_balance_transaction",
        status: LedgerEntryStatuses.CONFIRMED,
        reference_id: null,
      });
    }
    tx.update(paymentRef, { processing_fee_minor: feeMinor, processing_fee_recorded_at: now });
    return true;
  });
  if (!written) return "already_recorded";
  if (payment.mission_id) await recalculateMissionFinancialBalance(payment.mission_id);
  return "recorded";
}

/** Paiements récents dont les frais restent à lire (au plus `limit`). */
export async function recordMissingProcessingFees(
  provider: PaymentProvider = getPaymentProvider(),
  limit = PROCESSING_FEE_BATCH
): Promise<Record<ProcessingFeeOutcome, number>> {
  const since = admin.firestore.Timestamp.fromMillis(Date.now() - PROCESSING_FEE_LOOKBACK_DAYS * 86_400_000);
  const recent = await db.collection("payments").where("captured_at", ">=", since).orderBy("captured_at", "desc").limit(500).get();
  const counts: Record<ProcessingFeeOutcome, number> = { recorded: 0, already_recorded: 0, not_applicable: 0, unavailable: 0 };
  for (const doc of recent.docs.filter((d) => needsProcessingFee(d.data() as PaymentDoc)).slice(0, limit)) {
    try {
      counts[await recordPaymentProcessingFee(doc.id, provider)] += 1;
    } catch (error) {
      counts.unavailable += 1;
      console.error("[processing-fee] échec", doc.id, error instanceof Error ? error.message : String(error));
    }
  }
  return counts;
}

const options = { secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET] };

export const onPaymentCapturedRecordProcessingFee = onDocumentWritten(
  { document: "payments/{paymentId}", ...options },
  async (event) => {
    const before = event.data?.before.data() as PaymentDoc | undefined;
    const after = event.data?.after.data() as PaymentDoc | undefined;
    if (!needsProcessingFee(after)) return;
    // Seulement à l'encaissement (ou quand la charge apparaît) : les autres
    // écritures d'un paiement ne relancent pas d'appel Stripe — le balayage
    // horaire rattrape un échec.
    const justCaptured = !before ||
      before.amount_captured_minor !== after!.amount_captured_minor ||
      before.provider_charge_id !== after!.provider_charge_id;
    if (!justCaptured) return;
    try {
      await recordPaymentProcessingFee(event.params.paymentId);
    } catch (error) {
      console.error("[processing-fee] échec", event.params.paymentId, error instanceof Error ? error.message : String(error));
    }
  }
);

export const recordMissingPaymentProcessingFees = onSchedule(
  { schedule: "every 60 minutes", timeZone: "America/Toronto", ...options },
  async () => {
    const counts = await recordMissingProcessingFees();
    if (counts.recorded + counts.unavailable > 0) console.log("[processing-fee]", counts);
  }
);
