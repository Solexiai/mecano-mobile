// -----------------------------------------------------------------------------
// submitDriverForReview — Cloud Function callable (driver uniquement).
//
// CONTEXTE (trouvé lors de l'audit Movi-K) : firestore.rules interdit au
// chauffeur de modifier `driver_profiles.status` lui-même (voir la règle
// `update` de `driver_profiles`, qui exige
// `request.resource.data.status == resource.data.status`). Il n'existait
// donc AUCUN moyen de faire transitionner un profil de
// 'registration_incomplete' à 'pending_review' une fois le formulaire
// d'onboarding complété — le flux d'inscription chauffeur était bloqué
// avant même d'atteindre la file d'attente analyste. Cette fonction comble
// ce chaînon manquant.
//
// 🔒 Ne modifie QUE `status` (et uniquement dans le sens
// registration_incomplete/documents_required -> pending_review). Ne touche
// à aucun champ protégé (approved_at, rating, etc.).
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { requireSignedIn } from "../lib/auth";
import { writeAuditLog } from "../lib/audit";
import { failedPrecondition, notFound, permissionDenied } from "../lib/errors";
import { DriverStatuses } from "../lib/types";

const ALLOWED_PREVIOUS_STATUSES: string[] = [
  DriverStatuses.REGISTRATION_INCOMPLETE,
  DriverStatuses.DOCUMENTS_REQUIRED,
];

export const submitDriverForReview = onCall(async (request) => {
  const ctx = requireSignedIn(request);

  if (!ctx.roles.includes("driver")) {
    throw permissionDenied("Rôle driver requis pour soumettre une candidature.");
  }

  const driverRef = db.collection("driver_profiles").doc(ctx.uid);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(driverRef);
    if (!snap.exists) {
      throw notFound("driver_profiles introuvable — complétez d'abord votre profil.");
    }
    const data = snap.data()!;

    if (!ALLOWED_PREVIOUS_STATUSES.includes(data.status)) {
      throw failedPrecondition(
        `Impossible de soumettre pour révision depuis le statut actuel (${data.status}).`
      );
    }

    tx.update(driverRef, {
      status: DriverStatuses.PENDING_REVIEW,
      submitted_for_review_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    writeAuditLog({
      actorUserId: ctx.uid,
      actorRole: "driver",
      action: "submitDriverForReview",
      sourceFunction: "submitDriverForReview",
      targetId: ctx.uid,
      metadata: { previous_status: data.status },
    });
  });

  return { success: true, status: DriverStatuses.PENDING_REVIEW };
});
