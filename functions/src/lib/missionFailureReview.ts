import { HttpsError } from "firebase-functions/v2/https";

const ELIGIBLE = new Set(["assigned", "driver_to_pickup", "arrived_at_pickup",
  "picked_up", "in_transit", "arrived_at_dropoff", "disputed", "refunded"]);

export function canConfirmMissionFailure(mission: Record<string, unknown>): boolean {
  return typeof mission.driver_id === "string" && !!mission.driver_id &&
    mission.assignment_mode !== "internal_test" &&
    ELIGIBLE.has(String(mission.status)) &&
    !mission.completed_at && !mission.delivered_at && !mission.proof_of_delivery_url;
}

export function validateFailureReviewInput(input: Record<string, unknown>) {
  const {missionId, action, reason, expectedStatus, expectedRevision, expectedDriverId} = input;
  if (typeof missionId !== "string" || !missionId || missionId.length > 128 || missionId.includes("/") ||
      (action !== "confirm" && action !== "revoke") ||
      typeof reason !== "string" || reason.trim().length < 3 || reason.trim().length > 2000 ||
      typeof expectedStatus !== "string" ||
      !("expectedDriverId" in input) || (expectedDriverId !== null && typeof expectedDriverId !== "string") ||
      !Number.isInteger(expectedRevision) || (expectedRevision as number) < 0 ||
      (action === "confirm" && input.deliveryNotCompleted !== true)) {
    throw new HttpsError("invalid-argument", "Mission, action, reason, revision and explicit confirmation are required.");
  }
  return {missionId, action, reason: reason.trim(), expectedStatus, expectedDriverId: expectedDriverId as string | null, expectedRevision: expectedRevision as number};
}
