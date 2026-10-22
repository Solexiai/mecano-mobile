// Configurable service areas. Legacy rectangles remain supported.
// Circle radius is geographic distance, never a routing/pricing distance.
import { db } from "./admin";

export interface ServiceZoneRect {
  name: string;
  min_lat: number;
  max_lat: number;
  min_lng: number;
  max_lng: number;
}
export interface ServiceZoneCircle {
  name: string;
  type: "circle";
  center_lat: number;
  center_lng: number;
  radius_km: number;
}
export interface ServiceZonesConfig {
  enabled: boolean;
  zones: (ServiceZoneRect | ServiceZoneCircle)[];
}
const CONFIG_DOC_PATH = "system_config/service_zones";

/**
 * Owner decision 2026-10-22: launch zone is Granby with a 40 km radius (same
 * values as config/service_zones.granby-pilot.json). Used by the price and
 * booking paths only when `system_config/service_zones` does not exist, so a
 * document written by an admin always takes precedence (including
 * `enabled: false`). Without it, those paths refused every request with
 * `service_area_unconfigured`.
 */
export const DEFAULT_SERVICE_ZONES: ServiceZonesConfig = Object.freeze({
  enabled: true,
  zones: [Object.freeze({
    name: "Granby",
    type: "circle" as const,
    center_lat: 45.39856,
    center_lng: -72.72225,
    radius_km: 40,
  })],
}) as ServiceZonesConfig;

export async function getServiceZonesConfig(
  options: { fallbackToLaunchZone?: boolean } = {}
): Promise<ServiceZonesConfig> {
  const snap = await db.doc(CONFIG_DOC_PATH).get();
  if (!snap.exists) {
    // Legacy callers keep their historical "no document = no restriction".
    return options.fallbackToLaunchZone
      ? { enabled: DEFAULT_SERVICE_ZONES.enabled, zones: [...DEFAULT_SERVICE_ZONES.zones] }
      : { enabled: false, zones: [] };
  }
  const data = snap.data() as Partial<ServiceZonesConfig> | undefined;
  return {
    enabled: data?.enabled === true,
    zones: Array.isArray(data?.zones) ? data.zones : [],
  };
}
function coordinatesValid(lat: number, lng: number): boolean {
  return Number.isFinite(lat) && Number.isFinite(lng) &&
    Math.abs(lat) <= 90 && Math.abs(lng) <= 180;
}
export function isWithinServiceZones(
  lat: number,
  lng: number,
  config: ServiceZonesConfig
): boolean {
  // Preserve legacy behavior. Booking additionally requires a configured zone.
  if (!config.enabled || config.zones.length === 0) return true;
  if (!coordinatesValid(lat, lng)) return false;
  return config.zones.some((z) => {
    if (!z || typeof z !== "object") return false;
    if ("type" in z) {
      if (z.type !== "circle" || !coordinatesValid(z.center_lat, z.center_lng) ||
          !Number.isFinite(z.radius_km) || z.radius_km <= 0) return false;
      const radians = Math.PI / 180;
      const a = Math.sin((lat - z.center_lat) * radians / 2) ** 2 +
        Math.cos(lat * radians) * Math.cos(z.center_lat * radians) *
        Math.sin((lng - z.center_lng) * radians / 2) ** 2;
      const distanceKm = 6371.0088 * 2 * Math.asin(Math.sqrt(Math.min(1, Math.max(0, a))));
      return distanceKm <= z.radius_km;
    }
    return coordinatesValid(z.min_lat, z.min_lng) &&
      coordinatesValid(z.max_lat, z.max_lng) &&
      lat >= z.min_lat && lat <= z.max_lat && lng >= z.min_lng && lng <= z.max_lng;
  });
}
