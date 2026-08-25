// -----------------------------------------------------------------------------
// setUserRole — Cloud Function callable, SUPER_ADMIN UNIQUEMENT.
//
// 🔒 SEUL point d'entrée pour élever/modifier les rôles d'un utilisateur.
// Écrit les Custom Claims Firebase Auth (source de vérité pour
// l'autorisation) PUIS met à jour le champ miroir `users/{uid}.roles`
// (affichage uniquement — voir docs/FIRESTORE_ARCHITECTURE.md, section
// Rôles). Journalise systématiquement dans audit_logs (changement de
// permission = action la plus sensible du système).
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { admin, authAdmin, db } from "../lib/admin";
import { requireSignedIn, requireSuperAdmin } from "../lib/auth";
import { invalidArgument } from "../lib/errors";
import { writeAuditLog } from "../lib/audit";
import { PlatformRole, PlatformRoles } from "../lib/types";

const VALID_ROLES: PlatformRole[] = Object.values(PlatformRoles);

export interface SetUserRoleRequest {
  targetUid: string;
  roles: PlatformRole[]; // ex: ['customer', 'driver']
}

export const setUserRole = onCall<SetUserRoleRequest>(async (request) => {
  const ctx = requireSignedIn(request);
  requireSuperAdmin(ctx);

  const { targetUid, roles } = request.data;
  if (!targetUid) throw invalidArgument("targetUid est requis.");
  if (!Array.isArray(roles) || roles.length === 0) {
    throw invalidArgument("roles doit être un tableau non vide.");
  }
  for (const r of roles) {
    if (!VALID_ROLES.includes(r)) {
      throw invalidArgument(`Rôle invalide: ${r}. Valeurs autorisées: ${VALID_ROLES.join(", ")}.`);
    }
  }

  // 1. Custom Claims (source de vérité pour l'autorisation).
  await authAdmin.setCustomUserClaims(targetUid, { role: roles[0], roles });

  // 1.b Durcissement défense-en-profondeur (Phase 7, Bloc E) : révoque les
  // refresh tokens existants pour forcer, dès la prochaine tentative de
  // rafraîchissement, l'obtention d'un NOUVEAU token reflétant les rôles à
  // jour. Ceci NE garantit PAS l'invalidation immédiate d'un ID token déjà
  // émis et non encore expiré (les callables `onCall` vérifient les tokens
  // via `verifyIdToken()` SANS `checkRevoked: true` — limitation du SDK
  // firebase-functions v2, confirmée par inspection ; un ID token existant
  // reste donc valide jusqu'à son expiration naturelle, ≤ 1h). C'est un
  // risque résiduel connu et documenté (voir docs/PHASE7_BUG_REPORT.md,
  // Bloc E) — hors de portée d'un correctif applicatif sans remplacer
  // `onCall` par un handler HTTPS personnalisé sur CHAQUE fonction
  // sensible, ce qui serait disproportionné pour ce correctif ciblé.
  await authAdmin.revokeRefreshTokens(targetUid);

  // 2. Miroir Firestore (affichage/requêtes UI uniquement).
  await db.collection("users").doc(targetUid).set(
    { roles, updated_at: admin.firestore.FieldValue.serverTimestamp() },
    { merge: true }
  );

  await writeAuditLog({
    actorUserId: ctx.uid,
    actorRole: "super_admin",
    action: "setUserRole",
    sourceFunction: "setUserRole",
    targetId: targetUid,
    metadata: { newRoles: roles },
  });

  return {
    success: true,
    targetUid,
    roles,
    note: "Le client doit appeler getIdTokenResult(forceRefresh: true) pour que le nouveau rôle prenne effet immédiatement.",
  };
});
