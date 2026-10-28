// -----------------------------------------------------------------------------
// payoutMode.ts — mode de versement des chauffeurs (option A, 2026-10-27).
//
// Les paiements Movi-K sont des « destination charges » Stripe Connect
// (stripeProvider.ts : transfer_data.destination + application_fee_amount).
// À la capture, Stripe vire donc DÉJÀ la part du chauffeur sur son compte
// connecté ; le compte Express la dépose ensuite sur son compte bancaire.
// Créer en plus un driver_payouts pour la même mission paierait le
// chauffeur deux fois. Ce module rend la décision explicite et lisible par
// tous les chemins concernés (calculateDriverPayout,
// processScheduledDriverPayouts, réconciliation, solde de mission).
// -----------------------------------------------------------------------------

import { db } from "./admin";
import { PaymentDoc, PaymentStatuses, PayoutMode, PayoutModes } from "./types";

export const PAYOUT_POLICY_CONFIG_DOC = "payout_policy_configs/default";

export function parsePayoutMode(value: unknown): PayoutMode {
  return value === PayoutModes.MOVIK_BATCH ? PayoutModes.MOVIK_BATCH : PayoutModes.STRIPE_DIRECT;
}

/** Toujours lu depuis Firestore (jamais mis en cache) ; absent = stripe_direct. */
export async function readPayoutMode(): Promise<PayoutMode> {
  const snap = await db.doc(PAYOUT_POLICY_CONFIG_DOC).get();
  return parsePayoutMode(snap.data()?.payout_mode);
}

const TRANSFERRING_STATUSES = new Set<string>([
  PaymentStatuses.CAPTURED,
  PaymentStatuses.PARTIALLY_REFUNDED,
  PaymentStatuses.REFUNDED,
  PaymentStatuses.DISPUTED,
  PaymentStatuses.CHARGEBACK,
]);

export interface ConnectTransferShare {
  /** Viré au compte connecté à la capture. */
  amountMinor: number;
  /** Renversé par les remboursements (reverse_transfer), au prorata. */
  reversedMinor: number;
  netMinor: number;
}

/**
 * Part du chauffeur virée par Stripe à la capture d'un paiement Connect, ou
 * null si ce paiement n'est pas (encore) une destination charge capturée.
 * Les remboursements sont créés avec reverse_transfer + refund_application_fee
 * (paymentOrchestration.ts) : Stripe renverse le virement au prorata du
 * montant remboursé — estimation ici, Stripe fait foi.
 */
export function connectTransferShare(payment: Partial<PaymentDoc>): ConnectTransferShare | null {
  if (!payment.connected_account_id || !payment.status || !TRANSFERRING_STATUSES.has(payment.status)) return null;
  const captured = payment.amount_captured_minor ?? 0;
  const fee = payment.application_fee_minor ?? 0;
  if (!Number.isInteger(captured) || captured <= 0 || !Number.isInteger(fee) || fee < 0 || fee > captured) return null;
  const amountMinor = captured - fee;
  const refunded = Math.min(Math.max(payment.amount_refunded_minor ?? 0, 0), captured);
  const reversedMinor = Math.min(amountMinor, Math.round((refunded * amountMinor) / captured));
  return { amountMinor, reversedMinor, netMinor: amountMinor - reversedMinor };
}
