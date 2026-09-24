import { createHash } from "crypto";
import { supportsVehicleCategory } from "./vehicleCategory";

type Data = Record<string, any>;
export const DISPATCH_GPS_MAX_AGE_MS = 5 * 60_000;
export const DELIVERY_OFFER_TTL_MS = 45_000;
export function coordinates(lat: unknown, lng: unknown): { lat: number; lng: number } | null {
  return typeof lat === "number" && Number.isFinite(lat) && Math.abs(lat) <= 90 &&
    typeof lng === "number" && Number.isFinite(lng) && Math.abs(lng) <= 180
    ? { lat, lng } : null;
}
export function distanceKm(a: { lat: number; lng: number }, b: { lat: number; lng: number }): number {
  const r = Math.PI / 180;
  const h = Math.sin((b.lat - a.lat) * r / 2) ** 2 + Math.cos(a.lat * r) *
    Math.cos(b.lat * r) * Math.sin((b.lng - a.lng) * r / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(Math.min(1, h)), Math.sqrt(Math.max(0, 1 - h)));
}
export function timestampMs(value: unknown): number | null {
  if (!value || typeof (value as { toMillis?: unknown }).toMillis !== "function") return null;
  const result = (value as { toMillis(): number }).toMillis();
  return Number.isFinite(result) ? result : null;
}
export function eligibleForPickup(driver: Data, location: Data | undefined, mission: Data, now: number):
  { distanceKm: number; origin: "gps" | "base" } | null {
  if (driver.status !== "approved" || driver.online_status !== "online" || driver.documents_all_valid !== true) return null;
  if (location?.active_delivery_id) return null;
  if (!supportsVehicleCategory(Array.isArray(driver.accepted_vehicle_categories) ? driver.accepted_vehicle_categories : [], mission.required_vehicle_category)) return null;
  const radius = driver.service_radius_km;
  const pickup = coordinates(mission.pickup_address?.lat, mission.pickup_address?.lng);
  if (!pickup || typeof radius !== "number" || !Number.isFinite(radius) || radius <= 0) return null;
  let point = coordinates(driver.base_lat, driver.base_lng);
  let origin: "gps" | "base" = "base";
  // Never present stale GPS as current, nor silently relocate that driver to base.
  // Base is used only before any GPS sample has been recorded.
  if (location?.updated_at !== undefined || location?.latitude !== undefined || location?.longitude !== undefined) {
    const at = timestampMs(location.updated_at);
    point = coordinates(location.latitude, location.longitude);
    if (!point || at === null || now - at > DISPATCH_GPS_MAX_AGE_MS || at > now + 30_000) return null;
    origin = "gps";
  }
  if (!point) return null;
  const distance = distanceKm(point, pickup);
  return distance <= radius ? { distanceKm: distance, origin } : null;
}

export function liveOffer(offer: Data, now: number): boolean {
  const expiry = timestampMs(offer.expires_at);
  return offer.status === "pending" && expiry !== null && expiry > now;
}

export function deliveryOfferId(missionId: string, driverId: string): string {
  return createHash("sha256").update(JSON.stringify([missionId, driverId])).digest("hex");
}
