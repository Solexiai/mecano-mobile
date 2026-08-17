// -----------------------------------------------------------------------------
// requestDriverDocuments — Cloud Function callable (analyst/admin/super_admin).
//
// Fait transitionner `driver_profiles/{driverId}.status` vers
// `documents_required` lorsqu'un analyste juge qu'un ou plusieurs documents
// doivent être corrigés/remplacés (permis expiré, photo illisible, etc.).
// Le chauffeur pourra ensuite re-soumettre via `submitDriverForReview`
// (qui accepte déjà `documents_required` comme statut de départ autorisé —
// voir ALLOWED_PREVIOUS_STATUSES dans submitDriverForReview.ts).
//
// 🔒 Comme approveDriver/rejectDriver, cette fonction est le SEUL point
// d'entrée pour ce changement de statut — firestore.rules interdit tout
// update direct de `status` par un client, même analyst/admin.
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { requireAnalystOrAbove, requireSignedIn } from "../lib/auth";
import { writeAuditLog } from "../lib/audit";
import { failedPrecondition, invalidArgument, notFound } from "../lib/errors";
import { DriverStatuses } from "../lib/types";

// Statuts depuis lesquels une demande de correction de documents est
// sensée : un dossier en cours de revue, déjà en correction (nouveau motif),
// ou même déjà approuvé (ex: permis expiré détecté après coup — voir aussi
// detectExpiringDocuments). PAS depuis rejected/suspended/registration_incomplete
// (le chauffeur doit d'abord compléter son onboarding normalement).
const ALLOWED_PREVIOUS_STATUSES: string[] = [
  DriverStatuses.PENDING_REVIEW,
  DriverStatuses.DOCUMENTS_REQUIRED,
  DriverStatuses.APPROVED,
];

export interface RequestDriverDocumentsRequest {
  driverId: string;
  reason: string;
}

export const requestDriverDocuments = onCall<RequestDriverDocumentsRequest>(async (request) => {
  const ctx = requireSignedIn(request);
  requireAnalystOrAbove(ctx);

  const { driverId, reason } = request.data;
  if (!driverId || typeof driverId !== "string") {
    throw invalidArgument("driverId est requis.");
  }
  if (!reason || typeof reason !== "string" || reason.trim().length < 3) {
    throw invalidArgument("reason est requis (motif, min. 3 caractères).");
  }

  const driverRef = db.collection("driver_profiles").doc(driverId);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(driverRef);
    if (!snap.exists) {
      throw notFound(`driver_profiles/${driverId} introuvable.`);
    }
    const data = snap.data()!;

    if (!ALLOWED_PREVIOUS_STATUSES.includes(data.status)) {
      throw failedPrecondition(
        `Impossible de demander des documents depuis le statut actuel (${data.status}).`
      );
    }

    tx.update(driverRef, {
      status: DriverStatuses.DOCUMENTS_REQUIRED,
      documents_required_reason: reason,
      documents_required_at: admin.firestore.FieldValue.serverTimestamp(),
      documents_required_by_user_id: ctx.uid,
    });

    writeAuditLog({
      actorUserId: ctx.uid,
      actorRole: ctx.role ?? "unknown",
      action: "driver_documents_requested",
      targetId: driverId,
      metadata: { previous_status: data.status, reason },
    });
  });

  return { success: true, driverId };
});
