// -----------------------------------------------------------------------------
// dispatchMissionToDrivers — déclenchée automatiquement (Firestore trigger)
// à la création d'une mission `searching_driver`, recherche les chauffeurs
// éligibles SANS scanner toute la collection (voir docs/FIRESTORE_ARCHITECTURE.md,
// section "Dispatch — comment on évite un scan complet") et crée une
// `delivery_offers/{id}` par chauffeur candidat.
//
// Phase 8D : chaque offre crée aussi une notification in-app canonique dans
// `users/{driverId}/notifications/...` puis tente une notification push FCM.
// Le push est strictement fail-soft : Firestore reste la source de vérité et
// une panne FCM ne doit jamais annuler/faire échouer le dispatch métier.
//
// Requête volontairement simple et bornée :
//   where status == 'approved'
//   where online_status == 'online'
// Les validations documentaires, la catégorie de véhicule et la zone sont
// ensuite filtrées en mémoire. La zone utilise d'abord current_geohash, puis
// les coordonnées de l'adresse de service comme repli avant le premier GPS.
// -----------------------------------------------------------------------------

import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { admin, db } from "../lib/admin";
import { encodeGeohash } from "../lib/geohash";
import { DeliveryMissionDoc, MissionStatuses } from "../lib/types";
import {
  logFinancialFailure,
  logFinancialSuccess,
  startFinancialOperationTimer,
} from "../lib/observability";
import { sendDeliveryOfferPush } from "../lib/pushNotifications";

const OFFER_EXPIRY_MS = 45_000; // 45s pour accepter avant que l'offre expire
const DISPATCH_ZONE_PREFIX_LENGTH = 3; // ~150km — large filtre initial, affiné ensuite côté client/app par distance réelle
const MAX_CANDIDATE_DRIVERS = 15;

