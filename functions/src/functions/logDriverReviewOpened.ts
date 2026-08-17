// -----------------------------------------------------------------------------
// logDriverReviewOpened — Cloud Function callable (analyst/admin/super_admin).
//
// Journalise l'ouverture d'un dossier chauffeur par un analyste (traçabilité
// "qui a consulté quel dossier, quand" — utile en cas d'audit/litige). N'écrit
// AUCUN champ métier sur driver_profiles : uniquement une entrée audit_logs.
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { requireAnalystOrAbove, requireSignedIn } from "../lib/auth";
import { writeAuditLog } from "../lib/audit";
import { invalidArgument } from "../lib/errors";

export interface LogDriverReviewOpenedRequest {
  driverId: string;
}

export const logDriverReviewOpened = onCall<LogDriverReviewOpenedRequest>(async (request) => {
  const ctx = requireSignedIn(request);
  requireAnalystOrAbove(ctx);

  const { driverId } = request.data;
  if (!driverId || typeof driverId !== "string") {
    throw invalidArgument("driverId est requis.");
  }

  await writeAuditLog({
    actorUserId: ctx.uid,
    actorRole: ctx.role ?? "unknown",
    action: "driver_review_opened",
    sourceFunction: "logDriverReviewOpened",
    targetId: driverId,
    metadata: {},
  });

  return { success: true };
});
