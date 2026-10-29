import {dispatchScheduledMission} from '../lib/scheduledDispatch';
import { findCompatibleVehicle } from "../lib/bookingServer";
import { readSchedulingPolicy } from "../lib/driverScheduling";
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
import { driverServesMissionCategory } from "../lib/vehicleCategory";
import { driverWithinDispatchRadius, pickupPoint } from "../lib/dispatchDistance";

// 2026-10-29 (recette avec Daniel) : 45 s -> 10 min. Avec 45 s et 3 rondes,
// une demande abandonnait la recherche en ~4 minutes : un chauffeur à temps
// partiel qui ne fixe pas son écran ne la voyait jamais. Les offres sont
// diffusées à tous les chauffeurs éligibles (le premier qui accepte gagne) :
// une fenêtre longue ne fait attendre personne.
export const OFFER_EXPIRY_MS = 10 * 60_000;
const DISPATCH_ZONE_PREFIX_LENGTH = 3; // ~150km — large filtre initial, affiné ensuite côté client/app par distance réelle
const MAX_CANDIDATE_DRIVERS = 15;
// DISP-01 (2026-10-28) — rondes du dispatch « immédiat » (sans politique de
// planification) : alignées sur le dispatch planifié (scheduledDispatch.ts).
// Après MAX_DISPATCH_ROUNDS rondes sans acceptation, la mission passe en
// `dispatch_state: no_driver_available` (client notifié, relance possible).
export const MAX_DISPATCH_ROUNDS = 3;
export const DISPATCH_RETRY_DELAY_MS = 60_000;
export const NO_DRIVER_AVAILABLE = "no_driver_available";
/** SEC-07 : délai minimal entre deux relances déclenchées par le même chauffeur. */
export const DRIVER_RESCAN_DEBOUNCE_MS = 60_000;

export interface DispatchOptions {
  /** Un chauffeur vient de se rendre disponible : on retente même une mission
   *  déjà déclarée sans chauffeur (la ronde compte quand même). */
  force?: boolean;
}

/**
 * Critères d'éligibilité d'un chauffeur pour une mission, hors véhicule
 * (documents, catégorie, distance). Partagés par la ronde de dispatch et par
 * l'ajout d'un chauffeur qui arrive en ligne pendant une ronde en cours.
 */
function driverMatchesMission(
  driver: FirebaseFirestore.DocumentData,
  location: FirebaseFirestore.DocumentData | undefined,
  mission: DeliveryMissionDoc,
  nowMillis: number
): boolean {
  // La validation documentaire reste obligatoire. Un champ absent sur
  // un ancien profil est traité comme non validé, jamais comme une
  // autorisation implicite.
  if (driver.documents_all_valid !== true) return false;

  const categories = Array.isArray(driver.accepted_vehicle_categories)
    ? (driver.accepted_vehicle_categories as string[])
    : [];
  if (!driverServesMissionCategory(categories, mission)) return false;

  // 2026-10-28 : distance réelle (GPS de moins de 30 min, sinon adresse de
  // base) comparée au rayon de service — voir lib/dispatchDistance.ts.
  const pickup = pickupPoint(mission as unknown as { pickup_address?: unknown });
  if (pickup) {
    return driverWithinDispatchRadius(driver, location, pickup, nowMillis);
  }

  // Repli historique (mission sans coordonnées de ramassage) : préfixe
  // geohash de la zone de dispatch.
  const zone = mission.dispatch_zone_geohash;
  if (typeof zone !== "string" || zone.length < DISPATCH_ZONE_PREFIX_LENGTH) return false;
  const currentGeohash =
    typeof driver.current_geohash === "string" && driver.current_geohash.length >= 3
      ? driver.current_geohash
      : typeof driver.base_lat === "number" && typeof driver.base_lng === "number"
        ? encodeGeohash(driver.base_lat, driver.base_lng, 6)
        : null;
  return currentGeohash?.slice(0, DISPATCH_ZONE_PREFIX_LENGTH) === zone.slice(0, DISPATCH_ZONE_PREFIX_LENGTH);
}

