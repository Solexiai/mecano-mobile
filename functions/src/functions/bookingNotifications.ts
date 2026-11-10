// -----------------------------------------------------------------------------
// bookingNotifications.ts — courriel de réservation et rappels 4 h
// (décision Daniel, 2026-11-10).
//
//   - onMissionCreatedSendConfirmation : à la création d'une mission (dépôt
//     payé), courriel « Réservation confirmée » au client.
//   - sendPickupReminders (toutes les 10 min) : 4 h avant le ramassage
//     d'une livraison acceptée, rappel au client ET au chauffeur — push,
//     cloche dans l'app et courriel. Un seul rappel par personne et par
//     livraison (`pickup_reminders/{mission}__{rôle}`).
//
// Les courriels partent seulement quand RESEND_API_KEY est configurée ; les
// push et la cloche fonctionnent dès le déploiement. Les missions de test
// interne et les livraisons « dès que possible » sont ignorées.
// -----------------------------------------------------------------------------

import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { admin, db } from "../lib/admin";
import {
  ReminderRole,
  bookingConfirmedEmail,
  isImmediateMission,
  pickupReminderEmail,
  pickupReminderPush,
  reminderDue,
} from "../lib/bookingEmails";
import { missionPickupAtMs } from "../lib/missionFees";
import { RESEND_API_KEY } from "../lib/secrets";
import {
  EmailLocale,
  EmailOutcome,
  accountEmail,
  normalizeEmailLocale,
  sendTransactionalEmail,
} from "../lib/transactionalEmail";

type Mission = Record<string, any>;

/** Statuts où un chauffeur a accepté et le ramassage n'a pas eu lieu. */
export const REMINDER_STATUSES = ["assigned", "driver_to_pickup"];

function isInternalTest(mission: Mission): boolean {
  return mission.assignment_mode === "internal_test" || mission.internal_test_authorized === true;
}

function millis(value: unknown): number | null {
  const ms = (value as { toMillis?: () => number } | null | undefined)?.toMillis?.();
  return typeof ms === "number" && Number.isFinite(ms) ? ms : null;
}

/** Courriel et langue du client, tels qu'enregistrés à la réservation. */
export async function customerContact(missionId: string, mission: Mission): Promise<{ email: string | null; locale: EmailLocale }> {
  const booking = (await db.collection("delivery_requests").doc(missionId).collection("private").doc("booking").get()).data();
  const email = typeof booking?.customer_email === "string" && booking.customer_email
    ? booking.customer_email as string
    : await accountEmail(String(mission.customer_id ?? ""));
  return { email, locale: normalizeEmailLocale(booking?.consent?.locale) };
}

/** Langue du chauffeur : celle de son appareil, sinon le français. */
async function userLocale(uid: string): Promise<EmailLocale> {
  const tokens = await db.collection("push_tokens").where("user_id", "==", uid).limit(1).get();
  return normalizeEmailLocale(tokens.docs[0]?.data().locale);
}

/**
 * « Réservation confirmée » ; un seul envoi automatique par mission. Le
 * service client peut la renvoyer (`resendKey`, fiche client 2026-11-10) :
 * chaque renvoi a sa propre clé, donc sa propre ligne de journal.
 */
export async function sendBookingConfirmation(
  missionId: string,
  given?: Mission,
  resendKey?: string
): Promise<EmailOutcome | "skipped"> {
  const mission = given ?? (await db.collection("delivery_requests").doc(missionId).get()).data();
  if (!mission || isInternalTest(mission) || typeof mission.customer_id !== "string") return "skipped";
  const { email, locale } = await customerContact(missionId, mission);
  return sendTransactionalEmail({
    key: resendKey ? `booking_confirmed__${missionId}__${resendKey}` : `booking_confirmed__${missionId}`,
    kind: resendKey ? "booking_confirmed_resend" : "booking_confirmed",
    userId: mission.customer_id,
    missionId,
    to: email,
    build: () => bookingConfirmedEmail(missionId, mission, locale),
  });
}

export const onMissionCreatedSendConfirmation = onDocumentCreated(
  { document: "delivery_requests/{missionId}", secrets: [RESEND_API_KEY] },
  async (event) => {
    await sendBookingConfirmation(event.params.missionId, event.data?.data());
  }
);

