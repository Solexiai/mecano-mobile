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
