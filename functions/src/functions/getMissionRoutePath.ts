// -----------------------------------------------------------------------------
// getMissionRoutePath — itinéraire par la route d'une mission (2026-11-18).
//
// Daniel : « les chauffeurs voient la map à vol d'oiseau ». La carte de suivi
// dessine désormais le trajet ramassage → livraison en suivant les routes.
//
// Lecture seule. Les coordonnées viennent du document mission, jamais de
// l'appelant : la fonction ne peut pas servir de relais ouvert vers le
// service d'itinéraire, et seuls le client, le chauffeur assigné et le
// personnel de CETTE mission obtiennent le tracé. Rien n'est écrit dans
// Firestore ; le tracé est gardé en mémoire le temps de vie de l'instance.
//
// Une panne du service d'itinéraire n'est pas une erreur pour l'application :
// la réponse porte `encodedPolyline: null` et la carte s'affiche sans tracé.
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { warn } from "firebase-functions/logger";
import { db } from "../lib/admin";
import { isAnalystOrAbove, requireSignedIn } from "../lib/auth";
import { invalidArgument, notFound, permissionDenied } from "../lib/errors";
import {
  DEFAULT_ROUTE_GEOMETRY_BASE_URL,
  ROUTE_PATH_PRECISION,
  canReadMissionRoute,
  missionRouteEndpoints,
  parseRouteGeometry,
  routeCacheKey,
  routeGeometryUrl,
} from "../lib/missionRoutePath";
import { consumeRoutingBudget } from "../lib/routingRateLimit";

export interface GetMissionRoutePathRequest {
  missionId: string;
}

export interface MissionRoutePathResponse {
  /** Tracé encodé (algorithme « polyline »), ou `null` si indisponible. */
  encodedPolyline: string | null;
  precision: number;
}

type RouteGeometryFetcher = (url: string) => Promise<unknown>;

const USER_AGENT = "Movi-K/1.0 (+https://movi-k.com; info@movi-k.com)";
const PROVIDER_TIMEOUT_MS = 8000;
const CACHE_TTL_MS = 6 * 60 * 60 * 1000;
const CACHE_MAX_ENTRIES = 200;

const cache = new Map<string, { polyline: string; storedAtMs: number }>();

async function fetchRouteGeometry(url: string): Promise<unknown> {
  const response = await fetch(url, {
    headers: { "User-Agent": USER_AGENT, Accept: "application/json" },
    signal: AbortSignal.timeout(PROVIDER_TIMEOUT_MS),
  });
  if (!response.ok) {
    throw new Error(`route_geometry_status_${response.status}`);
  }
  return response.json();
}

let geometryFetcher: RouteGeometryFetcher = fetchRouteGeometry;

export function setRouteGeometryFetcherForTesting(
  fetcher: RouteGeometryFetcher | null
): void {
  geometryFetcher = fetcher ?? fetchRouteGeometry;
  cache.clear();
}

function readCache(key: string, now: number): string | null {
  const entry = cache.get(key);
  if (!entry) return null;
  if (now - entry.storedAtMs > CACHE_TTL_MS) {
    cache.delete(key);
    return null;
  }
  return entry.polyline;
}

function writeCache(key: string, polyline: string, now: number): void {
  if (cache.size >= CACHE_MAX_ENTRIES) {
    // Map garde l'ordre d'insertion : la première clé est la plus ancienne.
    const oldest = cache.keys().next().value;
    if (oldest !== undefined) cache.delete(oldest);
  }
  cache.set(key, { polyline, storedAtMs: now });
}

function baseUrl(): string {
  const configured = process.env.ROUTE_GEOMETRY_BASE_URL?.trim();
  return configured && configured.startsWith("https://")
    ? configured
    : DEFAULT_ROUTE_GEOMETRY_BASE_URL;
}

export const getMissionRoutePath = onCall<GetMissionRoutePathRequest>(
  async (request): Promise<MissionRoutePathResponse> => {
    const ctx = requireSignedIn(request);
    const missionId = request.data?.missionId;
    if (typeof missionId !== "string" || !/^[a-zA-Z0-9_-]{1,128}$/.test(missionId)) {
      throw invalidArgument("missionId invalide.");
    }

    const mission = (await db.collection("delivery_requests").doc(missionId).get()).data();
    if (!mission) throw notFound("Livraison introuvable.");
    if (!canReadMissionRoute(mission, ctx.uid, isAnalystOrAbove(ctx))) {
      throw permissionDenied("Itinéraire inaccessible.");
    }

    const unavailable: MissionRoutePathResponse = {
      encodedPolyline: null,
      precision: ROUTE_PATH_PRECISION,
    };
    const endpoints = missionRouteEndpoints(mission);
    if (!endpoints) return unavailable;

    const key = routeCacheKey(endpoints);
    const cached = readCache(key, Date.now());
    if (cached) return { encodedPolyline: cached, precision: ROUTE_PATH_PRECISION };

    // Même budget par compte que le calcul de distance : borne les appels au
    // service d'itinéraire même si celui-ci est en panne (pas de mise en cache).
    await consumeRoutingBudget(ctx.uid);

    let polyline: string | null = null;
    try {
      polyline = parseRouteGeometry(await geometryFetcher(routeGeometryUrl(baseUrl(), endpoints)));
    } catch (error) {
      warn("mission_route_path_provider_failed", {
        reason: error instanceof Error ? error.message : "unknown_error",
      });
      return unavailable;
    }
    if (!polyline) {
      warn("mission_route_path_no_route", { missionId });
      return unavailable;
    }
    writeCache(key, polyline, Date.now());
    return { encodedPolyline: polyline, precision: ROUTE_PATH_PRECISION };
  }
);
