import { getPublicBookingConfiguration } from '../lib/bookingAvailability';
import { onCall } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { normalizeLoad } from '../lib/booking';
import { admin, db } from '../lib/admin';
import { requireSignedIn, isSuperAdmin, isInternalDemoCustomer } from '../lib/auth';
import { resolveLockedQuote } from '../lib/quoteIntegrity';
import { permissionDenied, failedPrecondition } from '../lib/errors';
import { readDriverOfferCompensation } from '../lib/driverOfferCompensation';
import { toMinorUnits } from '../lib/money';
import { invalidArgument } from '../lib/errors';
import { findCompatibleVehicle, reviewBooking } from '../lib/bookingServer';

export const getBookingConfiguration = onCall(async request => {
  const ctx = request.auth ? requireSignedIn(request) : null;
  const configuration = await getPublicBookingConfiguration(ctx?.uid);
  return { ...configuration, internal_test_request: !!ctx && (isSuperAdmin(ctx) || isInternalDemoCustomer(ctx)) };
});
export const reviewDeliveryLoad = onCall(async request => {
  const { uid } = requireSignedIn(request);
  return (await reviewBooking(request.data.load, request.data.stops, uid)).review;
});
// One active draft per account; no addresses/contact details in URLs or logs.
export const saveBookingDraft = onCall(async request => {
  const { uid } = requireSignedIn(request);
  const { draft, revision, draftId, ownerUid } = request.data ?? {};
  if (ownerUid !== uid) throw permissionDenied('Le compte a changé.');
  if (!draft || typeof draft !== 'object' || JSON.stringify(draft).length > 50000 ||
    !Number.isSafeInteger(revision) || revision < 0 || typeof draftId !== 'string' || !/^[a-zA-Z0-9_-]{8,80}$/.test(draftId)) throw invalidArgument('Brouillon invalide.');
  if (!Array.isArray(draft.items) || draft.items.length > 20) throw invalidArgument('Objets du brouillon invalides.');
  const photoItemIds = draft.items.map((i: { id?: unknown }) => i.id).filter((id: unknown) => typeof id === 'string' && /^[a-zA-Z0-9_-]{1,80}$/.test(id as string));
  const ref = db.doc(`booking_drafts/${uid}`);
  return db.runTransaction(async tx => {
    const old = (await tx.get(ref)).data(); const now = admin.firestore.Timestamp.now();
    if (old?.draft_id === draftId && old.revision > revision) return { saved: false };
    const created = old?.draft_id === draftId ? old.created_at : now;
    if (created.toMillis() + 86400000 <= now.toMillis()) throw invalidArgument('Ce brouillon a expiré. Créez une nouvelle demande.');
    if (old?.draft_id && old.draft_id !== draftId) {
      tx.set(db.doc(`booking_draft_retirements/${uid}_${old.draft_id}`), {
        owner_uid: uid, draft_id: old.draft_id, expires_at: old.expires_at,
      });
    }
    tx.set(ref, { owner_uid: uid, draft_id: draftId, draft, revision, photo_item_ids: photoItemIds, created_at: created,
      updated_at: now, expires_at: admin.firestore.Timestamp.fromMillis(created.toMillis()+86400000) });
    return { saved: true };
  });
});
export const getBookingDraft = onCall(async request => {
  const { uid } = requireSignedIn(request); const ref = db.doc(`booking_drafts/${uid}`);
  const doc = (await ref.get()).data();
  if (!doc || doc.expires_at.toMillis() <= Date.now()) return { draft: null };
  return { draft: doc.draft, draftId: doc.draft_id, revision: doc.revision };
});
export const clearBookingDraft = onCall(async request => {
  const { uid } = requireSignedIn(request); const ref = db.doc(`booking_drafts/${uid}`);
  await db.runTransaction(async tx => { const d = (await tx.get(ref)).data(); if (d?.draft_id === request.data.draftId) tx.delete(ref); });
  return { cleared: true };
});
// Photos referenced by an official mission remain governed by mission retention.
// Orphan draft/review photos are removed after their container expires.
export async function cleanupExpiredBookingData(): Promise<void> {
  const now=admin.firestore.Timestamp.now();
  for(const collection of ['booking_drafts','booking_draft_retirements','booking_reviews']) {
    const expired=await db.collection(collection).where('expires_at','<=',now).limit(100).get();
    for(const doc of expired.docs) {
      const expiredData=await db.runTransaction(async tx=>{
        const current=(await tx.get(doc.ref)).data();
        if(!current || current.expires_at.toMillis()>Date.now())return null;
        const owner=current.owner_uid ?? current.customer_id;const draftId=current.draft_id;
        if(typeof owner!=='string' || typeof draftId!=='string') {tx.delete(doc.ref);return null;}
        const grantRef=db.doc(`booking_photo_grants/${owner}_${draftId}`);
        const grant=(await tx.get(grantRef)).data();
        const review=(await tx.get(db.doc(`booking_reviews/${owner}_${draftId}`))).data();
        const retain=!!grant?.mission_id || (review?.expires_at.toMillis()>Date.now());
        if(!retain)tx.set(grantRef,{expired:true,customer_id:owner});
        // Keep the expired row until Storage succeeds, so the next run retries.
        if(retain)tx.delete(doc.ref);
        return retain?null:{owner,draftId};
      });
      if(expiredData) {
        const [files]=await admin.storage().bucket().getFiles({prefix:`booking_photos/${expiredData.owner}/${expiredData.draftId}/`,maxResults:100,autoPaginate:false});
        await Promise.all(files.map(file=>file.delete({ignoreNotFound:true})));
        await db.runTransaction(async tx=>{
          const current=(await tx.get(doc.ref)).data();
          if(current && current.draft_id===expiredData.draftId && current.expires_at.toMillis()<=Date.now())tx.delete(doc.ref);
        });
      }
    }
  }
}
export const cleanupBookingDrafts = onSchedule('every 60 minutes', cleanupExpiredBookingData);

