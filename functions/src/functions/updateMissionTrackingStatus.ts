// -----------------------------------------------------------------------------
// updateMissionTrackingStatus — Cloud Function callable (driver assigné
// uniquement).
//
// Gère les transitions de statut INTERMÉDIAIRES du trajet (celles qui ne
// déclenchent AUCUNE écriture financière, contrairement à completePickup()
// et completeDelivery()) :
//   assigned            -> driver_to_pickup
//   driver_to_pickup    -> arrived_at_pickup
//   picked_up           -> in_transit
//   in_transit          -> arrived_at_dropoff
//
// RÈGLE CRITIQUE : chaque transition n'est autorisée QUE depuis son statut
// prédécesseur exact (machine à états stricte, pas de saut de statut), et
// UNIQUEMENT par le chauffeur assigné à la mission (mission.driver_id ==
// ctx.uid) — jamais par le client ni par un autre chauffeur. Le
// ramassage/livraison eux-mêmes restent gérés par completePickup()/
// completeDelivery() (financier), non par cette fonction.
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { requireSignedIn } from "../lib/auth";
import { failedPrecondition, invalidArgument, notFound, permissionDenied } from "../lib/errors";
import { writeAuditLog } from "../lib/audit";
import { MissionStatus, MissionStatuses } from "../lib/types";

export interface UpdateMissionTrackingStatusRequest {
  missionId: string;
  targetStatus: MissionStatus;
}

/** Transitions valides : statut cible -> statut(s) prédécesseur(s) autorisé(s). */
const ALLOWED_TRANSITIONS: Partial<Record<MissionStatus, MissionStatus[]>> = {
  [MissionStatuses.DRIVER_TO_PICKUP]: [MissionStatuses.ASSIGNED],
  [MissionStatuses.ARRIVED_AT_PICKUP]: [MissionStatuses.DRIVER_TO_PICKUP],
  [MissionStatuses.IN_TRANSIT]: [MissionStatuses.PICKED_UP],
  [MissionStatuses.ARRIVED_AT_DROPOFF]: [MissionStatuses.IN_TRANSIT],
};

const EVENT_TYPE_BY_STATUS: Partial<Record<MissionStatus, string>> = {
  [MissionStatuses.DRIVER_TO_PICKUP]: "driver_to_pickup",
  [MissionStatuses.ARRIVED_AT_PICKUP]: "arrived_at_pickup",
  [MissionStatuses.IN_TRANSIT]: "in_transit",
  [MissionStatuses.ARRIVED_AT_DROPOFF]: "arrived_at_dropoff",
};

export const updateMissionTrackingStatus = onCall<UpdateMissionTrackingStatusRequest>(
  async (request) => {
    const ctx = requireSignedIn(request);
    const { missionId, targetStatus } = request.data;
    if (!missionId) throw invalidArgument("missionId est requis.");
    if (!targetStatus || !ALLOWED_TRANSITIONS[targetStatus]) {
      throw invalidArgument(
        `targetStatus invalide. Valeurs acceptées: ${Object.keys(ALLOWED_TRANSITIONS).join(", ")}.`
      );
    }

    const missionRef = db.collection("delivery_requests").doc(missionId);

    await db.runTransaction(async (tx) => {
      const snap = await tx.get(missionRef);
      if (!snap.exists) throw notFound(`delivery_requests/${missionId} introuvable.`);
      const mission = snap.data()!;

      if (mission.driver_id !== ctx.uid) {
        throw permissionDenied("Seul le chauffeur assigné peut mettre à jour le statut de cette mission.");
      }

      const allowedPredecessors = ALLOWED_TRANSITIONS[targetStatus]!;
      if (!allowedPredecessors.includes(mission.status)) {
        throw failedPrecondition(
          `Transition invalide : impossible de passer de '${mission.status}' à '${targetStatus}'.`
        );
      }

      const now = admin.firestore.Timestamp.now();
      tx.update(missionRef, { status: targetStatus });

      const eventRef = missionRef.collection("tracking_events").doc();
      tx.set(eventRef, {
        event_type: EVENT_TYPE_BY_STATUS[targetStatus],
        occurred_at: now,
        metadata: {},
      });
    });

    await writeAuditLog({
      actorUserId: ctx.uid,
      actorRole: "driver",
      action: "mission_status_updated",
      sourceFunction: "updateMissionTrackingStatus",
      targetId: missionId,
      metadata: { targetStatus },
    });

    return { success: true, missionId, status: targetStatus };
  }
);
