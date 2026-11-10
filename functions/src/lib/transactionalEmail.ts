// -----------------------------------------------------------------------------
// transactionalEmail.ts — courriels Movi-K (décision Daniel, 2026-11-10).
//
// Envoi par l'API Resend (https://resend.com), sans dépendance npm : un POST
// JSON avec `fetch` (Node 22). La clé vit dans Secret Manager
// (RESEND_API_KEY) ; tant qu'elle ne commence pas par `re_`, rien n'est
// envoyé et le journal note « not_configured ».
//
// Un courriel = un document `email_log/{clé}` créé AVANT l'envoi : deux
// déclenchements concurrents ne peuvent pas envoyer deux fois le même
// courriel. Le journal ne contient jamais l'adresse courriel (seulement
// l'identifiant de l'utilisateur). Collection fermée aux clients
// (firestore.rules : refus par défaut).
// -----------------------------------------------------------------------------

import { admin, db } from "./admin";

export const EMAIL_FROM = "Movi-K <reservations@movi-k.com>";
export const EMAIL_REPLY_TO = "infos@movi-k.com";
const RESEND_ENDPOINT = "https://api.resend.com/emails";
const MAX_ATTEMPTS = 3;

export type EmailLocale = "fr" | "en" | "es";

export interface OutgoingEmail {
  to: string;
  subject: string;
  html: string;
  text: string;
  /** Lettres, chiffres, _ et - seulement (contrainte Resend). */
  category: string;
}

export interface EmailSender {
  send(email: OutgoingEmail, idempotencyKey: string): Promise<{ id: string }>;
}

/** Clé Resend lue à l'exécution (secret injecté par Cloud Functions). */
function resendApiKey(): string | null {
  const key = process.env.RESEND_API_KEY?.trim();
  return key && key.startsWith("re_") ? key : null;
}

