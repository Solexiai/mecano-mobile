// -----------------------------------------------------------------------------
// leadFollowUps.ts — relances automatiques des prospects
// (décision Daniel, 2026-11-17).
//
//   - sendLeadFollowUps (toutes les 30 min, envois de 9 h à 20 h) :
//       · client qui a obtenu un prix sans réserver : courriel le lendemain
//         (J+1), puis 3 jours après sa première demande (J+3) ;
//       · chauffeur dont l'inscription n'est pas terminée (profil, document
//         demandé, versements Stripe) : mêmes relances ; pour Stripe, un
//         courriel dès l'approbation.
//     Les relances s'arrêtent dès que la personne réserve, termine son étape
//     ou se désabonne. Jamais plus d'une série par 14 jours.
//   - emailUnsubscribe (page publique) : lien « Me désabonner » des relances.
//   - adminEmailSettings (admin) : adresse postale de Movi-K et interrupteur.
//
// Rien ne part tant que l'adresse postale n'est pas écrite
// (`system_config/email_settings`) ni sans RESEND_API_KEY. Chaque relance est
// réservée dans `lead_followups/{…}` AVANT l'envoi : jamais deux fois la même.
// Aucun changement aux prix, au dépôt, aux paiements ni aux statuts.
// -----------------------------------------------------------------------------

