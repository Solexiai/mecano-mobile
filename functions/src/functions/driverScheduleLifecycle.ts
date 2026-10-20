import { onCall } from 'firebase-functions/v2/https';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { db, admin } from '../lib/admin';
import { requireSignedIn, requireAnyRole, isAdminOrAbove } from '../lib/auth';
import { OPEN_FOR_ACCEPTANCE_STATUSES, PlatformRoles } from '../lib/types';
import { invalidArgument, permissionDenied, failedPrecondition, notFound } from '../lib/errors';
import { readSchedulingPolicy, confirmedSlot, prepareReservation, terminalScheduleStatuses, missionRequestedAt } from '../lib/driverScheduling';
import { dispatchScheduledMission } from '../lib/scheduledDispatch';
import { writeAuditLogInTransaction } from '../lib/audit';
function id(v: unknown): string {
    if (typeof v !== 'string' || !v || v.includes('/') || v.length > 200)
        throw invalidArgument('Identifiant invalide.');
    return v;
}
export const declineDeliveryOffer = onCall(async request => {
  const ctx = requireSignedIn(request);
  requireAnyRole(ctx, [PlatformRoles.DRIVER]);
  const missionId = request.data?.missionId;
  if (typeof missionId !== 'string' || !/^[a-zA-Z0-9_-]{1,100}$/.test(missionId)) {
    throw invalidArgument('Mission invalide.');
  }
  return db.runTransaction(async tx => {
    const [missionSnap, driverSnap, offers] = await Promise.all([
      tx.get(db.doc('delivery_requests/' + missionId)),
      tx.get(db.doc('driver_profiles/' + ctx.uid)),
      tx.get(db.collection('delivery_offers').where('mission_id','==',missionId).where('driver_id','==',ctx.uid)),
    ]);
    const driver = driverSnap.data(), mission = missionSnap.data();
    if (driver?.status !== 'approved' || driver.documents_all_valid !== true || offers.empty) {
      throw permissionDenied('Offre inaccessible.');
    }
    if (offers.docs.every(doc => doc.data().status === 'declined')) return {declined:true};
    if (!mission || mission.driver_id || !OPEN_FOR_ACCEPTANCE_STATUSES.includes(mission.status)) {
      throw failedPrecondition('Cette demande n’est plus disponible.');
    }
    const now = admin.firestore.Timestamp.now();
    const pending = offers.docs.filter(doc => {
      const offer = doc.data();
      return offer.status === 'pending' && typeof offer.expires_at?.toMillis === 'function' &&
        offer.expires_at.toMillis() > now.toMillis();
    });
    if (!pending.length) throw failedPrecondition('Cette offre a expiré.');
    for (const offer of pending) tx.update(offer.ref,{status:'declined',declined_at:now});
    return {declined:true};
  });
});
/** Changes the driver's occupied interval; pickup time stays locked.
 * A different customer appointment must use the existing revised request/quote flow. */
