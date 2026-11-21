// -----------------------------------------------------------------------------
// repairOrphanAccounts.ts — comptes de connexion sans fiche (Daniel, 2026-11-21)
//
// Constat : un compte (dupontsylvainsd@…) existait dans Firebase Auth mais
// n'apparaissait nulle part dans l'admin. À l'inscription, l'app crée d'abord
// le compte de connexion, puis la fiche `users/{uid}` ; si la 2e écriture
// échoue (réseau coupé, bloqueur de pub qui bloque Firestore, onglet fermé),
// la personne existe sans fiche : invisible, jamais relancée, et son courriel
// est « déjà utilisé » si elle réessaie.
//
// Ce rattrapage tourne toutes les heures : il parcourt les comptes Auth et
// crée la fiche manquante — chauffeur si un dossier ou un prospect chauffeur
// existe, client sinon. Il est aussi appelable par le super-admin (bouton
// « Vérifier les comptes » de l'admin) pour ne pas attendre.
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { admin, authAdmin, db } from "../lib/admin";
import { requireSignedIn, requireSuperAdmin } from "../lib/auth";
import { writeAuditLog } from "../lib/audit";

export interface RepairResult {
  scanned: number;
  repaired: string[];
}

export async function repairOrphanAccounts(): Promise<RepairResult> {
  const repaired: string[] = [];
  let scanned = 0;
  let pageToken: string | undefined;
  do {
    const page = await authAdmin.listUsers(1000, pageToken);
    pageToken = page.pageToken;
    for (const user of page.users) {
      scanned += 1;
      const ref = db.collection("users").doc(user.uid);
      if ((await ref.get()).exists) continue;

      const [profile, lead] = await Promise.all([
        db.collection("driver_profiles").doc(user.uid).get(),
        db.collection("driver_leads").doc(user.uid).get(),
      ]);
      const claimRoles = Array.isArray(user.customClaims?.roles) ? (user.customClaims!.roles as string[]) : [];
      const isDriver = profile.exists || lead.exists || claimRoles.includes("driver");
      const roles = claimRoles.length > 0 ? claimRoles : isDriver ? ["customer", "driver"] : ["customer"];
      if (isDriver && !roles.includes("driver")) roles.push("driver");

      const createdAt = user.metadata.creationTime
        ? admin.firestore.Timestamp.fromDate(new Date(user.metadata.creationTime))
        : admin.firestore.Timestamp.now();

      await ref.set({
        uid: user.uid,
        email: user.email ?? null,
        full_name: user.displayName ?? "",
        roles,
        role: roles[0],
        created_at: createdAt,
        is_disabled: user.disabled === true,
        email_verified: user.emailVerified === true,
        ...(isDriver && !profile.exists ? { driver_signup: "started" } : {}),
        // Trace : fiche recréée après coup, pas écrite par l'inscription.
        profile_repaired_at: admin.firestore.FieldValue.serverTimestamp(),
      });
      repaired.push(user.uid);
    }
  } while (pageToken);
  return { scanned, repaired };
}

/** Toutes les heures : les fiches manquantes réapparaissent d'elles-mêmes. */
export const repairOrphanAccountsHourly = onSchedule(
  { schedule: "every 60 minutes", timeZone: "America/Toronto", timeoutSeconds: 300 },
  async () => {
    const result = await repairOrphanAccounts();
    if (result.repaired.length > 0) {
      console.log("[comptes] fiches recréées", { scanned: result.scanned, repaired: result.repaired });
    }
  }
);

/** Super-admin : lancer le rattrapage tout de suite. */
export const repairOrphanAccountsNow = onCall(async (request) => {
  const ctx = requireSignedIn(request);
  requireSuperAdmin(ctx);
  const result = await repairOrphanAccounts();
  await writeAuditLog({
    actorUserId: ctx.uid,
    actorRole: ctx.role ?? "super_admin",
    action: "orphan_accounts_repaired",
    sourceFunction: "repairOrphanAccountsNow",
    targetId: "users",
    metadata: { scanned: result.scanned, repaired: result.repaired.length },
  });
  return result;
});
