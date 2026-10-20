import { db, admin } from './admin';
import { findCompatibleVehicle } from './bookingServer';
import { readSchedulingPolicy, missionRequestedAt, locationInDriverZone, prepareReservation } from './driverScheduling';
import { supportsVehicleCategory } from './vehicleCategory';
import { isRuntimeFlagEnabled, RuntimeFlagKeys } from './runtimeFlags';
import { sendDeliveryOfferPush } from './pushNotifications';
/** Return false only when the existing dispatch path remains applicable. */
export async function dispatchScheduledMission(missionId: string): Promise<boolean> {
    const policy = await readSchedulingPolicy();
    if (!policy)
        return false;
    if (!(await isRuntimeFlagEnabled(RuntimeFlagKeys.ALLOW_DRIVER_ACCEPTANCE)) ||
        !(await isRuntimeFlagEnabled(RuntimeFlagKeys.ACCEPT_NEW_DELIVERY_REQUESTS)))
        return true;
    const ref = db.doc('delivery_requests/' + missionId), m = (await ref.get()).data();
    if (!m || m.driver_id || m.status !== 'searching_driver' || m.assignment_mode === 'internal_test' || m.pricing_snapshot?.pre_assignment)
        return true;
    const now = Date.now(), requested = missionRequestedAt(m), start = requested ? Date.parse(requested) : now;
    const route = m.estimated_duration_minutes;
    if (!Number.isFinite(start) || start < now - 60000 || typeof route !== 'number' || !Number.isFinite(route) || route <= 0 ||
        start - now > policy.max_advance_minutes * 60000) {
        await ref.update({ dispatch_state: 'schedule_requires_review' });
        return true;
    }
    // Route-only interval is an eligibility lower bound, never a confirmed duration.
    const slot = { start: new Date(start).toISOString(), pickup_at: new Date(start).toISOString(),
        end: new Date(start + route * 60000).toISOString(), policy_version: policy.version };
    const candidateQuery = db.collection('driver_profiles').where('status', '==', 'approved').where('online_status', '==', 'online').orderBy(admin.firestore.FieldPath.documentId()).limit(200);
    const candidates = await (typeof m.dispatch_candidate_cursor === 'string' ? candidateQuery.startAfter(m.dispatch_candidate_cursor) : candidateQuery).get();
    const ids = candidates.docs.map(d => d.id);
    const winners = await db.runTransaction(async (tx) => {
        const current = (await tx.get(ref)).data();
        const p = await readSchedulingPolicy(tx);
        if (!p || p.version !== policy.version || !current || current.driver_id || current.status !== 'searching_driver' ||
            current.assignment_mode === 'internal_test' || current.pricing_snapshot?.pre_assignment)
            return [];
        if (missionRequestedAt(current) !== requested || current.estimated_duration_minutes !== route)
            return [];
        const prior = await tx.get(db.collection('delivery_offers').where('mission_id', '==', missionId));
        const round = (current.dispatch_round ?? 0) + 1;
        if (round > 3)
            return [];
        const zones = (await tx.get(db.doc('system_config/service_zones'))).data();
        const eligible: string[] = [];
        for (const uid of ids) {
            if (eligible.length >= 15)
                break;
            if (prior.docs.some(o => o.data().driver_id === uid && o.data().status === 'declined'))
                continue;
            const [profile, location] = await Promise.all([tx.get(db.doc('driver_profiles/' + uid)), tx.get(db.doc('driver_locations/' + uid))]);
            const d = profile.data();
            if (!d || d.status !== 'approved' || d.documents_all_valid !== true || d.online_status !== 'online' ||
                !supportsVehicleCategory(d.accepted_vehicle_categories ?? [], current.required_vehicle_category) ||
                !locationInDriverZone(d, location.data(), current.pickup_address, zones as never))
                continue;
            if (current.booking_snapshot && !(await findCompatibleVehicle(uid, current.booking_snapshot, tx)))
                continue;
            try {
                await prepareReservation(tx, uid, missionId, slot);
            }
            catch (error) {
                if ((error as {
                    code?: string;
                }).code === 'failed-precondition')
                    continue;
                throw error;
            }
            eligible.push(uid);
        }
        const stamp = admin.firestore.Timestamp.now(), expires = admin.firestore.Timestamp.fromMillis(stamp.toMillis() + 45000);
        for (const uid of eligible) {
            const offer = db.doc('delivery_offers/' + missionId + '_' + round + '_' + uid);
            tx.set(offer, { mission_id: missionId, driver_id: uid, offered_at: stamp, expires_at: expires, status: 'pending', round,
                duration_status: 'driver_confirmation_required', scheduling_policy_version: policy.version });
            const notification = db.doc('users/' + uid + '/notifications/delivery_offer_' + missionId);
            tx.set(notification, { id: notification.id, type: 'delivery_offer', title_key: 'notif_delivery_offer_title',
                body_key: 'notif_delivery_offer_body', is_read: false, created_at: stamp, related_mission_id: missionId,
                metadata: { offer_id: offer.id, expires_at: expires } });
        }
        tx.update(ref, { status: eligible.length ? 'offered' : 'searching_driver', dispatch_round: round,
            offered_driver_ids: eligible, offered_until: expires,
            dispatch_state: eligible.length ? 'offered' : round >= 3 ? 'no_driver_available' : 'searching',
            dispatch_candidates_limited: candidates.size === 200,
            dispatch_candidate_cursor: candidates.size === 200 ? candidates.docs[candidates.size - 1].id : null,
            dispatch_next_attempt_at: admin.firestore.Timestamp.fromMillis(stamp.toMillis() + 60000) });
        return eligible;
    });
    await Promise.all(winners.map(driverId => sendDeliveryOfferPush({ driverId, missionId, expiresAtMillis: Date.now() + 45000 })));
    return true;
}
