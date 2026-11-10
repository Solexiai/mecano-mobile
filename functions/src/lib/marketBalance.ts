// -----------------------------------------------------------------------------
// Équilibre offre / demande par ville (demande de Daniel, 10 nov. 2026).
//
// Module PUR : aucun accès Firestore. Les triggers et la callable de
// `functions/marketBalance.ts` lisent les données ; ce module les transforme
// en faits simples, puis les agrège ville par ville avec un verdict :
//   - taux d'acceptation bas, ou demandes restées sans chauffeur
//     → il manque des chauffeurs ;
//   - peu de livraisons par chauffeur approuvé → il manque des clients ;
//   - sinon la ville est en équilibre.
// Les seuils sont des points de départ, à ajuster après le pilote de Granby.
// -----------------------------------------------------------------------------

import { encodeGeohash } from "./geohash";

export const MARKET_EVENTS_COLLECTION = "market_balance_events";

/** Les événements d'équilibre sont gardés ~13 mois (champ `expire_at`, TTL facultatif). */
export const MARKET_EVENT_TTL_DAYS = 400;

/** Secteur ≈ 5 km × 5 km : assez fin pour un quartier, sans suivre personne. */
export const SECTOR_GEOHASH_PRECISION = 5;

export interface MarketBalanceThresholds {
  /** Sous ce nombre de demandes tranchées, pas de verdict sur le taux d'acceptation. */
  minDecidedRequests: number;
  /** Taux d'acceptation sous lequel il manque des chauffeurs. */
  minAcceptanceRate: number;
  /** Part des demandes restées sans chauffeur au-delà de laquelle il manque des chauffeurs. */
  maxNoDriverShare: number;
  /** Livraisons par chauffeur approuvé et par semaine sous lesquelles il manque des clients. */
  minJobsPerDriverPerWeek: number;
}

export const MARKET_BALANCE_THRESHOLDS: MarketBalanceThresholds = {
  minDecidedRequests: 5,
  minAcceptanceRate: 0.85,
  maxNoDriverShare: 0.1,
  minJobsPerDriverPerWeek: 2,
};

export const DECLINE_REASONS = ["too_far", "price_too_low", "no_space", "not_available", "other"] as const;
export type DeclineReason = (typeof DECLINE_REASONS)[number];

export function isDeclineReason(value: unknown): value is DeclineReason {
  return typeof value === "string" && (DECLINE_REASONS as readonly string[]).includes(value);
}

const ONLINE_STATES = new Set(["online", "on_mission"]);
const OPEN_STATUSES = new Set(["searching_driver", "offered"]);
const NO_DRIVER_AVAILABLE = "no_driver_available";
const DAY_MS = 86_400_000;
const WEEK_MS = 7 * DAY_MS;

// ---------------------------------------------------------------------------
// Petites conversions
// ---------------------------------------------------------------------------

export interface CityRef {
  key: string;
  label: string;
}

export const UNKNOWN_CITY: CityRef = { key: "_inconnue", label: "Ville inconnue" };
export const TOTAL_CITY: CityRef = { key: "_total", label: "Toutes les villes" };

