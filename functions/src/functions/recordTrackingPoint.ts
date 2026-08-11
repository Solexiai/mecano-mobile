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
import { requireSignedIn } from "../lib/auth";
import { invalidArgument, permissionDenied } from "../lib/errors";
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
  const { latitude, longitude, accuracy, heading, speed } = request.data;

  if (typeof latitude !== "number" || typeof longitude !== "number") {
    throw invalidArgument("latitude et longitude sont requis.");
  }

  const driverId = ctx.uid;
  const driverProfileRef = db.collection("driver_profiles").doc(driverId);
  const locationRef = db.collection("driver_locations").doc(driverId);

  const driverProfileSnap = await driverProfileRef.get();
  if (!driverProfileSnap.exists) {
    throw permissionDenied("Profil chauffeur introuvable.");
  }

  const now = admin.firestore.Timestamp.now();
  const geohash = encodeGeohash(latitude, longitude, 6);

  // 1. Position courante (document unique, toujours écrasé).
  const currentLocationSnap = await locationRef.get();
  const activeDeliveryId = currentLocationSnap.exists
    ? (currentLocationSnap.data()!.active_delivery_id as string | null)
    : null;

  await locationRef.set(
    {
      driver_id: driverId,
      latitude,
      longitude,
      accuracy: accuracy ?? null,
      heading: heading ?? null,
      speed: speed ?? null,
      updated_at: now,
      active_delivery_id: activeDeliveryId,
    },
    { merge: true }
  );

  // 2. Dénormalisation dispatch.
  await driverProfileRef.update({ current_geohash: geohash });

  // 3. Historique — UNIQUEMENT si une mission active existe réellement.
  if (activeDeliveryId) {
    const missionSnap = await db.collection("delivery_requests").doc(activeDeliveryId).get();
    if (missionSnap.exists && missionSnap.data()!.driver_id === driverId) {
      await db
        .collection("driver_locations")
        .doc(driverId)
        .collection("history")
        .add({
          delivery_id: activeDeliveryId,
          latitude,
          longitude,
          recorded_at: now,
        });
    }
  }

  return { success: true };
});
