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

import {requireCompatibleVehicle} from '../lib/bookingServer';
import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { requireSignedIn } from "../lib/auth";
import { failedPrecondition, invalidArgument, notFound, permissionDenied } from "../lib/errors";
import { writeAuditLog } from "../lib/audit";
import { requireMissionProgressPermission } from "../lib/driverSuspensionPolicy";
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

/**
 * Champ de timestamp métier dédié à écrire sur le document mission pour
 * chaque statut cible (Phase 5, partie 3 — "STATUTS TERRAIN"). Distinct de
 * tout `updated_at` générique pour permettre de reconstituer précisément le
 * parcours d'une mission (ETA futur, analytics, résolution de litige).
 */
const TIMESTAMP_FIELD_BY_STATUS: Partial<Record<MissionStatus, string>> = {
  [MissionStatuses.DRIVER_TO_PICKUP]: "driver_to_pickup_at",
  [MissionStatuses.ARRIVED_AT_PICKUP]: "arrived_at_pickup_at",
  [MissionStatuses.IN_TRANSIT]: "in_transit_at",
  [MissionStatuses.ARRIVED_AT_DROPOFF]: "arrived_at_dropoff_at",
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

      await requireMissionProgressPermission(tx, ctx.uid);
      let startScheduled = false;
      if(mission.scheduling && targetStatus===MissionStatuses.DRIVER_TO_PICKUP){
        const profile=(await tx.get(db.doc('driver_profiles/'+ctx.uid))).data();
        if(profile?.documents_all_valid!==true)throw failedPrecondition('Documents chauffeur à mettre à jour.');
        if(mission.assignment_mode!=='internal_test'&&!['authorized','captured'].includes(mission.payment_status))throw failedPrecondition('La validation de paiement doit être terminée avant le départ.');
        await requireCompatibleVehicle(ctx.uid,mission.booking_snapshot,tx,mission.assigned_vehicle_id);
        const nowMs=Date.now();
        if(Date.parse(mission.scheduling.start)>nowMs||Date.parse(mission.scheduling.end)<=nowMs)throw failedPrecondition('Le début doit se situer dans le créneau réservé.');
        const locationRef=db.doc('driver_locations/'+ctx.uid);
        const [location,agenda]=await Promise.all([tx.get(locationRef),tx.get(db.doc('driver_agendas/'+ctx.uid))]);
        const active=location.data()?.active_delivery_id;
        if(active&&active!==missionId){
          const other=await tx.get(db.doc('delivery_requests/'+active));
          if(other.exists&&!['completed','cancelled','payment_failed','refunded','disputed'].includes(other.data()!.status))throw failedPrecondition('Terminez la mission en cours avant de démarrer celle-ci.');
        }
        if(!agenda.exists)throw failedPrecondition('Agenda indisponible.');
        startScheduled=true;
      }
      const now = admin.firestore.Timestamp.now();
      if(startScheduled){
        tx.set(db.doc('driver_agendas/'+ctx.uid),{lock_version:admin.firestore.FieldValue.increment(1)},{merge:true});
        tx.set(db.doc('driver_locations/'+ctx.uid),{active_delivery_id:missionId},{merge:true});
        tx.update(db.doc('driver_profiles/'+ctx.uid),{online_status:'on_mission'});
        tx.update(missionRef,{schedule_state:'in_progress'});
      }
      const timestampField = TIMESTAMP_FIELD_BY_STATUS[targetStatus]!;
      tx.update(missionRef, { status: targetStatus, [timestampField]: now });

      const eventRef = missionRef.collection("tracking_events").doc();
      tx.set(eventRef, {
        event_type: EVENT_TYPE_BY_STATUS[targetStatus],
        actor_uid: ctx.uid,
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
