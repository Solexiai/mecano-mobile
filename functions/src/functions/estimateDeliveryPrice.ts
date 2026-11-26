// -----------------------------------------------------------------------------
// estimateDeliveryPrice — Cloud Function callable PUBLIQUE, LECTURE SEULE
// (décision du propriétaire, 26 novembre 2026).
//
// Deux codes postaux + un poids (léger, moyen, lourd) → une fourchette de
// prix, taxes comprises. Aucune connexion requise : c'est la réponse à
// « combien ça coûte ? » sur l'accueil et sur la page d'arrivée des
// publicités. Ce n'est pas un devis : rien n'est écrit dans
// `delivery_quotes`, et le prix exact vient ensuite du parcours de demande.
//
// Garde-fous d'un calcul ouvert à tous :
//   - plafond par adresse IP et plafond global par jour (routingRateLimit) ;
//   - trajets gardés en mémoire 6 h : un même couple de codes postaux ne
//     coûte qu'un appel Google Routes ;
//   - la réponse ne contient que deux dollars entiers et une distance.
// -----------------------------------------------------------------------------
import { CallableRequest, HttpsError, onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { failedPrecondition, invalidArgument } from "../lib/errors";
import { missionFeePolicyFrom } from "../lib/missionFees";
import { PILOT_PRICING_CATEGORIES } from "../lib/pricingConfigValidation";
import {
  assemblePublicEstimate,
  ESTIMATE_HIGH_HANDLING,
  ESTIMATE_LOW_HANDLING,
  estimateItemCategory,
  normalizePostalCode,
  parseEstimateWeight,
  PublicEstimate,
} from "../lib/publicEstimate";
import { consumePublicEstimateBudget } from "../lib/routingRateLimit";
import { PricingVersionDoc } from "../lib/types";
import { calculatePostalCodeRoute, RouteEstimate } from "./calculateRoute";
import { quoteAmounts } from "./previewPricingConfiguration";

export interface EstimateDeliveryPriceRequest {
  fromPostalCode: string;
  toPostalCode: string;
  weight: string;
}

const UNAVAILABLE = "L'estimation n'est pas disponible pour le moment.";
const ROUTE_NOT_FOUND = "Trajet introuvable. Vérifiez les deux codes postaux.";

const ROUTE_CACHE_MS = 6 * 60 * 60 * 1000;
const ROUTE_CACHE_MAX = 500;
const routeCache = new Map<string, { route: RouteEstimate; expiresAtMs: number }>();

const CONFIG_CACHE_MS = 10 * 60 * 1000;
let cachedConfig: { id: string; config: PricingVersionDoc; expiresAtMs: number } | null = null;

export function clearEstimateCachesForTesting(): void {
  routeCache.clear();
  cachedConfig = null;
}

async function activeGrid(now: number): Promise<{ id: string; config: PricingVersionDoc }> {
  if (cachedConfig && cachedConfig.expiresAtMs > now) return cachedConfig;
  const activeSnap = await db.collection("pricing_configs").doc("active").get();
  const rawActiveId = activeSnap.data()?.active_pricing_version;
  const id = typeof rawActiveId === "string" && rawActiveId.trim() ? rawActiveId.trim() : null;
  if (!id) throw failedPrecondition(UNAVAILABLE);
  const config = (await db.collection("pricing_versions").doc(id).get()).data() as PricingVersionDoc | undefined;
  if (!config) throw failedPrecondition(UNAVAILABLE);
  cachedConfig = { id, config, expiresAtMs: now + CONFIG_CACHE_MS };
  return cachedConfig;
}

/**
 * Adresse IP du visiteur. Derrière Google, la dernière valeur de
 * `x-forwarded-for` est celle que Google a vue ; les précédentes sont
 * écrites par le visiteur et ne comptent pas.
 */
export function visitorIp(request: Pick<CallableRequest<unknown>, "rawRequest">): string {
  const raw = request.rawRequest as unknown as { headers?: Record<string, unknown>; ip?: unknown } | undefined;
  const header = raw?.headers?.["x-forwarded-for"];
  const forwarded = (Array.isArray(header) ? header.join(",") : typeof header === "string" ? header : "")
    .split(",").map((part) => part.trim()).filter(Boolean);
  const ip = forwarded.length ? forwarded[forwarded.length - 1] : typeof raw?.ip === "string" ? raw.ip : "";
  return ip && ip.length <= 64 ? ip : "unknown";
}

export const estimateDeliveryPrice = onCall<EstimateDeliveryPriceRequest>(
  async (request): Promise<PublicEstimate> => {
    const data = (request.data ?? {}) as Partial<EstimateDeliveryPriceRequest>;
    const from = normalizePostalCode(data.fromPostalCode);
    const to = normalizePostalCode(data.toPostalCode);
    const weight = parseEstimateWeight(data.weight);
    if (!from || !to) throw invalidArgument("Entrez deux codes postaux canadiens, par exemple J2G 3V5.");
    if (!weight) throw invalidArgument("Choisissez léger, moyen ou lourd.");

    const now = Date.now();
    const key = `${from}|${to}`;
    let route = routeCache.get(key);
    if (!route || route.expiresAtMs <= now) {
      // Seul un trajet à calculer coûte un appel Google : c'est lui qu'on plafonne.
      await consumePublicEstimateBudget(visitorIp(request));
      const fetched = await calculatePostalCodeRoute({ fromPostalCode: from, toPostalCode: to });
      if (!fetched) throw new HttpsError("not-found", ROUTE_NOT_FOUND);
      if (routeCache.size >= ROUTE_CACHE_MAX) routeCache.clear();
      route = { route: fetched, expiresAtMs: now + ROUTE_CACHE_MS };
      routeCache.set(key, route);
    }

    const { id, config } = await activeGrid(now);
    const category = estimateItemCategory(config, weight);
    const feePolicy = missionFeePolicyFrom(config.mission_fee_policy, id);
    const atMillis = admin.firestore.Timestamp.now().toMillis();
    const scenario = {
      id: `estimate_${weight}`,
      distanceKm: route.route.distanceKm,
      durationMinutes: route.route.estimatedDurationMinutes,
      additionalStops: 0,
      items: category ? [{ category, quantity: 1 }] : [],
    };
    const low = await quoteAmounts(config, PILOT_PRICING_CATEGORIES[0],
      { ...scenario, handling: { ...ESTIMATE_LOW_HANDLING } }, feePolicy, atMillis);
    const high = await quoteAmounts(config, PILOT_PRICING_CATEGORIES[0],
      { ...scenario, handling: { ...ESTIMATE_HIGH_HANDLING } }, feePolicy, atMillis);
    const estimate = low && high
      ? assemblePublicEstimate(low.customer_total_minor, high.customer_total_minor, route.route.distanceKm)
      : null;
    if (!estimate) throw failedPrecondition(UNAVAILABLE);
    return estimate;
  }
);
