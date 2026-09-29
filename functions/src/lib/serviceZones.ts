// -----------------------------------------------------------------------------
// serviceZones — validation CONFIGURABLE de la zone de service Movi-K.
//
// MOVI-K — CORRECTION UX LIVRAISON (adresses réelles + autocomplete +
// géocodage), section "ZONE DE SERVICE" : prépare la capacité de refuser un
// pickup/dropoff hors zone, SANS jamais hardcoder de ville (ex: Terrebonne,
// Granby) dans le code. La configuration vit dans Firestore
// (`system_config/service_zones`), modifiable sans redéploiement :
//
//   system_config/service_zones = {
//     enabled: boolean,           // false par défaut => aucune restriction
//     zones: [                     // liste de rectangles lat/lng (simple,
//       {                          // suffisant pour un MVP ; remplaçable
//         name: string,            // plus tard par des polygones réels sans
//         min_lat: number,         // changer l'appelant (isWithinServiceZones
//         max_lat: number,         // reste le seul point d'entrée).
//         min_lng: number,
//         max_lng: number,
//       },
//     ],
//   }
//
// Comportement fail-open TANT QUE non configuré (`enabled` absent/false ou
// aucune zone définie) : AUCUNE régression pour les déploiements existants
// qui n'ont pas encore défini de zone. Une fois `enabled: true` avec au
// moins une zone, toute coordonnée hors de TOUTES les zones est rejetée.
// -----------------------------------------------------------------------------

import { db } from "./admin";

export interface ServiceZoneRect {
  name: string;
  min_lat: number;
  max_lat: number;
  min_lng: number;
  max_lng: number;
}

export interface ServiceZonesConfig {
  enabled: boolean;
  zones: ServiceZoneRect[];
}

const CONFIG_DOC_PATH = "system_config/service_zones";

export async function getServiceZonesConfig(): Promise<ServiceZonesConfig> {
  const snap = await db.doc(CONFIG_DOC_PATH).get();
  if (!snap.exists) {
    return { enabled: false, zones: [] };
  }
  const data = snap.data() as Partial<ServiceZonesConfig> | undefined;
  return {
    enabled: data?.enabled === true,
    zones: Array.isArray(data?.zones) ? (data!.zones as ServiceZoneRect[]) : [],
  };
}

/**
 * Retourne `true` si (lat, lng) est acceptable :
 *  - la validation est désactivée (`enabled: false` ou aucune zone) => true
 *    (comportement historique inchangé, aucune régression) ;
 *  - OU la coordonnée tombe dans AU MOINS une zone configurée.
 */
export function isWithinServiceZones(
  lat: number,
  lng: number,
  config: ServiceZonesConfig
): boolean {
  if (!config.enabled || config.zones.length === 0) return true;
  return config.zones.some(
    (z) => lat >= z.min_lat && lat <= z.max_lat && lng >= z.min_lng && lng <= z.max_lng
  );
}

function haversineKm(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const toRad = (value: number): number => (value * Math.PI) / 180;
  const earthRadiusKm = 6371;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return earthRadiusKm * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/**
 * Validation géographique de repli quand aucune zone globale n'est encore
 * configurée. Elle s'appuie uniquement sur des chauffeurs réellement
 * approuvés, documentés et possédant une base géocodée + un rayon positif.
 * Elle ne garantit jamais qu'un chauffeur est disponible maintenant.
 */
export async function isWithinApprovedDriverCoverage(lat: number, lng: number): Promise<boolean> {
  const snap = await db
    .collection("driver_profiles")
    .where("status", "==", "approved")
    .limit(100)
    .get();

  return snap.docs.some((doc) => {
    const driver = doc.data();
    if (driver.documents_all_valid !== true) return false;

    const baseLat = driver.base_lat;
    const baseLng = driver.base_lng;
    const radiusKm = Number(driver.service_radius_km);

    if (
      typeof baseLat !== "number" ||
      typeof baseLng !== "number" ||
      !Number.isFinite(radiusKm) ||
      radiusKm <= 0
    ) {
      return false;
    }

    return haversineKm(lat, lng, baseLat, baseLng) <= radiusKm;
  });
}

/**
 * Point d'entrée utilisé avant un devis. Une zone Firestore explicite a
 * priorité. Tant qu'elle n'existe pas, on utilise les zones déclarées des
 * chauffeurs approuvés plutôt que de prétendre couvrir une région entière.
 */
export async function isWithinCurrentServiceArea(
  lat: number,
  lng: number,
  config?: ServiceZonesConfig
): Promise<boolean> {
  const resolvedConfig = config ?? (await getServiceZonesConfig());
  if (resolvedConfig.enabled && resolvedConfig.zones.length > 0) {
    return isWithinServiceZones(lat, lng, resolvedConfig);
  }
  return isWithinApprovedDriverCoverage(lat, lng);
}
