// -----------------------------------------------------------------------------
// scheduledPaymentHold.ts — blocage du solde à J-4 pour les réservations
// lointaines (décision Daniel, 2026-11-06 ; voir plan-depot-reservation-30-jours).
//
// Une autorisation de carte Stripe expire après ~7 jours (Visa ~5). Pour une
// réservation jusqu'à 30 jours à l'avance, le blocage du solde n'est donc
// pas posé à l'acceptation du chauffeur mais 4 jours avant le ramassage :
//   - acceptDelivery : si le ramassage est à plus de 4 jours, la mission
//     reçoit `scheduled_hold` (échéance = ramassage − 4 jours) et aucun
//     paiement n'est créé tout de suite ;
//   - la tâche planifiée (processScheduledPaymentHolds, toutes les heures)
//     pose le blocage à l'échéance avec la logique habituelle
//     (createAndAuthorizeMissionPayment, keepMissionOnFailure) ;
//   - refus : le client est averti (notification + push), nouvelle tentative
//     chaque jour ; si rien n'est corrigé la veille du ramassage, la mission
//     est annulée par Movi-K et le dépôt est gardé (le client a été averti).
// Le dépôt de 25 $ a déjà été encaissé à la réservation (bookingDeposit.ts).
// -----------------------------------------------------------------------------

import { admin, db } from "./admin";
import { writeAuditLogInTransaction } from "./audit";
import { keepDepositInTransaction } from "./bookingDeposit";
import { missionPickupAtMs } from "./missionFees";
import { MissionStatuses, PaymentStatuses } from "./types";
import { createAndAuthorizeMissionPayment } from "../payment/paymentOrchestration";

export const SCHEDULED_HOLD_POLICY = Object.freeze({
  version: "MOVIK-HOLD-20261106-001",
  /** Blocage posé 4 jours avant le ramassage. */
  lead_ms: 4 * 24 * 60 * 60 * 1000,
  /** Nouvelle tentative chaque jour après un refus. */
  retry_ms: 24 * 60 * 60 * 1000,
  /** Annulation si la carte refuse encore à moins de 24 h du ramassage. */
  cancel_within_ms: 24 * 60 * 60 * 1000,
});

/** Valeur de `payment_status` d'une mission dont le blocage est à venir. */
export const PAYMENT_STATUS_HOLD_SCHEDULED = "hold_scheduled";

export interface ScheduledHoldDoc {
  policy_version: string;
  status: "scheduled" | "failed" | "placed" | "cancelled";
  pickup_at: FirebaseFirestore.Timestamp;
  due_at: FirebaseFirestore.Timestamp;
  /** Prochaine tentative ; null quand plus rien n'est à faire (placé / annulé). */
  next_attempt_at: FirebaseFirestore.Timestamp | null;
  attempts: number;
  last_failure_code?: string | null;
  last_failure_message?: string | null;
  last_attempt_at?: FirebaseFirestore.Timestamp | null;
  placed_payment_id?: string | null;
  created_at: FirebaseFirestore.Timestamp;
  updated_at: FirebaseFirestore.Timestamp;
}

/** Heure de ramassage à retenir pour le blocage : créneau réservé, sinon heure demandée. */
export function holdPickupAtMs(mission: Record<string, any>, reservedPickupIso?: string | null): number | null {
  if (typeof reservedPickupIso === "string") {
    const ms = Date.parse(reservedPickupIso);
    if (Number.isFinite(ms)) return ms;
  }
  return missionPickupAtMs(mission);
}

/** Vrai quand le blocage doit attendre J-4 plutôt que l'acceptation. */
export function shouldScheduleHold(pickupAtMs: number | null, nowMs = Date.now()): boolean {
  return pickupAtMs !== null && pickupAtMs - nowMs > SCHEDULED_HOLD_POLICY.lead_ms;
}

export function buildScheduledHold(pickupAtMs: number, now: admin.firestore.Timestamp): ScheduledHoldDoc {
  const due = admin.firestore.Timestamp.fromMillis(pickupAtMs - SCHEDULED_HOLD_POLICY.lead_ms);
  return {
    policy_version: SCHEDULED_HOLD_POLICY.version,
    status: "scheduled",
    pickup_at: admin.firestore.Timestamp.fromMillis(pickupAtMs),
    due_at: due,
    next_attempt_at: due,
    attempts: 0,
    last_failure_code: null,
    last_failure_message: null,
    last_attempt_at: null,
    placed_payment_id: null,
    created_at: now,
    updated_at: now,
  };
}

const ACTIVE_STATUSES: ReadonlySet<string> = new Set([
  MissionStatuses.ASSIGNED,
  MissionStatuses.DRIVER_TO_PICKUP,
  MissionStatuses.ARRIVED_AT_PICKUP,
]);

export type ScheduledHoldResult = "placed" | "retry_scheduled" | "cancelled" | "skipped";

/**
 * Pose le blocage d'une mission dont l'échéance est atteinte. Idempotent :
 * une mission déjà bloquée, annulée ou terminée est ignorée.
 */
