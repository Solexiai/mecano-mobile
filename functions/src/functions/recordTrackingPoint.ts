// -----------------------------------------------------------------------------
// recordTrackingPoint — Cloud Function callable (driver assigné uniquement).
//
// 🔒 Seul point d'entrée pour écrire dans
// `driver_locations/{driverId}/history/{eventId}` (firestore.rules interdit
// tout write direct sur cette sous-collection). N'écrit QUE si une mission
// active existe réellement pour ce chauffeur — empêche un chauffeur
// d'alimenter un historique sans mission réelle et permet d'appliquer la
// politique de rétention côté serveur de façon fiable (voir
// cleanupExpiredTrackingHistory ci-dessous).
//
// Met aussi à jour la position COURANTE (`driver_locations/{driverId}`,
// document unique, écriture fréquente — voir docs/FIRESTORE_ARCHITECTURE.md
// #5) ainsi que `driver_profiles.current_geohash` (dénormalisé pour le
// dispatch, voir #2).
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { requireAnyRole, requireSignedIn } from "../lib/auth";
import { DriverStatuses, MissionStatuses, PlatformRoles } from "../lib/types";
import { SuspensionModes } from "../lib/driverSuspensionPolicy";
import { failedPrecondition, invalidArgument, permissionDenied } from "../lib/errors";
import { encodeGeohash } from "../lib/geohash";

export interface RecordTrackingPointRequest {
  latitude: number;
  longitude: number;
  accuracy?: number;
  heading?: number;
  speed?: number;
}

export const recordTrackingPoint = onCall<RecordTrackingPointRequest>(async (request) => {
  const ctx = requireSignedIn(request);
  // R-K-03-A : un profil Firestore seul ne confère pas le rôle chauffeur.
  requireAnyRole(ctx, [PlatformRoles.DRIVER]);
  const { latitude, longitude, accuracy, heading, speed } = request.data;

  if (typeof latitude !== "number" || typeof longitude !== "number") {
    throw invalidArgument("latitude et longitude sont requis.");
  }

  const driverId = ctx.uid;
  const driverProfileRef = db.collection("driver_profiles").doc(driverId);
  const locationRef = db.collection("driver_locations").doc(driverId);

  const geohash = encodeGeohash(latitude, longitude, 6);
  const historyRef = locationRef.collection("history").doc();
  const activeStatuses: string[] = [
    MissionStatuses.ASSIGNED,
    MissionStatuses.DRIVER_TO_PICKUP,
    MissionStatuses.ARRIVED_AT_PICKUP,
    MissionStatuses.PICKED_UP,
    MissionStatuses.IN_TRANSIT,
    MissionStatuses.ARRIVED_AT_DROPOFF,
  ];

  // Une reprise Firestore doit réévaluer profil/mission sans rattacher une
  // ancienne mesure à une NOUVELLE assignation observée après le premier essai.
  let observedAssignment = false;
  let firstDeliveryId: string | null = null;
  await db.runTransaction(async (tx) => {
    const [driverProfileSnap, currentLocationSnap] = await Promise.all([
      tx.get(driverProfileRef),
      tx.get(locationRef),
    ]);
    if (!driverProfileSnap.exists) {
      throw permissionDenied("Profil chauffeur introuvable.");
    }
    const profile = driverProfileSnap.data()!;
    const ordinarySuspension = profile.status === DriverStatuses.SUSPENDED &&
      profile.suspension_mode === SuspensionModes.ORDINARY;
    if (profile.status !== DriverStatuses.APPROVED && !ordinarySuspension) {
      throw permissionDenied("Chauffeur non approuvé ou suspendu d'urgence : GPS refusé.");
    }
    const activeDeliveryId = (currentLocationSnap.data()?.active_delivery_id ?? null) as string | null;
    if (observedAssignment && activeDeliveryId !== firstDeliveryId) {
      throw failedPrecondition("L'assignation a changé pendant le rapport GPS. Transmettez une nouvelle position.");
    }
    firstDeliveryId = activeDeliveryId;
    observedAssignment = true;
    // Ordinary suspension allows existing assigned mission GPS only.
    // It must not make the driver discoverable/online without a mission.
    if (ordinarySuspension && !activeDeliveryId) {
      throw permissionDenied("Suspension ordinaire : suivi GPS sans mission interdit.");
    }

    // Toutes les lectures précèdent les écritures ; une fin de mission ou une
    // suspension concurrente invalide l'essai et impose une nouvelle vérification.
    if (activeDeliveryId) {
      const missionSnap = await tx.get(db.collection("delivery_requests").doc(activeDeliveryId));
      if (!missionSnap.exists) {
        throw failedPrecondition("La mission liée au suivi GPS est introuvable.");
      }
      const mission = missionSnap.data()!;
      if (mission.driver_id !== driverId) {
        throw permissionDenied("Cette mission n'est pas assignée à ce chauffeur.");
      }
      if (!activeStatuses.includes(mission.status)) {
        throw failedPrecondition("Le suivi GPS de cette mission n'est plus actif.");
      }
    }

    const now = admin.firestore.Timestamp.now();
    tx.set(locationRef, {
      driver_id: driverId,
      latitude,
      longitude,
      accuracy: accuracy ?? null,
      heading: heading ?? null,
      speed: speed ?? null,
      updated_at: now,
      // Ne jamais recopier un lien lu : l'assignation appartient au serveur.
      // Le document nouvellement créé conserve le contrat sans mission.
      ...(!currentLocationSnap.exists ? { active_delivery_id: null } : {}),
    }, { merge: true });
    tx.update(driverProfileRef, { current_geohash: geohash });
    if (activeDeliveryId) {
      tx.set(historyRef, {
        delivery_id: activeDeliveryId,
        latitude,
        longitude,
        recorded_at: now,
      });
    }
  });

  return { success: true };
});
