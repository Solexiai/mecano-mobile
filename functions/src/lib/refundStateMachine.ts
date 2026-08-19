// -----------------------------------------------------------------------------
// refundStateMachine.ts — Machine d'état REFUND explicite (point 3 de la
// directive 38 points Phase 6), appliquée UNIQUEMENT côté serveur. Mêmes
// principes que paymentStateMachine.ts / payoutStateMachine.ts.
//
//   REQUESTED -> PROCESSING -> SUCCEEDED
//   REQUESTED -> PROCESSING -> FAILED
//   FAILED -> PROCESSING (nouvelle tentative explicite, ex: admin relance)
//
// Aucune transition n'est valide depuis SUCCEEDED (état terminal). FAILED
// n'est PAS terminal : un remboursement échoué peut être retenté (le
// RefundDoc reste le même document, protégé par le même idempotency_key —
// voir refundPayment.ts, section retry).
// -----------------------------------------------------------------------------

import { RefundStatus, RefundStatuses } from "./types";

const TRANSITIONS: Record<RefundStatus, RefundStatus[]> = {
  [RefundStatuses.REQUESTED]: [RefundStatuses.PROCESSING, RefundStatuses.FAILED],
  [RefundStatuses.PROCESSING]: [RefundStatuses.SUCCEEDED, RefundStatuses.FAILED],
  [RefundStatuses.FAILED]: [RefundStatuses.PROCESSING],
  [RefundStatuses.SUCCEEDED]: [],
};

export class InvalidRefundTransitionError extends Error {
  constructor(from: RefundStatus, to: RefundStatus) {
    super(`Transition de remboursement invalide: '${from}' -> '${to}'.`);
    this.name = "InvalidRefundTransitionError";
  }
}

export function isValidRefundTransition(from: RefundStatus, to: RefundStatus): boolean {
  return TRANSITIONS[from]?.includes(to) ?? false;
}

export function assertValidRefundTransition(from: RefundStatus, to: RefundStatus): void {
  if (!isValidRefundTransition(from, to)) {
    throw new InvalidRefundTransitionError(from, to);
  }
}

export function isTerminalRefundStatus(status: RefundStatus): boolean {
  return TRANSITIONS[status].length === 0;
}
