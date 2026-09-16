import type { CallableRequest, Request } from "firebase-functions/v2/https";
import type { DecodedIdToken } from "firebase-admin/auth";
import {
  calculateRoute,
  CalculateRouteRequest,
  setRouteFetcherForTesting,
} from "../../src/functions/calculateRoute";

const validInput: CalculateRouteRequest = {
  pickupLat: 45.6066,
  pickupLng: -73.7124,
  dropoffLat: 45.3984,
  dropoffLng: -71.8992,
};

function signedRequest(
  data: CalculateRouteRequest
): CallableRequest<CalculateRouteRequest> {
  return {
    data,
    auth: {
      uid: "route_test_user",
      token: {} as DecodedIdToken,
      rawToken: "test-token",
    },
    rawRequest: {} as Request,
    acceptsStreaming: false,
  };
}
describe("calculateRoute", () => {
  afterEach(() => setRouteFetcherForTesting(null));

  it("retourne la distance et la durée routières du fournisseur", async () => {
    setRouteFetcherForTesting(async () => ({
      distanceKm: 182.4,
      estimatedDurationMinutes: 128.5,
      isApproximate: false,
    }));

    await expect(
      calculateRoute.run(signedRequest(validInput))
    ).resolves.toEqual({
      distanceKm: 182.4,
      estimatedDurationMinutes: 128.5,
      isApproximate: false,
    });
  });

  it("rejette les coordonnées hors plage", async () => {
    await expect(
      calculateRoute.run(
        signedRequest({ ...validInput, pickupLat: 120 })
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });
  it("exige une session Firebase authentifiée", async () => {
    const request: CallableRequest<CalculateRouteRequest> = {
      data: validInput,
      auth: undefined,
      rawRequest: {} as Request,
      acceptsStreaming: false,
    };
    await expect(calculateRoute.run(request)).rejects.toMatchObject({
      code: "unauthenticated",
    });
  });

  it("masque une panne du fournisseur derrière une erreur interne", async () => {
    setRouteFetcherForTesting(async () => {
      throw new Error("provider unavailable");
    });
    await expect(
      calculateRoute.run(signedRequest(validInput))
    ).rejects.toMatchObject({ code: "internal" });
  });
});
