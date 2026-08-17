// -----------------------------------------------------------------------------
// reactivateDriver — Cloud Function callable, ADMIN/SUPER_ADMIN UNIQUEMENT.
//
// Réactive un chauffeur suspendu (retour à 'approved'). Symétrique de
// suspendDriver. Ne peut être appliquée que depuis le statut 'suspended'
// (voir garde explicite dans approveDriver.ts qui redirige justement les
// admins vers cette fonction plutôt que d'accepter suspended -> approved).
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { requireAdminOrAbove, requireSignedIn } from "../lib/auth";
import { writeAuditLog } from "../lib/audit";
import { failedPrecondition, invalidArgument, notFound } from "../lib/errors";
import { DriverStatuses } from "../lib/types";

export interface ReactivateDriverRequest {
  driverId: string;
}

export const reactivateDriver = onCall<ReactivateDriverRequest>(async (request) => {
  const ctx = requireSignedIn(request);
  requireAdminOrAbove(ctx);

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

    if (data.status !== DriverStatuses.SUSPENDED) {
      throw failedPrecondition(
        `Seul un chauffeur suspendu peut être réactivé (statut actuel: ${data.status}).`
      );
    }

    tx.update(driverRef, {
      status: DriverStatuses.APPROVED,
      suspended_at: null,
      suspended_by_user_id: null,
      suspension_reason: null,
      reactivated_at: admin.firestore.FieldValue.serverTimestamp(),
      reactivated_by_user_id: ctx.uid,
    });

    writeAuditLog({
      actorUserId: ctx.uid,
      actorRole: ctx.role ?? "unknown",
      action: "driver_reactivated",
      targetId: driverId,
      metadata: { previous_status: data.status },
    });
  });

  return { success: true, driverId };
});
