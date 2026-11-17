// -----------------------------------------------------------------------------
// driverProfilePurge.ts — effacer le DOSSIER chauffeur d'un compte (Daniel,
// 2026-11-17). Partagé par `deleteDriverProfile` (le dossier seulement, le
// compte client reste) et `deleteCustomerAccount` (le compte au complet :
// dossier chauffeur d'abord, puis le reste).
//
// Part : driver_profiles/{uid}, ses documents, ses offres, ses notes internes,
// ses fichiers de documents dans Storage, et le rôle « driver » (claims +
// users/{uid}). Reste : ses livraisons comme chauffeur (preuves comptables).
// -----------------------------------------------------------------------------

import { admin, authAdmin, db } from "./admin";
import { PlatformRoles } from "./types";

/** Statuts où le chauffeur est en route : on n'efface pas son dossier. */
export const DRIVER_ACTIVE_MISSION_STATUSES = new Set<string>([
  "assigned",
  "driver_to_pickup",
  "arrived_at_pickup",
  "picked_up",
  "in_transit",
  "arrived_at_dropoff",
]);

export interface DriverPurgeResult {
  documentsDeleted: number;
  offersDeleted: number;
  notesDeleted: number;
  remainingRoles: string[];
}

/** Nombre de livraisons en cours où ce compte est le chauffeur. */
export async function countActiveDriverMissions(driverId: string): Promise<number> {
  const missions = await db
    .collection("delivery_requests")
    .where("driver_id", "==", driverId)
    .limit(100)
    .get();
  return missions.docs.filter((doc) => DRIVER_ACTIVE_MISSION_STATUSES.has(String(doc.data().status))).length;
}

/**
 * Efface le dossier chauffeur. Appelant responsable des vérifications
 * (droits, missions actives). Si le compte de connexion n'existe plus
 * (`keepAuth: false`), on ne touche ni aux claims ni aux jetons.
 */
export async function purgeDriverProfile(
  driverId: string,
  options: { keepAuth: boolean }
): Promise<DriverPurgeResult> {
  const driverRef = db.collection("driver_profiles").doc(driverId);
  const [documents, offers, notes, userRecord] = await Promise.all([
    db.collection("driver_documents").where("driver_id", "==", driverId).get(),
    db.collection("delivery_offers").where("driver_id", "==", driverId).get(),
    db.collection("driver_internal_notes").where("driver_id", "==", driverId).get(),
    options.keepAuth ? authAdmin.getUser(driverId).catch(() => null) : Promise.resolve(null),
  ]);

  const currentRoles = Array.isArray(userRecord?.customClaims?.roles)
    ? (userRecord!.customClaims!.roles as string[])
    : [];
  const remainingRoles = currentRoles.filter((role) => role !== PlatformRoles.DRIVER);
  const safeRoles = remainingRoles.length > 0 ? remainingRoles : [PlatformRoles.CUSTOMER];

  const refs = [
    ...documents.docs.map((d) => d.ref),
    ...offers.docs.map((d) => d.ref),
    ...notes.docs.map((d) => d.ref),
    driverRef,
  ];
  for (let i = 0; i < refs.length; i += 400) {
    const batch = db.batch();
    refs.slice(i, i + 400).forEach((ref) => batch.delete(ref));
    await batch.commit();
  }

  if (options.keepAuth) {
    await db.collection("users").doc(driverId).set(
      {
        roles: safeRoles,
        role: safeRoles[0],
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    if (userRecord) {
      await authAdmin.setCustomUserClaims(driverId, { role: safeRoles[0], roles: safeRoles });
      await authAdmin.revokeRefreshTokens(driverId);
    }
  }

  await admin
    .storage()
    .bucket()
    .deleteFiles({ prefix: `driver_documents/${driverId}/` })
    .catch((error: unknown) => {
      console.warn("driver_document_storage_cleanup_failed", { driverId, error: String(error) });
    });

  return {
    documentsDeleted: documents.size,
    offersDeleted: offers.size,
    notesDeleted: notes.size,
    remainingRoles: safeRoles,
  };
}
