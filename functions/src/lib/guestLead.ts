// -----------------------------------------------------------------------------
// Prospect invité (décision du propriétaire du 17 novembre 2026, construite le
// 26) : « prix client visible avec le courriel seulement ; mot de passe à la
// réservation ».
//
// La demande de livraison ouvre un compte Firebase ANONYME en arrière-plan.
// À l'étape du prix, le visiteur donne seulement son courriel : il est rangé
// dans `users/{uid}` avec `guest: true`. Le compte ne devient un vrai compte
// (courriel + mot de passe, courriel à vérifier) qu'à la réservation ; le
// serveur refuse toujours de réserver sans courriel vérifié.
//
// Le courriel d'un invité est une adresse TAPÉE, pas vérifiée : elle ne sert
// qu'aux relances « votre prix » (deux courriels au plus, désabonnement en un
// clic), avec une seule série par adresse par 14 jours.
// -----------------------------------------------------------------------------
import { createHash } from "crypto";

export const GUEST_EMAIL_MAX_CHANGES = 3;
export const GUEST_LEADS_PER_IP_PER_DAY = 10;

/** « Marie@Exemple.com » → « marie@exemple.com » ; null si ce n'est pas un courriel plausible. */
export function normalizeLeadEmail(raw: unknown): string | null {
  if (typeof raw !== "string") return null;
  const email = raw.trim().toLowerCase();
  if (email.length < 6 || email.length > 254) return null;
  // Une arobase, un point dans le domaine, pas d'espace ni de caractère de contrôle.
  if (!/^[^\s@<>",;:\\()[\]]+@[a-z0-9-]+(\.[a-z0-9-]+)+$/.test(email)) return null;
  const [local, domain] = email.split("@");
  if (local.length > 64 || domain.startsWith("-") || domain.includes("..") || /\.[0-9]+$/.test(domain)) return null;
  return email;
}

/** Clé d'une adresse dans `lead_emails` : jamais l'adresse en clair comme identifiant. */
export function leadEmailKey(email: string): string {
  return createHash("sha256").update(email.trim().toLowerCase()).digest("hex");
}

/** Vrai pour une session ouverte sans courriel ni mot de passe. */
export function isAnonymousToken(token: Record<string, unknown> | undefined): boolean {
  const firebase = token?.firebase as { sign_in_provider?: unknown } | undefined;
  return firebase?.sign_in_provider === "anonymous";
}

export interface GuestSeriesState {
  user_id?: unknown;
  started_at_ms?: unknown;
  /** L'adresse s'est désabonnée (lien d'une relance) : plus aucune relance d'invité. */
  unsubscribed?: unknown;
}

/**
 * Une adresse d'invité reçoit une seule série de relances par période de
 * `cooldownMs`, quel que soit le nombre de sessions qui l'ont tapée. Vrai si
 * la session `uid` peut envoyer maintenant. Jamais à une adresse désabonnée.
 */
export function guestSeriesAllowed(
  state: GuestSeriesState | undefined, uid: string, nowMs: number, cooldownMs: number
): boolean {
  if (state?.unsubscribed === true) return false;
  if (!state || state.user_id === uid) return true;
  return typeof state.started_at_ms !== "number" || nowMs - state.started_at_ms >= cooldownMs;
}

export const GUEST_EMAIL_REQUIRED = "Entrez votre courriel pour voir votre prix.";

/**
 * Le mur du prix tient aussi côté serveur : une session anonyme n'obtient un
 * prix exact qu'après avoir laissé son courriel (fiche `guest: true`).
 */
export function guestMayGetPrice(profile: Record<string, unknown> | undefined): boolean {
  return profile?.guest === true && normalizeLeadEmail(profile.email) !== null;
}
