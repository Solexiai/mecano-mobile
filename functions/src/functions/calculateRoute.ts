// -----------------------------------------------------------------------------
// calculateRoute — distance et durée routières réelles via Google Routes API.
// L'appel est exécuté côté serveur avec l'identité de la Cloud Function :
// aucune clé Google Maps sensible n'est exposée dans le navigateur.
// -----------------------------------------------------------------------------

import { GoogleAuth } from "google-auth-library";
import { onCall } from "firebase-functions/v2/https";
import { requireSignedIn } from "../lib/auth";
import { internal, invalidArgument } from "../lib/errors";

export interface CalculateRouteRequest {
  pickupLat: number;
  pickupLng: number;
  dropoffLat: number;
  dropoffLng: number;
  intermediateStops?: Array<{ lat: number; lng: number }>;
}

export interface RouteEstimate {
  distanceKm: number;
  estimatedDurationMinutes: number;
  isApproximate: false;
}

interface GoogleRoutesResponse {
  routes?: Array<{
    distanceMeters?: number;
    duration?: string;
  }>;
}
type RouteFetcher = (input: CalculateRouteRequest) => Promise<RouteEstimate>;

const googleAuth = new GoogleAuth({
  scopes: ["https://www.googleapis.com/auth/cloud-platform"],
});

function isCoordinateValid(value: unknown, min: number, max: number): value is number {
  return (
    typeof value === "number" &&
    Number.isFinite(value) &&
    value >= min &&
    value <= max
  );
}

function validateInput(input: CalculateRouteRequest): void {
  if (
    !isCoordinateValid(input.pickupLat, -90, 90) ||
    !isCoordinateValid(input.dropoffLat, -90, 90) ||
    !isCoordinateValid(input.pickupLng, -180, 180) ||
    !isCoordinateValid(input.dropoffLng, -180, 180)
  ) {
    throw invalidArgument("Coordonnées de départ ou d'arrivée invalides.");
  }
  for (const stop of input.intermediateStops ?? []) {
    if (
      !isCoordinateValid(stop.lat, -90, 90) ||
      !isCoordinateValid(stop.lng, -180, 180)
    ) {
      throw invalidArgument("Coordonnées d'un arrêt intermédiaire invalides.");
    }
  }
}
async function fetchGoogleRoute(
  input: CalculateRouteRequest
): Promise<RouteEstimate> {
  const projectId =
    process.env.GCLOUD_PROJECT ??
    process.env.GOOGLE_CLOUD_PROJECT ??
    "movik-connect-prod";
  const client = await googleAuth.getClient();
  const response = await client.request<GoogleRoutesResponse>({
    url: "https://routes.googleapis.com/directions/v2:computeRoutes",
    method: "POST",
    headers: {
      "X-Goog-FieldMask": "routes.distanceMeters,routes.duration",
      "X-Goog-User-Project": projectId,
    },
    data: {
      origin: {
        location: {
          latLng: {
            latitude: input.pickupLat,
            longitude: input.pickupLng,
          },
        },
      },
      destination: {
        location: {
          latLng: {
            latitude: input.dropoffLat,
            longitude: input.dropoffLng,
          },
        },
      },
      intermediates: (input.intermediateStops ?? []).map((stop) => ({
        location: { latLng: { latitude: stop.lat, longitude: stop.lng } },
      })),
      travelMode: "DRIVE",
      routingPreference: "TRAFFIC_UNAWARE",
      languageCode: "fr-CA",
      units: "METRIC",
    },
  });

  const route = response.data.routes?.[0];
  const distanceMeters = route?.distanceMeters;
  const durationSeconds = Number(route?.duration?.replace(/s$/, ""));
  if (
    typeof distanceMeters !== "number" ||
    !Number.isFinite(distanceMeters) ||
    distanceMeters <= 0 ||
    !Number.isFinite(durationSeconds) ||
    durationSeconds <= 0
  ) {
    throw new Error("Google Routes n'a retourné aucun itinéraire exploitable.");
  }

  return {
    distanceKm: Number((distanceMeters / 1000).toFixed(2)),
    estimatedDurationMinutes: Number((durationSeconds / 60).toFixed(1)),
    isApproximate: false,
  };
}

let routeFetcher: RouteFetcher = fetchGoogleRoute;

export function setRouteFetcherForTesting(fetcher: RouteFetcher | null): void {
  routeFetcher = fetcher ?? fetchGoogleRoute;
}

/** Route autoritaire réutilisable par le devis, toujours calculée serveur. */
export async function calculateAuthoritativeRoute(
  input: CalculateRouteRequest
): Promise<RouteEstimate> {
  validateInput(input);
  try {
    return await routeFetcher(input);
  } catch (error) {
    console.error(
      "[calculateRoute] Google Routes request failed",
      error instanceof Error ? error.message : "unknown_error"
    );
    throw internal("Impossible de calculer l'itinéraire routier pour le moment.");
  }
}

export const calculateRoute = onCall<CalculateRouteRequest>(async (request) => {
  requireSignedIn(request);
  return calculateAuthoritativeRoute(request.data);
});
