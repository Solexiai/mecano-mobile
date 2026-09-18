import { setRouteFetcherForTesting } from "../src/functions/calculateRoute";

beforeEach(() => {
  setRouteFetcherForTesting(async () => ({
    distanceKm: 12,
    estimatedDurationMinutes: 25,
    isApproximate: false,
  }));
});

afterAll(() => setRouteFetcherForTesting(null));