import { onCall, onRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { admin, db } from "../lib/admin";
import { writeAuditLog } from "../lib/audit";
import { requireAdminOrAbove, requireSignedIn } from "../lib/auth";
import {
  EMAIL_SETTINGS_DOC,
  EmailSettings,
  POSTAL_ADDRESS_MAX_LENGTH,
  emailPreference,
  followUpsReady,
  getEmailSettings,
  setFollowUpSubscription,
  unsubscribeUrl,
} from "../lib/emailPreferences";
import { grantDriverRole } from "../lib/driverRole";
import { invalidArgument } from "../lib/errors";
import { guestSeriesAllowed, leadEmailKey } from "../lib/guestLead";
import {
  DriverFollowUpStage,
  FOLLOW_UP_COOLDOWN_MS,
  FOLLOW_UP_END_MS,
  FOLLOW_UP_FIRST_MS,
  FollowUpStep,
  driverFollowUpEmail,
  followUpMillis,
  followUpStepDue,
  quoteFollowUpEmail,
  withinFollowUpSendingHours,
} from "../lib/followUpEmails";
import { RESEND_API_KEY } from "../lib/secrets";
import { accountEmail, escapeHtml, normalizeEmailLocale, sendTransactionalEmail } from "../lib/transactionalEmail";
import { DriverStatuses } from "../lib/types";

type Doc = Record<string, any>;

/** Plafond par passage : protège le quota quotidien de Resend. */
export const FOLLOW_UPS_PER_RUN = 40;
const STAFF_ROLES = ["analyst", "admin", "super_admin"];

interface Series {
  anchorId: string;
  anchorMs: number;
  sent: Partial<Record<FollowUpStep, number>>;
  stopped: boolean;
}

function readSent(raw: unknown): Partial<Record<FollowUpStep, number>> {
  const sent: Partial<Record<FollowUpStep, number>> = {};
  if (raw && typeof raw === "object") {
    for (const step of [0, 1, 2] as FollowUpStep[]) {
      const value = (raw as Doc)[String(step)];
      if (typeof value === "number") sent[step] = value;
    }
  }
  return sent;
}

/**
 * Réserve la relance `step` de cette série (une seule fois, même si deux
 * passages tournent en même temps). Renvoie false si elle est déjà prise.
 */
async function claimStep(stateId: string, base: Doc, series: Series, step: FollowUpStep, nowMs: number): Promise<boolean> {
  const ref = db.collection("lead_followups").doc(stateId);
  return db.runTransaction(async (tx) => {
    const current = (await tx.get(ref)).data();
    const sameSeries = current?.anchor_id === series.anchorId && current?.anchor_at_ms === series.anchorMs;
    const sent = sameSeries ? readSent(current?.sent) : {};
    if (sameSeries && current?.stopped_reason) return false;
    if (sent[step] !== undefined) return false;
    tx.set(ref, {
      ...base,
      anchor_id: series.anchorId,
      anchor_at_ms: series.anchorMs,
      sent: { ...sent, [String(step)]: nowMs },
      stopped_reason: null,
      updated_at: admin.firestore.Timestamp.fromMillis(nowMs),
    });
    return true;
  });
}

async function stopSeries(
  stateId: string, base: Doc, series: Series, reason: string, nowMs: number, stoppedAtMs = nowMs
): Promise<void> {
  await db.collection("lead_followups").doc(stateId).set({
    ...base,
    stopped_at_ms: stoppedAtMs,
    anchor_id: series.anchorId,
    anchor_at_ms: series.anchorMs,
    sent: { ...series.sent },
    stopped_reason: reason,
    updated_at: admin.firestore.Timestamp.fromMillis(nowMs),
  });
}

/** Langue de l'appareil de la personne, sinon le français. */
async function deviceLocale(uid: string) {
  const tokens = await db.collection("push_tokens").where("user_id", "==", uid).limit(1).get();
  return normalizeEmailLocale(tokens.docs[0]?.data().locale);
}

// ---- Clients : prix obtenu, pas de réservation --------------------------------

/** Moment de la dernière réservation du client depuis le début de la série ; null s'il n'a pas réservé. */
async function lastBookingSince(uid: string, quotes: Array<{ data: Doc; ms: number }>, anchorMs: number): Promise<number | null> {
  const times = quotes
    .filter((q) => q.ms >= anchorMs && (q.data.is_consumed === true || (typeof q.data.mission_id === "string" && q.data.mission_id)))
    .map((q) => q.ms);
  const missions = await db.collection("delivery_requests").where("customer_id", "==", uid).limit(100).get();
  for (const m of missions.docs) {
    const ms = followUpMillis(m.data().created_at);
    if (ms !== null && ms >= anchorMs) times.push(ms);
  }
  return times.length ? Math.max(...times) : null;
}

/**
 * Réserve la série de relances de cette adresse d'invité pour la session
 * `uid`. Refusée si l'adresse est celle d'un vrai compte : ce compte a ses
 * propres relances, et la personne a peut-être déjà réservé avec lui.
 */
async function claimGuestEmailSeries(email: string, uid: string, nowMs: number): Promise<boolean> {
  const owner = await admin.auth().getUserByEmail(email).catch(() => null);
  if (owner && owner.uid !== uid) return false;
  const ref = db.collection("lead_emails").doc(leadEmailKey(email));
  return db.runTransaction(async (tx) => {
    const state = (await tx.get(ref)).data();
    if (!guestSeriesAllowed(state, uid, nowMs, FOLLOW_UP_COOLDOWN_MS)) return false;
    if (state?.user_id !== uid) tx.set(ref, { user_id: uid, started_at_ms: nowMs, unsubscribed: false });
    return true;
  });
}

async function runQuoteFollowUps(settings: EmailSettings, nowMs: number, budget: { left: number }): Promise<string[]> {
  const done: string[] = [];
  const since = admin.firestore.Timestamp.fromMillis(nowMs - FOLLOW_UP_END_MS);
  const snap = await db.collection("delivery_quotes").where("created_at", ">=", since).get();
  const byCustomer = new Map<string, Array<{ id: string; data: Doc; ms: number }>>();
  for (const doc of snap.docs) {
    const data = doc.data();
    const ms = followUpMillis(data.created_at);
    if (typeof data.customer_id !== "string" || !data.customer_id || ms === null) continue;
    const list = byCustomer.get(data.customer_id) ?? [];
    list.push({ id: doc.id, data, ms });
    byCustomer.set(data.customer_id, list);
  }

  for (const [uid, quotes] of byCustomer) {
    if (budget.left <= 0) break;
    try {
      quotes.sort((a, b) => a.ms - b.ms);
      const stateId = `customer__${uid}`;
      const base = { kind: "customer_quote", user_id: uid };
      const state = (await db.collection("lead_followups").doc(stateId).get()).data();
      const stateAnchor = typeof state?.anchor_at_ms === "number" ? (state.anchor_at_ms as number) : null;
      let series: Series;
      if (stateAnchor !== null && state?.stopped_reason === "booked") {
        // Il a réservé : seule une NOUVELLE demande de prix, faite après, se relance.
        const stoppedAt = typeof state?.stopped_at_ms === "number" ? (state.stopped_at_ms as number) : nowMs;
        const later = quotes.filter((q) => q.ms > stoppedAt);
        if (later.length === 0) continue;
        series = { anchorId: later[0].id, anchorMs: later[0].ms, sent: {}, stopped: false };
      } else if (stateAnchor !== null && nowMs - stateAnchor < FOLLOW_UP_COOLDOWN_MS) {
        // Série en cours (ou terminée depuis moins de 14 jours) : on la garde.
        series = { anchorId: String(state?.anchor_id ?? ""), anchorMs: stateAnchor, sent: readSent(state?.sent), stopped: !!state?.stopped_reason };
      } else {
        series = { anchorId: quotes[0].id, anchorMs: quotes[0].ms, sent: {}, stopped: false };
      }
      if (series.stopped) continue;
      const step = followUpStepDue({ anchorMs: series.anchorMs, nowMs, sent: series.sent });
      if (step !== 1 && step !== 2) continue;

      const bookedAt = await lastBookingSince(uid, quotes, series.anchorMs);
      if (bookedAt !== null) {
        await stopSeries(stateId, base, series, "booked", nowMs, bookedAt);
        continue;
      }
      const user = (await db.collection("users").doc(uid).get()).data();
      const roles: unknown[] = Array.isArray(user?.roles) ? user!.roles : [];
      if (user?.deleted === true || roles.some((r) => STAFF_ROLES.includes(String(r)))) continue;
      const preference = await emailPreference(uid);
      if (preference.unsubscribed) {
        await stopSeries(stateId, base, series, "unsubscribed", nowMs);
        continue;
      }
      const to = await accountEmail(uid);
      if (!to) continue;
      // Adresse tapée par un visiteur sans mot de passe : une seule série
      // par adresse par 14 jours, quel que soit le nombre de sessions.
      if (user?.guest === true && !(await claimGuestEmailSeries(to, uid, nowMs))) continue;
      if (!(await claimStep(stateId, base, series, step, nowMs))) continue;

      const latest = quotes[quotes.length - 1]; // le prix le plus récent
      const outcome = await sendTransactionalEmail({
        key: `quote_followup_${step}__${uid}__${series.anchorId}`,
        kind: `quote_followup_${step}`,
        userId: uid,
        missionId: null,
        to,
        build: () => quoteFollowUpEmail({
          quote: latest.data,
          step,
          locale: normalizeEmailLocale(latest.data.locale),
          customerName: user?.full_name ?? user?.display_name,
          legal: { postalAddress: settings.postalAddress, unsubscribeUrl: unsubscribeUrl(uid, preference.token) },
        }),
      });
      if (outcome === "sent") {
        budget.left -= 1;
        done.push(`${uid}__${step}`);
      }
    } catch (error) {
      console.error("[relance] client ignoré", uid, error instanceof Error ? error.message : error);
    }
  }
  return done;
}

// ---- Chauffeurs : inscription pas terminée -------------------------------------

/**
 * Étape où le chauffeur est arrêté, et depuis quand ; null si rien à relancer.
 * `immediate` : un premier courriel part tout de suite (annonce de l'approbation).
 */
export function driverFollowUpStage(
  profile: Doc
): { stage: DriverFollowUpStage; anchorMs: number | null; approved: boolean; immediate: boolean } | null {
  if (profile.status === DriverStatuses.REGISTRATION_INCOMPLETE) {
    return { stage: "profile", anchorMs: followUpMillis(profile.created_at), approved: false, immediate: false };
  }
  if (profile.status === DriverStatuses.DOCUMENTS_REQUIRED) {
    // Courriel tout de suite (« votre dossier est en suspens »), puis J+1, J+3.
    return { stage: "documents", anchorMs: followUpMillis(profile.documents_required_at), approved: false, immediate: true };
  }
  if (profile.stripe_payouts_enabled === true) return null;
  if (profile.status === DriverStatuses.APPROVED) {
    return { stage: "stripe", anchorMs: followUpMillis(profile.approved_at), approved: true, immediate: true };
  }
  // Dossier envoyé, en révision : les versements peuvent déjà être activés (2026-11-17).
  if (profile.status === DriverStatuses.PENDING_REVIEW) {
    return { stage: "stripe", anchorMs: followUpMillis(profile.submitted_for_review_at), approved: false, immediate: false };
  }
  return null;
}

/**
 * Relance d'un chauffeur à l'étape `stage` (série commencée à `anchorMs`).
 * Renvoie la clé de la relance envoyée, ou null.
 */
async function followUpDriver(params: {
  uid: string; stage: DriverFollowUpStage; anchorMs: number; approved: boolean; immediate: boolean;
  profile: Doc; settings: EmailSettings; nowMs: number;
}): Promise<string | null> {
  const { uid, stage, anchorMs, nowMs } = params;
  // Trop tôt ou trop tard : aucune lecture de plus.
  if (nowMs - anchorMs >= FOLLOW_UP_END_MS || nowMs < anchorMs) return null;
  const stateId = `driver_${stage}__${uid}`;
  const base = { kind: `driver_${stage}`, user_id: uid };
  const state = (await db.collection("lead_followups").doc(stateId).get()).data();
  const sameSeries = state?.anchor_at_ms === anchorMs;
  const series: Series = {
    anchorId: `${stage}_${anchorMs}`,
    anchorMs,
    sent: sameSeries ? readSent(state?.sent) : {},
    stopped: sameSeries && !!state?.stopped_reason,
  };
  if (series.stopped) return null;
  const step = followUpStepDue({ anchorMs, nowMs, sent: series.sent, immediate: params.immediate });
  if (step === null) return null;

  const preference = await emailPreference(uid);
  if (preference.unsubscribed) {
    await stopSeries(stateId, base, series, "unsubscribed", nowMs);
    return null;
  }
  const to = await accountEmail(uid);
  if (!to) return null;
  if (!(await claimStep(stateId, base, series, step, nowMs))) return null;

  const locale = await deviceLocale(uid);
  const outcome = await sendTransactionalEmail({
    key: `driver_followup_${stage}_${step}__${uid}__${anchorMs}`,
    kind: `driver_followup_${stage}_${step}`,
    userId: uid,
    missionId: null,
    to,
    build: () => driverFollowUpEmail({
      stage,
      step,
      locale,
      driverName: params.profile.full_name,
      documentsReason: params.profile.documents_required_reason,
      approved: params.approved,
      legal: { postalAddress: params.settings.postalAddress, unsubscribeUrl: unsubscribeUrl(uid, preference.token) },
    }),
  });
  return outcome === "sent" ? `${uid}__${stage}__${step}` : null;
}

async function runDriverFollowUps(settings: EmailSettings, nowMs: number, budget: { left: number }): Promise<string[]> {
  const done: string[] = [];
  const snap = await db.collection("driver_profiles")
    .where("status", "in", [
      DriverStatuses.REGISTRATION_INCOMPLETE, DriverStatuses.DOCUMENTS_REQUIRED,
      DriverStatuses.PENDING_REVIEW, DriverStatuses.APPROVED,
    ])
    .get();
  for (const doc of snap.docs) {
    if (budget.left <= 0) break;
    try {
      const profile = doc.data();
      const found = driverFollowUpStage(profile);
      if (!found || found.anchorMs === null) continue;
      const key = await followUpDriver({ uid: doc.id, ...found, anchorMs: found.anchorMs, profile, settings, nowMs });
      if (key) {
        budget.left -= 1;
        done.push(key);
      }
    } catch (error) {
      console.error("[relance] chauffeur ignoré", doc.id, error instanceof Error ? error.message : error);
    }
  }

  // Compte créé au début de l'inscription, dossier jamais enregistré
  // (`driver_leads`, 2026-11-17) : relance « Terminez votre inscription ».
  const since = admin.firestore.Timestamp.fromMillis(nowMs - FOLLOW_UP_END_MS);
  const leads = await db.collection("driver_leads").where("started_at", ">=", since).get();
  for (const doc of leads.docs) {
    if (budget.left <= 0) break;
    try {
      const anchorMs = followUpMillis(doc.data().started_at);
      if (anchorMs === null || nowMs - anchorMs < FOLLOW_UP_FIRST_MS) continue;
      if ((await db.collection("driver_profiles").doc(doc.id).get()).exists) continue;
      const user = (await db.collection("users").doc(doc.id).get()).data();
      // Rattrapage (2026-11-19) : les prospects notés avant que le rôle soit
      // posé dès les coordonnées sortent des clients au prochain passage.
      const roles: string[] = Array.isArray(user?.roles) ? user!.roles : [];
      if (!roles.includes("driver")) await grantDriverRole(doc.id, roles, "started");
      const key = await followUpDriver({
        uid: doc.id, stage: "profile", anchorMs, approved: false, immediate: false,
        profile: { full_name: user?.full_name }, settings, nowMs,
      });
      if (key) {
        budget.left -= 1;
        done.push(key);
      }
    } catch (error) {
      console.error("[relance] prospect chauffeur ignoré", doc.id, error instanceof Error ? error.message : error);
    }
  }
  return done;
}

/**
 * Le visiteur vient de créer son compte au début de l'inscription chauffeur
 * (2026-11-17). Noté une seule fois ; sert uniquement aux relances.
 */
export const markDriverLead = onCall(async (request) => {
  const ctx = requireSignedIn(request);
  const ref = db.collection("driver_leads").doc(ctx.uid);
  const created = await db.runTransaction(async (tx) => {
    if ((await tx.get(ref)).exists) return false;
    tx.set(ref, { user_id: ctx.uid, started_at: admin.firestore.Timestamp.now() });
    return true;
  });
  // Chauffeur dès les coordonnées (Daniel, 2026-11-19) : plus jamais dans
  // les clients, et pas de prix possible avec ce compte. L'app doit
  // rafraîchir son jeton (getIdTokenResult(forceRefresh: true)).
  const roles = await grantDriverRole(ctx.uid, ctx.roles, "started");
  return { created, roles };
});

/**
 * Document refusé ou demandé (2026-11-19) : le courriel « Votre dossier est
 * en suspens » part sans attendre le cron. Même série que les relances, donc
 * jamais en double ; silencieux si l'adresse postale n'est pas réglée (le
 * cron enverra dès qu'elle le sera). Renvoie vrai si un courriel est parti.
 */
export async function sendDriverDocumentsEmailNow(driverId: string, nowMs = Date.now()): Promise<boolean> {
  const settings = await getEmailSettings();
  if (!followUpsReady(settings)) return false;
  const profile = (await db.collection("driver_profiles").doc(driverId).get()).data();
  if (!profile) return false;
  const found = driverFollowUpStage(profile);
  if (!found || found.stage !== "documents" || found.anchorMs === null) return false;
  const key = await followUpDriver({ uid: driverId, ...found, anchorMs: found.anchorMs, profile, settings, nowMs });
  return key !== null;
}

/** Un passage des relances (appelé par le cron et par les tests). */
export async function runLeadFollowUps(
  nowMs = Date.now()
): Promise<{ status: "sent" | "outside_hours" | "not_ready"; customers: string[]; drivers: string[] }> {
  if (!withinFollowUpSendingHours(nowMs)) return { status: "outside_hours", customers: [], drivers: [] };
  const settings = await getEmailSettings();
  if (!followUpsReady(settings)) return { status: "not_ready", customers: [], drivers: [] };
  const budget = { left: FOLLOW_UPS_PER_RUN };
  const customers = await runQuoteFollowUps(settings, nowMs, budget);
  const drivers = await runDriverFollowUps(settings, nowMs, budget);
  return { status: "sent", customers, drivers };
}

export const sendLeadFollowUps = onSchedule(
  { schedule: "every 30 minutes", timeZone: "America/Toronto", secrets: [RESEND_API_KEY], timeoutSeconds: 300 },
  async () => {
    const result = await runLeadFollowUps();
    if (result.status === "not_ready") {
      console.log("[relances] en attente : adresse postale absente ou relances fermées (system_config/email_settings)");
    } else if (result.customers.length + result.drivers.length > 0) {
      console.log("[relances]", { customers: result.customers.length, drivers: result.drivers.length });
    }
  }
);

// ---- Désabonnement (page publique) ---------------------------------------------

function page(title: string, body: string): string {
  return `<!doctype html><html lang="fr"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">` +
    `<meta name="robots" content="noindex"><title>${escapeHtml(title)}</title>` +
    `<body style="margin:0;background:#F3F6FB;font-family:Arial,Helvetica,sans-serif;color:#0F2A5C">` +
    `<div style="max-width:480px;margin:48px auto;background:#fff;border-radius:16px;padding:28px">` +
    `<div style="font-size:22px;font-weight:800;margin-bottom:16px">Movi-K</div>${body}</div></body></html>`;
}

export const emailUnsubscribe = onRequest(async (req, res) => {
  res.set({
    "Cache-Control": "no-store",
    "Referrer-Policy": "no-referrer",
    "Content-Security-Policy": "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; frame-ancestors 'none'",
  });
  const uid = typeof req.query.u === "string" ? req.query.u : "";
  const token = typeof req.query.t === "string" ? req.query.t : "";
  const invalid = () => res.status(400).type("html").send(page(
    "Lien invalide",
    "<h1 style=\"font-size:20px\">Lien invalide</h1><p>Ce lien de désabonnement n'est plus valide. Écrivez à info@movi-k.com et nous nous en occupons.</p>" +
    "<p style=\"color:#54607A\">This unsubscribe link is no longer valid. Write to info@movi-k.com and we will take care of it.</p>"
  ));
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(uid) || !/^[A-Za-z0-9_-]{20,128}$/.test(token)) {
    invalid();
    return;
  }
  try {
    if (req.method === "POST") {
      if (!(await setFollowUpSubscription(uid, token, true))) {
        invalid();
        return;
      }
      res.status(200).type("html").send(page(
        "Désabonnement confirmé",
        "<h1 style=\"font-size:20px\">C'est fait ✅</h1><p>Vous ne recevrez plus de rappels de Movi-K. Les courriels liés à une réservation en cours (confirmation, rappel du ramassage, reçu) continuent.</p>" +
        "<p style=\"color:#54607A\">Done. You will no longer receive reminders from Movi-K. Emails about an active booking (confirmation, pickup reminder, receipt) continue.</p>"
      ));
      return;
    }
    if (req.method !== "GET") {
      res.status(405).send("Method Not Allowed");
      return;
    }
    res.status(200).type("html").send(page(
      "Se désabonner",
      "<h1 style=\"font-size:20px\">Ne plus recevoir de rappels ?</h1><p>Confirmez pour ne plus recevoir les rappels de Movi-K par courriel.</p>" +
      "<p style=\"color:#54607A\">Confirm to stop receiving reminder emails from Movi-K.</p>" +
      `<form method="post" action="?u=${encodeURIComponent(uid)}&amp;t=${encodeURIComponent(token)}">` +
      "<button type=\"submit\" style=\"background:#0F2A5C;color:#fff;border:0;border-radius:12px;padding:14px 22px;font-weight:700;font-size:16px;cursor:pointer\">Me désabonner / Unsubscribe</button></form>"
    ));
  } catch (error) {
    console.error("[désabonnement] échec", error instanceof Error ? error.message : error);
    res.status(500).type("html").send(page("Erreur", "<p>Une erreur est survenue. Réessayez ou écrivez à info@movi-k.com.</p>"));
  }
});

