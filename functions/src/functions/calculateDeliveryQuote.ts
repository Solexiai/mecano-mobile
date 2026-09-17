// -----------------------------------------------------------------------------
// calculateDeliveryQuote — Cloud Function callable (customer).
//
// Calcule un devis OFFICIEL en rejouant CustomerPricingEngine côté serveur
// avec la pricing_version active lue depuis Firestore (jamais un montant
// fourni par le client). Écrit `delivery_quotes/{id}` (🔒 write côté client
// interdit par firestore.rules) avec une durée de validité issue de
// `quote_config.quote_validity_minutes`.
//
// 🔒 Remise client (code promo) : le client envoie UNIQUEMENT un `promoCode`
// (chaîne). Le MONTANT de la remise n'est JAMAIS accepté depuis le client —
// il est résolu ici en lisant `promo_codes/{code}` côté serveur (existence,
// `is_active`, fenêtre de validité, `max_discount_amount`). Voir test
// "customer promotion" (Étape 12) qui vérifie précisément qu'un montant
// envoyé directement par le client est ignoré.
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { requireSignedIn } from "../lib/auth";
import { invalidArgument, failedPrecondition } from "../lib/errors";
import { calculateCustomerQuote } from "../lib/pricingEngine";
import { PricingVersionDoc } from "../lib/types";
import { resolveConfiguredVehicleCategory } from "../lib/vehicleCategory";
import { calculateAuthoritativeRoute } from "./calculateRoute";
import {
  LOCKED_QUOTE_SCHEMA_VERSION,
  LockedQuotePricingSnapshot,
  buildQuoteIntegrityEnvelope,
  computeQuoteIntegrityHash,
} from "../lib/quoteIntegrity";
import { DEFAULT_CURRENCY, toMajorUnits, toMinorUnits } from "../lib/money";
import {
  DEFAULT_JURISDICTION,
  applyTaxSnapshotToQuote,
  resolveAndFreezeTaxSnapshot,
} from "../lib/taxEngine";

export interface QuoteStopInput {
  type: "pickup" | "dropoff";
  address: {
    line1: string;
    city: string;
    postal_code: string;
    lat: number;
    lng: number;
    formatted_address?: string;
    place_id?: string;
  };
}

export interface CalculateDeliveryQuoteRequest {
  vehicleCategory: string;
  /** Coordonnées officielles utilisées par le serveur pour calculer l'itinéraire. */
  stops?: QuoteStopInput[];
  /** Champs legacy tolérés au transport, mais JAMAIS utilisés pour calculer le devis. */
  distanceKm?: number;
  estimatedDurationMinutes?: number;
  handling?: {
    isHeavyItem?: boolean;
    isBulkyItem?: boolean;
    needsStairs?: boolean;
    noElevator?: boolean;
    needsSecondHandler?: boolean;
    needsSpecialEquipment?: boolean;
  };
  totalWaitingMinutes?: number;
  additionalStopsCount?: number;
  applicableSurchargeIds?: string[];
  /** Code promo optionnel — le MONTANT est résolu côté serveur, jamais accepté du client. */
  promoCode?: string;
}

/**
 * Résout le montant de remise à partir d'un code promo, en lisant
 * `promo_codes/{code}` côté serveur. Retourne 0 si le code est absent,
 * inconnu, inactif ou hors fenêtre de validité — ne lève JAMAIS d'erreur
 * pour un code invalide (dégrade silencieusement à "pas de remise") afin de
 * ne pas bloquer un devis pour une simple faute de frappe du client.
 */
async function resolvePromoDiscountAmount(
  promoCode: string | undefined,
  rawSubtotal: number
): Promise<number> {
  if (!promoCode) return 0;
  const snap = await db.collection("promo_codes").doc(promoCode).get();
  if (!snap.exists) return 0;
  const promo = snap.data()!;
  const now = admin.firestore.Timestamp.now();
  if (!promo.is_active) return 0;
  if (promo.starts_at && now.toMillis() < promo.starts_at.toMillis()) return 0;
  if (promo.ends_at && now.toMillis() >= promo.ends_at.toMillis()) return 0;

  const rawAmount =
    promo.discount_mode === "percentage"
      ? rawSubtotal * (promo.discount_value as number)
      : (promo.discount_value as number);
  const maxAmount = (promo.max_discount_amount as number | undefined) ?? rawAmount;
  return Math.min(rawAmount, maxAmount);
}

