import { coordinates, distanceKm, eligibleForPickup, liveOffer, DISPATCH_GPS_MAX_AGE_MS } from "../../src/lib/dispatchEligibility";
const now = 1_800_000_000_000;
const at = (ms: number) => ({ toMillis: () => ms });
const driver = { status: "approved", online_status: "online", documents_all_valid: true,
  accepted_vehicle_categories: ["cargoVan"], service_radius_km: 5, base_lat: 45.5, base_lng: -73.6 };
const mission = { required_vehicle_category: "cargoVan", pickup_address: { lat: 45.501, lng: -73.601 } };
describe("dispatch geographic eligibility", () => {
  test("uses base only before the first GPS sample", () => {
    expect(eligibleForPickup(driver, undefined, mission, now)?.origin).toBe("base");
  });
  test("rejects a pickup 50 km away despite a shared geohash cell", () => {
    expect(eligibleForPickup(driver, undefined, { ...mission, pickup_address: { lat: 45.9, lng: -73.3 } }, now)).toBeNull();
  });
  test("includes nearby pickups across adjacent geohash cells", () => {
    const result = eligibleForPickup({ ...driver, base_lng: -73.1251 }, undefined,
      { ...mission, pickup_address: { lat: 45.5, lng: -73.1249 } }, now);
    expect(result?.distanceKm).toBeLessThan(0.02);
  });
  test("uses fresh GPS instead of base", () => {
    expect(eligibleForPickup({ ...driver, base_lat: 1, base_lng: 2 },
      { latitude: 45.5, longitude: -73.6, updated_at: at(now) }, mission, now)?.origin).toBe("gps");
  });
  test.each([now - DISPATCH_GPS_MAX_AGE_MS - 1, now + 30001])("rejects stale/future GPS without moving driver to base", (timestamp) => {
    expect(eligibleForPickup(driver, { latitude: 45.5, longitude: -73.6, updated_at: at(timestamp) }, mission, now)).toBeNull();
  });
  test.each([{ status: "suspended" }, { online_status: "on_mission" }, { online_status: "offline" },
    { documents_all_valid: false }, { service_radius_km: 0 }, { service_radius_km: NaN },
    { accepted_vehicle_categories: ["car"] }])("rejects ineligible driver %j", (overrides) => {
    expect(eligibleForPickup({ ...driver, ...overrides }, undefined, mission, now)).toBeNull();
  });
  test("rejects a driver still attached to a mission", () => {
    expect(eligibleForPickup(driver, { active_delivery_id: "other" }, mission, now)).toBeNull();
  });
  test.each([[91, 0], [0, 181], [NaN, 0], [0, Infinity], ["45", 0]])("rejects invalid coordinates %j %j", (lat, lng) => {
    expect(coordinates(lat, lng)).toBeNull();
  });
  test("calculates zero distance and handles antipodes", () => {
    expect(distanceKm({ lat: 0, lng: 0 }, { lat: 0, lng: 0 })).toBe(0);
    expect(Number.isFinite(distanceKm({ lat: 0, lng: 0 }, { lat: 0, lng: 180 }))).toBe(true);
  });
  test("expires an offer at the exact boundary", () => {
    expect(liveOffer({ status: "pending", expires_at: at(now) }, now)).toBe(false);
    expect(liveOffer({ status: "pending", expires_at: at(now + 1) }, now)).toBe(true);
    expect(liveOffer({ status: "declined", expires_at: at(now + 1000) }, now)).toBe(false);
    expect(liveOffer({ status: "pending" }, now)).toBe(false);
  });
});
