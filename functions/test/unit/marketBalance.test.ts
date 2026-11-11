// Équilibre offre / demande par ville : calcul pur, triggers et callables.

type Row = Record<string, unknown> & { id: string };
const stamp = (ms: number) => ({ toMillis: () => ms });
const store: Record<string, Row[]> = {};
const writes: Array<{ path: string; data: Record<string, unknown> }> = [];

function value(v: unknown): unknown {
  return v && typeof (v as { toMillis?: unknown }).toMillis === "function" ? (v as { toMillis: () => number }).toMillis() : v;
}
function query(name: string, filters: Array<(r: Row) => boolean> = [], max = Infinity, order?: string): any {
  return {
    where: (field: string, op: string, v: unknown) =>
      query(name, [...filters, (r) => {
        const a = value(r[field]) as number, b = value(v) as number;
        if (r[field] === undefined) return false;
        return op === "==" ? r[field] === v : op === ">=" ? a >= b : op === "<" ? a < b : false;
      }], max, order),
    orderBy: (field: string) => query(name, filters, max, field),
    limit: (n: number) => query(name, filters, n, order),
    doc: (id: string) => ({ id, path: `${name}/${id}` }),
    get: async () => {
      let rows = (store[name] ?? []).filter((r) => filters.every((f) => f(r)));
      if (order) rows = [...rows].sort((x, y) => (value(x[order]) as number) - (value(y[order]) as number));
      rows = rows.slice(0, max);
      const docs = rows.map((r) => ({ id: r.id, ref: { path: `${name}/${r.id}` }, data: () => r }));
      return { docs, size: docs.length, empty: docs.length === 0 };
    },
  };
}

jest.mock("firebase-functions/v2/https", () => ({
  ...jest.requireActual("firebase-functions/v2/https"),
  onCall: (handler: unknown) => handler,
}));
jest.mock("firebase-functions/v2/firestore", () => ({ onDocumentUpdated: (_path: string, handler: unknown) => handler }));
jest.mock("../../src/lib/admin", () => ({
  admin: { firestore: { Timestamp: { fromMillis: (ms: number) => stamp(ms), now: () => stamp(1_000) } } },
  db: {
    collection: (name: string) => ({
      ...query(name),
      doc: (id: string) => ({
        id,
        set: async (data: Record<string, unknown>) => { writes.push({ path: `${name}/${id}`, data }); },
      }),
    }),
    getAll: async (...refs: Array<{ id: string }>) =>
      refs.map((ref) => {
        const row = (store.delivery_requests ?? []).find((r) => r.id === ref.id);
        return { id: ref.id, data: () => row };
      }),
    batch: () => {
      const ops: Array<{ path: string; data: Record<string, unknown> }> = [];
      return {
        update: (ref: { path: string }, data: Record<string, unknown>) => ops.push({ path: ref.path, data }),
        commit: async () => { writes.push(...ops); },
      };
    },
  },
}));
jest.mock("../../src/lib/auth", () => ({
  requireSignedIn: jest.fn(() => ({ uid: "driver_a" })),
  requireAnalystOrAbove: jest.fn(),
  requireAnyRole: jest.fn(),
}));

import {
  buildDriverStatusEvent,
  buildMarketBalance,
  buildNoDriverEvent,
  MarketBalanceInput,
  missionFact,
  normalizeCity,
  onlineMillisInWindow,
  parseBalanceWindow,
} from "../../src/lib/marketBalance";
import {
  getMarketBalance,
  recordDriverAvailabilityChange,
  recordMissionNoDriver,
  recordOfferDeclineReason,
} from "../../src/functions/marketBalance";
import { requireAnalystOrAbove } from "../../src/lib/auth";

const H = 3_600_000;
const D = 24 * H;
const FROM = Date.UTC(2026, 10, 9, 5); // lundi 9 nov. 2026, 00 h à Montréal
const TO = FROM + 7 * D;
const NOW = TO + H;
const granby = normalizeCity("Granby");

function input(over: Partial<MarketBalanceInput> = {}): MarketBalanceInput {
  return {
    fromMs: FROM,
    toMs: TO,
    nowMs: NOW,
    missionsCreated: [],
    missionsCompleted: [],
    missionsById: new Map(),
    offers: [],
    drivers: [],
    driverEvents: [],
    noDriverEvents: [],
    quotes: [],
    availabilityMeasured: true,
    ...over,
  };
}
function mission(id: string, over: Record<string, unknown> = {}) {
  return missionFact(id, {
    pickup_address: { city: "Granby", lat: 45.4, lng: -72.73 },
    created_at: stamp(FROM + D),
    status: "searching_driver",
    ...over,
  });
}

