// -----------------------------------------------------------------------------
// emailPreferences.ts — réglages des relances et désabonnement
// (décision Daniel, 2026-11-17).
//
//   - `system_config/email_settings` : adresse postale de Movi-K (exigée par
//     la loi canadienne anti-pourriel dans tout courriel de relance) et
//     interrupteur des relances. Sans adresse postale, AUCUNE relance ne part.
//   - `email_preferences/{uid}` : jeton secret du lien « Me désabonner » et
//     choix de la personne. Collection fermée aux clients (refus par défaut
//     de firestore.rules) : seules les Cloud Functions y touchent.
//
// Les courriels de service (réservation confirmée, rappel 4 h, reçu) ne sont
// pas des relances : ils partent toujours.
// -----------------------------------------------------------------------------

import { randomBytes, timingSafeEqual } from "crypto";
import { admin, db } from "./admin";
import { leadEmailKey, normalizeLeadEmail } from "./guestLead";

export const EMAIL_SETTINGS_DOC = "system_config/email_settings";
export const POSTAL_ADDRESS_MAX_LENGTH = 200;

export interface EmailSettings {
  /** Adresse postale affichée au bas des relances ; vide = relances en attente. */
  postalAddress: string;
  /** Interrupteur des relances (vrai par défaut). */
  followUpsEnabled: boolean;
}

export function parseEmailSettings(data: Record<string, unknown> | undefined): EmailSettings {
  const address = typeof data?.postal_address === "string" ? data.postal_address.trim() : "";
  return {
    postalAddress: address.slice(0, POSTAL_ADDRESS_MAX_LENGTH),
    followUpsEnabled: data?.followups_enabled !== false,
  };
}

export async function getEmailSettings(): Promise<EmailSettings> {
  return parseEmailSettings((await db.doc(EMAIL_SETTINGS_DOC).get()).data());
}

/** Les relances peuvent-elles partir ? (interrupteur ouvert ET adresse postale écrite) */
export function followUpsReady(settings: EmailSettings): boolean {
  return settings.followUpsEnabled && settings.postalAddress.length >= 10;
}

export function unsubscribeUrl(uid: string, token: string): string {
  const project = process.env.GCLOUD_PROJECT ?? process.env.GCP_PROJECT ?? "movik-connect-prod";
  return `https://us-central1-${project}.cloudfunctions.net/emailUnsubscribe?u=${encodeURIComponent(uid)}&t=${encodeURIComponent(token)}`;
}

/**
 * Jeton de désabonnement de la personne (créé au besoin) et son choix actuel.
 */
export async function emailPreference(uid: string): Promise<{ token: string; unsubscribed: boolean }> {
  const ref = db.collection("email_preferences").doc(uid);
  return db.runTransaction(async (tx) => {
    const data = (await tx.get(ref)).data();
    if (typeof data?.token === "string" && data.token.length >= 20) {
      return { token: data.token, unsubscribed: data.followups_unsubscribed === true };
    }
    const token = randomBytes(24).toString("base64url");
    tx.set(ref, { user_id: uid, token, followups_unsubscribed: false, created_at: admin.firestore.Timestamp.now() }, { merge: true });
    return { token, unsubscribed: false };
  });
}

/**
 * Désabonne (ou réabonne) la personne si le jeton du lien est le bon.
 * Renvoie false si le lien est invalide.
 */
export async function setFollowUpSubscription(uid: string, token: string, unsubscribed: boolean): Promise<boolean> {
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(uid) || !/^[A-Za-z0-9_-]{20,128}$/.test(token)) return false;
  const ref = db.collection("email_preferences").doc(uid);
  const stored = (await ref.get()).data()?.token;
  if (typeof stored !== "string" || stored.length !== token.length) return false;
  if (!timingSafeEqual(Buffer.from(stored), Buffer.from(token))) return false;
  await ref.update({
    followups_unsubscribed: unsubscribed,
    updated_at: admin.firestore.Timestamp.now(),
    ...(unsubscribed ? { unsubscribed_at: admin.firestore.Timestamp.now() } : {}),
  });
  // Visiteur sans mot de passe (2026-11-26) : le désabonnement vaut pour
  // l'ADRESSE, pas seulement pour cette session. Sinon la même adresse,
  // tapée plus tard dans une autre session, serait relancée de nouveau.
  const profile = (await db.collection("users").doc(uid).get()).data();
  const typed = profile?.guest === true ? normalizeLeadEmail(profile.email) : null;
  if (typed) {
    await db.collection("lead_emails").doc(leadEmailKey(typed)).set({ unsubscribed }, { merge: true });
  }
  return true;
}
