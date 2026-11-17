import { onCall } from "firebase-functions/v2/https";
import { db } from "../lib/admin";
import { requireAdminOrAbove, requireSignedIn } from "../lib/auth";
import { failedPrecondition, invalidArgument, notFound } from "../lib/errors";
import { writeAuditLog } from "../lib/audit";
import { countActiveDriverMissions, purgeDriverProfile } from "../lib/driverProfilePurge";

export interface DeleteDriverProfileRequest {
  driverId: string;
}

/**
 * Supprime uniquement le dossier chauffeur. Le compte client et son historique
 * sont conservés afin de ne jamais effacer des commandes ou paiements.
 * Pour effacer le compte au complet : `deleteCustomerAccount` (super-admin).
 *
 * 2026-11-17 (Daniel) : un admin peut retirer son PROPRE dossier chauffeur
 * (ex. compte de test) ; il sera déconnecté et devra se reconnecter.
 */
export const deleteDriverProfile = onCall<DeleteDriverProfileRequest>(async (request) => {
  const ctx = requireSignedIn(request);
  requireAdminOrAbove(ctx);
  const driverId = request.data.driverId?.trim();
  if (!driverId) throw invalidArgument("driverId est requis.");

  const driverRef = db.collection("driver_profiles").doc(driverId);
  const driverSnap = await driverRef.get();
  if (!driverSnap.exists) {
    throw notFound(`driver_profiles/${driverId} introuvable.`);
  }

  if ((await countActiveDriverMissions(driverId)) > 0) {
    throw failedPrecondition(
      "Ce chauffeur possède une mission active. Terminez ou annulez-la avant de supprimer son dossier."
    );
  }

  const result = await purgeDriverProfile(driverId, { keepAuth: true });

  await writeAuditLog({
    actorUserId: ctx.uid,
    actorRole: ctx.role ?? "admin",
    action: "driver_profile_deleted",
    sourceFunction: "deleteDriverProfile",
    targetId: driverId,
    metadata: {
      ...result,
      selfService: driverId === ctx.uid,
      preservedCustomerAccount: true,
    },
  });

  return {
    success: true,
    driverId,
    preservedCustomerAccount: true,
    remainingRoles: result.remainingRoles,
  };
});
