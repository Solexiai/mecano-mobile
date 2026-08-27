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
import { requireSignedIn } from "../lib/auth";
import { failedPrecondition, invalidArgument, notFound, permissionDenied } from "../lib/errors";
import { encodeGeohash } from "../lib/geohash";
import { MissionStatuses } from "../lib/types";
import { RuntimeFlagKeys, isRuntimeFlagEnabled, killSwitchRefusal } from "../lib/runtimeFlags";

export interface StopInput {
  type: "pickup" | "dropoff";
  address: {
    line1: string;
    city: string;
    postal_code: string;
    lat: number;
    lng: number;
  };
  contactInstructions?: string;
  accessDetails?: string;
}

export interface CreateDeliveryRequestRequest {
  quoteId: string;
  itemCategoryKey: string;
  description: string;
  requiredVehicleCategory: string;
  distanceKm: number;
  estimatedDurationMinutes: number;
  stops: StopInput[]; // stops[0] doit être le pickup
  customerDisplayName: string;
}

export const createDeliveryRequest = onCall<CreateDeliveryRequestRequest>(async (request) => {
  const ctx = requireSignedIn(request);

  // 🔒 Phase 7, Bloc X (X-6) — kill switch. OFF => aucune NOUVELLE mission
  // n'est créée. N'affecte jamais une mission déjà existante (ce contrôle
  // est placé AVANT toute lecture/écriture, donc ne peut interférer avec
  // le cycle de vie d'une mission déjà créée). Vérifié en tout premier
  // (avant même la validation d'input) pour éviter tout travail inutile
  // et pour qu'un client modifié ne puisse jamais contourner ce contrôle
  // serveur-autoritaire.
  if (!(await isRuntimeFlagEnabled(RuntimeFlagKeys.ACCEPT_NEW_DELIVERY_REQUESTS))) {
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
  if (typeof input.distanceKm !== "number" || !Number.isFinite(input.distanceKm) || input.distanceKm < 0) {
    throw invalidArgument("distanceKm doit être un nombre positif.");
  }
  if (
    typeof input.estimatedDurationMinutes !== "number" ||
    !Number.isFinite(input.estimatedDurationMinutes) ||
    input.estimatedDurationMinutes < 0
  ) {
    throw invalidArgument("estimatedDurationMinutes doit être un nombre positif.");
  }

  // PHASE 6, point 1/4 — « le moyen de paiement doit être sécurisé AVANT ou
  // PENDANT la mission, jamais seulement après. » On refuse la création
  // d'une mission si le client n'a pas encore de moyen de paiement par
  // défaut enregistré (createCustomerPaymentProfile() +
  // attachCustomerPaymentMethod() doivent avoir été appelés en amont côté
  // UI, typiquement à l'écran de devis). Ceci NE déclenche PAS encore
  // l'autorisation réelle — celle-ci n'a lieu qu'à acceptDelivery(), une
  // fois le chauffeur connu et le montant final recalculé serveur.
  const paymentProfileSnap = await db.collection("payment_profiles").doc(ctx.uid).get();
  if (!paymentProfileSnap.exists || !paymentProfileSnap.data()?.default_payment_method_id) {
    throw failedPrecondition(
      "Aucun moyen de paiement enregistré. Veuillez ajouter une carte avant de créer une demande de livraison."
    );
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
    const now = admin.firestore.Timestamp.now();
    if (quote.expires_at.toMillis() < now.toMillis()) {
      throw failedPrecondition("Ce devis a expiré. Merci de recalculer un nouveau devis.");
    }

    const pickup = input.stops[0];
    const lastStop = input.stops[input.stops.length - 1];
    const dispatchGeohash = encodeGeohash(pickup.address.lat, pickup.address.lng, 5);

    tx.set(missionRef, {
      customer_id: ctx.uid,
      customer_display_name: input.customerDisplayName,
      driver_id: null,
      driver_display_name: null,
      status: MissionStatuses.SEARCHING_DRIVER,
      item_category_key: input.itemCategoryKey,
      description: input.description,
      required_vehicle_category: input.requiredVehicleCategory,
      pickup_address: pickup.address,
      dropoff_address: lastStop.address,
      distance_km: input.distanceKm,
      estimated_duration_minutes: input.estimatedDurationMinutes,
      pricing_version: quote.pricing_version,
      driver_offer_amount: 0, // fixé par acceptDelivery()/createFinancialSnapshot()
      customer_total: quote.customer_total,
      // Dénormalisé depuis le devis pour que acceptDelivery() recalcule avec
      // EXACTEMENT la même remise (jamais un montant client) — voir
      // resolvePromoDiscountAmount() dans calculateDeliveryQuote.ts.
      customer_discount_amount: quote.quote_breakdown?.customerDiscountAmount ?? 0,
      payment_status: "pending",
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

    input.stops.forEach((stop, index) => {
      const stopRef = missionRef.collection("stops").doc();
      tx.set(stopRef, {
        sequence: index,
        type: stop.type,
        address: stop.address,
        contact_instructions: stop.contactInstructions ?? null,
        access_details: stop.accessDetails ?? null,
        completed_at: null,
      });
    });

    tx.update(quoteRef, { is_consumed: true, mission_id: missionRef.id });

    const eventRef = missionRef.collection("tracking_events").doc();
    tx.set(eventRef, {
      event_type: "mission_created",
      actor_uid: ctx.uid,
      occurred_at: now,
      metadata: {},
    });
  });

  return { missionId: missionRef.id };
});
