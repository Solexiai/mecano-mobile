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

  // 2. Premier passage SANS remise — nécessaire pour connaître le subtotal
  // brut (base de calcul d'une remise en pourcentage), sans jamais faire
  // confiance à un montant envoyé par le client.
  const baseArgs = {
    vehicleCategory: input.vehicleCategory,
    distanceKm: input.distanceKm,
    estimatedDurationMinutes: input.estimatedDurationMinutes,
    handling: input.handling,
    totalWaitingMinutes: input.totalWaitingMinutes,
    additionalStopsCount: input.additionalStopsCount,
    applicableSurchargeIds: input.applicableSurchargeIds,
  };
  const unDiscountedResult = calculateCustomerQuote(config, baseArgs);

  // 3. Résolution serveur du montant de remise (jamais un montant client).
  const customerDiscountAmount = await resolvePromoDiscountAmount(
    input.promoCode,
    unDiscountedResult.subtotal // == rawSubtotal ici puisqu'aucune remise n'a encore été appliquée
  );

  // 4. Calcul final du devis avec la remise résolue côté serveur.
  const pricingResult = calculateCustomerQuote(config, {
    ...baseArgs,
    customerDiscountAmount,
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
