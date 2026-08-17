// -----------------------------------------------------------------------------
// rejectDriver — Cloud Function callable (analyst/admin/super_admin).
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { db } from "../lib/admin";
import { requireAnalystOrAbove, requireSignedIn } from "../lib/auth";
import { writeAuditLog } from "../lib/audit";
import { invalidArgument, notFound } from "../lib/errors";
import { DriverStatuses } from "../lib/types";

export interface RejectDriverRequest {
  driverId: string;
  reason: string;
}

export const rejectDriver = onCall<RejectDriverRequest>(async (request) => {
  const ctx = requireSignedIn(request);
  requireAnalystOrAbove(ctx);

  const { driverId, reason } = request.data;
  if (!driverId || typeof driverId !== "string") {
    throw invalidArgument("driverId est requis.");
  }
  if (!reason || typeof reason !== "string" || reason.trim().length < 3) {
    throw invalidArgument("reason est requis (motif de rejet, min. 3 caractères).");
  }

  const driverRef = db.collection("driver_profiles").doc(driverId);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(driverRef);
    if (!snap.exists) {
      throw notFound(`driver_profiles/${driverId} introuvable.`);
    }
    const data = snap.data()!;

    tx.update(driverRef, {
      status: DriverStatuses.REJECTED,
      rejection_reason: reason,
      approved_at: null,
      approved_by_user_id: null,
    });

    writeAuditLog({
      actorUserId: ctx.uid,
      actorRole: ctx.role ?? "unknown",
      action: "driver_rejected",
      sourceFunction: "rejectDriver",
      targetId: driverId,
      metadata: { previous_status: data.status, reason },
    });
  });

  return { success: true, driverId };
});
