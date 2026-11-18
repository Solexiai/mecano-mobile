// -----------------------------------------------------------------------------
// missionRoutePath — tracé routier d'une mission (2026-11-18), calculs purs.
//
// Pourquoi : la carte de suivi (chauffeur et client) reliait les positions GPS
// par des lignes droites, « à vol d'oiseau ». Elle dessine maintenant
// l'itinéraire par la route entre le ramassage et la livraison.
//
// Fournisseur : un serveur OSRM (données OpenStreetMap). Le tracé de Google
// Routes ne peut pas être affiché sur un fond de carte OpenStreetMap
// (conditions Google Maps Platform, « No use with a non-Google map »), et la
// carte de l'application est OpenStreetMap (`flutter_map`).
//
// Ce fichier ne fait aucune entrée/sortie : adresse de la requête, lecture de
// la réponse, contrôle d'accès. L'appel réseau est dans `getMissionRoutePath`.
// -----------------------------------------------------------------------------

export interface RoutePoint {
  lat: number;
  lng: number;
}

export interface MissionRouteEndpoints {
  pickup: RoutePoint;
  dropoff: RoutePoint;
}

/** Précision du tracé encodé renvoyé par OSRM (`geometries=polyline`). */
export const ROUTE_PATH_PRECISION = 5;

/** Au-delà, le tracé est refusé plutôt que d'alourdir la réponse. */
export const MAX_ENCODED_ROUTE_LENGTH = 150000;

/**
 * Serveur OSRM public de FOSSGIS (celui d'openstreetmap.org). Usage léger
 * seulement : une requête par seconde au plus, agent utilisateur identifiable,
 * attribution OpenStreetMap affichée sur la carte. Remplaçable par n'importe
 * quel serveur compatible OSRM avec la variable `ROUTE_GEOMETRY_BASE_URL`.
 */
export const DEFAULT_ROUTE_GEOMETRY_BASE_URL = "https://routing.openstreetmap.de/routed-car";

function readPoint(value: unknown): RoutePoint | null {
  if (!value || typeof value !== "object") return null;
  const { lat, lng } = value as Record<string, unknown>;
  if (typeof lat !== "number" || typeof lng !== "number") return null;
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
  // (0, 0) = adresse jamais géocodée : aucun itinéraire inventé.
  if (lat === 0 && lng === 0) return null;
  return { lat, lng };
}

/** Coordonnées de ramassage et de livraison lues dans le document mission. */
export function missionRouteEndpoints(
  mission: Record<string, unknown>
): MissionRouteEndpoints | null {
  const pickup = readPoint(mission.pickup_address);
  const dropoff = readPoint(mission.dropoff_address);
  if (!pickup || !dropoff) return null;
  if (pickup.lat === dropoff.lat && pickup.lng === dropoff.lng) return null;
  return { pickup, dropoff };
}

/**
 * Le tracé ne révèle rien de plus que les deux adresses de la mission : il
 * est donc lisible par les mêmes personnes, soit le client de la mission,
 * son chauffeur assigné et le personnel (analyste ou plus).
 */
export function canReadMissionRoute(
  mission: Record<string, unknown>,
  uid: string,
  isStaff: boolean
): boolean {
  if (isStaff) return true;
  if (!uid) return false;
  return mission.customer_id === uid || mission.driver_id === uid;
}

function coordinate(value: number): string {
  // 6 décimales ≈ 11 cm : suffisant, et clé de cache stable.
  return value.toFixed(6);
}

/** Clé de cache : mêmes extrémités, même tracé. */
export function routeCacheKey(endpoints: MissionRouteEndpoints): string {
  const { pickup, dropoff } = endpoints;
  return [pickup.lat, pickup.lng, dropoff.lat, dropoff.lng].map(coordinate).join(",");
}

/** Adresse OSRM : longitude avant latitude, tracé complet, sans étapes. */
export function routeGeometryUrl(
  baseUrl: string,
  endpoints: MissionRouteEndpoints
): string {
  const base = baseUrl.replace(/\/+$/, "");
  const { pickup, dropoff } = endpoints;
  const path =
    `${coordinate(pickup.lng)},${coordinate(pickup.lat)};` +
    `${coordinate(dropoff.lng)},${coordinate(dropoff.lat)}`;
  return `${base}/route/v1/driving/${path}` +
    "?overview=full&geometries=polyline&alternatives=false&steps=false";
}

/**
 * Tracé encodé (algorithme « polyline », précision 5) de la première route
 * d'une réponse OSRM, ou `null` si la réponse n'est pas exploitable.
 */
export function parseRouteGeometry(body: unknown): string | null {
  if (!body || typeof body !== "object") return null;
  const { code, routes } = body as { code?: unknown; routes?: unknown };
  if (code !== "Ok" || !Array.isArray(routes) || routes.length === 0) return null;
  const geometry = (routes[0] as { geometry?: unknown } | null)?.geometry;
  if (typeof geometry !== "string") return null;
  if (geometry.length < 2 || geometry.length > MAX_ENCODED_ROUTE_LENGTH) return null;
  // Un tracé encodé n'utilise que les caractères ASCII 63 (« ? ») à 126 (« ~ »).
  if (!/^[?-~]+$/.test(geometry)) return null;
  return geometry;
}
