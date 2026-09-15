import { onCall } from "firebase-functions/v2/https";
import { admin, authAdmin, db } from "../lib/admin";
import { requireAdminOrAbove, requireSignedIn } from "../lib/auth";
import { failedPrecondition, invalidArgument, notFound } from "../lib/errors";
import { writeAuditLog } from "../lib/audit";
import { MissionStatuses, PlatformRoles } from "../lib/types";

export interface DeleteDriverProfileRequest {
  driverId: string;
}

const ACTIVE_MISSION_STATUSES = new Set<string>([
  MissionStatuses.ASSIGNED,
  MissionStatuses.DRIVER_TO_PICKUP,
  MissionStatuses.ARRIVED_AT_PICKUP,
  MissionStatuses.PICKED_UP,
  MissionStatuses.IN_TRANSIT,
  MissionStatuses.ARRIVED_AT_DROPOFF,
]);

/**
 * Supprime uniquement le dossier chauffeur. Le compte client et son historique
 * sont conservés afin de ne jamais effacer des commandes ou paiements.
 */
export const deleteDriverProfile = onCall<DeleteDriverProfileRequest>(async (request) => {
  const ctx = requireSignedIn(request);
  requireAdminOrAbove(ctx);
  const driverId = request.data.driverId?.trim();
  if (!driverId) throw invalidArgument("driverId est requis.");
  if (driverId === ctx.uid) {
    throw failedPrecondition("Vous ne pouvez pas supprimer votre propre dossier chauffeur.");
  }

  const driverRef = db.collection("driver_profiles").doc(driverId);
  const driverSnap = await driverRef.get();
  if (!driverSnap.exists) {
    throw notFound(`driver_profiles/${driverId} introuvable.`);
  }

  const missions = await db
    .collection("delivery_requests")
    .where("driver_id", "==", driverId)
    .limit(100)
    .get();
  const hasActiveMission = missions.docs.some((doc) =>
    ACTIVE_MISSION_STATUSES.has(String(doc.data().status))
  );
  if (hasActiveMission) {
    throw failedPrecondition(
      "Ce chauffeur possède une mission active. Terminez ou annulez-la avant de supprimer son dossier."
    );
  }

  const [documents, offers, notes, userRecord] = await Promise.all([
    db.collection("driver_documents").where("driver_id", "==", driverId).get(),
    db.collection("delivery_offers").where("driver_id", "==", driverId).get(),
    db.collection("driver_internal_notes").where("driver_id", "==", driverId).get(),
    authAdmin.getUser(driverId),
  ]);

  const batch = db.batch();
  documents.docs.forEach((doc) => batch.delete(doc.ref));
  offers.docs.forEach((doc) => batch.delete(doc.ref));
  notes.docs.forEach((doc) => batch.delete(doc.ref));
  batch.delete(driverRef);

  const currentRoles = Array.isArray(userRecord.customClaims?.roles)
    ? (userRecord.customClaims!.roles as string[])
    : [];
  const remainingRoles = currentRoles.filter((role) => role !== PlatformRoles.DRIVER);
  const safeRoles = remainingRoles.length > 0 ? remainingRoles : [PlatformRoles.CUSTOMER];

  batch.set(
    db.collection("users").doc(driverId),
    {
      roles: safeRoles,
      role: safeRoles[0],
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  await batch.commit();

  await authAdmin.setCustomUserClaims(driverId, {
    role: safeRoles[0],
    roles: safeRoles,
  });
  await authAdmin.revokeRefreshTokens(driverId);
  await admin.storage().bucket().deleteFiles({
    prefix: `driver_documents/${driverId}/`,
  }).catch((error: unknown) => {
    console.warn("driver_document_storage_cleanup_failed", {
      driverId,
      error: String(error),
    });
  });

  await writeAuditLog({
    actorUserId: ctx.uid,
    actorRole: ctx.role ?? "admin",
    action: "driver_profile_deleted",
    sourceFunction: "deleteDriverProfile",
    targetId: driverId,
    metadata: {
      documentsDeleted: documents.size,
      offersDeleted: offers.size,
      notesDeleted: notes.size,
      preservedCustomerAccount: true,
      remainingRoles: safeRoles,
    },
  });

  return {
    success: true,
    driverId,
    preservedCustomerAccount: true,
    remainingRoles: safeRoles,
  };
});
