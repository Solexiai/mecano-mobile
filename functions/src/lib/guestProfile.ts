// -----------------------------------------------------------------------------
// guestProfile.ts — passage de la fiche « invité » à la fiche d'un client
// ordinaire (prix avec le courriel seulement, voir lib/guestLead.ts).
//
// Le navigateur appelle `completeGuestAccount` juste après le choix du mot de
// passe. Si cet appel se perd (réseau, onglet fermé), le compte existe mais
// sa fiche reste « invité ». `settleGuestProfileIfNeeded` est le filet : le
// serveur refait le passage lui-même à l'étape de la carte, par laquelle
// passe toute première réservation.
// -----------------------------------------------------------------------------
import type { CallableRequest } from "firebase-functions/v2/https";
import { admin, db } from "./admin";
import { isAnonymousToken } from "./guestLead";

export function cleanFullName(raw: unknown): string {
  return typeof raw === "string" ? raw.trim().slice(0, 120) : "";
}

/**
 * La fiche « invité » devient celle d'un client ordinaire. Le courriel est
 * celui du compte (jeton de connexion), jamais une valeur envoyée par le
 * client. Retourne `false` si une fiche ordinaire existe déjà : on n'y touche
 * pas.
 */
export async function settleGuestProfile(
  uid: string, email: string, fullName: string, emailVerified = false
): Promise<boolean> {
  const ref = db.collection("users").doc(uid);
  return db.runTransaction(async (tx) => {
    const existing = (await tx.get(ref)).data();
    // Une fiche ordinaire existe déjà : on n'y touche pas.
    if (existing && existing.guest !== true) return false;
    const now = Date.now();
    tx.set(ref, {
      uid,
      email,
      roles: Array.isArray(existing?.roles) && existing!.roles.length ? existing!.roles : ["customer"],
      guest: false,
      ...(fullName ? { full_name: fullName } : {}),
      created_at: existing?.created_at ?? new Date(now).toISOString(),
      is_disabled: false,
      email_verified: emailVerified,
      account_completed_at: admin.firestore.Timestamp.fromMillis(now),
      updated_at: admin.firestore.Timestamp.fromMillis(now),
    }, { merge: true });
    return true;
  });
}

/**
 * Filet de sécurité (2026-11-27) : un vrai compte (courriel + mot de passe)
 * dont la fiche est encore « invité » est complété sur place. Le nom vient
 * du compte. Ne bloque jamais l'appelant.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function settleGuestProfileIfNeeded(request: CallableRequest<any>): Promise<boolean> {
  try {
    const token = request.auth?.token as Record<string, unknown> | undefined;
    const uid = request.auth?.uid;
    const email = typeof token?.email === "string" ? token.email.toLowerCase() : "";
    if (!uid || !email || isAnonymousToken(token)) return false;
    const profile = (await db.collection("users").doc(uid).get()).data();
    if (profile?.guest !== true) return false;
    return await settleGuestProfile(uid, email, cleanFullName(token?.name), token?.email_verified === true);
  } catch (error) {
    console.error("[guest] fiche invité non complétée", error instanceof Error ? error.message : error);
    return false;
  }
}
