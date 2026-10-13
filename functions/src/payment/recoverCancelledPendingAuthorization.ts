// GAP-S-02: compensate a cancelled mission whose payment remained pending
// because a callable crashed after the provider authorized the PaymentIntent.
// No provider I/O is performed inside Firestore transactions.
import { admin, db } from "../lib/admin";
import { assertValidPaymentTransition } from "../lib/paymentStateMachine";
import { MissionStatuses, PaymentDoc, PaymentStatuses } from "../lib/types";
import { assertStripeReferenceEnvironmentConsistencyOrLog } from "../lib/stripeEnvironment";
import { resolveCorrelationId, startFinancialOperationTimer } from "../lib/observability";
import { getPaymentProvider } from "./paymentProviderFactory";
import { cancelMissionPaymentAuthorization } from "./paymentOrchestration";

export type PendingRecoveryResult =
  | "cancelled"
  | "already_cancelled"
  | "not_applicable"
  | "needs_manual_review";

export async function recoverCancelledPendingAuthorization(
  paymentId: string
): Promise<PendingRecoveryResult> {
  const payRef = db.collection("payments").doc(paymentId);
  const initial = await payRef.get();
  if (!initial.exists) return "not_applicable";
  const payment = initial.data() as PaymentDoc;
  if (payment.status === PaymentStatuses.CANCELLED) return "already_cancelled";
  if (payment.status !== PaymentStatuses.AUTHORIZATION_PENDING) return "not_applicable";

  const missionRef = db.collection("delivery_requests").doc(payment.mission_id);
  const missionSnap = await missionRef.get();
  if (!missionSnap.exists) throw new Error("Recovery mission is missing.");
  const mission = missionSnap.data()!;
  if (mission.status !== MissionStatuses.CANCELLED) return "not_applicable";
  if (mission.active_payment_id !== paymentId) {
    throw new Error("Recovery payment/mission reference mismatch.");
  }
  const providerId = payment.provider_payment_intent_id;
  if (!providerId) {
    // createPayment has confirm:false; without a stored reference we cannot
    // safely infer a PaymentIntent or perform any provider-side operation.
    return "needs_manual_review";
  }
  const provider = getPaymentProvider();
  const correlationId = resolveCorrelationId(undefined);
  assertStripeReferenceEnvironmentConsistencyOrLog({
    activeEnvironment: provider.environment,
    storedEnvironment: payment.stripe_environment ?? null,
    operation: "recover_cancelled_pending_authorization",
    operationStartedAt: startFinancialOperationTimer(),
    correlationId,
    identifiers: { missionId: payment.mission_id, paymentId },
    refType: `payments/${paymentId}`,
  });
  const status = await provider.getPaymentStatus(providerId);
  if (status.status === "canceled") {
    return db.runTransaction(async (tx): Promise<PendingRecoveryResult> => {
      const [currentPay, currentMission] = await Promise.all([
        tx.get(payRef), tx.get(missionRef),
      ]);
      const current = currentPay.data() as PaymentDoc | undefined;
      if (current?.status === PaymentStatuses.CANCELLED) return "already_cancelled";
      if (current?.status !== PaymentStatuses.AUTHORIZATION_PENDING ||
          current.provider_payment_intent_id !== providerId ||
          currentMission.data()?.status !== MissionStatuses.CANCELLED ||
          currentMission.data()?.active_payment_id !== paymentId) {
        throw new Error("Recovery state changed while finalizing cancellation.");
      }
      assertValidPaymentTransition(current.status, PaymentStatuses.CANCELLED);
      tx.update(payRef, {
        status: PaymentStatuses.CANCELLED,
        cancelled_at: admin.firestore.Timestamp.now(),
        updated_at: admin.firestore.Timestamp.now(),
      });
      tx.update(missionRef, { payment_status: PaymentStatuses.CANCELLED });
      return "cancelled";
    });
  }
  if (status.status !== "requires_capture") {
    // Never infer an authorized hold from an ambiguous, captured, or failed
    // provider status. Those require a separate policy/human investigation.
    return "needs_manual_review";
  }
  if (
    status.amountAuthorizedMinor !== payment.amount_requested_minor ||
    status.amountCapturedMinor !== 0 ||
    !Number.isSafeInteger(payment.amount_requested_minor) ||
    payment.amount_requested_minor <= 0
  ) {
    throw new Error("Recovery provider amount or capture state mismatch.");
  }

  // Bridge the existing valid pending -> authorized transition, then use
  // the existing idempotent provider cancellation. A crash after this commit
  // is also covered by onPaymentAuthorizedAfterMissionCancel.
  const transition = await db.runTransaction(async (tx): Promise<"authorized" | "already"> => {
    const [currentPay, currentMission] = await Promise.all([
      tx.get(payRef), tx.get(missionRef),
    ]);
    const current = currentPay.data() as PaymentDoc | undefined;
    if (current?.status === PaymentStatuses.CANCELLED) return "already";
    if (current?.status !== PaymentStatuses.AUTHORIZATION_PENDING ||
        current.provider_payment_intent_id !== providerId ||
        currentMission.data()?.status !== MissionStatuses.CANCELLED ||
        currentMission.data()?.active_payment_id !== paymentId) {
      throw new Error("Recovery state changed before authorization reconciliation.");
    }
    assertValidPaymentTransition(current.status, PaymentStatuses.AUTHORIZED);
    tx.update(payRef, {
      status: PaymentStatuses.AUTHORIZED,
      amount_authorized_minor: payment.amount_requested_minor,
      authorized_at: admin.firestore.Timestamp.now(),
      updated_at: admin.firestore.Timestamp.now(),
    });
    return "authorized";
  });
  if (transition === "already") return "already_cancelled";
  const cancelled = await cancelMissionPaymentAuthorization(payment.mission_id, paymentId);
  if (!cancelled.success || cancelled.skipped) {
    throw new Error("Cancelled mission authorization compensation failed.");
  }
  return "cancelled";
}
