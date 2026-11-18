// Itinéraire par la route d'une mission (2026-11-18) : la carte de suivi ne
// trace plus « à vol d'oiseau ». Aucun appel réseau ni Firestore réel ici.
jest.mock("../../src/lib/admin", () => ({ db: { collection: jest.fn() }, admin: {} }));

import type { CallableRequest, Request } from "firebase-functions/v2/https";
import type { DecodedIdToken } from "firebase-admin/auth";
import { db } from "../../src/lib/admin";
import * as routingBudget from "../../src/lib/routingRateLimit";
import {
  getMissionRoutePath,
  GetMissionRoutePathRequest,
  setRouteGeometryFetcherForTesting,
} from "../../src/functions/getMissionRoutePath";
import {
  MAX_ENCODED_ROUTE_LENGTH,
  canReadMissionRoute,
  missionRouteEndpoints,
  parseRouteGeometry,
  routeCacheKey,
  routeGeometryUrl,
} from "../../src/lib/missionRoutePath";

// Granby → Cowansville (coordonnées approximatives, adresses fictives).
const granby = { line1: "1 rue Fictive", city: "Granby", lat: 45.4001, lng: -72.7329 };
const cowansville = { line1: "2 rue Fictive", city: "Cowansville", lat: 45.2001, lng: -72.7466 };
const POLYLINE = "_p~iF~ps|U_ulLnnqC_mqNvxq`@";

function missionDoc(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    customer_id: "customer_1",
    driver_id: "driver_1",
    status: "assigned",
    pickup_address: granby,
    dropoff_address: cowansville,
    ...overrides,
  };
}

function request(
  uid: string | null,
  missionId: unknown = "mission_1",
  token: Record<string, unknown> = {}
): CallableRequest<GetMissionRoutePathRequest> {
  return {
    data: { missionId } as GetMissionRoutePathRequest,
    auth: uid === null
      ? undefined
      : { uid, token: token as unknown as DecodedIdToken, rawToken: "test-token" },
    rawRequest: {} as Request,
    acceptsStreaming: false,
  };
}

describe("missionRoutePath (calculs purs)", () => {
  const endpoints = { pickup: granby, dropoff: cowansville };

  it("construit l'adresse OSRM : longitude avant latitude, tracé complet", () => {
    expect(routeGeometryUrl("https://osrm.example.test/routed-car/", endpoints)).toBe(
      "https://osrm.example.test/routed-car/route/v1/driving/" +
        "-72.732900,45.400100;-72.746600,45.200100" +
        "?overview=full&geometries=polyline&alternatives=false&steps=false"
    );
  });

  it("garde une clé de cache par paire d'extrémités", () => {
    expect(routeCacheKey(endpoints)).toBe("45.400100,-72.732900,45.200100,-72.746600");
    expect(routeCacheKey({ pickup: cowansville, dropoff: granby })).not.toBe(routeCacheKey(endpoints));
  });

  it("lit le tracé de la première route d'une réponse OSRM", () => {
    expect(parseRouteGeometry({ code: "Ok", routes: [{ geometry: POLYLINE }, { geometry: "??" }] }))
      .toBe(POLYLINE);
  });

  it.each([
    ["réponse vide", null],
    ["texte", "Ok"],
    ["aucune route", { code: "NoRoute", routes: [] }],
    ["code d'erreur", { code: "InvalidQuery", routes: [{ geometry: POLYLINE }] }],
    ["routes absentes", { code: "Ok" }],
    ["tracé non textuel", { code: "Ok", routes: [{ geometry: { type: "LineString" } }] }],
    ["tracé vide", { code: "Ok", routes: [{ geometry: "" }] }],
    ["caractères hors tracé encodé", { code: "Ok", routes: [{ geometry: "<script>alert(1)</script>" }] }],
    ["tracé démesuré", { code: "Ok", routes: [{ geometry: "?".repeat(MAX_ENCODED_ROUTE_LENGTH + 1) }] }],
  ])("refuse une réponse inexploitable : %s", (_label, body) => {
    expect(parseRouteGeometry(body)).toBeNull();
  });

  it("lit les extrémités du document mission", () => {
    expect(missionRouteEndpoints(missionDoc())).toEqual({
      pickup: { lat: 45.4001, lng: -72.7329 },
      dropoff: { lat: 45.2001, lng: -72.7466 },
    });
  });

  it.each([
    ["ramassage absent", { pickup_address: undefined }],
    ["livraison non géocodée (0, 0)", { dropoff_address: { lat: 0, lng: 0 } }],
    ["latitude hors plage", { pickup_address: { lat: 95, lng: -72 } }],
    ["longitude non numérique", { dropoff_address: { lat: 45, lng: "-72" } }],
    ["coordonnée infinie", { pickup_address: { lat: Number.POSITIVE_INFINITY, lng: -72 } }],
    ["mêmes extrémités", { dropoff_address: granby }],
  ])("n'invente aucun itinéraire : %s", (_label, overrides) => {
    expect(missionRouteEndpoints(missionDoc(overrides))).toBeNull();
  });

  it("réserve le tracé au client, au chauffeur assigné et au personnel", () => {
    const mission = missionDoc();
    expect(canReadMissionRoute(mission, "customer_1", false)).toBe(true);
    expect(canReadMissionRoute(mission, "driver_1", false)).toBe(true);
    expect(canReadMissionRoute(mission, "stranger", false)).toBe(false);
    expect(canReadMissionRoute(mission, "stranger", true)).toBe(true);
    expect(canReadMissionRoute(missionDoc({ driver_id: null }), "", false)).toBe(false);
  });
});

