// -----------------------------------------------------------------------------
// chargeWastedTripFee — admin only. Closes a mission whose pickup could not
// happen because of the customer (absent, item refused or not as described…)
// and charges the travel fee of the 2026-10-22 policy (lib/missionFees.ts).
//
// Safeguards:
//   - the failed delivery must first be confirmed by Movi-K
//     (reviewMissionFailure -> mission_outcome_reviews/{id}.confirmed), never
//     on the driver's word alone;
//   - only before pickup (the goods never left the customer);
//   - only with an active card hold; otherwise the case is handled manually;
//   - optimistic check on the status the admin was looking at.
// The fee is collected by onMissionEndedClearTracking -> chargeMissionFee.
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { writeAuditLogInTransaction } from "../lib/audit";
import { requireAdminOrAbove, requireSignedIn } from "../lib/auth";
import { aborted, failedPrecondition, invalidArgument, notFound } from "../lib/errors";
import { DRIVER_COMMITTED_STATUSES, MISSION_FEE_POLICY, missionFeeAmounts } from "../lib/missionFees";
import { MissionStatuses, PaymentStatuses } from "../lib/types";

export const chargeWastedTripFee = onCall(async (request) => {
  const ctx = requireSignedIn(request);
  requireAdminOrAbove(ctx);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const missionId = d.missionId, expectedStatus = d.expectedStatus, reason = d.reason;
  if (typeof missionId !== "string" || !missionId || missionId.length > 128 || missionId.includes("/") ||
      typeof expectedStatus !== "string" ||
      typeof reason !== "string" || reason.trim().length < 3 || reason.trim().length > 2000) {
    throw invalidArgument("Mission, statut attendu et motif sont requis.");
  }
  const missionRef = db.collection("delivery_requests").doc(missionId);
  const reviewRef = db.collection("mission_outcome_reviews").doc(missionId);

  return db.runTransaction(async (tx) => {
    const [missionSnap, reviewSnap] = await Promise.all([tx.get(missionRef), tx.get(reviewRef)]);
    if (!missionSnap.exists) throw notFound("Mission introuvable.");
    const mission = missionSnap.data()!;
    if (mission.status !== expectedStatus) {
      throw aborted("La mission a changé. Actualisez avant de confirmer.");
    }
    if (mission.assignment_mode === "internal_test" || typeof mission.driver_id !== "string" ||
        !DRIVER_COMMITTED_STATUSES.includes(String(mission.status))) {
      throw failedPrecondition("Frais de déplacement possibles seulement après acceptation et avant le ramassage.");
    }
    if (reviewSnap.data()?.confirmed !== true) {
      throw failedPrecondition("Confirmez d'abord l'échec de la livraison.");
    }
    const paymentId = mission.active_payment_id;
    const paySnap = typeof paymentId === "string" && paymentId
      ? await tx.get(db.collection("payments").doc(paymentId)) : null;
    const payment = paySnap?.data();
    if (!payment || payment.status !== PaymentStatuses.AUTHORIZED || payment.mission_id !== missionId) {
      throw failedPrecondition("Aucune autorisation de carte active : frais non percevables, à traiter manuellement.");
    }
    const amounts = missionFeeAmounts(payment.amount_authorized_minor as number);
    if (amounts.total_minor <= 0) throw failedPrecondition("Montant autorisé invalide.");

    const now = admin.firestore.Timestamp.now();
    tx.update(missionRef, {
      status: MissionStatuses.CANCELLED,
      cancelled_at: now,
      cancelled_by: "admin",
      cancellation_reason: "customer_failed_delivery",
      cancellation_fee: {
        kind: "customer_failed_delivery",
        status: "pending",
        ...amounts,
        payment_id: paymentId,
        policy_version: MISSION_FEE_POLICY.version,
        decided_at: now,
        decided_by: ctx.uid,
        note: reason.trim(),
        updated_at: now,
      },
    });
    writeAuditLogInTransaction(tx, {
      actorUserId: ctx.uid,
      actorRole: ctx.role ?? "admin",
      action: "mission_wasted_trip_fee",
      sourceFunction: "chargeWastedTripFee",
      targetId: missionId,
      metadata: { previousStatus: mission.status, ...amounts, policyVersion: MISSION_FEE_POLICY.version,
        reason: reason.trim() },
    });
    return { success: true, missionId, feeMinor: amounts.total_minor };
  });
});
