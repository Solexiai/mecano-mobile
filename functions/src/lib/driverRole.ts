// -----------------------------------------------------------------------------
// driverRole.ts — poser le rôle « driver » (Daniel, 2026-11-19)
//
// « Il n'y a pas d'utilisateurs : il y a des clients qui veulent le service
// et il y a des chauffeurs. » Quelqu'un qui arrive par le chemin chauffeur
// est un chauffeur dès ses coordonnées (`markDriverLead`), pas seulement
// quand son dossier est envoyé (`registerAsDriver`). Il n'apparaît donc
// jamais dans les clients et ne peut pas demander de prix avec ce compte.
//
// `users/{uid}.driver_signup` : "started" (coordonnées données, dossier pas
// envoyé) puis "submitted" (dossier envoyé). L'admin affiche « Inscription
// inachevée » tant que c'est "started".
// -----------------------------------------------------------------------------

import { admin, authAdmin, db } from "./admin";
import { PlatformRole, PlatformRoles } from "./types";

export type DriverSignupStage = "started" | "submitted";

/**
 * Ajoute le rôle driver aux claims et à `users/{uid}` (sans effet s'il y est
 * déjà, hormis la mise à jour de `driver_signup`). Renvoie les rôles finaux.
 * Si le compte de connexion n'existe pas (tests, compte effacé), seul le
 * document `users` est touché.
 */
export async function grantDriverRole(
  uid: string,
  currentRoles: readonly string[] | undefined,
  stage: DriverSignupStage
): Promise<PlatformRole[]> {
  let roles: PlatformRole[] = (currentRoles ?? []).filter(Boolean) as PlatformRole[];
  if (roles.length === 0) {
    const record = await authAdmin.getUser(uid).catch(() => null);
    const claimed = record?.customClaims?.roles;
    roles = Array.isArray(claimed) && claimed.length > 0 ? (claimed as PlatformRole[]) : [PlatformRoles.CUSTOMER];
  }
  const alreadyDriver = roles.includes(PlatformRoles.DRIVER);
  const newRoles = alreadyDriver ? roles : [...roles, PlatformRoles.DRIVER];

  if (!alreadyDriver) {
    await authAdmin
      .setCustomUserClaims(uid, { role: roles[0] ?? PlatformRoles.CUSTOMER, roles: newRoles })
      .catch((error: { code?: string }) => {
        if (error?.code !== "auth/user-not-found") throw error;
      });
  }

  const update: Record<string, unknown> = {
    roles: newRoles,
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  };
  // « submitted » ne redescend jamais à « started ».
  const existing = (await db.collection("users").doc(uid).get()).data()?.driver_signup;
  if (!(stage === "started" && existing === "submitted")) update.driver_signup = stage;
  await db.collection("users").doc(uid).set(update, { merge: true });

  return newRoles;
}
