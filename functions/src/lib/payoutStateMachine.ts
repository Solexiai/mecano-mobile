// -----------------------------------------------------------------------------
// payoutStateMachine.ts — Machine d'état VERSEMENT CHAUFFEUR explicite,
// appliquée UNIQUEMENT côté serveur (miroir de paymentStateMachine.ts pour
// driver_payouts, point 6 + point 9 du cahier des charges Phase 6).
//
// Cycle de vie nominal :
//   pending  -> held       (chauffeur "nouveau"/"à risque", rétention prolongée)
//   pending  -> eligible    (rétention écoulée dès la création, aucune raison de retenir)
//   held     -> eligible    (rétention écoulée après un temps de blocage)
//   eligible -> scheduled   (batch de versement planifié)
//   scheduled -> processing (appel PaymentProvider.createDriverPayout() en cours)
//   processing -> paid      (confirmation fournisseur)
//   processing -> failed    (refus fournisseur, ex: compte connecté invalide)
//   failed   -> scheduled   (nouvelle tentative manuelle/admin, même idempotency_key)
//   paid     -> reversed    (remboursement post-versement, compensation — point 20)
// -----------------------------------------------------------------------------

import { PayoutStatus, PayoutStatuses } from "./types";

const TRANSITIONS: Record<PayoutStatus, PayoutStatus[]> = {
  [PayoutStatuses.PENDING]: [PayoutStatuses.HELD, PayoutStatuses.ELIGIBLE, PayoutStatuses.FAILED],
  [PayoutStatuses.HELD]: [PayoutStatuses.ELIGIBLE, PayoutStatuses.FAILED],
  [PayoutStatuses.ELIGIBLE]: [PayoutStatuses.SCHEDULED, PayoutStatuses.FAILED],
  [PayoutStatuses.SCHEDULED]: [PayoutStatuses.PROCESSING, PayoutStatuses.FAILED],
  [PayoutStatuses.PROCESSING]: [PayoutStatuses.PAID, PayoutStatuses.FAILED],
  [PayoutStatuses.FAILED]: [PayoutStatuses.SCHEDULED],
  [PayoutStatuses.PAID]: [PayoutStatuses.REVERSED],
  [PayoutStatuses.REVERSED]: [],
};

export class InvalidPayoutTransitionError extends Error {
  constructor(from: PayoutStatus, to: PayoutStatus) {
    super(`Transition de versement invalide: '${from}' -> '${to}'.`);
    this.name = "InvalidPayoutTransitionError";
  }
}

export function isValidPayoutTransition(from: PayoutStatus, to: PayoutStatus): boolean {
  return TRANSITIONS[from]?.includes(to) ?? false;
}

export function assertValidPayoutTransition(from: PayoutStatus, to: PayoutStatus): void {
  if (!isValidPayoutTransition(from, to)) {
    throw new InvalidPayoutTransitionError(from, to);
  }
}

export function isTerminalPayoutStatus(status: PayoutStatus): boolean {
  return TRANSITIONS[status].length === 0;
}
