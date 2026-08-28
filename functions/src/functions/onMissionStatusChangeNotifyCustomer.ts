// -----------------------------------------------------------------------------
// onMissionStatusChangeNotifyCustomer — Firestore trigger (Phase 5, partie 3).
//
// CHOIX D'ARCHITECTURE (décision autonome) : notifications transactionnelles
// centralisées dans UN SEUL trigger `onDocumentUpdated` sur
// `delivery_requests/{missionId}`, plutôt que dupliquées dans chacune des
// Cloud Functions qui font transitionner le statut (acceptDelivery,
// updateMissionTrackingStatus, completePickup, completeDelivery, + annulation
// client directe). Avantages :
//   1. Un seul endroit à maintenir/tester pour la logique de notification.
//   2. Aucune modification (et donc aucun risque de régression) des 4
//      Cloud Functions déjà entièrement testées qui gèrent les transitions.
//   3. Couvre AUSSI l'annulation, qui n'est pas une Cloud Function mais une
//      écriture client directe permise par firestore.rules — un trigger sur
//      le document est le seul endroit qui peut l'intercepter de façon fiable
//      (voir onMissionEndedClearTracking.ts qui suit exactement le même
//      raisonnement pour le nettoyage du tracking GPS).
//
// Crée un document dans `users/{customer_id}/notifications/{notificationId}`
// (voir docs/FIRESTORE_ARCHITECTURE.md #19 pour le schéma canonique) à
// chaque transition de statut pertinente. Les notifications utilisent des
// clés i18n (`title_key`/`body_key`) résolues côté client dans
// lib/l10n/app_strings.dart, jamais de texte figé côté serveur (FR/EN/ES).
// -----------------------------------------------------------------------------

import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { admin, db } from "../lib/admin";
import { DeliveryMissionDoc, MissionStatuses } from "../lib/types";
import {
  logFinancialFailure,
  logFinancialSuccess,
  startFinancialOperationTimer,
} from "../lib/observability";

interface NotificationSpec {
  type: string;
  titleKey: string;
  bodyKey: string;
}

/** Statut de mission -> notification client à créer lors de l'ENTRÉE dans ce statut. */
const NOTIFICATION_BY_STATUS: Partial<Record<string, NotificationSpec>> = {
  [MissionStatuses.ASSIGNED]: {
    type: "driver_assigned",
    titleKey: "notif_driver_assigned_title",
    bodyKey: "notif_driver_assigned_body",
  },
  [MissionStatuses.DRIVER_TO_PICKUP]: {
    type: "driver_to_pickup",
    titleKey: "notif_driver_to_pickup_title",
    bodyKey: "notif_driver_to_pickup_body",
  },
  [MissionStatuses.ARRIVED_AT_PICKUP]: {
    type: "arrived_at_pickup",
    titleKey: "notif_arrived_at_pickup_title",
    bodyKey: "notif_arrived_at_pickup_body",
  },
  [MissionStatuses.PICKED_UP]: {
    type: "picked_up",
    titleKey: "notif_picked_up_title",
    bodyKey: "notif_picked_up_body",
  },
  [MissionStatuses.IN_TRANSIT]: {
    type: "in_transit",
    titleKey: "notif_in_transit_title",
    bodyKey: "notif_in_transit_body",
  },
  [MissionStatuses.ARRIVED_AT_DROPOFF]: {
    type: "arrived_at_dropoff",
    titleKey: "notif_arrived_at_dropoff_title",
    bodyKey: "notif_arrived_at_dropoff_body",
  },
  [MissionStatuses.COMPLETED]: {
    type: "completed",
    titleKey: "notif_completed_title",
    bodyKey: "notif_completed_body",
  },
  [MissionStatuses.CANCELLED]: {
    type: "cancelled",
    titleKey: "notif_cancelled_title",
    bodyKey: "notif_cancelled_body",
  },
};

export const onMissionStatusChangeNotifyCustomer = onDocumentUpdated(
  "delivery_requests/{missionId}",
  async (event) => {
    const before = event.data?.before.data() as DeliveryMissionDoc | undefined;
    const after = event.data?.after.data() as DeliveryMissionDoc | undefined;
    if (!after) return;

    const missionId = event.params.missionId;

    if (before && before.status === after.status) return; // pas une transition de statut
    const spec = NOTIFICATION_BY_STATUS[after.status];
    if (!spec) return; // statut sans notification définie (draft, quoted, searching_driver, offered, disputed, refunded, delivered)

    if (!after.customer_id) return; // garde-fou défensif

    const notifRef = db
      .collection("users")
      .doc(after.customer_id)
      .collection("notifications")
      .doc();

    // 🔒 Phase 7, Bloc Y (Y-1/Y-2) — "notification failure" était un GAP
    // silencieux avant ce correctif : une écriture Firestore échouée ici
    // (permission dénormalisée, timeout, quota) ne devait jamais faire
    // planter le trigger (le déclencheur n'a aucun mécanisme de retry
    // métier ni de statut affiché au client), mais restait totalement
    // invisible côté observabilité. Le try/catch préserve exactement le
    // même comportement fonctionnel (jamais d'exception propagée) tout en
    // rendant l'échec journalisé/alertable (voir docs/MONITORING_RUNBOOK.md).
    // Aucune donnée sensible journalisée : uniquement mission_id (métier),
    // jamais customer_id/adresse/contenu de notification.
    const operationStartedAt = startFinancialOperationTimer();
    try {
      await notifRef.set({
        id: notifRef.id,
        type: spec.type,
        title_key: spec.titleKey,
        body_key: spec.bodyKey,
        is_read: false,
        created_at: admin.firestore.Timestamp.now(),
        related_mission_id: missionId,
        metadata: {},
      });
      logFinancialSuccess(
        "mission_notification_created",
        operationStartedAt,
        { missionId },
        { metadata: { notificationType: spec.type } }
      );
    } catch (err) {
      logFinancialFailure(
        "mission_notification_created",
        operationStartedAt,
        "notification_write_failed",
        { missionId },
        {
          metadata: {
            notificationType: spec.type,
            errorMessage: err instanceof Error ? err.message : String(err),
          },
        }
      );
      // Ne jamais faire échouer le trigger pour une notification manquée —
      // la transition de statut métier elle-même a déjà réussi (ce trigger
      // s'exécute APRÈS l'écriture du document `delivery_requests`).
    }
  }
);
