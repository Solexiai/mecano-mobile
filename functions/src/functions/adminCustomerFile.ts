// -----------------------------------------------------------------------------
// adminCustomerFile.ts — fiche client du service client (Daniel, 2026-11-10,
// phase 1).
//
//   - getAdminCustomerFile (analyste et plus) : tout ce qu'un agent doit voir
//     en 30 secondes — compte, chiffres clés, pastilles, livraisons, prix
//     calculés sans réservation, paiements, courriels et notifications,
//     conditions acceptées, notes internes, actions du personnel. Un
//     analyste ne voit ni le téléphone complet ni les adresses (ville
//     seulement). Chaque consultation est journalisée (Loi 25).
//   - addCustomerNote / setCustomerNotePinned (admin et plus) : notes
//     internes, jamais visibles par le client.
//   - resendCustomerEmail (admin et plus) : renvoyer la confirmation de
//     réservation ou le reçu Stripe d'un paiement.
//
// Lecture seulement côté paiements : rien ici ne rembourse, ne capture ni ne
// modifie un tarif. Collection `customer_notes` fermée aux clients
// (firestore.rules : refus par défaut).
// -----------------------------------------------------------------------------

import { HttpsError, onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { writeAuditLog } from "../lib/audit";
import {
  AuthContext,
  isAdminOrAbove,
  requireAdminOrAbove,
  requireAnalystOrAbove,
  requireSignedIn,
} from "../lib/auth";
import { paymentReceiptEmail } from "../lib/bookingEmails";
import {
  byNewest,
  customerBadges,
  isoOf,
  maskPhone,
  millisOf,
  missionRow,
  paymentRow,
  quoteRow,
  summarizeCustomer,
} from "../lib/customerFile";
import { failedPrecondition, invalidArgument, notFound, permissionDenied } from "../lib/errors";
import { RESEND_API_KEY, STRIPE_SECRET_KEY } from "../lib/secrets";
import { accountEmail, normalizeEmailLocale, sendTransactionalEmail } from "../lib/transactionalEmail";
import { getPaymentProvider } from "../payment/paymentProviderFactory";
import { customerContact, sendBookingConfirmation } from "./bookingNotifications";

type Doc = Record<string, any>;

function docId(raw: unknown, label: string): string {
  if (typeof raw !== "string" || !raw || raw.length > 128 || raw.includes("/")) {
    throw invalidArgument(`${label} invalide.`);
  }
  return raw;
}

function roleOf(ctx: AuthContext): string {
  return ctx.role ?? ctx.roles[0] ?? "staff";
}

const PAID = ["captured", "partially_refunded", "refunded"];

export const getAdminCustomerFile = onCall(async (request) => {
  const ctx = requireSignedIn(request);
  requireAnalystOrAbove(ctx);
  const userId = docId(request.data?.userId, "Identifiant client");
  const canAct = isAdminOrAbove(ctx);
  const cityOnly = !canAct;

  const [
    authUser, userSnap, profileSnap, missionsSnap, paymentsSnap, ratingsSnap,
    quotesSnap, emailsSnap, notifSnap, notesSnap, auditSnap,
  ] = await Promise.all([
    admin.auth().getUser(userId).catch(() => null),
    db.collection("users").doc(userId).get(),
    db.collection("payment_profiles").doc(userId).get(),
    db.collection("delivery_requests").where("customer_id", "==", userId).limit(201).get(),
    db.collection("payments").where("customer_id", "==", userId).limit(301).get(),
    db.collection("ratings").where("rater_id", "==", userId).limit(201).get(),
    db.collection("delivery_quotes").where("customer_id", "==", userId).limit(201).get(),
    db.collection("email_log").where("user_id", "==", userId).limit(101).get(),
    db.collection("users").doc(userId).collection("notifications").orderBy("created_at", "desc").limit(30).get(),
    db.collection("customer_notes").where("user_id", "==", userId).limit(200).get(),
    db.collection("audit_logs").where("target_id", "==", userId).limit(150).get(),
  ]);
  if (!authUser && !userSnap.exists) throw notFound("Compte introuvable.");

  const user = userSnap.data() ?? {};
  const missions = missionsSnap.docs.map((d) => ({ id: d.id, data: d.data() }));
  const payments = paymentsSnap.docs.map((d) => ({ id: d.id, data: d.data() }));
  const ratings = ratingsSnap.docs.map((d) => d.data()).filter((r) => r.rater_role === "customer");
  const openQuotes = quotesSnap.docs.filter((d) => d.data().is_consumed !== true);

  const stats = summarizeCustomer({
    missions: missions.map((m) => m.data),
    payments: payments.map((p) => p.data),
    ratings,
    quotesNotBooked: openQuotes.length,
  });
  const createdAt = authUser?.metadata.creationTime ?? null;
  const createdAtMs = createdAt ? Date.parse(createdAt) : millisOf(user.created_at);

  const missionRows = byNewest<ReturnType<typeof missionRow>>(missions.map((m) => missionRow(m.id, m.data, cityOnly)));
  // Conditions acceptées et langue : documents privés des 10 dernières réservations.
  const consents: Array<{
    missionId: string; termsVersion: string | null; acceptedAt: string | null; locale: string | null; marketing: boolean;
  }> = [];
  for (const row of missionRows.slice(0, 10)) {
    const booking = (await db.collection("delivery_requests").doc(row.id).collection("private").doc("booking").get()).data();
    if (!booking?.consent) continue;
    consents.push({
      missionId: row.id,
      termsVersion: typeof booking.consent.terms_version === "string" ? booking.consent.terms_version : null,
      acceptedAt: isoOf(booking.consent.accepted_at),
      locale: typeof booking.consent.locale === "string" ? booking.consent.locale : null,
      marketing: booking.marketing_preference?.opt_in === true,
    });
  }

  const phone = user.booking_contacts?.pickup_phone;
  await writeAuditLog({
    actorUserId: ctx.uid,
    actorRole: roleOf(ctx),
    action: "customer_file_viewed",
    sourceFunction: "getAdminCustomerFile",
    targetId: userId,
  });

  return {
    generatedAt: new Date().toISOString(),
    canAct,
    masked: cityOnly,
    truncated: missionsSnap.size > 200 || paymentsSnap.size > 300,
    account: {
      userId,
      fullName: typeof user.full_name === "string" ? user.full_name : authUser?.displayName ?? null,
      email: authUser?.email ?? (typeof user.email === "string" ? user.email : null),
      emailVerified: authUser?.emailVerified === true,
      disabled: authUser?.disabled === true,
      createdAt: createdAtMs ? new Date(createdAtMs).toISOString() : null,
      lastSignInAt: authUser?.metadata.lastSignInTime ? new Date(authUser.metadata.lastSignInTime).toISOString() : null,
      phone: typeof phone === "string" && phone.trim() ? (cityOnly ? maskPhone(phone) : phone.trim()) : null,
      locale: consents[0]?.locale ?? null,
      cardOnFile: typeof profileSnap.data()?.default_payment_method_id === "string",
    },
    stats,
    badges: customerBadges(stats, createdAtMs),
    missions: missionRows.slice(0, 100),
    quotes: byNewest(openQuotes.map((d) => quoteRow(d.id, d.data(), cityOnly))).slice(0, 20),
    payments: byNewest(payments.map((p) => paymentRow(p.id, p.data))).slice(0, 150),
    emails: byNewest(emailsSnap.docs.map((d) => {
      const e = d.data();
      return {
        kind: String(e.kind ?? ""),
        status: String(e.status ?? ""),
        missionId: typeof e.mission_id === "string" ? e.mission_id : null,
        createdAt: isoOf(e.created_at),
        sentAt: isoOf(e.sent_at),
      };
    })).slice(0, 50),
    notifications: notifSnap.docs.map((d) => {
      const n = d.data();
      return {
        type: String(n.type ?? ""),
        titleKey: typeof n.title_key === "string" ? n.title_key : null,
        createdAt: isoOf(n.created_at),
        read: n.is_read === true,
      };
    }),
    consents,
    notes: byNewest<{ id: string; text: string; pinned: boolean; authorName: string | null; createdAt: string | null }>(
      notesSnap.docs.map((d) => {
      const n = d.data();
      return {
        id: d.id,
        text: String(n.text ?? ""),
        pinned: n.pinned === true,
        authorName: typeof n.author_name === "string" ? n.author_name : null,
        createdAt: isoOf(n.created_at),
      };
    })).sort((a, b) => Number(b.pinned) - Number(a.pinned)),
    staffActions: byNewest(auditSnap.docs
      .map((d) => d.data())
      .filter((a) => a.action !== "customer_file_viewed")
      .map((a) => ({
        action: String(a.action ?? ""),
        actorUserId: typeof a.actor_user_id === "string" ? a.actor_user_id : null,
        createdAt: isoOf(a.created_at),
      }))).slice(0, 30),
  };
});

async function staffName(ctx: AuthContext): Promise<string> {
  const me = (await db.collection("users").doc(ctx.uid).get()).data();
  return typeof me?.full_name === "string" && me.full_name.trim() ? me.full_name.trim() : ctx.email ?? ctx.uid;
}

export const addCustomerNote = onCall(async (request) => {
  const ctx = requireSignedIn(request);
  requireAdminOrAbove(ctx);
  const userId = docId(request.data?.userId, "Identifiant client");
  const text = typeof request.data?.text === "string" ? request.data.text.trim() : "";
  if (!text || text.length > 1000) throw invalidArgument("La note doit faire entre 1 et 1000 caractères.");
  const ref = db.collection("customer_notes").doc();
  await ref.set({
    id: ref.id,
    user_id: userId,
    text,
    pinned: request.data?.pinned === true,
    author_uid: ctx.uid,
    author_name: await staffName(ctx),
    created_at: admin.firestore.Timestamp.now(),
  });
  await writeAuditLog({
    actorUserId: ctx.uid, actorRole: roleOf(ctx), action: "customer_note_added",
    sourceFunction: "addCustomerNote", targetId: userId, metadata: { noteId: ref.id },
  });
  return { id: ref.id };
});

export const setCustomerNotePinned = onCall(async (request) => {
  const ctx = requireSignedIn(request);
  requireAdminOrAbove(ctx);
  const noteId = docId(request.data?.noteId, "Note");
  const ref = db.collection("customer_notes").doc(noteId);
  const note = (await ref.get()).data();
  if (!note) throw notFound("Note introuvable.");
  const pinned = request.data?.pinned === true;
  await ref.update({ pinned, updated_at: admin.firestore.Timestamp.now() });
  await writeAuditLog({
    actorUserId: ctx.uid, actorRole: roleOf(ctx), action: pinned ? "customer_note_pinned" : "customer_note_unpinned",
    sourceFunction: "setCustomerNotePinned", targetId: String(note.user_id ?? ""), metadata: { noteId },
  });
  return { pinned };
});

export const resendCustomerEmail = onCall({ secrets: [STRIPE_SECRET_KEY, RESEND_API_KEY] }, async (request) => {
  const ctx = requireSignedIn(request);
  requireAdminOrAbove(ctx);
  const userId = docId(request.data?.userId, "Identifiant client");
  const kind = request.data?.kind;
  const stamp = `resend_${Date.now()}`;
  let outcome: string;
  let target: Record<string, unknown>;

  if (kind === "booking_confirmed") {
    const missionId = docId(request.data?.missionId, "Livraison");
    const mission = (await db.collection("delivery_requests").doc(missionId).get()).data();
    if (!mission) throw notFound("Livraison introuvable.");
    if (mission.customer_id !== userId) throw permissionDenied("Cette livraison n'est pas à ce client.");
    outcome = await sendBookingConfirmation(missionId, mission, stamp);
    if (outcome === "skipped") throw failedPrecondition("Aucune confirmation pour une livraison de test interne.");
    target = { missionId };
  } else if (kind === "payment_receipt") {
    const paymentId = docId(request.data?.paymentId, "Paiement");
    const payment = (await db.collection("payments").doc(paymentId).get()).data() as Doc | undefined;
    if (!payment) throw notFound("Paiement introuvable.");
    if (payment.customer_id !== userId) throw permissionDenied("Ce paiement n'est pas à ce client.");
    if (!PAID.includes(payment.status) || typeof payment.provider_charge_id !== "string") {
      throw failedPrecondition("Aucun reçu : ce paiement n'a pas été encaissé.");
    }
    const provider = getPaymentProvider();
    if (payment.stripe_environment && payment.stripe_environment !== provider.environment) {
      throw failedPrecondition("Ce paiement appartient à un autre environnement Stripe.");
    }
    const receiptUrl = await provider.getChargeReceiptUrl(payment.provider_charge_id);
    if (!receiptUrl) throw failedPrecondition("Stripe n'a pas de reçu pour ce paiement.");
    const missionId = typeof payment.mission_id === "string" ? payment.mission_id : null;
    const mission = missionId ? (await db.collection("delivery_requests").doc(missionId).get()).data() : undefined;
    const contact = mission && missionId
      ? await customerContact(missionId, mission)
      : { email: await accountEmail(userId), locale: normalizeEmailLocale(null) };
    outcome = await sendTransactionalEmail({
      key: `payment_receipt__${paymentId}__${stamp}`,
      kind: "payment_receipt_resend",
      userId,
      missionId,
      to: contact.email,
      build: () => paymentReceiptEmail({
        missionId,
        amountMinor: Math.max(0, (payment.amount_captured_minor ?? 0) - (payment.amount_refunded_minor ?? 0)),
        paidAtMs: millisOf(payment.captured_at),
        receiptUrl,
        locale: contact.locale,
      }),
    });
    target = { paymentId };
  } else {
    throw invalidArgument("Type de courriel inconnu.");
  }

  await writeAuditLog({
    actorUserId: ctx.uid, actorRole: roleOf(ctx), action: "customer_email_resent",
    sourceFunction: "resendCustomerEmail", targetId: userId, metadata: { kind, outcome, ...target },
  });
  if (outcome === "failed") throw new HttpsError("unavailable", "L'envoi a échoué. Réessayez dans un instant.");
  return { outcome };
});
