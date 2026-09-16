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
import type { UserRecord } from "firebase-admin/auth";
import { admin, authAdmin, db } from "../lib/admin";
import { requireSignedIn, requireSuperAdmin } from "../lib/auth";
import { failedPrecondition, invalidArgument, notFound } from "../lib/errors";
import { writeAuditLog } from "../lib/audit";
import { PlatformRole, PlatformRoles } from "../lib/types";

const VALID_ROLES: PlatformRole[] = Object.values(PlatformRoles);

function isAuthUserNotFound(error: unknown): boolean {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    (error as { code?: string }).code === "auth/user-not-found"
  );
}

function validClaimRoles(user: UserRecord): PlatformRole[] {
  const rawRoles = Array.isArray(user.customClaims?.roles)
    ? user.customClaims?.roles
    : typeof user.customClaims?.role === "string"
      ? [user.customClaims.role]
      : [];
  return rawRoles.filter((role): role is PlatformRole =>
    VALID_ROLES.includes(role as PlatformRole)
  );
}

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

  const sourceUserRef = db.collection("users").doc(targetUid);
  const sourceDriverRef = db.collection("driver_profiles").doc(targetUid);
  const [sourceUserSnap, sourceDriverSnap] = await Promise.all([
    sourceUserRef.get(),
    sourceDriverRef.get(),
  ]);

  let targetUser: UserRecord;
  let resolvedByEmail = false;
  try {
    targetUser = await authAdmin.getUser(targetUid);
  } catch (error) {
    if (!isAuthUserNotFound(error)) throw error;

    // Les anciens comptes de test peuvent conserver un document Firestore
    // sous un UID Auth supprimé/recréé. Le re-lien automatique est limité au
    // bouton client+chauffeur : il exige les deux documents source et ne peut
    // jamais servir à attribuer un rôle administratif par simple courriel.
    if (
      !roles.includes(PlatformRoles.DRIVER) ||
      !sourceUserSnap.exists ||
      !sourceDriverSnap.exists
    ) {
      throw notFound(
        "Ce dossier n'est relié à aucun compte de connexion Firebase actif."
      );
    }

    const sourceEmail = (sourceUserSnap.get("email") as string | undefined)
      ?.trim()
      .toLowerCase();
    if (!sourceEmail) {
      throw failedPrecondition(
        "Le dossier ne contient aucun courriel permettant de retrouver le compte de connexion."
      );
    }

    try {
      targetUser = await authAdmin.getUserByEmail(sourceEmail);
    } catch (lookupError) {
      if (isAuthUserNotFound(lookupError)) {
        throw notFound(
          "Aucun compte de connexion Firebase ne correspond au courriel de ce dossier."
        );
      }
      throw lookupError;
    }

    if (targetUser.email?.trim().toLowerCase() !== sourceEmail) {
      throw failedPrecondition(
        "Le courriel du dossier ne correspond pas au compte de connexion trouvé."
      );
    }
    resolvedByEmail = targetUser.uid !== targetUid;
  }

  const resolvedUid = targetUser.uid;
  const effectiveRoles = resolvedByEmail
    ? [...new Set([...validClaimRoles(targetUser), ...roles])]
    : roles;

  const migration = resolvedByEmail
    ? await (async () => {
        const resolvedUserRef = db.collection("users").doc(resolvedUid);
        const resolvedDriverRef = db.collection("driver_profiles").doc(resolvedUid);
        const [
          resolvedUserSnap,
          resolvedDriverSnap,
          driverDocuments,
          driverVehicles,
          assignedMissions,
        ] = await Promise.all([
          resolvedUserRef.get(),
          resolvedDriverRef.get(),
          db.collection("driver_documents").where("driver_id", "==", targetUid).get(),
          db.collection("driver_vehicles").where("driver_id", "==", targetUid).get(),
          db.collection("delivery_requests").where("driver_id", "==", targetUid).limit(1).get(),
        ]);

        if (!assignedMissions.empty) {
          throw failedPrecondition(
            "Ce dossier possède déjà une mission. Sa migration doit être vérifiée manuellement."
          );
        }
        if (driverDocuments.size + driverVehicles.size > 440) {
          throw failedPrecondition(
            "Ce dossier contient trop d'éléments pour une migration automatique sécurisée."
          );
        }

        return {
          resolvedUserRef,
          resolvedDriverRef,
          resolvedUserSnap,
          resolvedDriverSnap,
          driverDocuments,
          driverVehicles,
        };
      })()
    : null;

  // Les claims Firebase Auth demeurent la source de vérité des permissions.
  await authAdmin.setCustomUserClaims(resolvedUid, {
    role: effectiveRoles[0],
    roles: effectiveRoles,
  });
  await authAdmin.revokeRefreshTokens(resolvedUid);

  const batch = db.batch();
  const now = admin.firestore.FieldValue.serverTimestamp();
  if (migration) {
    const sourceUser = sourceUserSnap.data() ?? {};
    const resolvedUser = migration.resolvedUserSnap.data() ?? {};
    batch.set(
      migration.resolvedUserRef,
      {
        ...sourceUser,
        ...resolvedUser,
        uid: resolvedUid,
        email: targetUser.email ?? sourceUser.email,
        roles: effectiveRoles,
        legacy_uids: admin.firestore.FieldValue.arrayUnion(targetUid),
        updated_at: now,
      },
      { merge: true }
    );
    batch.set(
      sourceUserRef,
      {
        roles: effectiveRoles,
        canonical_uid: resolvedUid,
        migrated_to_uid: resolvedUid,
        updated_at: now,
      },
      { merge: true }
    );

    const sourceDriver = sourceDriverSnap.data() ?? {};
    if (!migration.resolvedDriverSnap.exists) {
      batch.set(
        migration.resolvedDriverRef,
        {
          ...sourceDriver,
          uid: resolvedUid,
          legacy_uid: targetUid,
          updated_at: now,
        },
        { merge: true }
      );
    }
    batch.set(
      sourceDriverRef,
      {
        canonical_uid: resolvedUid,
        migrated_to_uid: resolvedUid,
        legacy_status: sourceDriver.status ?? null,
        status: "inactive",
        online_status: "offline",
        updated_at: now,
      },
      { merge: true }
    );
    migration.driverDocuments.docs.forEach((doc) => {
      batch.update(doc.ref, { driver_id: resolvedUid, updated_at: now });
    });
    migration.driverVehicles.docs.forEach((doc) => {
      batch.update(doc.ref, { driver_id: resolvedUid, updated_at: now });
    });
  } else {
    batch.set(sourceUserRef, { roles: effectiveRoles, updated_at: now }, { merge: true });
  }
  await batch.commit();

  await writeAuditLog({
    actorUserId: ctx.uid,
    actorRole: "super_admin",
    action: "setUserRole",
    sourceFunction: "setUserRole",
    targetId: resolvedUid,
    metadata: {
      sourceUid: targetUid,
      resolvedUid,
      resolvedByEmail,
      newRoles: effectiveRoles,
    },
  });

  return {
    success: true,
    targetUid: resolvedUid,
    sourceUid: targetUid,
    relinked: resolvedByEmail,
    roles: effectiveRoles,
    note: "Le client doit rafraîchir son jeton ou se reconnecter pour appliquer immédiatement les nouveaux rôles.",
  };
});