/** Push à tous les appareils de l'utilisateur, chacun dans sa langue. */
async function pushToUser(uid: string, missionId: string, role: ReminderRole, mission: Mission, pickupMs: number): Promise<void> {
  try {
    const tokens = await db.collection("push_tokens").where("user_id", "==", uid).get();
    for (const doc of tokens.docs) {
      const data = doc.data();
      if (typeof data.token !== "string" || data.token.length < 20) continue;
      const copy = pickupReminderPush(mission, role, pickupMs, normalizeEmailLocale(data.locale));
      await admin.messaging().send({
        token: data.token,
        notification: copy,
        data: { type: `pickup_reminder_${role}`, missionId },
        android: { priority: "high", notification: { sound: "default", tag: `pickup-reminder-${missionId}` } },
      }).catch(() => undefined);
    }
  } catch (error) {
    console.error("[rappel] push non envoyé", missionId, error instanceof Error ? error.message : error);
  }
}

/**
 * Rappel à une personne : réservé d'abord (une seule fois), puis cloche, push
 * et courriel. Renvoie false si ce rappel a déjà été fait.
 */
async function remind(missionId: string, mission: Mission, role: ReminderRole, uid: string, pickupMs: number): Promise<boolean> {
  const claimRef = db.collection("pickup_reminders").doc(`${missionId}__${role}`);
  const claimed = await db.runTransaction(async (tx) => {
    if ((await tx.get(claimRef)).exists) return false;
    const now = admin.firestore.Timestamp.now();
    tx.set(claimRef, { mission_id: missionId, role, user_id: uid, pickup_at_ms: pickupMs, created_at: now });
    const notifRef = db.collection("users").doc(uid).collection("notifications").doc();
    tx.set(notifRef, {
      id: notifRef.id,
      type: `pickup_reminder_${role}`,
      title_key: `notif_pickup_reminder_${role}_title`,
      body_key: `notif_pickup_reminder_${role}_body`,
      is_read: false,
      created_at: now,
      related_mission_id: missionId,
      metadata: { pickup_at_ms: pickupMs },
    });
    return true;
  });
  if (!claimed) return false;
  await pushToUser(uid, missionId, role, mission, pickupMs);
  const contact = role === "customer"
    ? await customerContact(missionId, mission)
    : { email: await accountEmail(uid), locale: await userLocale(uid) };
  await sendTransactionalEmail({
    key: `pickup_reminder_${role}__${missionId}`,
    kind: `pickup_reminder_${role}`,
    userId: uid,
    missionId,
    to: contact.email,
    build: () => pickupReminderEmail(missionId, mission, role, pickupMs, contact.locale),
  });
  return true;
}

/** Une passe du rappel 4 h (appelée par le cron et par les tests). */
export async function runPickupReminders(
  nowMs = Date.now()
): Promise<{ customer: number; driver: number; reminded: string[] }> {
  const result = { customer: 0, driver: 0, reminded: [] as string[] };
  const snap = await db.collection("delivery_requests").where("status", "in", REMINDER_STATUSES).get();
  for (const doc of snap.docs) {
    const mission = doc.data();
    if (isInternalTest(mission) || isImmediateMission(mission)) continue;
    const pickupMs = missionPickupAtMs(mission);
    try {
      if (
        typeof mission.customer_id === "string" &&
        reminderDue({ pickupMs, nowMs, committedAtMs: millis(mission.created_at) }) &&
        (await remind(doc.id, mission, "customer", mission.customer_id, pickupMs as number))
      ) {
        result.customer += 1;
        result.reminded.push(`${doc.id}__customer`);
      }
      if (
        typeof mission.driver_id === "string" && mission.driver_id &&
        reminderDue({ pickupMs, nowMs, committedAtMs: millis(mission.accepted_at) }) &&
        (await remind(doc.id, mission, "driver", mission.driver_id, pickupMs as number))
      ) {
        result.driver += 1;
        result.reminded.push(`${doc.id}__driver`);
      }
    } catch (error) {
      console.error("[rappel] livraison ignorée", doc.id, error instanceof Error ? error.message : error);
    }
  }
  return result;
}

export const sendPickupReminders = onSchedule(
  { schedule: "every 10 minutes", timeZone: "America/Toronto", secrets: [RESEND_API_KEY] },
  async () => {
    const result = await runPickupReminders();
    if (result.customer + result.driver > 0) {
      console.log("[rappel 4 h]", { customer: result.customer, driver: result.driver });
    }
  }
);
