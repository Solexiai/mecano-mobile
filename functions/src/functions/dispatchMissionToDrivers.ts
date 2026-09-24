// Single dispatch path. Database snapshots are re-read before each commit;
// duplicated or delayed events must not recreate offers or reopen a mission.
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { admin, db } from "../lib/admin";
import { MissionStatuses } from "../lib/types";
import { eligibleForPickup, liveOffer, timestampMs, DELIVERY_OFFER_TTL_MS, deliveryOfferId } from "../lib/dispatchEligibility";
import { logFinancialFailure, logFinancialSuccess, startFinancialOperationTimer } from "../lib/observability";
import { sendDeliveryOfferPush } from "../lib/pushNotifications";

const MAX_CANDIDATE_DRIVERS = 15;
const PAGE_SIZE = 50;
const MAX_PAGES = 20;
const OPEN = [MissionStatuses.SEARCHING_DRIVER, MissionStatuses.OFFERED];
type Candidate = { id: string; distanceKm: number; origin: "gps" | "base" };

async function dispatchMission(missionId: string): Promise<void> {
  const timer = startFinancialOperationTimer();
  const missionRef = db.collection("delivery_requests").doc(missionId);
  const first = await missionRef.get();
  const mission = first.data();
  if (!mission || mission.driver_id || !OPEN.includes(mission.status)) return;
  const prior = await db.collection("delivery_offers").where("mission_id", "==", missionId).get();
  if (prior.docs.some((d) => liveOffer(d.data(), Date.now()))) return;
  const priorDrivers = new Set(prior.docs.map((d) => d.data().driver_id));
  const candidates: Candidate[] = [];
  let cursor: FirebaseFirestore.QueryDocumentSnapshot | undefined;
  let scanned = 0;
  let scanComplete = false;
  for (let page = 0; page < MAX_PAGES; page++) {
    let query = db.collection("driver_profiles").where("status", "==", "approved")
      .where("online_status", "==", "online").orderBy(admin.firestore.FieldPath.documentId()).limit(PAGE_SIZE);
    if (cursor) query = query.startAfter(cursor);
    const drivers = await query.get();
    scanned += drivers.size;
    if (drivers.empty) { scanComplete = true; break; }
    const locations = await db.getAll(...drivers.docs.map((d) => db.collection("driver_locations").doc(d.id)));
    for (let i = 0; i < drivers.docs.length; i++) {
      const eligibility = eligibleForPickup(drivers.docs[i].data(), locations[i].data(), mission, Date.now());
      if (eligibility && !priorDrivers.has(drivers.docs[i].id)) candidates.push({ id: drivers.docs[i].id, ...eligibility });
    }
    cursor = drivers.docs[drivers.docs.length - 1];
    if (drivers.size < PAGE_SIZE) { scanComplete = true; break; }
    // Bound work per event. Do not report an exhaustive search when capped.
    if (candidates.length >= MAX_CANDIDATE_DRIVERS) break;
  }
  candidates.sort((a, b) => a.distanceKm - b.distanceKm || a.id.localeCompare(b.id));
  const selected = candidates.slice(0, MAX_CANDIDATE_DRIVERS);
  const created = await db.runTransaction(async (tx) => {
    const current = (await tx.get(missionRef)).data();
    if (!current || current.driver_id || !OPEN.includes(current.status)) return null;
    const nowMs = Date.now();
    const offers = await tx.get(db.collection("delivery_offers").where("mission_id", "==", missionId));
    if (offers.docs.some((d) => liveOffer(d.data(), nowMs))) return null;
    // A declined/expired offer is not offered again to the same driver.
    const previouslyOffered = new Set(offers.docs.map((d) => d.data().driver_id));
    const remaining = selected.filter((c) => !previouslyOffered.has(c.id));
    const fresh: Candidate[] = [];
    for (const candidate of remaining) {
      const driver = await tx.get(db.collection("driver_profiles").doc(candidate.id));
      const location = await tx.get(db.collection("driver_locations").doc(candidate.id));
      const eligible = eligibleForPickup(driver.data() ?? {}, location.data(), current, nowMs);
      if (eligible) fresh.push({ id: candidate.id, ...eligible });
    }
    const now = admin.firestore.Timestamp.fromMillis(nowMs);
    const expiresAt = admin.firestore.Timestamp.fromMillis(nowMs + DELIVERY_OFFER_TTL_MS);
    for (const offer of offers.docs) {
      if (offer.data().status === "pending") tx.update(offer.ref, { status: "expired" });
    }
    for (const driver of fresh) {
      const offerRef = db.collection("delivery_offers").doc(deliveryOfferId(missionId, driver.id));
      tx.create(offerRef, {
        mission_id: missionId, driver_id: driver.id, offered_at: now,
        expires_at: expiresAt, status: "pending", dispatch_version: 2,
        pickup_distance_km: driver.distanceKm, location_source: driver.origin,
      });
      const notificationRef = db.collection("users").doc(driver.id).collection("notifications")
        .doc(`delivery_offer_${missionId}`);
      tx.set(notificationRef, { id: notificationRef.id, type: "delivery_offer",
        title_key: "notif_delivery_offer_title", body_key: "notif_delivery_offer_body",
        is_read: false, created_at: now, related_mission_id: missionId,
        metadata: { offer_id: offerRef.id, expires_at: expiresAt } });
    }
    tx.update(missionRef, { dispatch_version: 2, dispatch_scan_complete: scanComplete,
      status: fresh.length ? MissionStatuses.OFFERED : MissionStatuses.SEARCHING_DRIVER,
      dispatch_offer_expires_at: fresh.length ? expiresAt : null });
    return fresh.map((d) => ({ ...d, expiresAtMs: expiresAt.toMillis() }));
  });
  if (created === null) return;
  if (!created.length) {
    logFinancialFailure("dispatch_no_driver_available", timer, "no_new_eligible_offer",
      { missionId }, { metadata: { candidatesScanned: scanned, scanComplete } });
    return;
  }
  const push = await Promise.all(created.map((driver) => sendDeliveryOfferPush({
    driverId: driver.id, missionId, expiresAtMillis: driver.expiresAtMs,
  })));
  logFinancialSuccess("dispatch_offers_created", timer, { missionId }, { metadata: {
    offersCreated: created.length, candidatesScanned: scanned,
    pushSent: push.reduce((sum, result) => sum + result.sent, 0),
  } });
}

