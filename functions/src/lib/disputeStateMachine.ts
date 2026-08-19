// -----------------------------------------------------------------------------
// disputeStateMachine.ts — Machine d'état DISPUTE/CHARGEBACK explicite
// (point 8 de la directive 38 points Phase 6). Mêmes principes que les
// autres machines d'état Phase 6.
//
//   OPENED -> UNDER_REVIEW -> WON -> CLOSED
//   OPENED -> UNDER_REVIEW -> LOST -> CLOSED
//   LOST -> REVERSED -> CLOSED (late-win / résolution comptable ultérieure)
//   OPENED -> WON | LOST directement possible (certains providers résolvent
//     sans étape "under_review" explicite côté webhook).
// -----------------------------------------------------------------------------

import { DisputeStatus, DisputeStatuses } from "./types";

const TRANSITIONS: Record<DisputeStatus, DisputeStatus[]> = {
  [DisputeStatuses.OPENED]: [
    DisputeStatuses.UNDER_REVIEW,
    DisputeStatuses.WON,
    DisputeStatuses.LOST,
  ],
  [DisputeStatuses.UNDER_REVIEW]: [DisputeStatuses.WON, DisputeStatuses.LOST],
  [DisputeStatuses.WON]: [DisputeStatuses.CLOSED],
  [DisputeStatuses.LOST]: [DisputeStatuses.REVERSED, DisputeStatuses.CLOSED],
  [DisputeStatuses.REVERSED]: [DisputeStatuses.CLOSED],
  [DisputeStatuses.CLOSED]: [],
};

export class InvalidDisputeTransitionError extends Error {
  constructor(from: DisputeStatus, to: DisputeStatus) {
    super(`Transition de litige invalide: '${from}' -> '${to}'.`);
    this.name = "InvalidDisputeTransitionError";
  }
}

export function isValidDisputeTransition(from: DisputeStatus, to: DisputeStatus): boolean {
  return TRANSITIONS[from]?.includes(to) ?? false;
}

export function assertValidDisputeTransition(from: DisputeStatus, to: DisputeStatus): void {
  if (!isValidDisputeTransition(from, to)) {
    throw new InvalidDisputeTransitionError(from, to);
  }
}

export function isTerminalDisputeStatus(status: DisputeStatus): boolean {
  return TRANSITIONS[status].length === 0;
}