export async function placeScheduledHold(missionId: string, nowMs = Date.now()): Promise<ScheduledHoldResult> {
  const missionRef = db.collection("delivery_requests").doc(missionId);
  const mission = (await missionRef.get()).data();
  const hold = mission?.scheduled_hold as ScheduledHoldDoc | undefined;
  if (!mission || !hold || (hold.status !== "scheduled" && hold.status !== "failed")) return "skipped";
  if (!ACTIVE_STATUSES.has(String(mission.status)) || typeof mission.driver_id !== "string" || !mission.driver_id) {
    await missionRef.update({ "scheduled_hold.status": "cancelled", "scheduled_hold.next_attempt_at": null,
      "scheduled_hold.updated_at": admin.firestore.Timestamp.now() });
    return "skipped";
  }
  if (mission.payment_status === PaymentStatuses.AUTHORIZED || mission.payment_status === PaymentStatuses.CAPTURED) {
    await missionRef.update({ "scheduled_hold.status": "placed", "scheduled_hold.next_attempt_at": null,
      "scheduled_hold.updated_at": admin.firestore.Timestamp.now() });
    return "skipped";
  }
  if (!mission.active_quote_id || !mission.active_financial_snapshot_id) return "skipped";

  const outcome = await createAndAuthorizeMissionPayment({
    missionId,
    customerId: mission.customer_id as string,
    driverId: mission.driver_id as string,
    quoteId: mission.active_quote_id as string,
    financialSnapshotId: mission.active_financial_snapshot_id as string,
    keepMissionOnFailure: true,
  });

  const now = admin.firestore.Timestamp.now();
  if (outcome.success) {
    await missionRef.update({
      "scheduled_hold.status": "placed",
      "scheduled_hold.next_attempt_at": null,
      "scheduled_hold.placed_payment_id": outcome.paymentId,
      "scheduled_hold.attempts": (hold.attempts ?? 0) + 1,
      "scheduled_hold.last_attempt_at": now,
      "scheduled_hold.updated_at": now,
    });
    return "placed";
  }
  if (outcome.status === PaymentStatuses.CANCELLED) return "skipped";

  const pickupMs = hold.pickup_at?.toMillis?.() ?? holdPickupAtMs(mission) ?? nowMs;
  const cancelNow = pickupMs - nowMs <= SCHEDULED_HOLD_POLICY.cancel_within_ms;
  await db.runTransaction(async (tx) => {
    const current = (await tx.get(missionRef)).data();
    if (!current || current.status === MissionStatuses.CANCELLED) return;
    const attempts = (current.scheduled_hold?.attempts ?? 0) + 1;
    if (cancelNow) {
      // Le client a été averti à chaque refus ; le dépôt reste acquis.
      if (current.deposit?.status === "captured") keepDepositInTransaction(tx, missionRef, now, "payment_hold_failed");
      tx.update(missionRef, {
        status: MissionStatuses.CANCELLED,
        cancelled_at: now,
        cancelled_by: "system",
        cancellation_reason: "payment_hold_failed",
        cancellation_fee: null,
        "scheduled_hold.status": "cancelled",
        "scheduled_hold.next_attempt_at": null,
        "scheduled_hold.attempts": attempts,
        "scheduled_hold.last_attempt_at": now,
        "scheduled_hold.last_failure_code": outcome.status,
        "scheduled_hold.last_failure_message": outcome.failureMessage ?? null,
        "scheduled_hold.updated_at": now,
      });
      // Le chauffeur apprend l'annulation dans sa cloche (le client reçoit
      // la sienne par onMissionStatusChangeNotifyCustomer).
      if (typeof current.driver_id === "string" && current.driver_id) {
        const notifRef = db.collection("users").doc(current.driver_id).collection("notifications").doc();
        tx.set(notifRef, {
          id: notifRef.id,
          type: "mission_cancelled_payment",
          title_key: "notif_driver_mission_cancelled_payment_title",
          body_key: "notif_driver_mission_cancelled_payment_body",
          is_read: false,
          created_at: now,
          related_mission_id: missionId,
          metadata: {},
        });
      }
      writeAuditLogInTransaction(tx, {
        actorUserId: "system", actorRole: "system", action: "mission_cancelled_payment_hold_failed",
        sourceFunction: "placeScheduledHold", targetId: missionId,
        metadata: { attempts, failureCode: outcome.status, driverId: current.driver_id ?? null },
      });
      return;
    }
    tx.update(missionRef, {
      "scheduled_hold.status": "failed",
      "scheduled_hold.next_attempt_at": admin.firestore.Timestamp.fromMillis(nowMs + SCHEDULED_HOLD_POLICY.retry_ms),
      "scheduled_hold.attempts": attempts,
      "scheduled_hold.last_attempt_at": now,
      "scheduled_hold.last_failure_code": outcome.status,
      "scheduled_hold.last_failure_message": outcome.failureMessage ?? null,
      "scheduled_hold.updated_at": now,
    });
    writeAuditLogInTransaction(tx, {
      actorUserId: "system", actorRole: "system", action: "payment_hold_refused_retry_scheduled",
      sourceFunction: "placeScheduledHold", targetId: missionId,
      metadata: { attempts, failureCode: outcome.status },
    });
  });
  return cancelNow ? "cancelled" : "retry_scheduled";
}

export interface ScheduledHoldBatchResult {
  examined: number;
  placed: number;
  retried: number;
  cancelled: number;
  skipped: number;
  errors: number;
}

/** Toutes les missions dont l'échéance de blocage est atteinte. */
export async function processScheduledPaymentHolds(nowMs = Date.now()): Promise<ScheduledHoldBatchResult> {
  const result: ScheduledHoldBatchResult = { examined: 0, placed: 0, retried: 0, cancelled: 0, skipped: 0, errors: 0 };
  const due = await db.collection("delivery_requests")
    .where("scheduled_hold.next_attempt_at", "<=", admin.firestore.Timestamp.fromMillis(nowMs))
    .limit(100)
    .get();
  for (const doc of due.docs) {
    result.examined += 1;
    try {
      const r = await placeScheduledHold(doc.id, nowMs);
      if (r === "placed") result.placed += 1;
      else if (r === "retry_scheduled") result.retried += 1;
      else if (r === "cancelled") result.cancelled += 1;
      else result.skipped += 1;
    } catch (error) {
      result.errors += 1;
      console.error("[scheduled-hold]", doc.id, error instanceof Error ? error.message : error);
    }
  }
  return result;
}