/** « Ville de Granby », « granby » et « GRANBY » donnent la même ville. */
export function normalizeCity(raw: unknown): CityRef | null {
  if (typeof raw !== "string") return null;
  const label = raw.trim().replace(/\s+/g, " ").replace(/^(ville de |ville d'|ville d’|city of )/i, "");
  if (!label || label.length > 120) return null;
  const key = label
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
  if (!key) return null;
  return { key, label: label.charAt(0).toUpperCase() + label.slice(1) };
}

export function toMillis(value: unknown): number | null {
  if (value && typeof (value as { toMillis?: unknown }).toMillis === "function") {
    const ms = (value as { toMillis: () => number }).toMillis();
    return Number.isFinite(ms) ? ms : null;
  }
  return null;
}

function validLatLng(lat: unknown, lng: unknown): boolean {
  return typeof lat === "number" && Number.isFinite(lat) && Math.abs(lat) <= 90 &&
    typeof lng === "number" && Number.isFinite(lng) && Math.abs(lng) <= 180;
}

export function sectorOf(lat: unknown, lng: unknown): string | null {
  return validLatLng(lat, lng) ? encodeGeohash(lat as number, lng as number, SECTOR_GEOHASH_PRECISION) : null;
}

function asRecord(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" ? (value as Record<string, unknown>) : {};
}

function str(value: unknown): string | null {
  return typeof value === "string" && value ? value : null;
}

// ---------------------------------------------------------------------------
// Événements écrits par les triggers
// ---------------------------------------------------------------------------

export interface DriverStatusEventFields {
  type: "driver_status";
  driver_id: string;
  from: string;
  to: string;
  city: string | null;
  city_key: string | null;
  sector: string | null;
}

/** Un chauffeur passe en ligne, hors ligne ou en mission : on garde le changement. */
export function buildDriverStatusEvent(
  driverId: string,
  before: Record<string, unknown> | undefined,
  after: Record<string, unknown> | undefined,
): DriverStatusEventFields | null {
  if (!before || !after) return null;
  const from = str(before.online_status) ?? "offline";
  const to = str(after.online_status) ?? "offline";
  if (from === to) return null;
  const city = normalizeCity(after.city);
  return {
    type: "driver_status",
    driver_id: driverId,
    from,
    to,
    city: city?.label ?? null,
    city_key: city?.key ?? null,
    // Adresse de service déclarée, jamais la position GPS du moment.
    sector: sectorOf(after.base_lat, after.base_lng),
  };
}

export interface NoDriverEventFields {
  type: "mission_no_driver";
  mission_id: string;
  round: number;
  city: string | null;
  city_key: string | null;
  sector: string | null;
}

/** Une demande vient de passer « aucun chauffeur disponible ». */
export function buildNoDriverEvent(
  missionId: string,
  before: Record<string, unknown> | undefined,
  after: Record<string, unknown> | undefined,
): NoDriverEventFields | null {
  if (!after || after.dispatch_state !== NO_DRIVER_AVAILABLE) return null;
  if (before?.dispatch_state === NO_DRIVER_AVAILABLE) return null;
  if (after.driver_id || after.assignment_mode === "internal_test") return null;
  const address = asRecord(after.pickup_address);
  const city = normalizeCity(address.city);
  return {
    type: "mission_no_driver",
    mission_id: missionId,
    round: typeof after.dispatch_round === "number" ? after.dispatch_round : 0,
    city: city?.label ?? null,
    city_key: city?.key ?? null,
    sector: sectorOf(address.lat, address.lng),
  };
}

/** Identifiant de document Firestore sûr à partir de l'id d'un événement. */
export function safeDocId(prefix: string, raw: string): string {
  return `${prefix}_${raw.replace(/[^A-Za-z0-9_-]/g, "_").slice(0, 300)}`;
}

// ---------------------------------------------------------------------------
// Période demandée par le tableau de bord
// ---------------------------------------------------------------------------

/** Au plus 35 jours : une semaine ou un mois. */
export const MAX_BALANCE_SPAN_MS = 35 * DAY_MS;
const EARLIEST_BALANCE_MS = Date.UTC(2024, 0, 1);

/** Lit {fromMillis, toMillis} ; null si la période est invalide. */
export function parseBalanceWindow(data: unknown, nowMs: number): { fromMs: number; toMs: number } | null {
  const d = asRecord(data);
  const fromMs = d.fromMillis;
  const toMs = d.toMillis;
  if (typeof fromMs !== "number" || typeof toMs !== "number") return null;
  if (!Number.isSafeInteger(fromMs) || !Number.isSafeInteger(toMs)) return null;
  if (toMs <= fromMs || toMs - fromMs > MAX_BALANCE_SPAN_MS) return null;
  if (fromMs < EARLIEST_BALANCE_MS || fromMs > nowMs) return null;
  return { fromMs, toMs };
}

// ---------------------------------------------------------------------------
// Faits lus par la callable
// ---------------------------------------------------------------------------

export interface MissionFact {
  id: string;
  city: CityRef | null;
  createdMs: number | null;
  acceptedMs: number | null;
  completedMs: number | null;
  cancelledMs: number | null;
  status: string;
  driverId: string | null;
  /** La demande est actuellement « aucun chauffeur disponible ». */
  noDriverNow: boolean;
  internalTest: boolean;
}

export function missionFact(id: string, data: Record<string, unknown>): MissionFact {
  return {
    id,
    city: normalizeCity(asRecord(data.pickup_address).city),
    createdMs: toMillis(data.created_at),
    acceptedMs: toMillis(data.accepted_at),
    completedMs: toMillis(data.completed_at),
    cancelledMs: toMillis(data.cancelled_at),
    status: str(data.status) ?? "",
    driverId: str(data.driver_id),
    noDriverNow: data.dispatch_state === NO_DRIVER_AVAILABLE && !data.driver_id,
    internalTest: data.assignment_mode === "internal_test",
  };
}

export interface OfferFact {
  missionId: string;
  driverId: string;
  status: string;
  declineReason: DeclineReason | null;
}

export function offerFact(data: Record<string, unknown>): OfferFact | null {
  const missionId = str(data.mission_id);
  const driverId = str(data.driver_id);
  if (!missionId || !driverId) return null;
  return {
    missionId,
    driverId,
    status: str(data.status) ?? "pending",
    declineReason: isDeclineReason(data.decline_reason) ? data.decline_reason : null,
  };
}

export interface DriverFact {
  id: string;
  city: CityRef | null;
  onlineStatus: string;
}

export function driverFact(id: string, data: Record<string, unknown>): DriverFact {
  return { id, city: normalizeCity(data.city), onlineStatus: str(data.online_status) ?? "offline" };
}

export interface DriverStatusEvent {
  driverId: string;
  atMs: number;
  from: string;
  to: string;
}

export interface NoDriverEvent {
  missionId: string;
  atMs: number;
  city: CityRef | null;
}

/** Sépare les événements d'équilibre lus dans `market_balance_events`. */
export function readMarketEvent(data: Record<string, unknown>):
  | { kind: "driver"; event: DriverStatusEvent }
  | { kind: "no_driver"; event: NoDriverEvent }
  | null {
  const atMs = toMillis(data.at);
  if (atMs === null) return null;
  if (data.type === "driver_status") {
    const driverId = str(data.driver_id);
    if (!driverId) return null;
    return { kind: "driver", event: { driverId, atMs, from: str(data.from) ?? "offline", to: str(data.to) ?? "offline" } };
  }
  if (data.type === "mission_no_driver") {
    const missionId = str(data.mission_id);
    if (!missionId) return null;
    return { kind: "no_driver", event: { missionId, atMs, city: normalizeCity(data.city) } };
  }
  return null;
}

export interface QuoteFact {
  city: CityRef | null;
  booked: boolean;
}

export function quoteFact(data: Record<string, unknown>): QuoteFact {
  const stops = Array.isArray(data.stops) ? data.stops : [];
  const pickup = asRecord(asRecord(stops[0]).address);
  return { city: normalizeCity(pickup.city), booked: !!data.mission_id || data.is_consumed === true };
}

// ---------------------------------------------------------------------------
// Heures en ligne
// ---------------------------------------------------------------------------

/**
 * Temps passé « en ligne » ou « en mission » dans [fromMs, min(toMs, nowMs)).
 * `events` contient les changements de CE chauffeur depuis fromMs jusqu'à
 * maintenant : l'état au début de la période est le « from » du premier
 * changement qui suit ; sans aucun changement, c'est l'état actuel.
 */
export function onlineMillisInWindow(
  events: DriverStatusEvent[],
  currentStatus: string,
  fromMs: number,
  toMs: number,
  nowMs: number,
): number {
  const end = Math.min(toMs, nowMs);
  if (end <= fromMs) return 0;
  const sorted = events.filter((e) => e.atMs >= fromMs).sort((a, b) => a.atMs - b.atMs);
  let state = sorted.length ? sorted[0].from : currentStatus;
  let cursor = fromMs;
  let total = 0;
  for (const event of sorted) {
    if (event.atMs >= end) break;
    if (ONLINE_STATES.has(state)) total += event.atMs - cursor;
    state = event.to;
    cursor = event.atMs;
  }
  if (ONLINE_STATES.has(state)) total += end - cursor;
  return total;
}

// ---------------------------------------------------------------------------
// Agrégation par ville
// ---------------------------------------------------------------------------

export type MarketVerdict = "drivers_short" | "customers_short" | "balanced" | "not_enough_data";

export interface CityBalance {
  key: string;
  label: string;
  /** Demandes créées dans la période (tests internes exclus). */
  requests: number;
  /** Dont prises par un chauffeur. */
  accepted: number;
  /** Demandes passées par « aucun chauffeur disponible ». */
  noDriver: number;
  /** Encore en recherche de chauffeur. */
  pending: number;
  /** Annulées avant qu'un chauffeur les prenne (choix du client ou paiement). */
  cancelledBeforeDriver: number;
  /** Prises ÷ (prises + restées sans chauffeur). */
  acceptanceRate: number | null;
  medianAcceptMinutes: number | null;
  completed: number;
  activeDrivers: number;
  approvedDrivers: number;
  onlineDriversNow: number;
  /** Livraisons par chauffeur approuvé, ramenées à 7 jours. */
  jobsPerDriverPerWeek: number | null;
  /** Heures marquées « en ligne » ou « en mission » ; null si pas encore mesuré. */
  availableHours: number | null;
  offers: { sent: number; accepted: number; declined: number; expired: number; pending: number };
  declineReasons: Record<string, number>;
  quotesNotBooked: number;
  verdict: MarketVerdict;
  reasons: string[];
}

export interface MarketBalanceInput {
  fromMs: number;
  toMs: number;
  nowMs: number;
  missionsCreated: MissionFact[];
  missionsCompleted: MissionFact[];
  /** Toutes les missions connues, pour rattacher les offres à une ville. */
  missionsById: Map<string, MissionFact>;
  offers: OfferFact[];
  drivers: DriverFact[];
  /** Changements depuis fromMs jusqu'à maintenant (pas seulement la période). */
  driverEvents: DriverStatusEvent[];
  noDriverEvents: NoDriverEvent[];
  quotes: QuoteFact[];
  /** false tant que le journal des chauffeurs ne couvre pas toute la période. */
  availabilityMeasured: boolean;
  thresholds?: MarketBalanceThresholds;
}

export interface MarketBalanceResult {
  fromMs: number;
  toMs: number;
  generatedAtMs: number;
  availabilityMeasured: boolean;
  thresholds: MarketBalanceThresholds;
  total: CityBalance;
  cities: CityBalance[];
}

interface Bucket {
  ref: CityRef;
  requests: number;
  accepted: number;
  noDriverIds: Set<string>;
  noDriverUnaccepted: number;
  pending: number;
  cancelledBeforeDriver: number;
  acceptMinutes: number[];
  completed: number;
  activeDrivers: Set<string>;
  approvedDrivers: number;
  onlineDriversNow: number;
  onlineMs: number;
  offers: CityBalance["offers"];
  declineReasons: Record<string, number>;
  quotesNotBooked: number;
}

function median(values: number[]): number | null {
  if (!values.length) return null;
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
}

function round1(value: number): number {
  return Math.round(value * 10) / 10;
}

function aggregate(input: MarketBalanceInput, pick: (city: CityRef | null) => CityRef): CityBalance[] {
  const t = input.thresholds ?? MARKET_BALANCE_THRESHOLDS;
  const buckets = new Map<string, Bucket>();
  const bucket = (city: CityRef | null): Bucket => {
    const ref = pick(city);
    let b = buckets.get(ref.key);
    if (!b) {
      b = {
        ref,
        requests: 0,
        accepted: 0,
        noDriverIds: new Set(),
        noDriverUnaccepted: 0,
        pending: 0,
        cancelledBeforeDriver: 0,
        acceptMinutes: [],
        completed: 0,
        activeDrivers: new Set(),
        approvedDrivers: 0,
        onlineDriversNow: 0,
        onlineMs: 0,
        offers: { sent: 0, accepted: 0, declined: 0, expired: 0, pending: 0 },
        declineReasons: {},
        quotesNotBooked: 0,
      };
      buckets.set(ref.key, b);
    }
    return b;
  };

  const inWindow = (ms: number | null) => ms !== null && ms >= input.fromMs && ms < input.toMs;
  const noDriverEventIds = new Set(input.noDriverEvents.filter((e) => inWindow(e.atMs)).map((e) => e.missionId));

  // 1. Demandes créées : acceptation, « aucun chauffeur », délai.
  const created = input.missionsCreated.filter((m) => !m.internalTest);
  const createdIds = new Set(created.map((m) => m.id));
  for (const m of created) {
    const b = bucket(m.city);
    b.requests += 1;
    const accepted = m.acceptedMs !== null || m.driverId !== null;
    const hadNoDriver = m.noDriverNow || noDriverEventIds.has(m.id);
    if (hadNoDriver) b.noDriverIds.add(m.id);
    if (accepted) {
      b.accepted += 1;
      if (m.acceptedMs !== null && m.createdMs !== null && m.acceptedMs >= m.createdMs) {
        b.acceptMinutes.push((m.acceptedMs - m.createdMs) / 60_000);
      }
    } else if (hadNoDriver) {
      b.noDriverUnaccepted += 1;
    } else if (m.cancelledMs !== null) {
      b.cancelledBeforeDriver += 1;
    } else if (OPEN_STATUSES.has(m.status)) {
      b.pending += 1;
    }
  }
  // Demandes plus anciennes tombées sans chauffeur pendant la période.
  for (const e of input.noDriverEvents) {
    if (!inWindow(e.atMs) || createdIds.has(e.missionId)) continue;
    const mission = input.missionsById.get(e.missionId);
    if (mission?.internalTest) continue;
    bucket(mission?.city ?? e.city).noDriverIds.add(e.missionId);
  }

  // 2. Livraisons terminées et chauffeurs actifs.
  for (const m of input.missionsCompleted) {
    if (m.internalTest || !inWindow(m.completedMs)) continue;
    const b = bucket(m.city);
    b.completed += 1;
    if (m.driverId) b.activeDrivers.add(m.driverId);
  }

  // 3. Chauffeurs approuvés, en ligne maintenant, heures disponibles.
  const eventsByDriver = new Map<string, DriverStatusEvent[]>();
  for (const e of input.driverEvents) {
    const list = eventsByDriver.get(e.driverId) ?? [];
    list.push(e);
    eventsByDriver.set(e.driverId, list);
  }
  for (const d of input.drivers) {
    const b = bucket(d.city);
    b.approvedDrivers += 1;
    if (ONLINE_STATES.has(d.onlineStatus)) b.onlineDriversNow += 1;
    if (input.availabilityMeasured) {
      b.onlineMs += onlineMillisInWindow(eventsByDriver.get(d.id) ?? [], d.onlineStatus, input.fromMs, input.toMs, input.nowMs);
    }
  }

  // 4. Offres envoyées aux chauffeurs, rattachées à la ville de la demande.
  for (const o of input.offers) {
    const mission = input.missionsById.get(o.missionId);
    if (mission?.internalTest) continue;
    const b = bucket(mission?.city ?? null);
    b.offers.sent += 1;
    if (o.status === "accepted") b.offers.accepted += 1;
    else if (o.status === "declined") {
      b.offers.declined += 1;
      const reason = o.declineReason ?? "not_given";
      b.declineReasons[reason] = (b.declineReasons[reason] ?? 0) + 1;
    } else if (o.status === "pending") b.offers.pending += 1;
    else b.offers.expired += 1;
  }

  // 5. Devis vus sans réservation : de la demande qu'on perd.
  for (const q of input.quotes) {
    if (!q.booked) bucket(q.city).quotesNotBooked += 1;
  }

  const spanMs = Math.max(DAY_MS, Math.min(input.toMs, input.nowMs) - input.fromMs);
  return [...buckets.values()].map((b): CityBalance => {
    const decided = b.accepted + b.noDriverUnaccepted;
    const acceptanceRate = decided > 0 ? b.accepted / decided : null;
    const jobsPerDriverPerWeek = b.approvedDrivers > 0 ? round1((b.completed / b.approvedDrivers) * (WEEK_MS / spanMs)) : null;
    const noDriver = b.noDriverIds.size;
    const reasons: string[] = [];
    if (acceptanceRate !== null && decided >= t.minDecidedRequests && acceptanceRate < t.minAcceptanceRate) {
      reasons.push("low_acceptance");
    }
    if (noDriver > 0 && (b.requests === 0 || noDriver / b.requests > t.maxNoDriverShare)) reasons.push("no_driver");
    if (b.approvedDrivers === 0 && b.requests > 0) reasons.push("no_approved_driver");
    let verdict: MarketVerdict;
    if (reasons.length) verdict = "drivers_short";
    else if (jobsPerDriverPerWeek !== null && jobsPerDriverPerWeek < t.minJobsPerDriverPerWeek) {
      verdict = "customers_short";
      reasons.push("few_jobs_per_driver");
    } else if (b.requests === 0 && b.completed === 0) verdict = "not_enough_data";
    else verdict = "balanced";
    return {
      key: b.ref.key,
      label: b.ref.label,
      requests: b.requests,
      accepted: b.accepted,
      noDriver,
      pending: b.pending,
      cancelledBeforeDriver: b.cancelledBeforeDriver,
      acceptanceRate: acceptanceRate === null ? null : Math.round(acceptanceRate * 1000) / 1000,
      medianAcceptMinutes: (() => {
        const m = median(b.acceptMinutes);
        return m === null ? null : Math.round(m);
      })(),
      completed: b.completed,
      activeDrivers: b.activeDrivers.size,
      approvedDrivers: b.approvedDrivers,
      onlineDriversNow: b.onlineDriversNow,
      jobsPerDriverPerWeek,
      availableHours: input.availabilityMeasured ? round1(b.onlineMs / 3_600_000) : null,
      offers: b.offers,
      declineReasons: b.declineReasons,
      quotesNotBooked: b.quotesNotBooked,
      verdict,
      reasons,
    };
  });
}

const VERDICT_ORDER: Record<MarketVerdict, number> = {
  drivers_short: 0,
  customers_short: 1,
  balanced: 2,
  not_enough_data: 3,
};

export function buildMarketBalance(input: MarketBalanceInput): MarketBalanceResult {
  const cities = aggregate(input, (city) => city ?? UNKNOWN_CITY).sort((a, b) =>
    (a.key === UNKNOWN_CITY.key ? 1 : 0) - (b.key === UNKNOWN_CITY.key ? 1 : 0) ||
    VERDICT_ORDER[a.verdict] - VERDICT_ORDER[b.verdict] ||
    b.requests - a.requests ||
    b.approvedDrivers - a.approvedDrivers ||
    a.label.localeCompare(b.label, "fr"));
  const [total] = aggregate(input, () => TOTAL_CITY);
  return {
    fromMs: input.fromMs,
    toMs: input.toMs,
    generatedAtMs: input.nowMs,
    availabilityMeasured: input.availabilityMeasured,
    thresholds: input.thresholds ?? MARKET_BALANCE_THRESHOLDS,
    total: total ?? emptyTotal(),
    cities,
  };
}

function emptyTotal(): CityBalance {
  return {
    key: TOTAL_CITY.key,
    label: TOTAL_CITY.label,
    requests: 0,
    accepted: 0,
    noDriver: 0,
    pending: 0,
    cancelledBeforeDriver: 0,
    acceptanceRate: null,
    medianAcceptMinutes: null,
    completed: 0,
    activeDrivers: 0,
    approvedDrivers: 0,
    onlineDriversNow: 0,
    jobsPerDriverPerWeek: null,
    availableHours: null,
    offers: { sent: 0, accepted: 0, declined: 0, expired: 0, pending: 0 },
    declineReasons: {},
    quotesNotBooked: 0,
    verdict: "not_enough_data",
    reasons: [],
  };
}
