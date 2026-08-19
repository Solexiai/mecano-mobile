// -----------------------------------------------------------------------------
// onMissionEndedClearTracking — Firestore trigger (Phase 5, partie 2).
//
// PROBLÈME RÉSOLU :
// `completeDelivery()` efface `driver_locations/{driverId}.active_delivery_id`
// à la fin NORMALE d'une mission (livraison confirmée). Mais l'ANNULATION
// d'une mission n'passe PAS par une Cloud Function : c'est une écriture
// client directe permise par `firestore.rules`
// (`delivery_requests/{missionId}` — le customer propriétaire peut passer
// `status` à `cancelled` une fois la mission assignée). Idem pour
// `disputed`/`refunded`, qui ne passent par aucune fonction dédiée dans ce
// squelette. Sans ce trigger, `active_delivery_id` resterait bloqué sur une
// mission terminée/annulée :
//   1. recordTrackingPoint() continuerait à écrire de l'historique GPS
//      rattaché à une mission qui n'est plus active (pollution).
//   2. La règle de lecture `driver_locations/{driverId}` resterait
//      artificiellement vraie pour ce client précis (fuite de tracking
//      au-delà de la fin réelle de la relation contractuelle).
//
// Se déclenche sur TOUTE transition de `delivery_requests/{missionId}` vers
// un statut terminal non `completed` (cancelled/disputed/refunded — `completed`
// est déjà géré par completeDelivery() lui-même, ne pas dupliquer l'écriture)
// et, si un chauffeur était assigné, remet
// `driver_locations/{driverId}.active_delivery_id` à `null` — MAIS
// uniquement si ce driver_locations pointe encore vers CETTE mission
// précise (évite d'écraser un active_delivery_id légitime si le chauffeur a
// déjà enchaîné une nouvelle mission entre-temps).
// -----------------------------------------------------------------------------

import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { db } from "../lib/admin";
import { DeliveryMissionDoc, MissionStatuses } from "../lib/types";

const TERMINAL_STATUSES_CLEARING_TRACKING: string[] = [
  MissionStatuses.CANCELLED,
  MissionStatuses.DISPUTED,
  MissionStatuses.REFUNDED,
];

export const onMissionEndedClearTracking = onDocumentUpdated(
  "delivery_requests/{missionId}",
  async (event) => {
    const before = event.data?.before.data() as DeliveryMissionDoc | undefined;
    const after = event.data?.after.data() as DeliveryMissionDoc | undefined;
    if (!after) return;

    const missionId = event.params.missionId;
    const wasAlreadyTerminal =
      !!before && TERMINAL_STATUSES_CLEARING_TRACKING.includes(before.status);
    const isNowTerminal = TERMINAL_STATUSES_CLEARING_TRACKING.includes(after.status);

    if (wasAlreadyTerminal || !isNowTerminal) return; // pas une transition ENTRANTE vers un statut terminal
    if (!after.driver_id) return; // aucune mission jamais assignée -> rien à nettoyer

    const locationRef = db.collection("driver_locations").doc(after.driver_id);
    const locationSnap = await locationRef.get();
    if (!locationSnap.exists) return;
    if (locationSnap.data()!.active_delivery_id !== missionId) return; // déjà réassigné ailleurs, ne pas écraser

    await locationRef.set({ active_delivery_id: null }, { merge: true });
  }
);
