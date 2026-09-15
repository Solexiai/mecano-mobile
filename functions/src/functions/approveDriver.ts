// -----------------------------------------------------------------------------
// approveDriver — Cloud Function callable (analyst/admin/super_admin).
//
// Écrit les champs sensibles de `driver_profiles/{driverId}` que les
// Security Rules interdisent au client (voir firestore.rules,
// `match /driver_profiles/{driverId}`). Journalise dans `audit_logs`.
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { requireAnalystOrAbove, requireSignedIn } from "../lib/auth";
import { writeAuditLog } from "../lib/audit";
import { failedPrecondition, invalidArgument, notFound } from "../lib/errors";
import { DriverDocumentStatuses, DriverStatuses } from "../lib/types";

const REQUIRED_DOCUMENT_TYPES = [
  "drivers_licence",
  "vehicle_registration",
  "insurance",
  "identity",
] as const;

export interface ApproveDriverRequest {
  driverId: string;
}

export const approveDriver = onCall<ApproveDriverRequest>(async (request) => {
  const ctx = requireSignedIn(request);
  requireAnalystOrAbove(ctx);

  const { driverId } = request.data;
  if (!driverId || typeof driverId !== "string") {
    throw invalidArgument("driverId est requis.");
  }

  const driverRef = db.collection("driver_profiles").doc(driverId);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(driverRef);
    if (!snap.exists) {
      throw notFound(`driver_profiles/${driverId} introuvable.`);
    }
    const data = snap.data()!;
    const documentsSnap = await tx.get(
      db.collection("driver_documents").where("driver_id", "==", driverId)
    );

    if (
      data.status === DriverStatuses.APPROVED &&
      data.documents_all_valid === true
    ) {
      throw failedPrecondition("Ce chauffeur est déjà approuvé.");
    }
    if (data.status === DriverStatuses.SUSPENDED) {
      throw failedPrecondition(
        "Un chauffeur suspendu doit être réactivé explicitement (pas via approveDriver)."
      );
    }

    // Le bouton « Approuver » finalise le dossier complet en une action,
    // mais seulement si chaque document obligatoire a réellement été
    // téléversé et n'est ni rejeté, expiré, ni à remplacer.
    const now = admin.firestore.Timestamp.now();
    const selectedDocuments = REQUIRED_DOCUMENT_TYPES.map((type) => {
      const candidates = documentsSnap.docs
        .filter((documentSnap) => {
          const document = documentSnap.data();
          if (document.type !== type) return false;
          if (
            document.status === DriverDocumentStatuses.REJECTED ||
            document.status === DriverDocumentStatuses.EXPIRED ||
            document.status === DriverDocumentStatuses.REPLACEMENT_REQUIRED
          ) {
            return false;
          }
          const expiresAt = document.expires_at as admin.firestore.Timestamp | null;
          return !expiresAt || expiresAt.toMillis() > now.toMillis();
        })
        .sort((a, b) => {
          const aTime = (a.data().uploaded_at as admin.firestore.Timestamp | undefined)
            ?.toMillis() ?? 0;
          const bTime = (b.data().uploaded_at as admin.firestore.Timestamp | undefined)
            ?.toMillis() ?? 0;
          return bTime - aTime;
        });
      return candidates[0] ?? null;
    });

    if (selectedDocuments.some((documentSnap) => documentSnap === null)) {
      throw failedPrecondition(
        "Tous les documents obligatoires doivent être téléversés et valides avant l'approbation."
      );
    }

    // 🔒 Empêche un chauffeur de s'auto-approuver : même si un analyste
    // malveillant appelait cette fonction avec son propre uid en tant que
    // driverId, la vérification `requireAnalystOrAbove` a déjà exigé un rôle
    // analyst/admin/super_admin distinct du rôle driver pour le compte
    // appelant — mais on ajoute une garde explicite supplémentaire :
    if (ctx.uid === driverId) {
      throw failedPrecondition("Un compte ne peut pas s'auto-approuver.");
    }

    for (const documentSnap of selectedDocuments) {
      tx.update(documentSnap!.ref, {
        status: DriverDocumentStatuses.APPROVED,
        reviewed_at: now,
        reviewed_by_user_id: ctx.uid,
        rejection_reason: null,
      });
    }

    tx.update(driverRef, {
      status: DriverStatuses.APPROVED,
      documents_all_valid: true,
      identity_verified: true,
      vehicle_verified: true,
      approved_at: now,
      approved_by_user_id: ctx.uid,
      rejection_reason: null,
    });

    writeAuditLog({
      actorUserId: ctx.uid,
      actorRole: ctx.role ?? "unknown",
      action: "driver_approved",
      sourceFunction: "approveDriver",
      targetId: driverId,
      metadata: { previous_status: data.status },
    });
  });

  return { success: true, driverId };
});