// ---- Réglages (admin) -------------------------------------------------------------

/**
 * "get" : réglages actuels. "save" { postalAddress?, followUpsEnabled? } :
 * écrit `system_config/email_settings` (journalisé).
 */
export const adminEmailSettings = onCall(async (request) => {
  const ctx = requireSignedIn(request);
  requireAdminOrAbove(ctx);
  const data = (request.data ?? {}) as Record<string, unknown>;
  if (data.action === "save") {
    const update: Record<string, unknown> = {};
    if (data.postalAddress !== undefined) {
      if (typeof data.postalAddress !== "string" || data.postalAddress.trim().length > POSTAL_ADDRESS_MAX_LENGTH) {
        throw invalidArgument("Adresse postale invalide.");
      }
      update.postal_address = data.postalAddress.trim().replace(/\s+/g, " ");
    }
    if (data.followUpsEnabled !== undefined) {
      if (typeof data.followUpsEnabled !== "boolean") throw invalidArgument("Interrupteur invalide.");
      update.followups_enabled = data.followUpsEnabled;
    }
    if (Object.keys(update).length === 0) throw invalidArgument("Rien à enregistrer.");
    await db.doc(EMAIL_SETTINGS_DOC).set(
      { ...update, updated_at: admin.firestore.Timestamp.now(), updated_by: ctx.uid },
      { merge: true }
    );
    await writeAuditLog({
      actorUserId: ctx.uid,
      actorRole: ctx.role ?? "unknown",
      action: "email_settings_updated",
      sourceFunction: "adminEmailSettings",
      targetId: "email_settings",
      metadata: { fields: Object.keys(update) },
    });
  } else if (data.action !== "get") {
    throw invalidArgument("Action invalide.");
  }
  const settings = await getEmailSettings();
  return { postalAddress: settings.postalAddress, followUpsEnabled: settings.followUpsEnabled, ready: followUpsReady(settings) };
});