beforeEach(() => {
  for (const key of Object.keys(store)) delete store[key];
  writes.length = 0;
});

describe("villes", () => {
  test("« Ville de Granby », « granby » et « GRANBY » sont la même ville", () => {
    expect(normalizeCity("Ville de Granby")?.key).toBe("granby");
    expect(normalizeCity("  granby ")?.key).toBe("granby");
    expect(normalizeCity("GRANBY")?.key).toBe("granby");
    expect(normalizeCity("Saint-Hyacinthe")?.key).toBe(normalizeCity("saint hyacinthe")?.key);
    expect(normalizeCity("Lévis")?.key).toBe("levis");
    expect(normalizeCity("")).toBeNull();
    expect(normalizeCity(42)).toBeNull();
  });
});

describe("période", () => {
  test("accepte une semaine, refuse plus de 35 jours ou une période à l'envers", () => {
    expect(parseBalanceWindow({ fromMillis: FROM, toMillis: TO }, NOW)).toEqual({ fromMs: FROM, toMs: TO });
    expect(parseBalanceWindow({ fromMillis: FROM, toMillis: FROM + 36 * D }, NOW)).toBeNull();
    expect(parseBalanceWindow({ fromMillis: TO, toMillis: FROM }, NOW)).toBeNull();
    expect(parseBalanceWindow({ fromMillis: NOW + D, toMillis: NOW + 2 * D }, NOW)).toBeNull();
    expect(parseBalanceWindow({ fromMillis: "x", toMillis: TO }, NOW)).toBeNull();
  });
});

describe("heures en ligne", () => {
  test("additionne les périodes en ligne et en mission", () => {
    const events = [
      { driverId: "a", atMs: FROM + 2 * H, from: "offline", to: "online" },
      { driverId: "a", atMs: FROM + 3 * H, from: "online", to: "on_mission" },
      { driverId: "a", atMs: FROM + 5 * H, from: "on_mission", to: "offline" },
    ];
    expect(onlineMillisInWindow(events, "offline", FROM, TO, NOW)).toBe(3 * H);
  });
  test("l'état au début de la semaine vient du changement qui suit, même après la semaine", () => {
    const events = [{ driverId: "a", atMs: TO + 30 * 60_000, from: "online", to: "offline" }];
    expect(onlineMillisInWindow(events, "offline", FROM, TO, NOW)).toBe(7 * D);
  });
  test("sans aucun changement, l'état actuel vaut pour toute la période écoulée", () => {
    expect(onlineMillisInWindow([], "online", FROM, TO, FROM + 10 * H)).toBe(10 * H);
    expect(onlineMillisInWindow([], "offline", FROM, TO, NOW)).toBe(0);
  });
});

