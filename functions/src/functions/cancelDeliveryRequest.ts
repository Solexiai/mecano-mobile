// -----------------------------------------------------------------------------
// cancelDeliveryRequest — customer cancellation with the fee policy of
// 2026-10-22 (lib/missionFees.ts).
//
// Two calls from the app:
//   1. { missionId, dryRun: true }  -> the fee that would apply (0 if free);
//   2. { missionId, acceptedFeeMinor } -> cancels. When a fee applies, the
//      customer must have been shown THAT exact amount: if the fee changed in
//      between (e.g. the 2-hour limit passed), the call is refused and the app
//      shows the new amount.
// The fee itself is collected by onMissionEndedClearTracking ->
// chargeMissionFee (partial capture of the existing card hold). Without a fee,
// the same trigger releases the hold, as before.
// Once a driver has accepted, the customer can no longer cancel by writing
// Firestore directly (firestore.rules): this function is the only path.
// -----------------------------------------------------------------------------

import { HttpsError, onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { writeAuditLogInTransaction } from "../lib/audit";
import { requireSignedIn } from "../lib/auth";
import { failedPrecondition, invalidArgument, notFound, permissionDenied } from "../lib/errors";
import {
  CUSTOMER_CANCELLABLE_STATUSES,
  isLateCancellation,
  DEFAULT_MISSION_FEE_POLICY,
  MissionFeePolicy,
  missionFeePolicyFrom,
  missionFeeAmounts,
  MissionFeeAmounts,
} from "../lib/missionFees";
import { MissionStatuses, PaymentStatuses } from "../lib/types";

export interface CancelDeliveryRequestInput {
  missionId: string;
  dryRun?: boolean;
  acceptedFeeMinor?: number;
}

function parseInput(data: unknown): CancelDeliveryRequestInput {
  const d = (data ?? {}) as Record<string, unknown>;
  if (typeof d.missionId !== "string" || !d.missionId || d.missionId.length > 128 || d.missionId.includes("/")) {
    throw invalidArgument("Demande invalide.");
  }
  if (d.dryRun !== undefined && typeof d.dryRun !== "boolean") throw invalidArgument("Demande invalide.");
  if (d.acceptedFeeMinor !== undefined &&
      (!Number.isSafeInteger(d.acceptedFeeMinor) || (d.acceptedFeeMinor as number) < 0)) {
    throw invalidArgument("Montant confirmé invalide.");
  }
  return { missionId: d.missionId, dryRun: d.dryRun as boolean | undefined,
    acceptedFeeMinor: d.acceptedFeeMinor as number | undefined };
}

export const cancelDeliveryRequest = onCall(async (request) => {
  const ctx = requireSignedIn(request);
  const input = parseInput(request.data);
  const missionRef = db.collection("delivery_requests").doc(input.missionId);

  return db.runTransaction(async (tx) => {
    const missionSnap = await tx.get(missionRef);
    if (!missionSnap.exists) throw notFound("Demande introuvable.");
    const mission = missionSnap.data()!;
    if (mission.customer_id !== ctx.uid) throw permissionDenied("Cette demande ne vous appartient pas.");
    if (!CUSTOMER_CANCELLABLE_STATUSES.includes(String(mission.status))) {
      throw failedPrecondition("Cette demande ne peut plus être annulée.");
    }

    const now = admin.firestore.Timestamp.now();
    let amounts: MissionFeeAmounts = missionFeeAmounts(0);
    let policy: MissionFeePolicy = DEFAULT_MISSION_FEE_POLICY;
    let paymentId: string | null = null;
    if (isLateCancellation(mission, now.toMillis()) && typeof mission.active_payment_id === "string") {
      const paySnap = await tx.get(db.collection("payments").doc(mission.active_payment_id));
      const payment = paySnap.data();
      // Only an active card hold can carry a fee; otherwise nothing can be collected.
      if (payment?.status === PaymentStatuses.AUTHORIZED && payment.mission_id === input.missionId) {
        // Amounts frozen on the card hold when the driver accepted.
        policy = missionFeePolicyFrom(payment.mission_fee_policy);
        amounts = missionFeeAmounts(payment.amount_authorized_minor as number, policy);
        paymentId = paySnap.id;
      }
    }
    const feeMinor = amounts.total_minor;

    if (input.dryRun) {
      return { missionId: input.missionId, feeMinor, feeKind: feeMinor > 0 ? "late_cancellation" : null,
        policyVersion: policy.version, cancelled: false };
    }
    if (feeMinor > 0 && input.acceptedFeeMinor !== feeMinor) {
      throw new HttpsError("failed-precondition", "Les frais d'annulation doivent être confirmés.",
        { reason: "fee_confirmation_required", fee_minor: feeMinor });
    }

    tx.update(missionRef, {
      status: MissionStatuses.CANCELLED,
      cancelled_at: now,
      cancelled_by: "customer",
      cancellation_reason: "customer_request",
      cancellation_fee: feeMinor > 0
        ? {
            kind: "late_cancellation",
            status: "pending",
            ...amounts,
            payment_id: paymentId,
            policy_version: policy.version,
            decided_at: now,
            decided_by: ctx.uid,
            updated_at: now,
          }
        : null,
    });
    writeAuditLogInTransaction(tx, {
      actorUserId: ctx.uid,
      actorRole: ctx.role ?? "customer",
      action: feeMinor > 0 ? "mission_cancelled_with_fee" : "mission_cancelled",
      sourceFunction: "cancelDeliveryRequest",
      targetId: input.missionId,
      metadata: { previousStatus: mission.status, feeMinor, policyVersion: policy.version },
    });
    return { missionId: input.missionId, feeMinor, feeKind: feeMinor > 0 ? "late_cancellation" : null,
      policyVersion: policy.version, cancelled: true };
  });
});