export const adjustDriverMissionSlot = onCall(async (request) => {
    const ctx = requireSignedIn(request);
    requireAnyRole(ctx, [PlatformRoles.DRIVER]);
    const missionId = id(request.data?.missionId);
    await db.runTransaction(async (tx) => {
        const ref = db.doc('delivery_requests/' + missionId), m = (await tx.get(ref)).data();
        const policy = await readSchedulingPolicy(tx);
        if (!m)
            throw notFound('Mission introuvable.');
        if (m.driver_id !== ctx.uid)
            throw permissionDenied();
        if (!policy || m.status !== 'assigned' || !m.scheduling)
            throw failedPrecondition('Ce créneau ne peut pas être modifié.');
        if (request.data.expectedStart !== m.scheduling.start || request.data.expectedEnd !== m.scheduling.end)
            throw failedPrecondition('Le créneau a changé. Rechargez la mission.');
        const slot = confirmedSlot(request.data.reservation, { ...m, requested_at: m.scheduling.pickup_at }, policy);
        if (slot.pickup_at !== m.scheduling.pickup_at)
            throw failedPrecondition('Un changement du rendez-vous client exige une demande révisée.');
        const reservation = await prepareReservation(tx, ctx.uid, missionId, slot);
        reservation.write();
        tx.update(ref, { scheduling: slot, duration_confirmation: { driver_id: ctx.uid, confirmed_at: admin.firestore.FieldValue.serverTimestamp(), policy_version: slot.policy_version } });
        writeAuditLogInTransaction(tx, { actorUserId: ctx.uid, actorRole: 'driver', action: 'driver_slot_adjusted', sourceFunction: 'adjustDriverMissionSlot', targetId: missionId, metadata: { policyVersion: policy.version } });
    });
    return { success: true };
});
export async function reconcileMissionSchedule(missionId: string): Promise<void> {
    await db.runTransaction(async (tx) => {
        const ref = db.doc('delivery_requests/' + missionId), m = (await tx.get(ref)).data();
        const jobRef = db.doc('calendar_sync_jobs/' + missionId), job = await tx.get(jobRef);
        const driverId = m?.driver_id ?? job.data()?.driver_id;
        if (!driverId || (!m?.scheduling && !job.exists))
            return;
        const root = db.doc('driver_agendas/' + driverId), rRef = root.collection('reservations').doc(missionId);
        const [rootDoc, reservation] = await Promise.all([tx.get(root), tx.get(rRef)]);
        const active = !!m?.driver_id && !terminalScheduleStatuses.has(m.status);
        const fingerprint = JSON.stringify({ status: m?.status ?? 'deleted', paymentStatus: m?.payment_status ?? null, driverId, slot: m?.scheduling ?? null });
        if (job.data()?.source_fingerprint === fingerprint)
            return;
        if (reservation.exists && !active)
            tx.update(rRef, { active: false, released_at: admin.firestore.Timestamp.now() });
        if (rootDoc.exists)
            tx.set(root, { lock_version: admin.firestore.FieldValue.increment(1) }, { merge: true });
        if (m?.scheduling)
            tx.update(ref, { schedule_state: active ? (m.status === 'assigned' ? (missionRequestedAt(m) ? 'reserved' : 'ready_to_start') : 'in_progress') : m.status });
        tx.set(jobRef, { mission_id: missionId, driver_id: driverId, source_fingerprint: fingerprint, state: 'pending',
            generation: admin.firestore.FieldValue.increment(1), attempts: 0, next_attempt_at: admin.firestore.Timestamp.now() }, { merge: true });
        if (!active && m?.customer_id) {
            for (const uid of [driverId, m.customer_id]) {
                const n = db.doc('users/' + uid + '/notifications/schedule_' + missionId);
                tx.set(n, { id: n.id, type: 'mission_status', title_key: 'notif_mission_update_title', body_key: 'notif_mission_update_body',
                    related_mission_id: missionId, is_read: false, created_at: admin.firestore.Timestamp.now(), metadata: { status: m.status } });
            }
        }
    });
}
export const onMissionScheduleChanged = onDocumentWritten('delivery_requests/{missionId}', event => reconcileMissionSchedule(event.params.missionId));
export async function sweepDriverOffers(): Promise<void> {
    if (!(await readSchedulingPolicy()))
        return;
    const cursorRef = db.doc('calendar_worker_state/offer_sweep');
    const cursor = (await cursorRef.get()).data()?.cursor;
    const query = db.collection('delivery_requests').where('status', 'in', ['offered', 'searching_driver']).orderBy(admin.firestore.FieldPath.documentId()).limit(50);
    const pending = await (typeof cursor === 'string' ? query.startAfter(cursor) : query).get();
    for (const doc of pending.docs) {
        let retry = false;
        await db.runTransaction(async (tx) => {
            const m = (await tx.get(doc.ref)).data();
            if (!m || m.driver_id || m.assignment_mode === 'internal_test' || m.pricing_snapshot?.pre_assignment ||
                !['offered', 'searching_driver'].includes(m.status))
                return;
            const offers = await tx.get(db.collection('delivery_offers').where('mission_id', '==', doc.id));
            const now = Date.now();
            const open = offers.docs.filter(o => o.data().status === 'pending' && o.data().expires_at?.toMillis() > now);
            for (const o of offers.docs)
                if (o.data().status === 'pending' && o.data().expires_at?.toMillis() <= now)
                    tx.update(o.ref, { status: 'expired' });
            if (open.length)
                return;
            const exhausted = (m.dispatch_round ?? 0) >= 3;
            retry = !exhausted && (m.dispatch_next_attempt_at?.toMillis() ?? 0) <= now;
            tx.update(doc.ref, { status: 'searching_driver', dispatch_state: exhausted ? 'no_driver_available' : 'searching' });
        });
        if (retry)
            await dispatchScheduledMission(doc.id);
        await cursorRef.set({ cursor: doc.id });
    }
    if (pending.size < 50)
        await cursorRef.set({ cursor: null });
}
export const maintainDriverOffers = onSchedule('every 1 minutes', sweepDriverOffers);
export const retryDriverSearch = onCall(async (request) => {
    const ctx = requireSignedIn(request), missionId = id(request.data?.missionId);
    await db.runTransaction(async (tx) => {
        const ref = db.doc('delivery_requests/' + missionId), m = (await tx.get(ref)).data();
        if (!m)
            throw notFound();
        if (m.customer_id !== ctx.uid && !isAdminOrAbove(ctx))
            throw permissionDenied();
        if (m.driver_id || m.status !== 'searching_driver' || m.dispatch_state !== 'no_driver_available')
            throw failedPrecondition('Cette recherche ne peut pas être relancée.');
        tx.update(ref, { dispatch_round: 0, dispatch_state: 'searching', dispatch_next_attempt_at: admin.firestore.Timestamp.now() });
    });
    await dispatchScheduledMission(missionId);
    return { success: true };
});
