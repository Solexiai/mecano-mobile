// -----------------------------------------------------------------------------
// adminMissionActions — admin only (owner request 2026-10-30): cancel a
// mission and remove it from the admin lists.
//
//   - "cancel" { missionId, reason? }: any mission not finished yet. Movi-K
//     cancels, so the customer pays nothing (booking terms, art. 5.6): no fee
//     is recorded and onMissionEndedClearTracking releases the card hold, as
//     for any cancellation without a fee. Pending driver offers are closed and
//     the assigned driver is back "online". A delivered or paid mission is
//     never cancelled here (refund from Finances instead).
//   - "delete" { missionId }: a finished mission (cancelled, completed,
//     refunded, payment failed) is hidden from the admin lists. The record is
//     kept, never erased: payments, receipts and disputes point to it, and the
//     accounting records must be kept (privacy policy, section 7).
// Both actions are audited.
// -----------------------------------------------------------------------------
import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { writeAuditLogInTransaction } from "../lib/audit";
import { requireAdminOrAbove, requireSignedIn } from "../lib/auth";
import { failedPrecondition, invalidArgument, notFound } from "../lib/errors";
import { MissionStatuses } from "../lib/types";

/** Not finished: an admin may cancel. */
export const ADMIN_CANCELLABLE_STATUSES: readonly string[] = [
  MissionStatuses.DRAFT, MissionStatuses.QUOTED, MissionStatuses.SEARCHING_DRIVER,
  MissionStatuses.OFFERED, MissionStatuses.ASSIGNED, MissionStatuses.DRIVER_TO_PICKUP,
  MissionStatuses.ARRIVED_AT_PICKUP, MissionStatuses.PICKED_UP, MissionStatuses.IN_TRANSIT,
  MissionStatuses.ARRIVED_AT_DROPOFF, MissionStatuses.PAYMENT_FAILED,
];

/** Finished: an admin may remove it from the lists. */
export const ADMIN_DELETABLE_STATUSES: readonly string[] = [
  MissionStatuses.CANCELLED, MissionStatuses.COMPLETED, MissionStatuses.REFUNDED,
  MissionStatuses.PAYMENT_FAILED,
];

function missionIdFrom(data: Record<string, unknown>): string {
  const id = data.missionId;
  if (typeof id !== "string" || !id || id.length > 128 || id.includes("/")) throw invalidArgument("Mission invalide.");
  return id;
}

export const adminMissionActions = onCall(async (request) => {
  const ctx = requireSignedIn(request);
  requireAdminOrAbove(ctx);
  const data = (request.data ?? {}) as Record<string, unknown>;
  const missionId = missionIdFrom(data);
  const missionRef = db.collection("delivery_requests").doc(missionId);

  if (data.action === "cancel") {
    const reason = typeof data.reason === "string" ? data.reason.trim().slice(0, 500) : "";
    return db.runTransaction(async (tx) => {
      const snap = await tx.get(missionRef);
      if (!snap.exists) throw notFound("Mission introuvable.");
      const mission = snap.data()!;
      const status = String(mission.status);
      if (!ADMIN_CANCELLABLE_STATUSES.includes(status)) {
        throw failedPrecondition(
          status === MissionStatuses.CANCELLED
            ? "Cette mission est déjà annulée."
            : "Cette mission est terminée : utilisez un remboursement dans Finances."
        );
      }
      const offers = await tx.get(db.collection("delivery_offers").where("mission_id", "==", missionId));
      const driverId = typeof mission.driver_id === "string" && mission.driver_id ? mission.driver_id : null;
      const driverRef = driverId ? db.collection("driver_profiles").doc(driverId) : null;
      const driverSnap = driverRef ? await tx.get(driverRef) : null;

      const now = admin.firestore.Timestamp.now();
      tx.update(missionRef, {
        status: MissionStatuses.CANCELLED,
        cancelled_at: now,
        cancelled_by: "admin",
        cancelled_by_user_id: ctx.uid,
        cancellation_reason: "admin_cancelled",
        admin_cancellation_note: reason || null,
        cancellation_fee: null,
        updated_at: now,
      });
      for (const offer of offers.docs) {
        if (offer.data().status === "pending") tx.update(offer.ref, { status: "expired", closed_at: now });
      }
      if (driverRef && driverSnap?.data()?.online_status === "on_mission") {
        tx.update(driverRef, { online_status: "online" });
      }
      writeAuditLogInTransaction(tx, {
        actorUserId: ctx.uid, actorRole: ctx.role ?? "admin", action: "mission_cancelled_by_admin",
        sourceFunction: "adminMissionActions", targetId: missionId,
        metadata: { previousStatus: status, reason: reason || null, driverId },
      });
      return { success: true, missionId, previousStatus: status };
    });
  }

  if (data.action === "delete") {
    return db.runTransaction(async (tx) => {
      const snap = await tx.get(missionRef);
      if (!snap.exists) throw notFound("Mission introuvable.");
      const mission = snap.data()!;
      const status = String(mission.status);
      if (!ADMIN_DELETABLE_STATUSES.includes(status)) {
        throw failedPrecondition("Annulez d'abord la mission : seule une mission terminée peut être effacée.");
      }
      if (mission.admin_archived === true) return { success: true, missionId, alreadyDeleted: true };
      const now = admin.firestore.Timestamp.now();
      tx.update(missionRef, { admin_archived: true, admin_archived_at: now, admin_archived_by: ctx.uid });
      writeAuditLogInTransaction(tx, {
        actorUserId: ctx.uid, actorRole: ctx.role ?? "admin", action: "mission_archived_by_admin",
        sourceFunction: "adminMissionActions", targetId: missionId,
        metadata: { status },
      });
      return { success: true, missionId };
    });
  }

  throw invalidArgument("Action inconnue.");
});