describe("verdict par ville", () => {
  test("taux d'acceptation bas → il manque des chauffeurs", () => {
    const created = [
      ...Array.from({ length: 4 }, (_, i) => mission(`ok${i}`, { accepted_at: stamp(FROM + D + 20 * 60_000), driver_id: "d1", status: "assigned" })),
      mission("nd1", { dispatch_state: "no_driver_available" }),
      mission("nd2", { dispatch_state: "no_driver_available" }),
    ];
    const r = buildMarketBalance(input({
      missionsCreated: created,
      drivers: [{ id: "d1", city: granby, onlineStatus: "online" }],
    }));
    const city = r.cities[0];
    expect(city.label).toBe("Granby");
    expect(city.requests).toBe(6);
    expect(city.accepted).toBe(4);
    expect(city.noDriver).toBe(2);
    expect(city.acceptanceRate).toBeCloseTo(4 / 6, 3);
    expect(city.medianAcceptMinutes).toBe(20);
    expect(city.verdict).toBe("drivers_short");
    expect(city.reasons).toEqual(expect.arrayContaining(["low_acceptance", "no_driver"]));
  });

  test("peu de livraisons par chauffeur approuvé → il manque des clients", () => {
    const done = mission("c1", { status: "completed", driver_id: "d1", accepted_at: stamp(FROM + D + 60_000), completed_at: stamp(FROM + 2 * D) });
    const r = buildMarketBalance(input({
      missionsCreated: [done],
      missionsCompleted: [done],
      drivers: ["d1", "d2", "d3"].map((id) => ({ id, city: granby, onlineStatus: "offline" })),
    }));
    expect(r.cities[0].jobsPerDriverPerWeek).toBeCloseTo(1 / 3, 1);
    expect(r.cities[0].activeDrivers).toBe(1);
    expect(r.cities[0].verdict).toBe("customers_short");
  });

  test("assez de livraisons et tout est accepté → équilibre", () => {
    const done = Array.from({ length: 6 }, (_, i) => mission(`c${i}`, {
      status: "completed", driver_id: "d1", accepted_at: stamp(FROM + D + 60_000), completed_at: stamp(FROM + 2 * D),
    }));
    const r = buildMarketBalance(input({
      missionsCreated: done,
      missionsCompleted: done,
      drivers: [{ id: "d1", city: granby, onlineStatus: "online" }, { id: "d2", city: granby, onlineStatus: "offline" }],
    }));
    expect(r.cities[0].acceptanceRate).toBe(1);
    expect(r.cities[0].jobsPerDriverPerWeek).toBe(3);
    expect(r.cities[0].verdict).toBe("balanced");
    expect(r.cities[0].onlineDriversNow).toBe(1);
  });

  test("des demandes sans aucun chauffeur approuvé dans la ville → il manque des chauffeurs", () => {
    const r = buildMarketBalance(input({ missionsCreated: [mission("m1", { pickup_address: { city: "Bromont" } })] }));
    expect(r.cities[0].label).toBe("Bromont");
    expect(r.cities[0].reasons).toContain("no_approved_driver");
    expect(r.cities[0].verdict).toBe("drivers_short");
  });

  test("tests internes exclus, offres et refus rattachés à la ville de la demande", () => {
    const internal = mission("t1", { assignment_mode: "internal_test" });
    const real = mission("m1");
    const r = buildMarketBalance(input({
      missionsCreated: [internal, real],
      missionsById: new Map([["t1", internal], ["m1", real]]),
      offers: [
        { missionId: "m1", driverId: "d1", status: "declined", declineReason: "too_far" },
        { missionId: "m1", driverId: "d2", status: "declined", declineReason: null },
        { missionId: "m1", driverId: "d3", status: "expired", declineReason: null },
        { missionId: "t1", driverId: "d1", status: "declined", declineReason: "too_far" },
      ],
      drivers: [{ id: "d1", city: granby, onlineStatus: "offline" }],
      quotes: [{ city: granby, booked: false }, { city: granby, booked: true }],
    }));
    const city = r.cities[0];
    expect(city.requests).toBe(1);
    expect(city.offers).toEqual({ sent: 3, accepted: 0, declined: 2, expired: 1, pending: 0 });
    expect(city.declineReasons).toEqual({ too_far: 1, not_given: 1 });
    expect(city.quotesNotBooked).toBe(1);
    expect(r.total.requests).toBe(1);
  });

  test("heures disponibles absentes tant que le journal ne couvre pas la semaine", () => {
    const r = buildMarketBalance(input({
      availabilityMeasured: false,
      drivers: [{ id: "d1", city: granby, onlineStatus: "online" }],
    }));
    expect(r.cities[0].availableHours).toBeNull();
    expect(r.total.availableHours).toBeNull();
  });

  test("une période sans aucune donnée donne un total vide", () => {
    const r = buildMarketBalance(input());
    expect(r.cities).toEqual([]);
    expect(r.total.verdict).toBe("not_enough_data");
  });
});

