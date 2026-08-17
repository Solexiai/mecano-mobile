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
import { DriverStatuses } from "../lib/types";

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

    if (data.status === DriverStatuses.APPROVED) {
      throw failedPrecondition("Ce chauffeur est déjà approuvé.");
    }
    if (data.status === DriverStatuses.SUSPENDED) {
      throw failedPrecondition(
        "Un chauffeur suspendu doit être réactivé explicitement (pas via approveDriver)."
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

    tx.update(driverRef, {
      status: DriverStatuses.APPROVED,
      approved_at: admin.firestore.FieldValue.serverTimestamp(),
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
