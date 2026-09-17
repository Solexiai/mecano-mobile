// -----------------------------------------------------------------------------
// createDeliveryRequest — Cloud Function callable (customer).
//
// 🔒 Seul point d'entrée pour créer une mission. Garantit la cohérence
// devis → mission (le devis doit exister, appartenir au client, être non
// expiré et non consommé). Crée le document condensé `delivery_requests/{id}`
// + les stops en sous-collection. firestore.rules interdit `create` direct
// sur `delivery_requests` (allow create: if false).
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { isInternalDemoCustomer, isSuperAdmin, requireSignedIn } from "../lib/auth";
import { failedPrecondition, invalidArgument, notFound, permissionDenied } from "../lib/errors";
import { encodeGeohash } from "../lib/geohash";
import { MissionAssignmentModes, MissionStatuses } from "../lib/types";
import { RuntimeFlagKeys, isRuntimeFlagEnabled, killSwitchRefusal } from "../lib/runtimeFlags";
import { getServiceZonesConfig, isWithinServiceZones } from "../lib/serviceZones";
import { resolveLockedQuote } from "../lib/quoteIntegrity";
import { toMajorUnits } from "../lib/money";

export interface StopInput {
  type: "pickup" | "dropoff";
  address: {
    line1: string;
    city: string;
    postal_code: string;
    lat: number;
    lng: number;
    // MOVI-K — CORRECTION UX LIVRAISON (adresses réelles + autocomplete +
    // géocodage) : miroir exact des champs optionnels ajoutés côté client
    // sur `MissionAddress` (lib/backend/models/mission_address.dart).
    // Optionnels pour rester rétrocompatibles avec les clients/anciennes
    // versions qui ne les envoient pas encore. Toujours générés
    // automatiquement côté client par `AddressAutocompleteProvider`,
    // jamais saisis manuellement.
    formatted_address?: string;
    place_id?: string;
  };
  contactInstructions?: string;
  accessDetails?: string;
}

export interface CreateDeliveryRequestRequest {
  quoteId: string;
  itemCategoryKey: string;
  description: string;
  requiredVehicleCategory: string;
  /** Champs legacy : ignorés financièrement pour un devis verrouillé. */
  distanceKm?: number;
  estimatedDurationMinutes?: number;
  stops: StopInput[]; // stops[0] doit être le pickup
  customerDisplayName: string;
}