class ResendSender implements EmailSender {
  constructor(private readonly apiKey: string) {}
  async send(email: OutgoingEmail, idempotencyKey: string): Promise<{ id: string }> {
    const response = await fetch(RESEND_ENDPOINT, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${this.apiKey}`,
        "Content-Type": "application/json",
        "Idempotency-Key": idempotencyKey.slice(0, 256),
      },
      signal: AbortSignal.timeout(15000),
      body: JSON.stringify({
        from: EMAIL_FROM,
        to: [email.to],
        reply_to: EMAIL_REPLY_TO,
        subject: email.subject,
        html: email.html,
        text: email.text,
        tags: [{ name: "category", value: email.category }],
      }),
    });
    const body = (await response.json().catch(() => ({}))) as { id?: string; message?: string };
    if (!response.ok || typeof body.id !== "string") {
      throw new Error(`Resend ${response.status}: ${String(body.message ?? "réponse invalide").slice(0, 300)}`);
    }
    return { id: body.id };
  }
}

let testSender: EmailSender | null = null;

/** Tests : remplace l'envoi réel (null = comportement normal). */
export function setEmailSenderForTesting(sender: EmailSender | null): void {
  testSender = sender;
}

function activeSender(): EmailSender | null {
  if (testSender) return testSender;
  const key = resendApiKey();
  return key ? new ResendSender(key) : null;
}

export type EmailOutcome = "sent" | "duplicate" | "not_configured" | "no_address" | "failed";

/**
 * Envoie un courriel une seule fois par `key` (ex. `booking_confirmed__<mission>`).
 * Ne lève jamais : un courriel raté ne doit bloquer ni une réservation ni un rappel.
 */
export async function sendTransactionalEmail(params: {
  key: string;
  kind: string;
  userId: string;
  missionId: string | null;
  to: string | null | undefined;
  build: () => Omit<OutgoingEmail, "to">;
}): Promise<EmailOutcome> {
  const ref = db.collection("email_log").doc(params.key);
  const now = admin.firestore.Timestamp.now();
  try {
    const claimed = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const data = snap.data();
      if (data && (data.status === "sent" || data.status === "sending" || (data.attempts ?? 0) >= MAX_ATTEMPTS)) {
        return false;
      }
      tx.set(ref, {
        kind: params.kind,
        user_id: params.userId,
        mission_id: params.missionId,
        status: "sending",
        attempts: (data?.attempts ?? 0) + 1,
        created_at: data?.created_at ?? now,
        updated_at: now,
      });
      return true;
    });
    if (!claimed) return "duplicate";

    const finish = (status: EmailOutcome, extra: Record<string, unknown> = {}) =>
      ref.update({ status, updated_at: admin.firestore.Timestamp.now(), ...extra }).then(() => status);

    const to = typeof params.to === "string" ? params.to.trim() : "";
    if (!to || !to.includes("@") || to.endsWith("@no-email.movik.ca")) return await finish("no_address");
    const sender = activeSender();
    if (!sender) return await finish("not_configured");
    try {
      const email = { ...params.build(), to };
      const { id } = await sender.send(email, params.key);
      return await finish("sent", { provider: "resend", provider_id: id, sent_at: admin.firestore.Timestamp.now() });
    } catch (error) {
      console.error(`[email] ${params.kind} non envoyé`, params.missionId, error instanceof Error ? error.message : error);
      return await finish("failed", { error: (error instanceof Error ? error.message : String(error)).slice(0, 500) });
    }
  } catch (error) {
    console.error(`[email] journal ${params.key} inaccessible`, error instanceof Error ? error.message : error);
    return "failed";
  }
}

/** Adresse courriel du compte (Firebase Auth), ou null. */
export async function accountEmail(uid: string): Promise<string | null> {
  try {
    const user = await admin.auth().getUser(uid);
    return user.email ?? null;
  } catch {
    return null;
  }
}

// ---- Mise en forme commune ---------------------------------------------------

export function escapeHtml(value: unknown): string {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

export function normalizeEmailLocale(raw: unknown): EmailLocale {
  return raw === "en" || raw === "es" ? raw : "fr";
}

/** 72,43 $ (fr, es) ou $72.43 (en). */
export function formatEmailMoney(amountMinor: number, locale: EmailLocale): string {
  const dollars = (Math.max(0, amountMinor) / 100).toFixed(2);
  return locale === "en" ? `$${dollars}` : `${dollars.replace(".", ",")} $`;
}

/** « mardi 10 novembre à 14 h 00 », heure du Québec. */
export function formatEmailDateTime(ms: number, locale: EmailLocale): string {
  const tag = locale === "en" ? "en-CA" : locale === "es" ? "es-CA" : "fr-CA";
  const date = new Intl.DateTimeFormat(tag, {
    timeZone: "America/Toronto", weekday: "long", day: "numeric", month: "long",
  }).format(ms);
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "America/Toronto", hour: "2-digit", minute: "2-digit", hourCycle: "h23",
  }).formatToParts(ms);
  const hour = parts.find((p) => p.type === "hour")?.value ?? "00";
  const minute = parts.find((p) => p.type === "minute")?.value ?? "00";
  if (locale === "en") return `${date} at ${hour}:${minute}`;
  if (locale === "es") return `${date} a las ${hour}:${minute}`;
  return `${date} à ${Number(hour)} h ${minute}`;
}

/** « 14 h 00 » / « 14:00 », heure du Québec. */
export function formatEmailTime(ms: number, locale: EmailLocale): string {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "America/Toronto", hour: "2-digit", minute: "2-digit", hourCycle: "h23",
  }).formatToParts(ms);
  const hour = parts.find((p) => p.type === "hour")?.value ?? "00";
  const minute = parts.find((p) => p.type === "minute")?.value ?? "00";
  return locale === "fr" ? `${Number(hour)} h ${minute}` : `${hour}:${minute}`;
}

/** Adresse lisible d'un arrêt (line1, ville). */
export function formatEmailAddress(address: unknown): string {
  if (!address || typeof address !== "object") return "";
  const a = address as Record<string, unknown>;
  return [a.line1, a.city].filter((v) => typeof v === "string" && v.trim()).join(", ");
}

/** Gabarit HTML Movi-K : en-tête bleu, rangées « libellé / valeur », bouton. */
export function renderEmailHtml(params: {
  title: string;
  intro: string;
  rows: Array<[string, string]>;
  highlight?: Array<[string, string]>;
  paragraphs?: string[];
  button?: { label: string; url: string };
  footer: string;
}): string {
  const row = ([label, value]: [string, string], strong = false) =>
    `<tr><td style="padding:6px 0;color:#54607A;font-size:14px;vertical-align:top;width:42%">${escapeHtml(label)}</td>` +
    `<td style="padding:6px 0;color:#0F2A5C;font-size:${strong ? 17 : 15}px;font-weight:${strong ? 800 : 600};text-align:right">${escapeHtml(value)}</td></tr>`;
  return `<!doctype html><html><body style="margin:0;background:#F3F6FB;font-family:Arial,Helvetica,sans-serif">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#F3F6FB;padding:24px 12px"><tr><td align="center">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;background:#ffffff;border-radius:16px;overflow:hidden">
<tr><td style="background:#0F2A5C;padding:20px 24px;color:#ffffff;font-size:22px;font-weight:800">Movi-K</td></tr>
<tr><td style="padding:24px">
<h1 style="margin:0 0 8px;color:#0F2A5C;font-size:22px">${escapeHtml(params.title)}</h1>
<p style="margin:0 0 16px;color:#3A4660;font-size:15px;line-height:1.5">${escapeHtml(params.intro)}</p>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0">${params.rows.map((r) => row(r)).join("")}</table>
${params.highlight?.length ? `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin-top:12px;background:#EEF3FB;border-radius:12px;padding:8px 14px">${params.highlight.map((r, i) => row(r, i === params.highlight!.length - 1)).join("")}</table>` : ""}
${(params.paragraphs ?? []).map((p) => `<p style="margin:14px 0 0;color:#3A4660;font-size:14px;line-height:1.5">${escapeHtml(p)}</p>`).join("")}
${params.button ? `<p style="margin:22px 0 4px;text-align:center"><a href="${escapeHtml(params.button.url)}" style="display:inline-block;background:#0F2A5C;color:#ffffff;text-decoration:none;font-weight:700;padding:14px 22px;border-radius:12px">${escapeHtml(params.button.label)}</a></p>` : ""}
</td></tr>
<tr><td style="padding:16px 24px;background:#F6F8FC;color:#7A859C;font-size:12px;line-height:1.5">${escapeHtml(params.footer)}</td></tr>
</table></td></tr></table></body></html>`;
}

/** Même contenu en texte brut (lecteurs de courriel sans HTML). */
export function renderEmailText(params: {
  title: string;
  intro: string;
  rows: Array<[string, string]>;
  highlight?: Array<[string, string]>;
  paragraphs?: string[];
  button?: { label: string; url: string };
  footer: string;
}): string {
  return [
    params.title,
    "",
    params.intro,
    "",
    ...params.rows.map(([l, v]) => `${l} : ${v}`),
    ...(params.highlight?.length ? ["", ...params.highlight.map(([l, v]) => `${l} : ${v}`)] : []),
    ...(params.paragraphs ?? []).flatMap((p) => ["", p]),
    ...(params.button ? ["", `${params.button.label} : ${params.button.url}`] : []),
    "",
    "—",
    params.footer,
  ].join("\n");
}
