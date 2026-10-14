// -----------------------------------------------------------------------------
// suspendDriver — Cloud Function callable, ADMIN/SUPER_ADMIN UNIQUEMENT.
//
// Suspend un chauffeur (ex: incident de sécurité, plainte grave). Distinct de
// rejectDriver (qui s'applique à une candidature jamais approuvée) : suspendDriver
// s'applique à un chauffeur potentiellement déjà `approved` et actif. Un
// chauffeur suspendu ne peut plus passer en ligne (`canGoOnline` == false côté
// Dart pour tout statut != 'approved').
//
// 🔒 Action plus sensible qu'approve/reject : réservée à admin/super_admin
// (pas analyst), pour limiter le risque d'abus sur des comptes actifs.
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { requireAdminOrAbove, requireSignedIn } from "../lib/auth";
import { writeAuditLog } from "../lib/audit";
import { failedPrecondition, invalidArgument, notFound } from "../lib/errors";
import { DriverStatuses } from "../lib/types";
import { SuspensionModes, SuspensionMode } from "../lib/driverSuspensionPolicy";

export interface SuspendDriverRequest {
  driverId: string;
  reason: string;
  suspensionMode?: SuspensionMode;
}

export const suspendDriver = onCall<SuspendDriverRequest>(async (request) => {
  const ctx = requireSignedIn(request);
  requireAdminOrAbove(ctx);

  const { driverId, reason, suspensionMode = SuspensionModes.URGENT } = request.data;
  if (!driverId || typeof driverId !== "string") {
    throw invalidArgument("driverId est requis.");
  }
  if (!reason || typeof reason !== "string" || reason.trim().length < 3) {
    throw invalidArgument("reason est requis (motif de suspension, min. 3 caractères).");
  }

  if (suspensionMode !== SuspensionModes.ORDINARY &&
      suspensionMode !== SuspensionModes.URGENT) {
    throw invalidArgument("Mode de suspension invalide.");
  }

  const driverRef = db.collection("driver_profiles").doc(driverId);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(driverRef);
    if (!snap.exists) {
      throw notFound(`driver_profiles/${driverId} introuvable.`);
    }
    const data = snap.data()!;

    if (data.status === DriverStatuses.SUSPENDED) {
      // A safety incident may escalate an ordinary suspension to urgent
      // without first reactivating the driver. No downgrade without review.
      if (suspensionMode !== SuspensionModes.URGENT ||
          data.suspension_mode !== SuspensionModes.ORDINARY) {
        throw failedPrecondition("Ce chauffeur est déjà suspendu.");
      }
    }

    tx.update(driverRef, {
      status: DriverStatuses.SUSPENDED,
      suspended_at: admin.firestore.FieldValue.serverTimestamp(),
      suspended_by_user_id: ctx.uid,
      suspension_reason: reason,
      suspension_mode: suspensionMode,
      // Un chauffeur suspendu ne peut pas rester "en ligne".
      online_status: "offline",
    });

    writeAuditLog({
      actorUserId: ctx.uid,
      actorRole: ctx.role ?? "unknown",
      action: "driver_suspended",
      sourceFunction: "suspendDriver",
      targetId: driverId,
      metadata: { previous_status: data.status, reason, suspensionMode },
    });
  });

  return { success: true, driverId };
});
