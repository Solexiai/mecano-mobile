import { Timestamp } from "firebase-admin/firestore";
import { encodeGeohash } from "../../src/lib/geohash";
import {
  decodeGeohashCenter, dispatchRadiusKm, driverDispatchPoint, driverWithinDispatchRadius, haversineKm, FRESH_LOCATION_MS,
} from "../../src/lib/dispatchDistance";

const granby = { lat: 45.402, lng: -72.733 };
const now = 1_800_000_000_000;
const ts = (ms: number) => Timestamp.fromMillis(ms);

describe("dispatch par distance réelle (2026-10-28)", () => {
  it("la frontière geohash ne décide plus : Chambly (≈45 km) hors 40 km, Bromont (≈13 km) dedans, Sherbrooke dehors", () => {
    expect(haversineKm(granby, { lat: 45.32, lng: -72.65 })).toBeLessThan(15);
    expect(driverWithinDispatchRadius({ base_lat: 45.32, base_lng: -72.65 }, undefined, granby, now)).toBe(true);
    expect(driverWithinDispatchRadius({ base_lat: 45.40, base_lng: -71.89 }, undefined, granby, now)).toBe(false); // Sherbrooke
    expect(driverWithinDispatchRadius({ base_lat: 45.45, base_lng: -73.29 }, undefined, granby, now)).toBe(false); // Chambly
    // Avec un rayon de service de 60 km, Chambly devient admissible.
    expect(driverWithinDispatchRadius({ base_lat: 45.45, base_lng: -73.29, service_radius_km: 60 }, undefined, granby, now)).toBe(true);
  });

  it("GPS frais prioritaire, GPS ancien ignoré au profit de l'adresse de base, puis dernière case GPS", () => {
    const fresh = { latitude: 45.70, longitude: -73.64, updated_at: ts(now - 60_000) }; // Terrebonne, il y a 1 min
    const stale = { ...fresh, updated_at: ts(now - FRESH_LOCATION_MS - 1) };
    const driver = { base_lat: granby.lat, base_lng: granby.lng };
    expect(driverWithinDispatchRadius(driver, fresh, granby, now)).toBe(false);
    expect(driverWithinDispatchRadius(driver, stale, granby, now)).toBe(true);
    const onlyGeohash = { current_geohash: encodeGeohash(45.40, -72.70, 6) };
    expect(driverWithinDispatchRadius(onlyGeohash, undefined, granby, now)).toBe(true);
    expect(driverDispatchPoint({}, undefined, now)).toBeNull();
  });

  it("décodage geohash et rayon par défaut", () => {
    const c = decodeGeohashCenter(encodeGeohash(45.402, -72.733, 6))!;
    expect(haversineKm(c, granby)).toBeLessThan(1);
    expect(decodeGeohashCenter("f25abc")).toBeNull(); // « a » n'existe pas en base32 geohash
    expect(decodeGeohashCenter("xn7")).toBeNull();
    expect(dispatchRadiusKm({})).toBe(40);
    expect(dispatchRadiusKm({ service_radius_km: 500 })).toBe(100);
  });
});
