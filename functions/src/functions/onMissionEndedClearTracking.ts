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
//
// BUG-001 (Phase 7, Bloc B) — CORRECTIF : ce trigger est aussi le SEUL point
// d'interception fiable de l'annulation client directe (écriture Firestore
// permise par firestore.rules, ne passe par aucune Cloud Function callable —
// voir onMissionStatusChangeNotifyCustomer.ts qui suit exactement le même
// raisonnement pour les notifications). Sur une transition ENTRANTE vers
// 'cancelled' avec un `active_payment_id` dont le paiement est encore
// AUTHORIZED (jamais capturé), l'autorisation Stripe DOIT être libérée
// (sinon les fonds du client restent bloqués jusqu'à expiration naturelle).
// Délégué à `cancelMissionPaymentAuthorization()` (paymentOrchestration.ts)
// qui suit le schéma en 3 temps standard (transaction de préparation ->
// appel provider HORS transaction avec idempotencyKey -> transaction
// d'application + audit_log) — jamais un appel provider DANS une transaction
// Firestore. Idempotent : si déjà CANCELLED (livraison at-least-once de ce
// trigger), ou si le paiement n'est pas AUTHORIZED (déjà CAPTURED, etc.),
// ne fait rien. Voir docs/PHASE7_BUG_REPORT.md (BUG-001) pour le diagnostic
// complet et missionCancellationPaymentRelease.test.ts pour le test de
// régression.
// -----------------------------------------------------------------------------

import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { db } from "../lib/admin";
import { DeliveryMissionDoc, MissionStatuses } from "../lib/types";
import { cancelMissionPaymentAuthorization } from "../payment/paymentOrchestration";
import { STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET } from "../lib/secrets";

const TERMINAL_STATUSES_CLEARING_TRACKING: string[] = [
  MissionStatuses.CANCELLED,
  MissionStatuses.DISPUTED,
  MissionStatuses.REFUNDED,
];

// 🔒 Phase 8B (item 6, audit "PHASE 8B — ARCHITECTURE STRIPE DÉFINITIVE
// LIVE-READY") — 3e occurrence CONFIRMÉE du même bug racine que BUG LIVE-02
// (processScheduledDriverPayouts.ts) / item 6 (calculateDriverPayout.ts) :
// ce trigger appelle `cancelMissionPaymentAuthorization()` ci-dessous, qui
// obtient un PaymentProvider via `getPaymentProvider()` et peut déclencher
// un appel RÉEL `provider.cancelAuthorization()` (paymentOrchestration.ts)
// dès qu'un client annule une mission dont le paiement est encore
// AUTHORIZED. Sans déclarer `secrets` dans les options `onDocumentUpdated`,
// Cloud Functions v2 n'injecte PAS `STRIPE_SECRET_KEY`/`STRIPE_WEBHOOK_SECRET`
// dans le runtime de CE trigger : l'appel provider échouerait
// SILENCIEUSEMENT (503 "fournisseur non configuré", capté par le chemin
// d'échec générique de cancelMissionPaymentAuthorization) à chaque
// annulation client réelle — laissant l'autorisation du client bloquée
// jusqu'à son expiration naturelle chez Stripe. Corrigé ICI.
export const onMissionEndedClearTracking = onDocumentUpdated(
  { document: "delivery_requests/{missionId}", secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET] },
  async (event) => {
    const before = event.data?.before.data() as DeliveryMissionDoc | undefined;
    const after = event.data?.after.data() as DeliveryMissionDoc | undefined;
    if (!after) return;

    const missionId = event.params.missionId;
    const wasAlreadyTerminal =
      !!before && TERMINAL_STATUSES_CLEARING_TRACKING.includes(before.status);
    const isNowTerminal = TERMINAL_STATUSES_CLEARING_TRACKING.includes(after.status);

    if (wasAlreadyTerminal || !isNowTerminal) return; // pas une transition ENTRANTE vers un statut terminal

    // BUG-001 — CORRECTIF : libère l'autorisation de paiement UNIQUEMENT sur
    // une transition ENTRANTE vers 'cancelled' précisément (pas
    // disputed/refunded, qui suivent leurs propres chemins financiers
    // dédiés — disputeOrchestration.ts / refundPayment()). Portée
    // volontairement étroite : annuler une AUTORISATION n'a de sens que
    // pour 'cancelled' (mission jamais menée à terme AVANT capture).
    if (after.status === MissionStatuses.CANCELLED) {
      const paymentId = (after.active_payment_id as string | null | undefined) ?? null;
      if (paymentId) {
        await cancelMissionPaymentAuthorization(missionId, paymentId);
      }
    }

    if (!after.driver_id) return; // aucune mission jamais assignée -> rien à nettoyer

    const locationRef = db.collection("driver_locations").doc(after.driver_id);
    const locationSnap = await locationRef.get();
    if (!locationSnap.exists) return;
    if (locationSnap.data()!.active_delivery_id !== missionId) return; // déjà réassigné ailleurs, ne pas écraser

    await locationRef.set({ active_delivery_id: null }, { merge: true });
  }
);
