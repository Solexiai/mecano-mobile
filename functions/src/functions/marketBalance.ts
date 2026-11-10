// -----------------------------------------------------------------------------
// Équilibre offre / demande par ville (10 nov. 2026).
//
// Deux triggers gardent ce que l'app ne gardait pas :
//   - recordDriverAvailabilityChange : chaque passage en ligne / hors ligne /
//     en mission d'un chauffeur (ville et secteur de son adresse de service,
//     jamais sa position GPS) ;
//   - recordMissionNoDriver : le moment où une demande passe « aucun
//     chauffeur disponible ».
// Ils écrivent seulement dans `market_balance_events` : aucune écriture dans
// les missions, les offres, les paiements ni les taxes, et le dispatch ne
// change pas.
//
// recordOfferDeclineReason : raison FACULTATIVE donnée par le chauffeur après
// un refus (trop loin, prix trop bas, pas de place…). Le refus lui-même reste
// géré par declineDeliveryOffer, inchangé.
//
// getMarketBalance : tableau Admin, ville par ville, pour une semaine.
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { admin, db } from "../lib/admin";
import { requireAnalystOrAbove, requireAnyRole, requireSignedIn } from "../lib/auth";
import { failedPrecondition, invalidArgument } from "../lib/errors";
import { PlatformRoles } from "../lib/types";
import {
  MARKET_EVENTS_COLLECTION,
  MARKET_EVENT_TTL_DAYS,
  MissionFact,
  buildDriverStatusEvent,
  buildMarketBalance,
  buildNoDriverEvent,
  DriverStatusEvent,
  driverFact,
  isDeclineReason,
  missionFact,
  NoDriverEvent,
  OfferFact,
  offerFact,
  parseBalanceWindow,
  quoteFact,
  readMarketEvent,
  safeDocId,
  toMillis,
} from "../lib/marketBalance";

const DAY_MS = 86_400_000;
/** Borne de lecture par collection : largement au-dessus d'une semaine de pilote. */
const MAX_DOCS = 5000;
/** Missions plus anciennes à rattacher (offres et « aucun chauffeur » de la période). */
const MAX_EXTRA_MISSIONS = 1000;

const ts = (ms: number) => admin.firestore.Timestamp.fromMillis(ms);

function eventMillis(time: unknown): number {
  const ms = typeof time === "string" ? Date.parse(time) : NaN;
  return Number.isFinite(ms) ? ms : Date.now();
}

function expiresAt(atMs: number) {
  return ts(atMs + MARKET_EVENT_TTL_DAYS * DAY_MS);
}

export const recordDriverAvailabilityChange = onDocumentUpdated(
  "driver_profiles/{driverId}",
  async (event) => {
    const fields = buildDriverStatusEvent(
      event.params.driverId,
      event.data?.before.data(),
      event.data?.after.data(),
    );
    if (!fields) return;
    const atMs = eventMillis(event.time);
    // Id déterministe : un trigger rejoué réécrit le même document.
    await db.collection(MARKET_EVENTS_COLLECTION).doc(safeDocId("drv", event.id)).set({
      ...fields,
      at: ts(atMs),
      expire_at: expiresAt(atMs),
    });
  },
);

export const recordMissionNoDriver = onDocumentUpdated(
  "delivery_requests/{missionId}",
  async (event) => {
    const missionId = event.params.missionId;
    const fields = buildNoDriverEvent(missionId, event.data?.before.data(), event.data?.after.data());
    if (!fields) return;
    const atMs = eventMillis(event.time);
    await db
      .collection(MARKET_EVENTS_COLLECTION)
      .doc(safeDocId("nodrv", `${missionId}_${fields.round}`))
      .set({ ...fields, at: ts(atMs), expire_at: expiresAt(atMs) });
  },
);

