// GAP-S-02 — A late authorization must not leave a hold on a cancelled mission.
// A Firestore event is durable across a callable crash after its payment
// transaction commits. Provider actions remain outside Firestore transactions.
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { db } from "../lib/admin";
import { MissionStatuses, PaymentStatuses } from "../lib/types";
import { cancelMissionPaymentAuthorization } from "../payment/paymentOrchestration";
import { STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET } from "../lib/secrets";

export const onPaymentAuthorizedAfterMissionCancel = onDocumentUpdated(
  {
    document: "payments/{paymentId}",
    secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET],
    retry: true,
  },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!after || after.status !== PaymentStatuses.AUTHORIZED) return;
    if (before?.status === PaymentStatuses.AUTHORIZED) return;

    const paymentId = event.params.paymentId;
    const missionId = after.mission_id;
    if (typeof missionId !== "string" || !missionId) {
      throw new Error("Authorized payment has no valid mission ID.");
    }

    const mission = await db.collection("delivery_requests").doc(missionId).get();
    if (!mission.exists) {
      throw new Error("Authorized payment mission is missing.");
    }
    const data = mission.data()!;
    if (data.status !== MissionStatuses.CANCELLED) return;
    if (data.active_payment_id !== paymentId) {
      throw new Error("Cancelled mission payment reference does not match.");
    }

    const outcome = await cancelMissionPaymentAuthorization(missionId, paymentId);
    if (!outcome.success || outcome.skipped) {
      // Fail the event so Firebase can retry the same idempotent cancellation.
      throw new Error("Late payment cancellation compensation was not confirmed.");
    }
  }
);
