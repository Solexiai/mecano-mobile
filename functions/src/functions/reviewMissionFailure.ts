import { HttpsError, onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { requireAdminOrAbove, requireSignedIn } from "../lib/auth";
import { writeAuditLogInTransaction } from "../lib/audit";
import { canConfirmMissionFailure, validateFailureReviewInput } from "../lib/missionFailureReview";

export const reviewMissionFailure = onCall(async request => {
  const ctx = requireSignedIn(request);
  requireAdminOrAbove(ctx);
  const input = validateFailureReviewInput(request.data ?? {});
  const missionRef = db.collection("delivery_requests").doc(input.missionId);
  const reviewRef = db.collection("mission_outcome_reviews").doc(input.missionId);
  return db.runTransaction(async tx => {
    const [missionSnap, reviewSnap] = await Promise.all([tx.get(missionRef), tx.get(reviewRef)]);
    if (!missionSnap.exists) throw new HttpsError("not-found", "Mission unavailable.");
    const mission = missionSnap.data()!;
    const review = reviewSnap.data();
    const revision = review?.revision ?? 0;
    if (mission.status !== input.expectedStatus || (mission.driver_id ?? null) !== input.expectedDriverId || revision !== input.expectedRevision) {
      throw new HttpsError("aborted", "The mission or review changed. Refresh before confirming.");
    }
    if (input.action === "confirm") {
      if (!canConfirmMissionFailure(mission)) {
        throw new HttpsError("failed-precondition", "This mission cannot be classified as a failed delivery.");
      }
      if (review?.confirmed === true) throw new HttpsError("already-exists", "Failure already confirmed.");
    } else if (review?.confirmed !== true) {
      throw new HttpsError("failed-precondition", "No confirmed failure to revoke.");
    }
    // Administrative finding only: never write mission status or financial data.
    tx.set(reviewRef, {
      mission_id: input.missionId,
      driver_id: input.action === "confirm" ? mission.driver_id : review!.driver_id,
      confirmed: input.action === "confirm",
      reason: input.reason,
      revision: revision + 1,
      observed_mission_status: mission.status,
      reviewed_by: ctx.uid,
      reviewed_at: admin.firestore.FieldValue.serverTimestamp(),
      responsibility: "not_determined",
      policy_version: "MOVIK-FAILURE-REVIEW-20261019-001",
    });
    writeAuditLogInTransaction(tx, {
      actorUserId: ctx.uid, actorRole: ctx.role ?? "unknown",
      action: input.action === "confirm" ? "mission_failure_confirmed" : "mission_failure_revoked",
      sourceFunction: "reviewMissionFailure", targetId: input.missionId,
      metadata: {reason: input.reason, revision: revision + 1, previousRevision: revision,
        observedStatus: mission.status, responsibility: "not_determined"},
    });
    return {success: true, revision: revision + 1};
  });
});