describe("getMissionRoutePath", () => {
  let missions: Record<string, Record<string, unknown> | undefined>;
  let fetcher: jest.Mock;
  let budget: jest.Mock;

  beforeEach(() => {
    missions = { mission_1: missionDoc() };
    (db.collection as jest.Mock).mockReset();
    (db.collection as jest.Mock).mockImplementation((name: string) => ({
      doc: (id: string) => ({
        get: async () => ({
          data: () => (name === "delivery_requests" ? missions[id] : undefined),
        }),
      }),
    }));
    fetcher = jest.fn(async () => ({ code: "Ok", routes: [{ geometry: POLYLINE }] }));
    setRouteGeometryFetcherForTesting(fetcher);
    budget = jest.spyOn(routingBudget, "consumeRoutingBudget")
      .mockResolvedValue(undefined) as unknown as jest.Mock;
  });
  afterEach(() => {
    setRouteGeometryFetcherForTesting(null);
    jest.restoreAllMocks();
  });

  it("renvoie au chauffeur assigné le tracé routier de sa mission", async () => {
    await expect(getMissionRoutePath.run(request("driver_1"))).resolves.toEqual({
      encodedPolyline: POLYLINE,
      precision: 5,
    });
    expect(fetcher).toHaveBeenCalledTimes(1);
    expect(fetcher.mock.calls[0][0]).toContain(
      "/route/v1/driving/-72.732900,45.400100;-72.746600,45.200100?overview=full"
    );
    expect(budget).toHaveBeenCalledWith("driver_1");
  });

  it("sert le client depuis la mémoire sans rappeler le service d'itinéraire", async () => {
    await getMissionRoutePath.run(request("driver_1"));
    await expect(getMissionRoutePath.run(request("customer_1"))).resolves.toEqual({
      encodedPolyline: POLYLINE,
      precision: 5,
    });
    expect(fetcher).toHaveBeenCalledTimes(1);
    expect(budget).toHaveBeenCalledTimes(1);
  });

  it("autorise le personnel et refuse un autre compte", async () => {
    await expect(
      getMissionRoutePath.run(request("staff_1", "mission_1", { role: "analyst" }))
    ).resolves.toMatchObject({ encodedPolyline: POLYLINE });
    fetcher.mockClear();
    await expect(getMissionRoutePath.run(request("stranger"))).rejects.toMatchObject({
      code: "permission-denied",
    });
    expect(fetcher).not.toHaveBeenCalled();
  });

  it("exige une session et un identifiant de mission valide avant toute lecture", async () => {
    await expect(getMissionRoutePath.run(request(null))).rejects.toMatchObject({
      code: "unauthenticated",
    });
    for (const missionId of [null, "", "a/b", "x".repeat(129), 42]) {
      await expect(getMissionRoutePath.run(request("driver_1", missionId))).rejects.toMatchObject({
        code: "invalid-argument",
      });
    }
    expect(db.collection).not.toHaveBeenCalled();
    expect(fetcher).not.toHaveBeenCalled();
  });

  it("répond introuvable pour une mission inexistante", async () => {
    await expect(getMissionRoutePath.run(request("driver_1", "absente"))).rejects.toMatchObject({
      code: "not-found",
    });
    expect(fetcher).not.toHaveBeenCalled();
  });

  it("n'appelle pas le service quand la mission n'a pas de coordonnées", async () => {
    missions.mission_1 = missionDoc({ dropoff_address: { lat: 0, lng: 0 } });
    await expect(getMissionRoutePath.run(request("driver_1"))).resolves.toEqual({
      encodedPolyline: null,
      precision: 5,
    });
    expect(fetcher).not.toHaveBeenCalled();
    expect(budget).not.toHaveBeenCalled();
  });

  it("une panne du service donne une carte sans tracé, sans rien mettre en mémoire", async () => {
    fetcher.mockRejectedValueOnce(new Error("provider unavailable"));
    await expect(getMissionRoutePath.run(request("driver_1"))).resolves.toEqual({
      encodedPolyline: null,
      precision: 5,
    });
    fetcher.mockResolvedValueOnce({ code: "NoRoute", routes: [] });
    await expect(getMissionRoutePath.run(request("driver_1"))).resolves.toEqual({
      encodedPolyline: null,
      precision: 5,
    });
    await expect(getMissionRoutePath.run(request("driver_1"))).resolves.toMatchObject({
      encodedPolyline: POLYLINE,
    });
    expect(fetcher).toHaveBeenCalledTimes(3);
  });

  it("ne contacte pas le service quand le quota refuse", async () => {
    budget.mockRejectedValueOnce({ code: "resource-exhausted" });
    await expect(getMissionRoutePath.run(request("driver_1"))).rejects.toMatchObject({
      code: "resource-exhausted",
    });
    expect(fetcher).not.toHaveBeenCalled();
  });
});
