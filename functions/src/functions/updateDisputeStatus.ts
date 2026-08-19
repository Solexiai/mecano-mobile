// -----------------------------------------------------------------------------
// updateDisputeStatus — Cloud Function callable (admin/super_admin
// uniquement). Permet une transition MANUELLE de statut de litige quand un
// admin traite le dossier hors du flux webhook automatique (ex: preuve
// envoyée manuellement à Stripe, décision confirmée par téléphone avant que
// le webhook n'arrive). Le webhook réel (Bloc D, processStripeWebhook.ts)
// appelle directement `transitionDisputeStatus()` sans passer par cette
// fonction callable (pas d'authentification utilisateur pour un webhook).
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { requireAdminOrAbove, requireSignedIn } from "../lib/auth";
import { invalidArgument } from "../lib/errors";
import { writeAuditLog } from "../lib/audit";
import { DisputeStatus, DisputeStatuses } from "../lib/types";
import { transitionDisputeStatus } from "../payment/disputeOrchestration";

export interface UpdateDisputeStatusRequest {
  disputeId: string;
  newStatus: DisputeStatus;
}

const VALID_STATUSES: string[] = Object.values(DisputeStatuses);

export const updateDisputeStatus = onCall<UpdateDisputeStatusRequest>(async (request) => {
  const ctx = requireSignedIn(request);
  requireAdminOrAbove(ctx);
  const { disputeId, newStatus } = request.data;

  if (!disputeId) throw invalidArgument("disputeId est requis.");
  if (!newStatus || !VALID_STATUSES.includes(newStatus)) {
    throw invalidArgument(`newStatus invalide. Valeurs autorisées: ${VALID_STATUSES.join(", ")}.`);
  }

  const outcome = await transitionDisputeStatus({ disputeId, newStatus });

  await writeAuditLog({
    actorUserId: ctx.uid,
    actorRole: ctx.role ?? "admin",
    action: "dispute_updated",
    sourceFunction: "updateDisputeStatus",
    targetId: disputeId,
    metadata: { newStatus, skipped: outcome.skipped },
  });

  return outcome;
});
