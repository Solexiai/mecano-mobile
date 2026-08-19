// -----------------------------------------------------------------------------
// Encodage geohash minimal (base32), sans dépendance externe.
//
// Utilisé pour maintenir `driver_profiles.current_geohash` et
// `delivery_requests.dispatch_zone_geohash` (voir docs/FIRESTORE_ARCHITECTURE.md
// section Dispatch). Précision par défaut ~1.2km (precision=6), suffisante
// pour une requête de zone grossière avant filtrage fin par distance réelle
// côté application/Cloud Function de dispatch.
// -----------------------------------------------------------------------------

const BASE32 = "0123456789bcdefghjkmnpqrstuvwxyz";

export function encodeGeohash(latitude: number, longitude: number, precision = 6): string {
  let latMin = -90;
  let latMax = 90;
  let lonMin = -180;
  let lonMax = 180;
  let isEven = true;
  let bit = 0;
  let ch = 0;
  let geohash = "";

  while (geohash.length < precision) {
    if (isEven) {
      const mid = (lonMin + lonMax) / 2;
      if (longitude > mid) {
        ch |= 1 << (4 - bit);
        lonMin = mid;
      } else {
        lonMax = mid;
      }
    } else {
      const mid = (latMin + latMax) / 2;
      if (latitude > mid) {
        ch |= 1 << (4 - bit);
        latMin = mid;
      } else {
        latMax = mid;
      }
    }
    isEven = !isEven;
    if (bit < 4) {
      bit++;
    } else {
      geohash += BASE32[ch];
      bit = 0;
      ch = 0;
    }
  }
  return geohash;
}

/**
 * Borne supérieure (exclue) pour une requête de plage `>= prefix && < bound`
 * sur un champ geohash — pattern utilisé par le dispatch (voir
 * FIRESTORE_ARCHITECTURE.md). `\uf8ff` est un caractère Unicode très élevé,
 * garantissant que tout geohash commençant par `prefix` est inclus.
 */
export function geohashUpperBound(prefix: string): string {
  return `${prefix}\uf8ff`;
}
