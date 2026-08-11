// -----------------------------------------------------------------------------
// calculateDeliveryQuote — Cloud Function callable (customer).
//
// Calcule un devis OFFICIEL en rejouant CustomerPricingEngine côté serveur
// avec la pricing_version active lue depuis Firestore (jamais un montant
// fourni par le client). Écrit `delivery_quotes/{id}` (🔒 write côté client
// interdit par firestore.rules) avec une durée de validité issue de
// `quote_config.quote_validity_minutes`.
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { requireSignedIn } from "../lib/auth";
import { invalidArgument, failedPrecondition } from "../lib/errors";
import { calculateCustomerQuote } from "../lib/pricingEngine";
import { PricingVersionDoc } from "../lib/types";

export interface CalculateDeliveryQuoteRequest {
  vehicleCategory: string;
  distanceKm: number;
  estimatedDurationMinutes: number;
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
}

export const calculateDeliveryQuote = onCall<CalculateDeliveryQuoteRequest>(async (request) => {
  const ctx = requireSignedIn(request);
  const input = request.data;

  if (!input.vehicleCategory) throw invalidArgument("vehicleCategory est requis.");
  if (typeof input.distanceKm !== "number" || input.distanceKm < 0) {
    throw invalidArgument("distanceKm doit être un nombre positif.");
  }
  if (typeof input.estimatedDurationMinutes !== "number" || input.estimatedDurationMinutes < 0) {
    throw invalidArgument("estimatedDurationMinutes doit être un nombre positif.");
  }

  // 1. Lire le pointeur de config active, puis la version elle-même.
  const activeConfigSnap = await db.collection("pricing_configs").doc("active").get();
  if (!activeConfigSnap.exists) {
    throw failedPrecondition("Aucune configuration tarifaire active (pricing_configs/active).");
  }
  const activePricingVersion = activeConfigSnap.data()!.active_pricing_version as string;

  const versionSnap = await db.collection("pricing_versions").doc(activePricingVersion).get();
  if (!versionSnap.exists) {
    throw failedPrecondition(`pricing_versions/${activePricingVersion} introuvable.`);
  }
  const config = versionSnap.data() as PricingVersionDoc;
  if (!config.is_active) {
    throw failedPrecondition("La pricing_version active pointée n'est plus marquée is_active.");
  }

  // 2. Calcul du devis (moteur PUR, rejoué ici avec les données serveur).
  const pricingResult = calculateCustomerQuote(config, {
    vehicleCategory: input.vehicleCategory,
    distanceKm: input.distanceKm,
    estimatedDurationMinutes: input.estimatedDurationMinutes,
    handling: input.handling,
    totalWaitingMinutes: input.totalWaitingMinutes,
    additionalStopsCount: input.additionalStopsCount,
    applicableSurchargeIds: input.applicableSurchargeIds,
  });

  // 3. Écriture du devis avec durée de validité configurée.
  const quoteRef = db.collection("delivery_quotes").doc();
  const now = admin.firestore.Timestamp.now();
  const expiresAt = admin.firestore.Timestamp.fromMillis(
    now.toMillis() + config.quote_config.quote_validity_minutes * 60_000
  );

  await quoteRef.set({
    id: quoteRef.id,
    mission_id: null, // rattaché lors de createDeliveryRequest()
    customer_id: ctx.uid,
    pricing_version: pricingResult.pricingVersion,
    customer_total: pricingResult.customerTotal,
    quote_breakdown: pricingResult,
    created_at: now,
    expires_at: expiresAt,
    is_consumed: false,
  });

  return {
    quoteId: quoteRef.id,
    pricingVersion: pricingResult.pricingVersion,
    customerTotal: pricingResult.customerTotal,
    breakdown: pricingResult,
    expiresAtMillis: expiresAt.toMillis(),
  };
});
