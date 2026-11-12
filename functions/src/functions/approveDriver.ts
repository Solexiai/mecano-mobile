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
import { DriverDocumentStatuses, DriverStatuses, PlatformRoles } from "../lib/types";
import { missingRequiredDocuments } from "../lib/driverDocuments";

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

    // SEC-05 (2026-10-28) : « Approuver le dossier » ne valide plus en bloc
    // des documents jamais revus. Chaque document obligatoire doit avoir été
    // APPROUVÉ individuellement (validateDriverDocument, revue humaine), être
    // non expiré. 2026-11-12 : permis recto ET verso (ou ancien permis en
    // une image), plus de pièce d'identité (lib/driverDocuments.ts).
    const now = admin.firestore.Timestamp.now();
    const missing = missingRequiredDocuments(
      documentsSnap.docs.map((documentSnap) => documentSnap.data()),
      (document) => {
        if (document.status !== DriverDocumentStatuses.APPROVED) return false;
        const expiresAt = document.expires_at as admin.firestore.Timestamp | null;
        return !expiresAt || expiresAt.toMillis() > now.toMillis();
      }
    );

    if (missing.length) {
      throw failedPrecondition(
        `Chaque document obligatoire doit d'abord être approuvé individuellement (manquants ou non approuvés : ${missing.join(", ")}).`
      );
    }

    // 🔒 Empêche un chauffeur de s'auto-approuver : même si un analyste
    // malveillant appelait cette fonction avec son propre uid en tant que
    // driverId, la vérification `requireAnalystOrAbove` a déjà exigé un rôle
    // analyst/admin/super_admin distinct du rôle driver pour le compte
    // appelant — mais on ajoute une garde explicite supplémentaire :
    if (
      ctx.uid === driverId &&
      !ctx.roles.includes(PlatformRoles.SUPER_ADMIN)
    ) {
      throw failedPrecondition(
        "Seul un super administrateur peut approuver son propre dossier de test."
      );
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