export const getBookingQuote = onCall(async request => {
  const { uid } = requireSignedIn(request);
  const id = request.data.quoteId;
  if (typeof id !== 'string' || !/^[a-zA-Z0-9_-]{1,100}$/.test(id)) throw invalidArgument('Devis invalide.');
  const q = (await db.doc(`delivery_quotes/${id}`).get()).data();
  if (!q || q.customer_id !== uid) throw permissionDenied('Devis inaccessible.');
  const locked = resolveLockedQuote(id, q);
  if (q.status === 'cancelled') throw invalidArgument('Devis indisponible.');
  if (locked.pricingSnapshot?.pre_assignment) {
    return { quoteId: id, customerTotal: locked.customerTotalMinor / 100,
      vehicleCategory: locked.pricingSnapshot.vehicle_category, booking: null, assignmentPending: true,
      breakdown: locked.pricingResult, distanceKm: locked.pricingSnapshot.distance_km,
      estimatedDurationMinutes: locked.pricingSnapshot.estimated_duration_minutes,
      expiresAtMillis: q.expires_at.toMillis(), missionId: q.mission_id ?? null };
  }
  if (!locked.pricingSnapshot?.booking) throw invalidArgument('Devis indisponible.');
  const attempt = (await db.doc(`booking_attempts/${uid}_${locked.pricingSnapshot.booking.load.draft_id}`).get()).data();
  return { quoteId: id, customerTotal: locked.customerTotalMinor / 100,
    vehicleCategory: locked.pricingSnapshot.booking.category, booking: locked.pricingSnapshot.booking,
    breakdown: locked.pricingResult, distanceKm: locked.pricingSnapshot.distance_km,
    estimatedDurationMinutes: locked.pricingSnapshot.estimated_duration_minutes,
    expiresAtMillis: q.expires_at.toMillis(), missionId: q.mission_id ?? attempt?.mission_id ?? null };
});

