// -----------------------------------------------------------------------------
// paymentStateMachine.ts — Machine d'état PAIEMENT explicite, appliquée
// UNIQUEMENT côté serveur (point 6 du cahier des charges Phase 6).
//
// « Le statut de paiement doit être une machine d'état EXPLICITE gérée
//   exclusivement côté serveur. » Flutter ne fait jamais de transition — il
// lit `payments/{id}.status` (déjà écrit par une Cloud Function) et
// n'affiche jamais un statut qu'il aurait lui-même déduit/anticipé.
// -----------------------------------------------------------------------------

import { PaymentStatus, PaymentStatuses } from "./types";

const TRANSITIONS: Record<PaymentStatus, PaymentStatus[]> = {
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
    PaymentStatuses.CAPTURED, // capture synchrone possible selon provider
    PaymentStatuses.CANCELLED, // mission annulée avant capture
    PaymentStatuses.FAILED, // autorisation expirée (fenêtre réseau dépassée)
  ],
  [PaymentStatuses.CAPTURE_PENDING]: [PaymentStatuses.CAPTURED, PaymentStatuses.FAILED],
  [PaymentStatuses.CAPTURED]: [
    PaymentStatuses.PARTIALLY_REFUNDED,
    PaymentStatuses.REFUNDED,
    PaymentStatuses.DISPUTED,
  ],
  [PaymentStatuses.PARTIALLY_REFUNDED]: [
    PaymentStatuses.REFUNDED,
    PaymentStatuses.DISPUTED,
  ],
  [PaymentStatuses.DISPUTED]: [PaymentStatuses.CHARGEBACK, PaymentStatuses.CAPTURED /* dispute gagnée, retour à l'état antérieur */],
  [PaymentStatuses.CHARGEBACK]: [PaymentStatuses.REFUNDED /* late-win documenté, résolution comptable */],
  // États terminaux (aucune transition sortante).
  [PaymentStatuses.FAILED]: [],
  [PaymentStatuses.CANCELLED]: [],
  [PaymentStatuses.REFUNDED]: [],
};

export class InvalidPaymentTransitionError extends Error {
  constructor(from: PaymentStatus, to: PaymentStatus) {
    super(`Transition de paiement invalide: '${from}' -> '${to}'.`);
    this.name = "InvalidPaymentTransitionError";
  }
}

export function isValidPaymentTransition(from: PaymentStatus, to: PaymentStatus): boolean {
  return TRANSITIONS[from]?.includes(to) ?? false;
}

/** Lève une erreur explicite si la transition n'est pas autorisée. */
export function assertValidPaymentTransition(from: PaymentStatus, to: PaymentStatus): void {
  if (!isValidPaymentTransition(from, to)) {
    throw new InvalidPaymentTransitionError(from, to);
  }
}

export function isTerminalPaymentStatus(status: PaymentStatus): boolean {
  return TRANSITIONS[status].length === 0;
}