export const createDeliveryRequest = onCall<CreateDeliveryRequestRequest>(async (request) => {
  const ctx = requireSignedIn(request);
  // Seuls les superadministrateurs en superlogin et le compte client de
  // démonstration explicitement autorisé créent une mission interne sans
  // opération Stripe. Les clients ordinaires restent protégés.
  const isInternalTest = isSuperAdmin(ctx) || isInternalDemoCustomer(ctx);

  // 🔒 Phase 7, Bloc X (X-6) — kill switch. OFF => aucune NOUVELLE mission
  // n'est créée. N'affecte jamais une mission déjà existante (ce contrôle
  // est placé AVANT toute lecture/écriture, donc ne peut interférer avec
  // le cycle de vie d'une mission déjà créée). Vérifié en tout premier
  // (avant même la validation d'input) pour éviter tout travail inutile
  // et pour qu'un client modifié ne puisse jamais contourner ce contrôle
  // serveur-autoritaire.
  if (
    !isInternalTest &&
    !(await isRuntimeFlagEnabled(RuntimeFlagKeys.ACCEPT_NEW_DELIVERY_REQUESTS))
  ) {
    throw killSwitchRefusal();
  }

  const input = request.data;

  if (!input.quoteId) throw invalidArgument("quoteId est requis.");
  if (!input.stops || input.stops.length < 2) {
    throw invalidArgument("Au moins 2 stops sont requis (1 pickup + 1 dropoff minimum).");
  }
  if (input.stops[0].type !== "pickup") {
    throw invalidArgument("stops[0] doit être de type 'pickup'.");
  }
  // 🔒 BLOC O — GAP COMBLÉ : distanceKm/estimatedDurationMinutes n'étaient
  // validés que dans calculateDeliveryQuote() (devis), jamais ici. Sans
  // cette garde, un client pourrait persister un distance_km/estimated_
  // duration_minutes négatif ou non-numérique sur delivery_requests, relu
  // ensuite par acceptDelivery() pour le recalcul serveur du prix. Impact
  // financier réel nul aujourd'hui (missionBaseValue est plancherée à
  // rule.minimum_charge dans calculateCustomerQuote — voir pricingEngine.ts),
  // mais il s'agit d'une donnée métier incohérente à rejeter explicitement
  // plutôt que de la tolérer silencieusement.
  if (
    input.distanceKm !== undefined &&
    (typeof input.distanceKm !== "number" || !Number.isFinite(input.distanceKm) || input.distanceKm < 0)
  ) {
    throw invalidArgument("distanceKm doit être un nombre positif.");
  }
  if (
    input.estimatedDurationMinutes !== undefined &&
    (typeof input.estimatedDurationMinutes !== "number" ||
      !Number.isFinite(input.estimatedDurationMinutes) ||
      input.estimatedDurationMinutes < 0)
  ) {
    throw invalidArgument("estimatedDurationMinutes doit être un nombre positif.");
  }

  // 🔒 MOVI-K — CORRECTION UX LIVRAISON (adresses réelles + autocomplete +
  // géocodage), défense en profondeur SERVEUR : le client (Flutter) est
  // désormais fail-closed (refuse d'appeler cette fonction si une adresse
  // n'a pas été résolue via un fournisseur cartographique), mais cette
  // Cloud Function reste le SEUL point d'écriture réel de
  // `delivery_requests` — elle ne doit jamais faire confiance uniquement au
  // client. Rejette toute adresse dont lat/lng est absente, hors plage
  // géographique valide, ou correspond au placeholder factice historique
  // "1,2" (visible sur le screenshot ayant motivé ce correctif) : un client
  // modifié/bogué ne doit jamais pouvoir persister une mission avec des
  // coordonnées non résolues.
  for (const stop of input.stops) {
    const { lat, lng } = stop.address ?? {};
    if (typeof lat !== "number" || typeof lng !== "number" || !Number.isFinite(lat) || !Number.isFinite(lng)) {
      throw invalidArgument("Adresse invalide : coordonnées manquantes ou non numériques.");
    }
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      throw invalidArgument("Adresse invalide : coordonnées hors plage géographique valide.");
    }
    if (lat === 1 && lng === 2) {
      throw invalidArgument(
        "Adresse invalide : coordonnées placeholder détectées (1,2). Une adresse réelle résolue est requise."
      );
    }
  }

  // Zone de service (configurable, désactivée par défaut — voir
  // lib/serviceZones.ts). Vérifie pickup ET dropoff (dernier stop).
  const serviceZonesConfig = await getServiceZonesConfig();
  if (serviceZonesConfig.enabled) {
    const pickupStop = input.stops[0];
    const finalStop = input.stops[input.stops.length - 1];
    const outOfZone = [pickupStop, finalStop].find(
      (s) => !isWithinServiceZones(s.address.lat, s.address.lng, serviceZonesConfig)
    );
    if (outOfZone) {
      throw failedPrecondition(
        "Cette adresse se trouve hors de la zone de service Movi-K actuellement disponible."
      );
    }
  }

  // PHASE 6, point 1/4 — « le moyen de paiement doit être sécurisé AVANT ou
  // PENDANT la mission, jamais seulement après. » On refuse la création
  // d'une mission si le client n'a pas encore de moyen de paiement par
  // défaut enregistré (createCustomerPaymentProfile() +
  // attachCustomerPaymentMethod() doivent avoir été appelés en amont côté
  // UI, typiquement à l'écran de devis). Ceci NE déclenche PAS encore
  // l'autorisation réelle — celle-ci n'a lieu qu'à acceptDelivery(), une
  // fois le chauffeur connu et le montant final recalculé serveur.
  if (!isInternalTest) {
    const paymentProfileSnap = await db.collection("payment_profiles").doc(ctx.uid).get();
    if (!paymentProfileSnap.exists || !paymentProfileSnap.data()?.default_payment_method_id) {
      throw failedPrecondition(
        "Aucun moyen de paiement enregistré. Veuillez ajouter une carte avant de créer une demande de livraison."
      );
    }
  }

  const quoteRef = db.collection("delivery_quotes").doc(input.quoteId);

  const missionRef = db.collection("delivery_requests").doc();

  await db.runTransaction(async (tx) => {
    const quoteSnap = await tx.get(quoteRef);
    if (!quoteSnap.exists) {
      throw notFound(`delivery_quotes/${input.quoteId} introuvable.`);
    }
    const quote = quoteSnap.data()!;

    if (quote.customer_id !== ctx.uid) {
      throw permissionDenied("Ce devis n'appartient pas à l'utilisateur courant.");
    }
    if (quote.is_consumed) {
      throw failedPrecondition("Ce devis a déjà été consommé par une autre mission.");
    }
    if (quote.status === "cancelled" || quote.cancelled_at) {
      throw failedPrecondition("Ce devis a été annulé.");
    }
    const now = admin.firestore.Timestamp.now();
    if (quote.expires_at.toMillis() < now.toMillis()) {
      throw failedPrecondition("Ce devis a expiré. Merci de recalculer un nouveau devis.");
    }

    const lockedQuote = resolveLockedQuote(input.quoteId, quote);
    if (!lockedQuote.isLockedSchema) {
      throw failedPrecondition(
        "Ce devis historique ne peut pas créer une nouvelle mission. Recalculez un devis sécurisé."
      );
    }
    const pricingVersionRef = db.collection("pricing_versions").doc(lockedQuote.pricingVersion);
    const pricingVersionSnap = await tx.get(pricingVersionRef);
    if (!pricingVersionSnap.exists) {
      throw failedPrecondition(
        `pricing_versions/${lockedQuote.pricingVersion} introuvable pour ce devis.`
      );
    }

    const quoteStops = lockedQuote.pricingSnapshot
      ? (quote.stops as StopInput[] | undefined)
      : undefined;
    if (lockedQuote.pricingSnapshot) {
      if (!Array.isArray(quoteStops) || quoteStops.length < 2) {
        throw failedPrecondition("Devis verrouillé invalide : arrêts officiels absents.");
      }
      if (input.requiredVehicleCategory !== lockedQuote.pricingSnapshot.vehicle_category) {
        throw failedPrecondition(
          "La catégorie de véhicule ne correspond plus au devis. Recalculez le devis."
        );
      }
      if (input.stops.length !== quoteStops.length) {
        throw failedPrecondition("Les arrêts ne correspondent plus au devis. Recalculez le devis.");
      }
      for (let i = 0; i < quoteStops.length; i += 1) {
        const expected = quoteStops[i];
        const received = input.stops[i];
        if (
          expected.type !== received.type ||
          expected.address.lat !== received.address.lat ||
          expected.address.lng !== received.address.lng ||
          expected.address.line1 !== received.address.line1 ||
          expected.address.city !== received.address.city ||
          expected.address.postal_code !== received.address.postal_code
        ) {
          throw failedPrecondition("Les adresses ne correspondent plus au devis. Recalculez le devis.");
        }
      }
    }

    const officialStops = quoteStops ?? input.stops;
    const officialVehicleCategory =
      lockedQuote.pricingSnapshot?.vehicle_category ?? input.requiredVehicleCategory;
    const officialDistanceKm =
      lockedQuote.pricingSnapshot?.distance_km ?? input.distanceKm;
    const officialDurationMinutes =
      lockedQuote.pricingSnapshot?.estimated_duration_minutes ??
      input.estimatedDurationMinutes;
    if (
      typeof officialDistanceKm !== "number" ||
      !Number.isFinite(officialDistanceKm) ||
      typeof officialDurationMinutes !== "number" ||
      !Number.isFinite(officialDurationMinutes)
    ) {
      throw failedPrecondition("Le devis historique ne contient pas de distance/durée exploitable.");
    }

    const pickup = officialStops[0];
    const lastStop = officialStops[officialStops.length - 1];
    const dispatchGeohash = encodeGeohash(pickup.address.lat, pickup.address.lng, 5);

    tx.set(missionRef, {
      customer_id: ctx.uid,
      customer_display_name: input.customerDisplayName,
      driver_id: null,
      driver_display_name: null,
      status: MissionStatuses.SEARCHING_DRIVER,
      item_category_key: input.itemCategoryKey,
      description: input.description,
      required_vehicle_category: officialVehicleCategory,
      pickup_address: pickup.address,
      dropoff_address: lastStop.address,
      distance_km: officialDistanceKm,
      estimated_duration_minutes: officialDurationMinutes,
      pricing_version: lockedQuote.pricingVersion,
      driver_offer_amount: 0, // fixé par acceptDelivery()/createFinancialSnapshot()
      customer_total: toMajorUnits(lockedQuote.customerTotalMinor),
      customer_total_minor: lockedQuote.customerTotalMinor,
      // Copié depuis la ventilation verrouillée pour compatibilité avec les
      // lectures historiques. Il n'est jamais recalculé à l'acceptation.
      customer_discount_amount: lockedQuote.pricingResult.customerDiscountAmount,
      quote_breakdown: lockedQuote.pricingResult,
      pricing_snapshot: lockedQuote.pricingSnapshot,
      quote_integrity_hash: lockedQuote.integrityHash,
      quote_schema_version: lockedQuote.pricingSnapshot?.schema_version ?? 0,
      tax_snapshot: lockedQuote.pricingSnapshot?.tax_snapshot ?? quote.tax_snapshot ?? null,
      payment_status: "pending",
      assignment_mode: isInternalTest
        ? MissionAssignmentModes.INTERNAL_TEST
        : MissionAssignmentModes.STANDARD,
      // Marqueur serveur distinct du mode affiché. acceptDelivery() exige
      // les deux valeurs afin qu'une modification isolée de
      // `assignment_mode` ne puisse jamais contourner Stripe.
      internal_test_authorized: isInternalTest,
      internal_test_assigned_by: null,
      internal_test_assigned_at: null,
      active_quote_id: input.quoteId,
      active_financial_snapshot_id: null,
      created_at: now,
      accepted_at: null,
      driver_to_pickup_at: null,
      arrived_at_pickup_at: null,
      picked_up_at: null,
      in_transit_at: null,
      arrived_at_dropoff_at: null,
      completed_at: null,
      cancelled_at: null,
      cancellation_reason: null,
      dispatch_zone_geohash: dispatchGeohash,
      proof_of_delivery_url: null,
    });

    officialStops.forEach((officialStop, index) => {
      const submittedStop = input.stops[index];
      const stopRef = missionRef.collection("stops").doc();
      tx.set(stopRef, {
        sequence: index,
        type: officialStop.type,
        address: officialStop.address,
        // Instructions non financières conservées depuis la soumission de
        // mission; elles ne peuvent pas modifier le prix verrouillé.
        contact_instructions: submittedStop?.contactInstructions ?? null,
        access_details: submittedStop?.accessDetails ?? null,
        completed_at: null,
      });
    });

    tx.update(quoteRef, {
      is_consumed: true,
      mission_id: missionRef.id,
      status: "consumed",
      consumed_at: now,
    });

    const eventRef = missionRef.collection("tracking_events").doc();
    tx.set(eventRef, {
      event_type: "mission_created",
      actor_uid: ctx.uid,
      occurred_at: now,
      metadata: { internal_test: isInternalTest },
    });
  });

  return { missionId: missionRef.id, internalTest: isInternalTest };
});
