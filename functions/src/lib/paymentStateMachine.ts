// -----------------------------------------------------------------------------
// paymentStateMachine.ts — Machine d'état SERVEUR pour PaymentDoc.status
// (point 6 du cahier des charges Phase 6).
//
// 🔒 Flutter ne peut JAMAIS forcer une transition. Cette fonction est la
// SEULE autorité qui valide qu'une transition de statut de paiement est
// légale. Toute Cloud Function qui modifie `payments/{id}.status` DOIT
// passer par `assertValidPaymentTransition()` avant d'écrire.
// -----------------------------------------------------------------------------

import { PaymentStatus, PaymentStatuses } from "./types";
import { failedPrecondition } from "./errors";

const ALLOWED_TRANSITIONS: Record<PaymentStatus, PaymentStatus[]> = {
  [PaymentStatuses.CREATED]: [
    PaymentStatuses.REQUIRES_PAYMENT_METHOD,
    PaymentStatuses.AUTHORIZATION_PENDING,
    PaymentStatuses.FAILED,
  ],
  [PaymentStatuses.REQUIRES_PAYMENT_METHOD]: [
    PaymentStatuses.AUTHORIZATION_PENDING,
    PaymentStatuses.FAILED,
    PaymentStatuses.CANCELLED,
  ],
  [PaymentStatuses.AUTHORIZATION_PENDING]: [
    PaymentStatuses.AUTHORIZED,
    PaymentStatuses.FAILED,
    PaymentStatuses.CANCELLED,
  ],
  [PaymentStatuses.AUTHORIZED]: [
    PaymentStatuses.CAPTURE_PENDING,
    PaymentStatuses.CANCELLED, // annulation d'autorisation (cancelAuthorization)
    PaymentStatuses.FAILED, // autorisation expirée
  ],
  [PaymentStatuses.CAPTURE_PENDING]: [
    PaymentStatuses.CAPTURED,
    PaymentStatuses.FAILED, // capture échouée
  ],
  [PaymentStatuses.CAPTURED]: [
    PaymentStatuses.PARTIALLY_REFUNDED,
    PaymentStatuses.REFUNDED,
    PaymentStatuses.DISPUTED,
  ],
  [PaymentStatuses.PARTIALLY_REFUNDED]: [
    PaymentStatuses.REFUNDED,
    PaymentStatuses.DISPUTED,
    PaymentStatuses.PARTIALLY_REFUNDED, // remboursement partiel supplémentaire
  ],
  [PaymentStatuses.DISPUTED]: [PaymentStatuses.CHARGEBACK, PaymentStatuses.CAPTURED /* dispute gagnée : retour à l'état capturé */],
  [PaymentStatuses.CHARGEBACK]: [PaymentStatuses.REFUNDED /* late-win / résolution documentée, via entrée compensatoire */],
  // États terminaux : aucune transition sortante.
  [PaymentStatuses.FAILED]: [],
  [PaymentStatuses.CANCELLED]: [],
  [PaymentStatuses.REFUNDED]: [],
};

export function isValidPaymentTransition(from: PaymentStatus, to: PaymentStatus): boolean {
  if (from === to) return false; // pas de no-op silencieux — chaque écriture doit être un changement réel
  return (ALLOWED_TRANSITIONS[from] ?? []).includes(to);
}

export function assertValidPaymentTransition(from: PaymentStatus, to: PaymentStatus): void {
  if (!isValidPaymentTransition(from, to)) {
    throw failedPrecondition(
      `Transition de paiement invalide : '${from}' -> '${to}'. Transitions autorisées depuis '${from}': [${(ALLOWED_TRANSITIONS[from] ?? []).join(", ")}].`
    );
  }
}

// -----------------------------------------------------------------------------
// Payout state machine (point 9).
// -----------------------------------------------------------------------------
import { PayoutStatus, PayoutStatuses } from "./types";

const PAYOUT_TRANSITIONS: Record<PayoutStatus, PayoutStatus[]> = {
  [PayoutStatuses.PENDING]: [PayoutStatuses.ELIGIBLE, PayoutStatuses.HELD],
  [PayoutStatuses.HELD]: [PayoutStatuses.ELIGIBLE, PayoutStatuses.PENDING],
  [PayoutStatuses.ELIGIBLE]: [PayoutStatuses.SCHEDULED, PayoutStatuses.HELD],
  [PayoutStatuses.SCHEDULED]: [PayoutStatuses.PROCESSING, PayoutStatuses.HELD],
  [PayoutStatuses.PROCESSING]: [PayoutStatuses.PAID, PayoutStatuses.FAILED],
  [PayoutStatuses.PAID]: [PayoutStatuses.REVERSED],
  [PayoutStatuses.FAILED]: [PayoutStatuses.SCHEDULED, PayoutStatuses.HELD],
  [PayoutStatuses.REVERSED]: [],
};

export function isValidPayoutTransition(from: PayoutStatus, to: PayoutStatus): boolean {
  if (from === to) return false;
  return (PAYOUT_TRANSITIONS[from] ?? []).includes(to);
}

export function assertValidPayoutTransition(from: PayoutStatus, to: PayoutStatus): void {
  if (!isValidPayoutTransition(from, to)) {
    throw failedPrecondition(
      `Transition de payout invalide : '${from}' -> '${to}'. Transitions autorisées depuis '${from}': [${(PAYOUT_TRANSITIONS[from] ?? []).join(", ")}].`
    );
  }
}

// -----------------------------------------------------------------------------
// Dispute state machine (point 21).
// -----------------------------------------------------------------------------
import { DisputeStatus, DisputeStatuses } from "./types";

const DISPUTE_TRANSITIONS: Record<DisputeStatus, DisputeStatus[]> = {
  [DisputeStatuses.OPENED]: [DisputeStatuses.UNDER_REVIEW, DisputeStatuses.LOST],
  [DisputeStatuses.UNDER_REVIEW]: [DisputeStatuses.WON, DisputeStatuses.LOST],
  [DisputeStatuses.WON]: [DisputeStatuses.REVERSED /* late-loss rarissime, documenté par Stripe */],
  [DisputeStatuses.LOST]: [DisputeStatuses.REVERSED /* late-win */],
  [DisputeStatuses.REVERSED]: [],
};

export function isValidDisputeTransition(from: DisputeStatus, to: DisputeStatus): boolean {
  if (from === to) return false;
  return (DISPUTE_TRANSITIONS[from] ?? []).includes(to);
}

export function assertValidDisputeTransition(from: DisputeStatus, to: DisputeStatus): void {
  if (!isValidDisputeTransition(from, to)) {
    throw failedPrecondition(
      `Transition de dispute invalide : '${from}' -> '${to}'.`
    );
  }
}