export const recordOfferDeclineReason = onCall(async (request) => {
  const ctx = requireSignedIn(request);
  requireAnyRole(ctx, [PlatformRoles.DRIVER]);
  const missionId = request.data?.missionId;
  if (typeof missionId !== "string" || !/^[a-zA-Z0-9_-]{1,100}$/.test(missionId)) {
    throw invalidArgument("Mission invalide.");
  }
  const reason = request.data?.reason;
  if (!isDeclineReason(reason)) throw invalidArgument("Raison invalide.");

  const offers = await db
    .collection("delivery_offers")
    .where("mission_id", "==", missionId)
    .where("driver_id", "==", ctx.uid)
    .get();
  const declined = offers.docs.filter((doc) => doc.data().status === "declined");
  if (!declined.length) throw failedPrecondition("Aucun refus à préciser pour cette demande.");
  const toUpdate = declined.filter((doc) => !doc.data().decline_reason);
  if (toUpdate.length) {
    const now = admin.firestore.Timestamp.now();
    const batch = db.batch();
    for (const doc of toUpdate) batch.update(doc.ref, { decline_reason: reason, decline_reason_at: now });
    await batch.commit();
  }
  return { recorded: true };
});

export const getMarketBalance = onCall(async (request) => {
  const ctx = requireSignedIn(request);
  requireAnalystOrAbove(ctx);
  const nowMs = Date.now();
  const window = parseBalanceWindow(request.data, nowMs);
  if (!window) throw invalidArgument("Période invalide (35 jours au plus).");
  const { fromMs, toMs } = window;

  const range = (collection: string, field: string) =>
    db.collection(collection).where(field, ">=", ts(fromMs)).where(field, "<", ts(toMs)).limit(MAX_DOCS).get();

  const [created, completed, offers, events, firstEvent, drivers, quotes] = await Promise.all([
    range("delivery_requests", "created_at"),
    range("delivery_requests", "completed_at"),
    range("delivery_offers", "offered_at"),
    // Depuis le début de la période jusqu'à maintenant : l'état d'un
    // chauffeur au début de la semaine se lit dans le changement qui suit.
    db.collection(MARKET_EVENTS_COLLECTION).where("at", ">=", ts(fromMs)).orderBy("at").limit(MAX_DOCS).get(),
    db.collection(MARKET_EVENTS_COLLECTION).orderBy("at").limit(1).get(),
    db.collection("driver_profiles").where("status", "==", "approved").limit(MAX_DOCS).get(),
    range("delivery_quotes", "created_at"),
  ]);

  const missionsById = new Map<string, MissionFact>();
  const missionsCreated = created.docs.map((d) => missionFact(d.id, d.data()));
  const missionsCompleted = completed.docs.map((d) => missionFact(d.id, d.data()));
  for (const m of [...missionsCreated, ...missionsCompleted]) missionsById.set(m.id, m);

  const offerFacts = offers.docs.map((d) => offerFact(d.data())).filter((o): o is OfferFact => o !== null);
  const driverEvents: DriverStatusEvent[] = [];
  const noDriverEvents: NoDriverEvent[] = [];
  for (const doc of events.docs) {
    const read = readMarketEvent(doc.data());
    if (read?.kind === "driver") driverEvents.push(read.event);
    else if (read?.kind === "no_driver") noDriverEvents.push(read.event);
  }

  // Offres et « aucun chauffeur » qui visent des demandes créées avant la
  // période : on lit ces demandes pour connaître leur ville.
  const missing = [...new Set([
    ...offerFacts.map((o) => o.missionId),
    ...noDriverEvents.map((e) => e.missionId),
  ])].filter((id) => !missionsById.has(id)).slice(0, MAX_EXTRA_MISSIONS);
  for (let i = 0; i < missing.length; i += 100) {
    const refs = missing.slice(i, i + 100).map((id) => db.collection("delivery_requests").doc(id));
    const snaps = await db.getAll(...refs);
    for (const snap of snaps) {
      const data = snap.data();
      if (data) missionsById.set(snap.id, missionFact(snap.id, data));
    }
  }

  const firstEventMs = firstEvent.empty ? null : toMillis(firstEvent.docs[0].data().at);
  const result = buildMarketBalance({
    fromMs,
    toMs,
    nowMs,
    missionsCreated,
    missionsCompleted,
    missionsById,
    offers: offerFacts,
    drivers: drivers.docs.map((d) => driverFact(d.id, d.data())),
    driverEvents,
    noDriverEvents,
    quotes: quotes.docs.map((d) => quoteFact(d.data())),
    availabilityMeasured: firstEventMs !== null && firstEventMs <= fromMs,
  });
  const truncated = [created, completed, offers, events, drivers, quotes].some((s) => s.size >= MAX_DOCS);
  return { ...result, truncated, measuredSinceMs: firstEventMs };
});