async function dispatchMission(missionId: string, mission: DeliveryMissionDoc): Promise<void> {
  // 🔒 Phase 7, Bloc Y (Y-1/Y-2) — un correlation_id + timer couvrent tout
  // le cycle de dispatch (recherche -> succès|aucun candidat), pour rendre
  // "dispatch échoué" (aucun chauffeur trouvé) observable/alertable côté
  // Cloud Logging sans jamais logger de PII (voir sanitizeMetadata) — seul
  // mission_id (identifiant métier) est transmis, jamais les coordonnées
  // GPS brutes ni un identifiant client/chauffeur non pertinent ici.
  const operationStartedAt = startFinancialOperationTimer();
  const zonePrefix = mission.dispatch_zone_geohash.slice(0, DISPATCH_ZONE_PREFIX_LENGTH);

  // Cherche d'abord les chauffeurs réellement disponibles. Les critères de
  // zone et de véhicule sont appliqués en mémoire sur ce petit lot borné.
  // Cela permet de réparer les profils approuvés plus anciens qui n'avaient
  // pas encore les champs dénormalisés current_geohash/documents_all_valid.
  const candidatesSnap = await db
    .collection("driver_profiles")
    .where("status", "==", "approved")
    .where("online_status", "==", "online")
    .limit(50)
    .get();

  const eligible = candidatesSnap.docs
    .filter((driverDoc) => {
      const driver = driverDoc.data();

      // La validation documentaire reste obligatoire. Un champ absent sur
      // un ancien profil est traité comme non validé, jamais comme une
      // autorisation implicite.
      if (driver.documents_all_valid !== true) return false;

      const categories = Array.isArray(driver.accepted_vehicle_categories)
        ? (driver.accepted_vehicle_categories as string[])
        : [];
      if (!categories.includes(mission.required_vehicle_category)) return false;

      // La dernière position GPS est prioritaire. Avant le premier partage
      // GPS, l'adresse de base validée pendant l'onboarding sert de repli :
      // le chauffeur peut donc recevoir une première offre sans cercle
      // impossible « mission requise avant activation du GPS ».
      const currentGeohash =
        typeof driver.current_geohash === "string" && driver.current_geohash.length >= 3
          ? driver.current_geohash
          : typeof driver.base_lat === "number" && typeof driver.base_lng === "number"
            ? encodeGeohash(driver.base_lat, driver.base_lng, 6)
            : null;

      return currentGeohash?.slice(0, DISPATCH_ZONE_PREFIX_LENGTH) === zonePrefix;
    })
    .slice(0, MAX_CANDIDATE_DRIVERS);

  if (eligible.length === 0) {
    // Aucun chauffeur dispo dans la zone immédiate — laissé en
    // 'searching_driver' ; un job planifié pourra élargir le rayon de
    // recherche (hors scope de ce squelette). NE PLANTE JAMAIS (comportement
    // métier normal, pas une erreur système) — mais DOIT rester observable
    // (Y-1 : "dispatch échoué" était un GAP silencieux avant ce correctif) :
    // journalisé en "failure" opérationnelle (jamais une exception levée)
    // pour permettre une alerte HIGH si ce cas se répète massivement (voir
    // docs/MONITORING_RUNBOOK.md, Y-5).
    logFinancialFailure(
      "dispatch_no_driver_available",
      operationStartedAt,
      "no_eligible_driver_in_zone",
      { missionId },
      { metadata: { candidatesScanned: candidatesSnap.size, zonePrefix } }
    );
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

    // Notification in-app créée DANS LE MÊME batch que l'offre : si le commit
    // réussit, le chauffeur voit au minimum la cloche/liste en temps réel,
    // même si son appareil n'a pas autorisé FCM/APNs ou si le push échoue.
    // ID déterministe par mission/chauffeur pour éviter les doublons lors
    // d'un retry at-least-once du trigger Firestore.
    const notificationRef = db
      .collection("users")
      .doc(driverDoc.id)
      .collection("notifications")
      .doc(`delivery_offer_${missionId}`);
    batch.set(notificationRef, {
      id: notificationRef.id,
      type: "delivery_offer",
      title_key: "notif_delivery_offer_title",
      body_key: "notif_delivery_offer_body",
      is_read: false,
      created_at: now,
      related_mission_id: missionId,
      metadata: {
        offer_id: offerRef.id,
        expires_at: expiresAt,
      },
    });
  }
  batch.update(db.collection("delivery_requests").doc(missionId), {
    status: MissionStatuses.OFFERED,
  });
  await batch.commit();

  // Push après le commit uniquement : ne jamais avertir un chauffeur d'une
  // offre qui n'a pas réellement été persistée. sendDeliveryOfferPush() est
  // fail-soft et ne propage jamais un échec FCM.
  const pushResults = await Promise.all(
    eligible.map((driverDoc) =>
      sendDeliveryOfferPush({
        driverId: driverDoc.id,
        missionId,
        expiresAtMillis: expiresAt.toMillis(),
      })
    )
  );
  const pushAttempted = pushResults.reduce((sum, result) => sum + result.attempted, 0);
  const pushSent = pushResults.reduce((sum, result) => sum + result.sent, 0);

  // Log APRÈS le commit réussi — ne jamais annoncer un succès avant que les
  // écritures (offres + notifications + statut OFFERED) soient persistées.
  logFinancialSuccess(
    "dispatch_offers_created",
    operationStartedAt,
    { missionId },
    {
      metadata: {
        offersCreated: eligible.length,
        inAppNotificationsCreated: eligible.length,
        pushAttempted,
        pushSent,
        candidatesScanned: candidatesSnap.size,
      },
    }
  );
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

/**
 * Relance les demandes déjà en attente lorsqu'un chauffeur devient réellement
 * disponible. Sans ce déclencheur, une demande créée quelques secondes avant
 * la mise en ligne du chauffeur pouvait rester bloquée indéfiniment.
 */
export const onDriverBecameAvailableDispatch = onDocumentUpdated(
  "driver_profiles/{driverId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!after) return;

    const isAvailable = (driver: FirebaseFirestore.DocumentData | undefined) =>
      driver?.status === "approved" &&
      driver?.online_status === "online" &&
      driver?.documents_all_valid === true;

    if (!isAvailable(after) || isAvailable(before)) return;

    const pendingMissions = await db
      .collection("delivery_requests")
      .where("status", "==", MissionStatuses.SEARCHING_DRIVER)
      .limit(25)
      .get();

    for (const missionDoc of pendingMissions.docs) {
      await dispatchMission(missionDoc.id, missionDoc.data() as DeliveryMissionDoc);
    }
  }
);