export const requestBookingReview = onCall(async request => {
  const { uid } = requireSignedIn(request);
  const id = request.data.draftId;
  if (typeof id !== 'string' || !/^[a-zA-Z0-9_-]{8,80}$/.test(id)) throw invalidArgument('Brouillon invalide.');
  if (request.data.load?.draft_id !== id) throw invalidArgument('Brouillon incohérent.');
  const checked = await reviewBooking(request.data.load, request.data.stops, uid);
  if (checked.review.status === 'ready') return { status: 'ready' };
  const ref = db.doc(`booking_reviews/${uid}_${id}`);
  await db.runTransaction(async tx => {
    const existing = (await tx.get(ref)).data();
    const grant = (await tx.get(db.doc(`booking_photo_grants/${uid}_${id}`))).data();
    if (grant?.expired) throw invalidArgument('Les photos de ce brouillon ont expiré.');
    const now = admin.firestore.Timestamp.now();
    tx.set(ref, { customer_id: uid, draft_id: id, load: normalizeLoad(request.data.load), stops: request.data.stops,
      reasons: checked.review.reasons, status: 'verification_required',
      created_at: existing?.created_at ?? now, updated_at: now,
      expires_at: admin.firestore.Timestamp.fromMillis(now.toMillis() + 7*86400000) });
  });
  return { status: 'verification_required', reviewId: ref.id };
});

export const getBookingVehicleForAcceptance = onCall(async request => {
  const { uid } = requireSignedIn(request);
  const id = request.data?.missionId;
  if (typeof id !== 'string' || !/^[a-zA-Z0-9_-]{1,100}$/.test(id)) throw invalidArgument('Mission invalide.');
  return db.runTransaction(async tx => {
    const driver = (await tx.get(db.doc('driver_profiles/' + uid))).data();
    if (driver?.status !== 'approved' || driver.documents_all_valid !== true) throw permissionDenied('Chauffeur non admissible.');
    const mission = (await tx.get(db.doc('delivery_requests/' + id))).data();
    if (!mission?.booking_snapshot || mission.driver_id ||
        !['searching_driver', 'offered'].includes(mission.status)) throw failedPrecondition('Mission indisponible.');
    const offers = await tx.get(db.collection('delivery_offers').where('mission_id', '==', id).where('driver_id', '==', uid));
    if (!offers.docs.some(d => d.data().status === 'pending' &&
        typeof d.data().expires_at?.toMillis === 'function' && d.data().expires_at.toMillis() > Date.now())) {
      throw failedPrecondition('Cette offre est indisponible ou expirée.');
    }
    const vehicle = await findCompatibleVehicle(uid, mission.booking_snapshot, tx);
    if (!vehicle) return { vehicle: null, offerTerms: null };
    const data = (await tx.get(db.doc('driver_vehicles/' + vehicle.vehicle_id))).data()!;
    let amountMinor = 0;
    if (!(mission.assignment_mode === 'internal_test' && mission.internal_test_authorized !== false &&
          (mission.internal_test_authorized === true || mission.internal_test_authorized === undefined))) {
      if (typeof mission.active_quote_id !== 'string' || !mission.active_quote_id) throw failedPrecondition('Devis officiel absent.');
      const quote = (await tx.get(db.doc('delivery_quotes/' + mission.active_quote_id))).data();
      if (!quote || quote.customer_id !== mission.customer_id || quote.mission_id !== id ||
          quote.is_consumed !== true || quote.status === 'cancelled' || quote.cancelled_at) throw failedPrecondition('Devis officiel invalide.');
      const locked = resolveLockedQuote(mission.active_quote_id, quote);
      if (mission.pricing_version !== locked.pricingVersion ||
          toMinorUnits(mission.customer_total) !== locked.customerTotalMinor ||
          (mission.customer_total_minor !== undefined && mission.customer_total_minor !== locked.customerTotalMinor) ||
          (locked.integrityHash && mission.quote_integrity_hash !== locked.integrityHash)) throw failedPrecondition('Mission et devis incohérents.');
      const { compensation } = await readDriverOfferCompensation(tx, uid, locked);
      amountMinor = toMinorUnits(compensation.driverOfferAmount);
    }
    return {
      vehicle: { id: vehicle.vehicle_id, label: String(data.make_model ?? '') + ' · ' + String(data.plate ?? vehicle.vehicle_id) },
      offerTerms: { amountMinor, currency: 'CAD', pricingVersion: mission.pricing_version },
    };
  });
});
