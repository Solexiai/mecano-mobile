// -----------------------------------------------------------------------------
// reverseDriverPayout — Cloud Function callable (admin/super_admin uniquement).
//
// PHASE 6 (payoutStateMachine.ts, transition PAID -> REVERSED, point 20) :
// compensation comptable administrative d'un versement DÉJÀ payé. Un
// versement Stripe PAID ne peut PAS être annulé via l'API Stripe (les fonds
// ont quitté le compte connecté) — cette fonction n'invente donc AUCUN appel
// provider. Elle documente qu'un recouvrement a été négocié hors-bande
// (ex: retenue sur un versement futur, remboursement volontaire du
// chauffeur) et crée les entrées ledger DRIVER_PAYOUT_REVERSAL
// correspondantes — voir `payment/paymentOrchestration.ts::reverseDriverPayout()`.
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { requireAdminOrAbove, requireSignedIn } from "../lib/auth";
import { invalidArgument } from "../lib/errors";
import { reverseDriverPayout as reverseDriverPayoutOrchestration } from "../payment/paymentOrchestration";

export interface ReverseDriverPayoutRequest {
  payoutId: string;
  /** Motif obligatoire — jamais un reversal silencieux/non documenté. */
  reason: string;
}

export const reverseDriverPayout = onCall<ReverseDriverPayoutRequest>(async (request) => {
  const ctx = requireSignedIn(request);
  requireAdminOrAbove(ctx);

  const { payoutId, reason } = request.data;
  if (!payoutId) throw invalidArgument("payoutId est requis.");
  if (!reason || typeof reason !== "string" || !reason.trim()) {
    throw invalidArgument("reason est requis (motif obligatoire pour tout reversal de versement).");
  }

  const outcome = await reverseDriverPayoutOrchestration({
    payoutId,
    reason: reason.trim(),
    initiatedByUserId: ctx.uid,
    initiatedByRole: ctx.role ?? "admin",
  });

  return outcome;
});