export const calculateDeliveryQuote = onCall<CalculateDeliveryQuoteRequest>(async (request) => {
  const ctx = requireSignedIn(request);
  const input = request.data;

  if (!input.vehicleCategory) throw invalidArgument("vehicleCategory est requis.");
  if (!Array.isArray(input.stops) || input.stops.length < 2) {
    throw invalidArgument("Au moins 2 arrêts géocodés sont requis pour calculer le devis.");
  }
  if (input.stops[0].type !== "pickup" || input.stops[input.stops.length - 1].type !== "dropoff") {
    throw invalidArgument("Le premier arrêt doit être le pickup et le dernier le dropoff.");
  }
  for (const stop of input.stops) {
    const { lat, lng } = stop.address ?? {};
    if (
      typeof lat !== "number" ||
      typeof lng !== "number" ||
      !Number.isFinite(lat) ||
      !Number.isFinite(lng) ||
      lat < -90 ||
      lat > 90 ||
      lng < -180 ||
      lng > 180 ||
      (lat === 1 && lng === 2)
    ) {
      throw invalidArgument("Chaque arrêt doit contenir des coordonnées géographiques valides.");
    }
  }

  // La distance et la durée viennent exclusivement du fournisseur routier
  // appelé côté serveur. Les anciennes valeurs envoyées par le client sont
  // volontairement ignorées afin qu'elles ne puissent jamais fixer un prix.
  const pickup = input.stops[0].address;
  const dropoff = input.stops[input.stops.length - 1].address;
  const route = await calculateAuthoritativeRoute({
    pickupLat: pickup.lat,
    pickupLng: pickup.lng,
    dropoffLat: dropoff.lat,
    dropoffLng: dropoff.lng,
    intermediateStops: input.stops.slice(1, -1).map((stop) => ({
      lat: stop.address.lat,
      lng: stop.address.lng,
    })),
  });

  // 1. Lire le pointeur de config active, puis la version elle-même.
  const activeConfigSnap = await db.collection("pricing_configs").doc("active").get();
  if (!activeConfigSnap.exists) {
    throw failedPrecondition("Aucune configuration tarifaire active (pricing_configs/active).");
  }

  // Fail closed si le document existe mais que son pointeur est absent/vide.
  // Cela produit une erreur métier contrôlée plutôt qu'un `.doc(undefined)`
  // difficile à diagnostiquer dans les logs.
  const rawActivePricingVersion = activeConfigSnap.data()?.active_pricing_version;
  if (typeof rawActivePricingVersion !== "string" || !rawActivePricingVersion.trim()) {
    throw failedPrecondition(
      "pricing_configs/active.active_pricing_version est absent ou invalide."
    );
  }
  const activePricingVersion = rawActivePricingVersion.trim();

  const versionSnap = await db.collection("pricing_versions").doc(activePricingVersion).get();
  if (!versionSnap.exists) {
    throw failedPrecondition(`pricing_versions/${activePricingVersion} introuvable.`);
  }
  const config = versionSnap.data() as PricingVersionDoc;
  if (!config.is_active) {
    throw failedPrecondition("La pricing_version active pointée n'est plus marquée is_active.");
  }

  // Compatibilité historique : Flutter envoie maintenant les catégories
  // Firestore en snake_case (`cargo_van`, `pickup_truck`, ...), tandis que
  // certaines anciennes pricing_versions immuables utilisent camelCase
  // (`cargoVan`, `pickupTruck`, ...). On résout contre la grille réellement
  // active puis on transmet au moteur la valeur EXACTE stockée dans cette
  // grille. Aucun tarif n'est inventé ou modifié ici.
  const configuredVehicleCategory = resolveConfiguredVehicleCategory(
    config.vehicle_rules.map((rule) => rule.category),
    input.vehicleCategory
  );
  if (!configuredVehicleCategory) {
    throw failedPrecondition(
      `Aucune règle de tarification pour la catégorie ${input.vehicleCategory}.`
    );
  }

  // 2. Premier passage SANS remise — nécessaire pour connaître le subtotal
  // brut (base de calcul d'une remise en pourcentage), sans jamais faire
  // confiance à un montant envoyé par le client.
  const baseArgs = {
    vehicleCategory: configuredVehicleCategory,
    distanceKm: route.distanceKm,
    estimatedDurationMinutes: route.estimatedDurationMinutes,
    handling: input.handling,
    totalWaitingMinutes: input.totalWaitingMinutes,
    // Dérivé des arrêts réellement figés dans le devis, jamais d'un nombre
    // libre fourni par le client.
    additionalStopsCount: Math.max(0, input.stops.length - 2),
    applicableSurchargeIds: input.applicableSurchargeIds,
  };
  const unDiscountedResult = calculateCustomerQuote(config, baseArgs);

  // 3. Résolution serveur du montant de remise (jamais un montant client).
  const customerDiscountAmount = await resolvePromoDiscountAmount(
    input.promoCode,
    unDiscountedResult.subtotal // == rawSubtotal ici puisqu'aucune remise n'a encore été appliquée
  );

  // 4. Calcul final du devis avec la remise résolue côté serveur.
  const flatPricingResult = calculateCustomerQuote(config, {
    ...baseArgs,
    customerDiscountAmount,
  });

  // Les taxes sont résolues et figées AU MOMENT DU DEVIS. Elles ne seront
  // plus relues lors de l'acceptation du chauffeur.
  const quoteCalculatedAt = admin.firestore.Timestamp.now();
  const taxSnapshot = await resolveAndFreezeTaxSnapshot({
    jurisdiction: DEFAULT_JURISDICTION,
    taxableAmountMajor: flatPricingResult.subtotal + flatPricingResult.customerServiceFee,
    applyToTransport: true,
    applyToPlatformFees: true,
    atMillis: quoteCalculatedAt.toMillis(),
  });
  const pricingResult = applyTaxSnapshotToQuote(flatPricingResult, taxSnapshot);
  // Le contrat monétaire officiel est exprimé en cents. On normalise aussi
  // la représentation majeure afin que devis, mission, snapshot et Stripe
  // portent exactement le même total, sans demi-cent résiduel.
  const customerTotalMinor = toMinorUnits(pricingResult.customerTotal);
  const lockedPricingResult = {
    ...pricingResult,
    customerTotal: toMajorUnits(customerTotalMinor),
  };

  // 5. Écriture du devis avec durée de validité configurée.
  const quoteRef = db.collection("delivery_quotes").doc();
  const now = quoteCalculatedAt;
  const expiresAt = admin.firestore.Timestamp.fromMillis(
    now.toMillis() + config.quote_config.quote_validity_minutes * 60_000
  );

  const normalizedHandling = {
    isHeavyItem: input.handling?.isHeavyItem === true,
    isBulkyItem: input.handling?.isBulkyItem === true,
    needsStairs: input.handling?.needsStairs === true,
    noElevator: input.handling?.noElevator === true,
    needsSecondHandler: input.handling?.needsSecondHandler === true,
    needsSpecialEquipment: input.handling?.needsSpecialEquipment === true,
  };
  const pricingSnapshot: LockedQuotePricingSnapshot = {
    schema_version: LOCKED_QUOTE_SCHEMA_VERSION,
    currency: DEFAULT_CURRENCY,
    pricing_version: lockedPricingResult.pricingVersion,
    vehicle_category: configuredVehicleCategory,
    distance_km: route.distanceKm,
    estimated_duration_minutes: route.estimatedDurationMinutes,
    route_provider: "google_routes",
    route_result: {
      distance_km: route.distanceKm,
      estimated_duration_minutes: route.estimatedDurationMinutes,
    },
    handling: normalizedHandling,
    total_waiting_minutes: input.totalWaitingMinutes ?? 0,
    additional_stops_count: Math.max(0, input.stops.length - 2),
    applicable_surcharge_ids: [...(input.applicableSurchargeIds ?? [])].sort(),
    promotion: {
      code: input.promoCode?.trim() || null,
      discount_amount: lockedPricingResult.customerDiscountAmount,
    },
    tax_snapshot: taxSnapshot,
    breakdown: lockedPricingResult,
    customer_total_minor: customerTotalMinor,
  };
  const integrityHash = computeQuoteIntegrityHash(
    buildQuoteIntegrityEnvelope({
      quoteId: quoteRef.id,
      customerId: ctx.uid,
      createdAtMillis: now.toMillis(),
      expiresAtMillis: expiresAt.toMillis(),
      stops: input.stops,
      pricingSnapshot,
    })
  );

  await quoteRef.set({
    id: quoteRef.id,
    mission_id: null, // rattaché lors de createDeliveryRequest()
    customer_id: ctx.uid,
    pricing_version: lockedPricingResult.pricingVersion,
    customer_total: lockedPricingResult.customerTotal,
    customer_total_minor: pricingSnapshot.customer_total_minor,
    quote_breakdown: lockedPricingResult,
    pricing_snapshot: pricingSnapshot,
    stops: input.stops,
    route_snapshot: {
      provider: "google_routes",
      distance_km: route.distanceKm,
      estimated_duration_minutes: route.estimatedDurationMinutes,
      calculated_at: now,
    },
    tax_snapshot: taxSnapshot,
    status: "active",
    cancelled_at: null,
    integrity_hash: integrityHash,
    integrity_algorithm: "sha256",
    created_at: now,
    expires_at: expiresAt,
    is_consumed: false,
  });

  return {
    quoteId: quoteRef.id,
    pricingVersion: lockedPricingResult.pricingVersion,
    customerTotal: lockedPricingResult.customerTotal,
    breakdown: lockedPricingResult,
    distanceKm: route.distanceKm,
    estimatedDurationMinutes: route.estimatedDurationMinutes,
    expiresAtMillis: expiresAt.toMillis(),
  };
});