async function closeUnavailableOffers(missionId: string): Promise<void> {
  await db.runTransaction(async (tx) => {
    const mission = (await tx.get(db.collection("delivery_requests").doc(missionId))).data();
    if (!mission || (!mission.driver_id && OPEN.includes(mission.status))) return;
    const offers = await tx.get(db.collection("delivery_offers").where("mission_id", "==", missionId));
    for (const doc of offers.docs) {
      if (doc.data().status === "pending") tx.update(doc.ref, {
        status: mission.driver_id === doc.data().driver_id ? "accepted" : "superseded",
      });
    }
  });
}

export const onMissionCreatedDispatch = onDocumentCreated("delivery_requests/{missionId}", async (event) => {
  if (event.data?.data().status === MissionStatuses.SEARCHING_DRIVER) await dispatchMission(event.params.missionId);
});
export const onMissionReopenedDispatch = onDocumentUpdated("delivery_requests/{missionId}", async (event) => {
  const before = event.data?.before.data(); const after = event.data?.after.data();
  if (!after) return;
  if (after.driver_id || !OPEN.includes(after.status)) {
    await closeUnavailableOffers(event.params.missionId);
  } else if (before?.status !== MissionStatuses.SEARCHING_DRIVER && after.status === MissionStatuses.SEARCHING_DRIVER) {
    await dispatchMission(event.params.missionId);
  }
});

export const onDriverBecameAvailableDispatch = onDocumentUpdated("driver_profiles/{driverId}", async (event) => {
  const available = (d: FirebaseFirestore.DocumentData | undefined) => d?.status === "approved" &&
    d?.online_status === "online" && d?.documents_all_valid === true;
  if (!available(event.data?.after.data()) || available(event.data?.before.data())) return;
  const pending = await db.collection("delivery_requests").where("status", "==", MissionStatuses.SEARCHING_DRIVER)
    .limit(100).get();
  for (const mission of pending.docs) await dispatchMission(mission.id);
});

// A single reconciliation job closes expired offers and restarts waiting searches.
// Existing scheduler jobs were inspected: none handled delivery-offer expiration.
async function reconcileOpenBatch(status: string): Promise<void> {
  const cursorRef = db.collection("system_config").doc("delivery_offer_reconciliation");
  const field = status === MissionStatuses.OFFERED ? "offered_cursor" : "waiting_cursor";
  const stored = (await cursorRef.get()).data()?.[field];
  let query = db.collection("delivery_requests").where("status", "==", status)
    .orderBy(admin.firestore.FieldPath.documentId()).limit(100);
  if (typeof stored === "string" && stored) query = query.startAfter(stored);
  let batch = await query.get();
  if (batch.empty && stored) batch = await db.collection("delivery_requests")
    .where("status", "==", status).orderBy(admin.firestore.FieldPath.documentId()).limit(100).get();
  for (const mission of batch.docs) {
    const deadline = timestampMs(mission.data().dispatch_offer_expires_at);
    if (status === MissionStatuses.SEARCHING_DRIVER || deadline === null || deadline <= Date.now()) {
      await dispatchMission(mission.id);
    }
  }
  // Resume bounded work fairly; do not repeatedly starve requests after the first 100.
  await cursorRef.set({ [field]: batch.size === 100 ? batch.docs[batch.size - 1].id : null }, { merge: true });
}
export const processDeliveryOfferExpirations = onSchedule("every 1 minutes", async () => {
  await reconcileOpenBatch(MissionStatuses.OFFERED);
  await reconcileOpenBatch(MissionStatuses.SEARCHING_DRIVER);
});