export async function dispatchMission(missionId: string, mission: DeliveryMissionDoc, options: DispatchOptions = {}): Promise<void> {
  if((mission as unknown as Record<string,unknown>).assignment_mode==='internal_test')return;
  if(await dispatchScheduledMission(missionId))return;
  // Price-only requests (no booking snapshot) await explicit manual
  // assignment, and an internal test never broadcasts real driver offers.
  // Commercial price-first bookings carry a driver-judgement booking_snapshot
  // (owner decision 2026-10-22) and are dispatched like any booking.
  const snapshot = 'pricing_snapshot' in mission ? mission.pricing_snapshot : undefined;
  if (snapshot && typeof snapshot === 'object' && 'pre_assignment' in snapshot && snapshot.pre_assignment &&
      !mission.booking_snapshot) return;
  // 🔒 Phase 7, Bloc Y (Y-1/Y-2) — un correlation_id + timer couvrent tout
  // le cycle de dispatch (recherche -> succès|aucun candidat), pour rendre
  // "dispatch échoué" (aucun chauffeur trouvé) observable/alertable côté
  // Cloud Logging sans jamais logger de PII (voir sanitizeMetadata) — seul
  // mission_id (identifiant métier) est transmis, jamais les coordonnées
  // GPS brutes ni un identifiant client/chauffeur non pertinent ici.
  const operationStartedAt = startFinancialOperationTimer();
  if (typeof mission.dispatch_zone_geohash !== "string" || mission.dispatch_zone_geohash.length < DISPATCH_ZONE_PREFIX_LENGTH) {
    logFinancialFailure("dispatch_no_driver_available", operationStartedAt, "mission_zone_missing", { missionId });
    return;
  }
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

  const pickup = pickupPoint(mission as unknown as { pickup_address?: unknown });
  const nowMillis = Date.now();
  // Positions GPS des candidats (≤ 50 lectures, lot déjà borné ci-dessus).
  const locations = pickup
    ? await Promise.all(candidatesSnap.docs.map((d) => db.doc("driver_locations/" + d.id).get()))
    : [];

  let eligible = candidatesSnap.docs
    .filter((driverDoc, index) =>
      driverMatchesMission(driverDoc.data(), pickup ? locations[index]?.data() : undefined, mission, nowMillis));
  if (mission.booking_snapshot) {
    const compatible = await Promise.all(eligible.map(async d => ({ d, vehicle: await findCompatibleVehicle(d.id, mission.booking_snapshot!) })));
    eligible = compatible.filter(x => x.vehicle !== null).map(x => x.d);
  }
  const now = admin.firestore.Timestamp.now();
  const expiresAt = admin.firestore.Timestamp.fromMillis(now.toMillis() + OFFER_EXPIRY_MS);
  const nextAttemptAt = admin.firestore.Timestamp.fromMillis(now.toMillis() + DISPATCH_RETRY_DELAY_MS);

  const missionRef = db.collection("delivery_requests").doc(missionId);
  // Firestore events may be replayed or overlap with assignment/cancellation.
  // Only the transaction that still observes an unassigned searching mission
  // may publish offers; a retry must not reopen it or notify drivers again.
  //
  // DISP-01 : la ronde est comptée DANS la transaction, qu'il y ait ou non
  // des chauffeurs éligibles, pour que le balayage (sweepDriverOffers) et le
  // client voient toujours un état cohérent : `searching` (nouvelle ronde à
  // venir), `offered` (offres en cours) ou `no_driver_available` (épuisé).
  let offered: typeof eligible = [];
  // Chauffeurs déjà sollicités lors d'une ronde précédente : la notification
  // in-app est simplement rafraîchie, sans nouveau push (pas de rafale).
  let alreadyNotified = new Set<string>();
  const dispatched = await db.runTransaction(async (tx) => {
    const current = (await tx.get(missionRef)).data();
    if (!current || current.status !== MissionStatuses.SEARCHING_DRIVER || current.driver_id) {
      return false;
    }
    const previousRound = typeof current.dispatch_round === "number" ? current.dispatch_round : 0;
    const exhaustedBefore = current.dispatch_state === NO_DRIVER_AVAILABLE || previousRound >= MAX_DISPATCH_ROUNDS;
    if (exhaustedBefore && !options.force) {
      if (current.dispatch_state !== NO_DRIVER_AVAILABLE) tx.update(missionRef, { dispatch_state: NO_DRIVER_AVAILABLE });
      return false;
    }
    const round = previousRound + 1;
    // Un chauffeur qui a refusé cette demande ne la revoit pas (même règle
    // que le dispatch planifié).
    const priorOffers = await tx.get(db.collection("delivery_offers").where("mission_id", "==", missionId));
    const declined = new Set(priorOffers.docs.filter((o) => o.data().status === "declined").map((o) => o.data().driver_id as string));
    alreadyNotified = new Set(priorOffers.docs.map((o) => o.data().driver_id as string));
    offered = eligible.filter((d) => !declined.has(d.id)).slice(0, MAX_CANDIDATE_DRIVERS);
    if (offered.length === 0) {
      const exhausted = round >= MAX_DISPATCH_ROUNDS && !options.force;
      tx.update(missionRef, {
        dispatch_round: round,
        dispatch_state: exhausted ? NO_DRIVER_AVAILABLE : "searching",
        dispatch_next_attempt_at: nextAttemptAt,
      });
      return false;
    }
    for (const driverDoc of offered) {
      const offerRef = db.collection("delivery_offers").doc();
      tx.set(offerRef, {
        mission_id: missionId,
        driver_id: driverDoc.id,
        offered_at: now,
        expires_at: expiresAt,
        status: "pending",
      });

      // Notification in-app créée DANS LA MÊME transaction que l'offre : si le commit
      // réussit, le chauffeur voit au minimum la cloche/liste en temps réel,
      // même si son appareil n'a pas autorisé FCM/APNs ou si le push échoue.
      // ID déterministe par mission/chauffeur pour éviter les doublons lors
      // d'un retry at-least-once du trigger Firestore.
      const notificationRef = db
        .collection("users")
        .doc(driverDoc.id)
        .collection("notifications")
        .doc(`delivery_offer_${missionId}`);
      tx.set(notificationRef, {
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
    tx.update(missionRef, {
      status: MissionStatuses.OFFERED,
      offered_driver_ids: offered.map((d) => d.id),
      offered_until: expiresAt,
      dispatch_round: round,
      dispatch_state: "offered",
      dispatch_next_attempt_at: nextAttemptAt,
    });
    return true;
  });
  if (!dispatched) {
    if (eligible.length === 0) {
      // Aucun chauffeur dispo dans la zone immédiate. NE PLANTE JAMAIS
      // (comportement métier normal, pas une erreur système) — mais DOIT
      // rester observable (Y-1 : "dispatch échoué" était un GAP silencieux) :
      // journalisé en "failure" opérationnelle pour permettre une alerte HIGH
      // si ce cas se répète massivement (voir docs/MONITORING_RUNBOOK.md, Y-5).
      logFinancialFailure(
        "dispatch_no_driver_available",
        operationStartedAt,
        "no_eligible_driver_in_zone",
        { missionId },
        { metadata: { candidatesScanned: candidatesSnap.size, zonePrefix } }
      );
    }
    return;
  }

  // Push après le commit uniquement : ne jamais avertir un chauffeur d'une
  // offre qui n'a pas réellement été persistée. sendDeliveryOfferPush() est
  // fail-soft et ne propage jamais un échec FCM.
  const pushResults = await Promise.all(
    offered.filter((driverDoc) => !alreadyNotified.has(driverDoc.id)).map((driverDoc) =>
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
        offersCreated: offered.length,
        inAppNotificationsCreated: offered.length,
        pushAttempted,
        pushSent,
        candidatesScanned: candidatesSnap.size,
      },
    }
  );
}

/**
 * 2026-10-29 (recette) : un chauffeur qui passe en ligne PENDANT une ronde
 * déjà en cours (mission `offered` à d'autres chauffeurs) n'était jamais
 * sollicité — il fallait attendre la ronde suivante, souvent la dernière.
 * Constaté en prod : Daniel passe en ligne à 9 h 32 min 05 s, la ronde 3
 * part 5 s plus tard avec une liste de candidats lue juste avant, sans lui ;
 * sa propre relance perd la course et la demande finit « aucun chauffeur ».
 *
 * Ajoute ce chauffeur à la ronde en cours : offre jusqu'à `offered_until`,
 * même notification in-app, push. Sans effet si la mission n'est plus
 * `offered`, si la ronde est échue, si le chauffeur a déjà une offre
 * (en attente ou refusée) ou s'il n'est pas éligible.
 */
export async function offerOpenMissionToDriver(missionId: string, driverId: string): Promise<boolean> {
  const missionRef = db.collection("delivery_requests").doc(missionId);
  const [driverSnap, locationSnap, missionSnap] = await Promise.all([
    db.doc("driver_profiles/" + driverId).get(),
    db.doc("driver_locations/" + driverId).get(),
    missionRef.get(),
  ]);
  const driver = driverSnap.data();
  const preview = missionSnap.data() as DeliveryMissionDoc | undefined;
  if (!driver || driver.status !== "approved" || driver.online_status !== "online" || !preview) return false;
  if (!driverMatchesMission(driver, locationSnap.data(), preview, Date.now())) return false;
  if (preview.booking_snapshot && !(await findCompatibleVehicle(driverId, preview.booking_snapshot))) return false;

  const joined = await db.runTransaction(async (tx): Promise<{ until: admin.firestore.Timestamp; first: boolean } | null> => {
    const current = (await tx.get(missionRef)).data();
    if (!current || current.status !== MissionStatuses.OFFERED || current.driver_id ||
        current.assignment_mode === "internal_test") return null;
    const until = current.offered_until;
    if (!(until instanceof admin.firestore.Timestamp) || until.toMillis() <= Date.now()) return null;
    const already = Array.isArray(current.offered_driver_ids) ? (current.offered_driver_ids as string[]) : [];
    if (already.includes(driverId)) return null;
    const prior = await tx.get(db.collection("delivery_offers")
      .where("mission_id", "==", missionId).where("driver_id", "==", driverId));
    if (prior.docs.some((o) => o.data().status === "declined" || o.data().status === "pending")) return null;

    const now = admin.firestore.Timestamp.now();
    const offerRef = db.collection("delivery_offers").doc();
    tx.set(offerRef, {
      mission_id: missionId,
      driver_id: driverId,
      offered_at: now,
      expires_at: until,
      status: "pending",
      joined_round: true,
    });
    const notificationRef = db.collection("users").doc(driverId).collection("notifications").doc(`delivery_offer_${missionId}`);
    tx.set(notificationRef, {
      id: notificationRef.id,
      type: "delivery_offer",
      title_key: "notif_delivery_offer_title",
      body_key: "notif_delivery_offer_body",
      is_read: false,
      created_at: now,
      related_mission_id: missionId,
      metadata: { offer_id: offerRef.id, expires_at: until },
    });
    tx.update(missionRef, { offered_driver_ids: admin.firestore.FieldValue.arrayUnion(driverId) });
    return { until, first: prior.empty };
  });
  if (!joined) return false;
  // Push uniquement à la première sollicitation de ce chauffeur pour cette mission.
  if (joined.first) {
    await sendDeliveryOfferPush({ driverId, missionId, expiresAtMillis: joined.until.toMillis() });
  }
  return true;
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

    // SEC-07 (2026-10-28) — anti-rafale : un chauffeur qui bascule en ligne /
    // hors ligne en boucle ne relance pas 25 dispatchs (offres + push) à
    // chaque fois. Une seule relance par chauffeur par minute ; l'écriture
    // ci-dessous redéclenche ce trigger, qui sort aussitôt (déjà disponible).
    const now = admin.firestore.Timestamp.now();
    const rescanAfter = after.dispatch_rescan_after;
    if (rescanAfter instanceof admin.firestore.Timestamp && rescanAfter.toMillis() > now.toMillis()) return;
    await event.data!.after.ref.update({
      dispatch_rescan_after: admin.firestore.Timestamp.fromMillis(now.toMillis() + DRIVER_RESCAN_DEBOUNCE_MS),
    });

    const pendingMissions = await db
      .collection("delivery_requests")
      .where("status", "in", [MissionStatuses.SEARCHING_DRIVER, MissionStatuses.OFFERED])
      .limit(25)
      .get();

    // La planification (si activée) gère ses propres réservations : on ne
    // greffe pas d'offre hors créneau sur ses rondes.
    const scheduling = await readSchedulingPolicy().catch(() => null);
    for (const missionDoc of pendingMissions.docs) {
      try {
        // Un chauffeur qui arrive est la meilleure occasion de retenter une
        // demande déclarée sans chauffeur (force) : la ronde est comptée.
        if (missionDoc.data().status === MissionStatuses.SEARCHING_DRIVER) {
          await dispatchMission(missionDoc.id, missionDoc.data() as DeliveryMissionDoc, { force: true });
        }
        // Ronde en cours (ou ronde lancée en parallèle par le balayage, qui a
        // gagné la course) : le chauffeur est ajouté aux candidats.
        if (!scheduling) await offerOpenMissionToDriver(missionDoc.id, event.params.driverId);
      } catch (error) {
        // Une mission défectueuse n'empêche pas les autres d'être proposées.
        console.error("[driver-online] dispatch failed", missionDoc.id, error instanceof Error ? error.message : String(error));
      }
    }
  }
);