describe("événements des triggers", () => {
  test("un passage en ligne est gardé avec la ville et le secteur de l'adresse de service", () => {
    const e = buildDriverStatusEvent("d1",
      { online_status: "offline" },
      { online_status: "online", city: "Ville de Granby", base_lat: 45.4, base_lng: -72.73, current_lat: 1 });
    expect(e).toMatchObject({ type: "driver_status", driver_id: "d1", from: "offline", to: "online", city: "Granby", city_key: "granby" });
    expect(e?.sector).toHaveLength(5);
    expect(buildDriverStatusEvent("d1", { online_status: "online" }, { online_status: "online" })).toBeNull();
  });

  test("« aucun chauffeur » est gardé une seule fois par passage, jamais pour un test interne", () => {
    const after = { dispatch_state: "no_driver_available", dispatch_round: 3, pickup_address: { city: "Granby", lat: 45.4, lng: -72.73 } };
    expect(buildNoDriverEvent("m1", { dispatch_state: "searching" }, after)).toMatchObject({ mission_id: "m1", round: 3, city_key: "granby" });
    expect(buildNoDriverEvent("m1", after, after)).toBeNull();
    expect(buildNoDriverEvent("m1", {}, { ...after, assignment_mode: "internal_test" })).toBeNull();
    expect(buildNoDriverEvent("m1", {}, { ...after, driver_id: "d1" })).toBeNull();
  });

  test("les triggers écrivent seulement dans market_balance_events, avec un id stable", async () => {
    const change = (before: object, after: object) => ({ before: { data: () => before }, after: { data: () => after } });
    await (recordDriverAvailabilityChange as any)({
      id: "evt/1", time: new Date(FROM).toISOString(), params: { driverId: "d1" },
      data: change({ online_status: "offline" }, { online_status: "online", city: "Granby" }),
    });
    await (recordMissionNoDriver as any)({
      id: "evt2", time: new Date(FROM).toISOString(), params: { missionId: "m1" },
      data: change({ dispatch_state: "searching" }, { dispatch_state: "no_driver_available", dispatch_round: 3 }),
    });
    expect(writes.map((w) => w.path)).toEqual(["market_balance_events/drv_evt_1", "market_balance_events/nodrv_m1_3"]);
    expect((writes[0].data.at as { toMillis: () => number }).toMillis()).toBe(FROM);
  });
});

describe("raison de refus", () => {
  test("est ajoutée aux offres refusées du chauffeur, sans écraser une raison déjà donnée", async () => {
    store.delivery_offers = [
      { id: "o1", mission_id: "m1", driver_id: "driver_a", status: "declined" },
      { id: "o2", mission_id: "m1", driver_id: "driver_a", status: "declined", decline_reason: "no_space" },
      { id: "o3", mission_id: "m1", driver_id: "driver_b", status: "declined" },
    ];
    await expect((recordOfferDeclineReason as any)({ data: { missionId: "m1", reason: "too_far" } })).resolves.toEqual({ recorded: true });
    expect(writes).toEqual([{ path: "delivery_offers/o1", data: { decline_reason: "too_far", decline_reason_at: expect.anything() } }]);
  });

  test("refuse une raison inconnue ou une demande sans refus", async () => {
    store.delivery_offers = [{ id: "o1", mission_id: "m1", driver_id: "driver_a", status: "pending" }];
    await expect((recordOfferDeclineReason as any)({ data: { missionId: "m1", reason: "lol" } })).rejects.toThrow("Raison invalide");
    await expect((recordOfferDeclineReason as any)({ data: { missionId: "m1", reason: "too_far" } })).rejects.toThrow("Aucun refus");
    expect(writes).toEqual([]);
  });
});

describe("getMarketBalance", () => {
  test("lit la semaine et renvoie les villes, réservé au personnel", async () => {
    store.delivery_requests = [
      { id: "m1", pickup_address: { city: "Granby" }, created_at: stamp(FROM + D), accepted_at: stamp(FROM + D + 10 * 60_000), driver_id: "d1", status: "assigned" },
      { id: "old", pickup_address: { city: "Bromont" }, created_at: stamp(FROM - 3 * D), status: "searching_driver" },
    ];
    store.delivery_offers = [{ id: "o1", mission_id: "old", driver_id: "d2", status: "expired", offered_at: stamp(FROM + 2 * D) }];
    store.driver_profiles = [{ id: "d1", status: "approved", city: "Granby", online_status: "online" }];
    store.market_balance_events = [{ id: "e0", type: "driver_status", driver_id: "d1", from: "offline", to: "online", at: stamp(FROM - D) }];
    const r = await (getMarketBalance as any)({ data: { fromMillis: FROM, toMillis: TO } });
    expect(r.availabilityMeasured).toBe(true);
    expect(r.truncated).toBe(false);
    const granbyRow = r.cities.find((c: { key: string }) => c.key === "granby");
    expect(granbyRow).toMatchObject({ requests: 1, accepted: 1, approvedDrivers: 1, medianAcceptMinutes: 10 });
    const bromont = r.cities.find((c: { key: string }) => c.key === "bromont");
    expect(bromont.offers.expired).toBe(1);
  });

  test("refuse une période invalide et garde la porte du personnel", async () => {
    await expect((getMarketBalance as any)({ data: { fromMillis: FROM, toMillis: FROM + 40 * D } })).rejects.toThrow("Période invalide");
    (requireAnalystOrAbove as jest.Mock).mockImplementationOnce(() => { throw new Error("denied"); });
    await expect((getMarketBalance as any)({ data: { fromMillis: FROM, toMillis: TO } })).rejects.toThrow("denied");
  });
});
