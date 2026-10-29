// Dispatch par distance réelle (2026-10-28, constaté en recette avec Daniel).
//
// Avant : le dispatch immédiat comparait les 3 premiers caractères du
// geohash (cases d'environ 110 × 156 km). La frontière de case passe à
// -73,125° de longitude, à ~30 km à l'ouest de Granby : un chauffeur à
// Chambly (45 km) était exclu alors qu'un chauffeur à Sherbrooke (75 km)
// était inclus. La zone de 40 km n'était donc pas respectée.
//
// Maintenant : distance à vol d'oiseau entre la position du chauffeur et
// l'adresse de ramassage, comparée au rayon de service du chauffeur (ou
// 40 km par défaut). Position retenue, dans l'ordre :
//   1. dernière position GPS si elle a moins de FRESH_LOCATION_MS ;
//   2. sinon l'adresse de base déclarée à l'inscription (base_lat/base_lng) ;
//   3. sinon le centre de sa dernière case GPS connue (current_geohash, ~1 km).
// Un chauffeur sans aucune position connue n'est pas sollicité.

export const DEFAULT_DISPATCH_RADIUS_KM = 40;
export const MAX_DISPATCH_RADIUS_KM = 100;
export const FRESH_LOCATION_MS = 30 * 60 * 1000;

export interface LatLng { lat: number; lng: number }

function valid(lat: unknown, lng: unknown): boolean {
  return typeof lat === "number" && Number.isFinite(lat) && Math.abs(lat) <= 90 &&
    typeof lng === "number" && Number.isFinite(lng) && Math.abs(lng) <= 180;
}

export function haversineKm(a: LatLng, b: LatLng): number {
  const r = Math.PI / 180;
  const x = Math.sin((b.lat - a.lat) * r / 2) ** 2 +
    Math.cos(a.lat * r) * Math.cos(b.lat * r) * Math.sin((b.lng - a.lng) * r / 2) ** 2;
  return 6371.0088 * 2 * Math.asin(Math.sqrt(Math.min(1, Math.max(0, x))));
}

/** Coordonnées du ramassage d'une mission, ou null si absentes. */
export function pickupPoint(mission: { pickup_address?: unknown }): LatLng | null {
  const a = mission.pickup_address as { lat?: unknown; lng?: unknown } | undefined;
  return a && valid(a.lat, a.lng) ? { lat: a.lat as number, lng: a.lng as number } : null;
}

/** Position du chauffeur à utiliser pour le dispatch (GPS frais, sinon base). */
export function driverDispatchPoint(
  driver: Record<string, unknown>,
  location: Record<string, unknown> | undefined,
  nowMillis = Date.now()
): LatLng | null {
  const updated = (location?.updated_at as { toMillis?: () => number } | undefined)?.toMillis?.();
  if (typeof updated === "number" && updated <= nowMillis && nowMillis - updated <= FRESH_LOCATION_MS &&
      valid(location?.latitude, location?.longitude)) {
    return { lat: location!.latitude as number, lng: location!.longitude as number };
  }
  if (valid(driver.base_lat, driver.base_lng)) {
    return { lat: driver.base_lat as number, lng: driver.base_lng as number };
  }
  return typeof driver.current_geohash === "string" ? decodeGeohashCenter(driver.current_geohash) : null;
}

const BASE32 = "0123456789bcdefghjkmnpqrstuvwxyz";

/** Centre d'une case geohash ; null si la chaîne n'est pas un geohash valide (≥ 5 caractères). */
export function decodeGeohashCenter(hash: string): LatLng | null {
  if (hash.length < 5) return null;
  const lat = [-90, 90], lng = [-180, 180];
  let even = true;
  for (const ch of hash.toLowerCase()) {
    const value = BASE32.indexOf(ch);
    if (value < 0) return null;
    for (let bit = 4; bit >= 0; bit--) {
      const range = even ? lng : lat;
      const mid = (range[0] + range[1]) / 2;
      if ((value >> bit) & 1) range[0] = mid; else range[1] = mid;
      even = !even;
    }
  }
  return { lat: (lat[0] + lat[1]) / 2, lng: (lng[0] + lng[1]) / 2 };
}

export function dispatchRadiusKm(driver: Record<string, unknown>): number {
  const r = driver.service_radius_km;
  return typeof r === "number" && Number.isFinite(r) && r > 0 ? Math.min(r, MAX_DISPATCH_RADIUS_KM) : DEFAULT_DISPATCH_RADIUS_KM;
}

export function driverWithinDispatchRadius(
  driver: Record<string, unknown>,
  location: Record<string, unknown> | undefined,
  pickup: LatLng,
  nowMillis = Date.now()
): boolean {
  const point = driverDispatchPoint(driver, location, nowMillis);
  return point !== null && haversineKm(point, pickup) <= dispatchRadiusKm(driver);
}
