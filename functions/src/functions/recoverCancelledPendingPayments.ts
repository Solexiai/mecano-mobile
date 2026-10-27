// GAP-S-02: bounded periodic repair for cancelled missions whose payments
// remained authorization_pending after a server interruption.
// This is additive; the normal payment and cancellation flows remain intact.
import { onSchedule } from "firebase-functions/v2/scheduler";
import { admin, db } from "../lib/admin";
import { MissionStatuses, PaymentDoc, PaymentStatuses } from "../lib/types";
import { recoverCancelledPendingAuthorization } from "../payment/recoverCancelledPendingAuthorization";
import { cancelMissionPaymentAuthorization } from "../payment/paymentOrchestration";
import { STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET } from "../lib/secrets";

const BATCH_LIMIT = 100;
const MIN_AGE_MILLIS = 5 * 60 * 1000;

export async function recoverCancelledPendingPaymentsBatch(
  nowMillis = Date.now()
): Promise<{ checked: number; recovered: number; manualReview: number; failed: number }> {
  // One indexed status filter avoids new composite-index requirements.
  // Never query or process an unbounded collection in a single invocation.
  const snapshot = await db.collection("payments")
    .where("status", "==", PaymentStatuses.AUTHORIZATION_PENDING)
    .limit(BATCH_LIMIT)
    .get();
  let recovered = 0;
  let manualReview = 0;
  let failed = 0;
  for (const entry of snapshot.docs) {
    const payment = entry.data() as PaymentDoc;
    const timestamp = payment.updated_at ?? payment.created_at;
    if (!(timestamp instanceof admin.firestore.Timestamp) ||
        timestamp.toMillis() > nowMillis - MIN_AGE_MILLIS) continue;
    try {
      const outcome = await recoverCancelledPendingAuthorization(entry.id);
      if (outcome === "cancelled") recovered++;
      if (outcome === "needs_manual_review") {
        manualReview++;
        console.error("[gap-s02] Manual payment recovery review needed", entry.id);
      }
    } catch (error) {
      failed++;
      console.error("[gap-s02] Payment recovery failed", entry.id,
        error instanceof Error ? error.message : String(error));
    }
  }
  return { checked: snapshot.size, recovered, manualReview, failed };
}

/**
 * PAY-10 (2026-10-27) — une mission ANNULÉE dont le paiement est resté
 * AUTHORIZED (l'appel Stripe de libération a échoué dans
 * onMissionEndedClearTracking, sans reprise) laissait les fonds bloqués sur
 * la carte du client jusqu'à expiration. Ce balayage rejoue la libération
 * idempotente (cancelMissionPaymentAuthorization) pour chaque paiement
 * AUTHORIZED dont la mission est CANCELLED.
 */
export async function releaseAuthorizationsOfCancelledMissionsBatch(
  nowMillis = Date.now()
): Promise<{ checked: number; released: number; failed: number }> {
  const snapshot = await db.collection("payments")
    .where("status", "==", PaymentStatuses.AUTHORIZED)
    .limit(BATCH_LIMIT)
    .get();
  let released = 0;
  let failed = 0;
  for (const entry of snapshot.docs) {
    const payment = entry.data() as PaymentDoc;
    const timestamp = payment.updated_at ?? payment.created_at;
    if (!(timestamp instanceof admin.firestore.Timestamp) ||
        timestamp.toMillis() > nowMillis - MIN_AGE_MILLIS) continue;
    try {
      const mission = (await db.collection("delivery_requests").doc(payment.mission_id).get()).data();
      if (!mission || mission.status !== MissionStatuses.CANCELLED || mission.active_payment_id !== entry.id) continue;
      const outcome = await cancelMissionPaymentAuthorization(payment.mission_id, entry.id);
      if (outcome.success && !outcome.skipped && !outcome.alreadyCancelled) released++;
      if (!outcome.success) {
        failed++;
        console.error("[pay-10] Authorization release still failing", entry.id, outcome.failureMessage ?? "");
      }
    } catch (error) {
      failed++;
      console.error("[pay-10] Authorization release failed", entry.id,
        error instanceof Error ? error.message : String(error));
    }
  }
  return { checked: snapshot.size, released, failed };
}

export const recoverCancelledPendingPayments = onSchedule(
  { schedule: "every 10 minutes", secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET] },
  async () => {
    const result = await recoverCancelledPendingPaymentsBatch();
    if (result.failed > 0 || result.manualReview > 0) {
      console.error("[gap-s02] Pending authorization recovery requires attention", result);
    }
    const released = await releaseAuthorizationsOfCancelledMissionsBatch();
    if (released.failed > 0) {
      console.error("[pay-10] Cancelled-mission authorization release requires attention", released);
    }
  }
);
