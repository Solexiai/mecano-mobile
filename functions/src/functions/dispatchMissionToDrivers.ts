// -----------------------------------------------------------------------------
// dispatchMissionToDrivers — déclenchée automatiquement (Firestore trigger)
// à la création d'une mission `searching_driver`, recherche les chauffeurs
// éligibles SANS scanner toute la collection (voir docs/FIRESTORE_ARCHITECTURE.md,
// section "Dispatch — comment on évite un scan complet") et crée une
// `delivery_offers/{id}` par chauffeur candidat.
//
// Requête utilisée (nécessite l'index composite #1 de firestore.indexes.json:
// driver_profiles(status, online_status, documents_all_valid, current_geohash)) :
//   where status == 'approved'
//   where online_status == 'online'
//   where documents_all_valid == true
//   where current_geohash >= prefix && < prefix+upperBound
// Le filtre `accepted_vehicle_categories array-contains <categorie>` est
// appliqué EN MÉMOIRE après la requête (voir docs/FIRESTORE_INDEXES.md,
// section "non indexées par design") plutôt que dans un index composite
// supplémentaire, car Firestore ne permet pas de combiner efficacement
// array-contains avec plusieurs autres filtres d'égalité/plage, et le lot
// pré-filtré par zone/statut reste toujours petit.
// -----------------------------------------------------------------------------

import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { admin, db } from "../lib/admin";
import { geohashUpperBound } from "../lib/geohash";
import { DeliveryMissionDoc, MissionStatuses } from "../lib/types";

const OFFER_EXPIRY_MS = 45_000; // 45s pour accepter avant que l'offre expire
const DISPATCH_ZONE_PREFIX_LENGTH = 3; // ~150km — large filtre initial, affiné ensuite côté client/app par distance réelle
const MAX_CANDIDATE_DRIVERS = 15;

async function dispatchMission(missionId: string, mission: DeliveryMissionDoc): Promise<void> {
  const zonePrefix = mission.dispatch_zone_geohash.slice(0, DISPATCH_ZONE_PREFIX_LENGTH);

  const candidatesSnap = await db
    .collection("driver_profiles")
    .where("status", "==", "approved")
    .where("online_status", "==", "online")
    .where("documents_all_valid", "==", true)
    .where("current_geohash", ">=", zonePrefix)
    .where("current_geohash", "<", geohashUpperBound(zonePrefix))
    .limit(50) // garde-fou — filtré ensuite en mémoire, jamais un scan complet
    .get();

  const eligible = candidatesSnap.docs
    .filter((d) =>
      (d.data().accepted_vehicle_categories as string[]).includes(mission.required_vehicle_category)
    )
    .slice(0, MAX_CANDIDATE_DRIVERS);

  if (eligible.length === 0) {
    // Aucun chauffeur dispo dans la zone immédiate — laissé en
    // 'searching_driver' ; un job planifié pourra élargir le rayon de
    // recherche (hors scope de ce squelette).
    return;
  }

  const now = admin.firestore.Timestamp.now();
  const expiresAt = admin.firestore.Timestamp.fromMillis(now.toMillis() + OFFER_EXPIRY_MS);

  const batch = db.batch();
  for (const driverDoc of eligible) {
    const offerRef = db.collection("delivery_offers").doc();
    batch.set(offerRef, {
      mission_id: missionId,
      driver_id: driverDoc.id,
      offered_at: now,
      expires_at: expiresAt,
      status: "pending",
    });
  }
  batch.update(db.collection("delivery_requests").doc(missionId), {
    status: MissionStatuses.OFFERED,
  });
  await batch.commit();
}

/** Déclenché à la création d'une mission (créée par createDeliveryRequest()). */
export const onMissionCreatedDispatch = onDocumentCreated(
  "delivery_requests/{missionId}",
  async (event) => {
    const mission = event.data?.data() as DeliveryMissionDoc | undefined;
    if (!mission || mission.status !== MissionStatuses.SEARCHING_DRIVER) return;
    await dispatchMission(event.params.missionId, mission);
  }
);

/**
 * Re-déclenche le dispatch si une mission repasse à `searching_driver`
 * (ex: toutes les offres ont expiré sans acceptation — logique de retry
 * gérée par un job planifié qui remet le statut à `searching_driver`, hors
 * scope détaillé de ce squelette).
 */
export const onMissionReopenedDispatch = onDocumentUpdated(
  "delivery_requests/{missionId}",
  async (event) => {
    const before = event.data?.before.data() as DeliveryMissionDoc | undefined;
    const after = event.data?.after.data() as DeliveryMissionDoc | undefined;
    if (!after) return;
    if (before?.status !== MissionStatuses.SEARCHING_DRIVER && after.status === MissionStatuses.SEARCHING_DRIVER) {
      await dispatchMission(event.params.missionId, after);
    }
  }
);
