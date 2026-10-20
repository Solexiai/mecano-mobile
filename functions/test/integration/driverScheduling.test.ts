jest.mock('../../src/lib/pushNotifications', () => ({ sendDeliveryOfferPush: jest.fn(async () => ({ attempted: 0, sent: 0 })) }));
import { db, admin } from '../../src/lib/admin';
import { acceptDelivery } from '../../src/functions/acceptDelivery';
import { updateMissionTrackingStatus } from '../../src/functions/updateMissionTrackingStatus';
import { adjustDriverMissionSlot } from '../../src/functions/driverScheduleLifecycle';
import { saveDriverAgenda } from '../../src/functions/driverAgenda';
import { declineDeliveryOffer, reconcileMissionSchedule, sweepDriverOffers } from '../../src/functions/driverScheduleLifecycle';
import { dispatchScheduledMission } from '../../src/lib/scheduledDispatch';
import { buildPricingConfig } from '../unit/fixtures';
import { seedOfficialLegacyQuote } from '../testUtils/officialQuoteFixture';
import { seedDefaultRuntimeFlagsEnabled } from '../testUtils/runtimeFlagsFixture';
import { FakePaymentProvider, buildFakePaymentProfile } from '../testUtils/fakePaymentProvider';
import { setPaymentProviderForTesting } from '../../src/payment/paymentProviderFactory';
const uid = 'schedule_driver_a', uid2 = 'schedule_driver_b', m1 = 'schedule_m1', m2 = 'schedule_m2', customer = 'schedule_customer';
let fake: FakePaymentProvider, start: string, end: string;
const req = (who: string, data: unknown) => ({ data, auth: { uid: who, token: { roles: ['driver'] } }, rawRequest: {}, acceptsStreaming: false } as any);
const request = (missionId = m1, who = uid) => req(who, { missionId, acceptanceRequestId: 'same-request-' + missionId,
    reservation: { start, pickup_at: start, end, policy_version: 'SCHED-TEST', full_duration_confirmed: true } });
async function seedMission(id: string) {
    const pricing = buildPricingConfig({ pricing_version: 'SCHED-PRICE' });
    const q = await seedOfficialLegacyQuote({ missionId: id, customerId: customer, pricingConfig: pricing, distanceKm: 10, estimatedDurationMinutes: 20 });
    await db.doc('delivery_requests/' + id).set({ customer_id: customer, driver_id: null, status: 'searching_driver', item_category_key: 'furniture', description: 'Synthetic calendar test', required_vehicle_category: 'cargoVan',
        pickup_address: { line1: 'TEST', city: 'TEST', lat: 45.4, lng: -72.7 }, dropoff_address: { line1: 'TEST', city: 'TEST', lat: 45.41, lng: -72.7 },
        distance_km: 10, estimated_duration_minutes: 20, requested_at: start, pricing_version: 'SCHED-PRICE', driver_offer_amount: 0,
        customer_total: q.pricingResult.customerTotal, customer_total_minor: Math.round(q.pricingResult.customerTotal * 100),
        quote_breakdown: q.pricingResult, customer_discount_amount: 0, payment_status: 'pending', active_quote_id: q.quoteId,
        active_financial_snapshot_id: null, created_at: admin.firestore.Timestamp.now(), dispatch_zone_geohash: 'f2' });
}
async function offers(id = m1) {
    for (const driver of [uid, uid2])
        await db.doc('delivery_offers/' + id + '_' + driver).set({ mission_id: id, driver_id: driver, status: 'pending', expires_at: admin.firestore.Timestamp.fromMillis(Date.now() + 45000) });
}
async function clear() {
    for (const name of ['delivery_offers', 'financial_snapshots', 'payments', 'audit_logs', 'calendar_sync_jobs']) {
        const docs = await db.collection(name).get();
        for (const d of docs.docs)
            if ([m1, m2].includes(d.data().mission_id ?? d.data().target_id ?? d.id))
                await db.recursiveDelete(d.ref);
    }
    for (const path of ['driver_agendas/' + uid, 'driver_agendas/' + uid2, 'driver_calendar_busy/' + uid, 'driver_calendar_busy/' + uid2,
        'driver_profiles/' + uid, 'driver_profiles/' + uid2, 'driver_locations/' + uid, 'driver_locations/' + uid2, 'delivery_requests/' + m1, 'delivery_requests/' + m2,
        'delivery_quotes/quote_' + m1, 'delivery_quotes/quote_' + m2, 'system_config/driver_scheduling', 'system_config/service_zones', 'payment_profiles/' + customer, 'pricing_versions/SCHED-PRICE'])
        await db.recursiveDelete(db.doc(path));
}
beforeEach(async () => {
    await clear();
    fake = new FakePaymentProvider();
    setPaymentProviderForTesting(fake);
    start = new Date(Date.now() + 3600000).toISOString();
    end = new Date(Date.now() + 7200000).toISOString();
    await seedDefaultRuntimeFlagsEnabled();
    await db.doc('system_config/driver_scheduling').set({ enabled: true, approved: true, duration_confirmation_approved: true, version: 'SCHED-TEST', max_advance_minutes: 1440 });
    await db.doc('system_config/service_zones').set({ enabled: true, zones: [{ name: 'test', type: 'circle', center_lat: 45.4, center_lng: -72.7, radius_km: 40 }] });
    await db.doc('pricing_versions/SCHED-PRICE').set(buildPricingConfig({ pricing_version: 'SCHED-PRICE' }));
    await db.doc('payment_profiles/' + customer).set(buildFakePaymentProfile(customer));
    for (const id of [uid, uid2]) {
        await db.doc('driver_profiles/' + id).set({ status: 'approved', documents_all_valid: true, online_status: 'online', full_name: 'TEST', accepted_vehicle_categories: ['cargoVan'], service_radius_km: 20, base_lat: 45.4, base_lng: -72.7, base_location_verified: true, verified_base_lat: 45.4, verified_base_lng: -72.7 });
        await db.doc('driver_agendas/' + id).set({ revision: 0, windows: [{ start: new Date(Date.now() - 3600000).toISOString(), end: new Date(Date.now() + 86400000).toISOString() }], blocked: [] });
    }
    await seedMission(m1);
    await seedMission(m2);
    await offers(m1);
    await offers(m2);
});
afterEach(async () => { setPaymentProviderForTesting(null); await clear(); });
test('scheduled assignment preserves exact quote/snapshot/payment cents and does not start GPS', async () => {
    const accepted = await acceptDelivery.run(request());
    const m = (await db.doc('delivery_requests/' + m1).get()).data()!;
    const snapshot = (await db.doc('financial_snapshots/' + accepted.snapshotId).get()).data()!;
    const quote = (await db.doc('delivery_quotes/' + m.active_quote_id).get()).data()!;
    expect(snapshot.customer_total_minor).toBe(quote.customer_total_minor);
    expect(m.customer_total_minor).toBe(quote.customer_total_minor);
    expect(fake.createdPaymentParams).toHaveLength(1);
    expect(fake.createdPaymentParams[0].amountMinor).toBe(quote.customer_total_minor);
    expect((await db.doc('driver_profiles/' + uid).get()).data()!.online_status).toBe('online');
    expect((await db.doc('driver_locations/' + uid).get()).data()?.active_delivery_id).toBeUndefined();
    expect((await db.doc('driver_agendas/' + uid + '/reservations/' + m1).get()).data()!.active).toBe(true);
    expect((await db.doc('delivery_offers/' + m1 + '_' + uid2).get()).data()!.status).toBe('expired');
});
test('two drivers race: exactly one reservation and one snapshot', async () => {
    const outcomes = await Promise.allSettled([acceptDelivery.run(request()), acceptDelivery.run(request(m1, uid2))]);
    expect(outcomes.filter(x => x.status === 'fulfilled')).toHaveLength(1);
    expect((await db.collection('financial_snapshots').where('mission_id', '==', m1).get()).size).toBe(1);
});
test('one driver racing two overlapping offers cannot reserve both', async () => {
    const outcomes = await Promise.allSettled([acceptDelivery.run(request(m1)), acceptDelivery.run(request(m2))]);
    expect(outcomes.filter(x => x.status === 'fulfilled')).toHaveLength(1);
    expect((await db.collection('driver_agendas/' + uid + '/reservations').get()).size).toBe(1);
});
test('same request replay returns the same assignment and payment', async () => {
    const a = await acceptDelivery.run(request()), b = await acceptDelivery.run(request());
    expect(a.snapshotId).toBe(b.snapshotId);
    expect(fake.createdPaymentParams).toHaveLength(1);
});
test('reused request id cannot replace duration', async () => {
    await acceptDelivery.run(request());
    const r = request();
    r.data.reservation.end = new Date(Date.parse(end) + 600000).toISOString();
    await expect(acceptDelivery.run(r)).rejects.toMatchObject({ code: 'failed-precondition' });
});
test('expired offer refuses assignment', async () => {
    await db.doc('delivery_offers/' + m1 + '_' + uid).update({ expires_at: admin.firestore.Timestamp.fromMillis(0) });
    await expect(acceptDelivery.run(request())).rejects.toMatchObject({ code: 'failed-precondition' });
});
test('availability edit cannot erase an accepted future slot', async () => {
    await acceptDelivery.run(request());
    await expect(saveDriverAgenda.run(req(uid, { revision: 0, agenda: { windows: [], blocked: [] } }))).rejects.toMatchObject({ code: 'failed-precondition' });
});
test('availability update racing accept leaves consistent result', async () => {
    const outcomes = await Promise.allSettled([acceptDelivery.run(request()), saveDriverAgenda.run(req(uid, { revision: 0, agenda: { windows: [], blocked: [] } }))]);
    expect(outcomes.filter(x => x.status === 'fulfilled')).toHaveLength(1);
});
test.each(['stale', 'busy', 'error'])('external calendar %s blocks acceptance', async (state) => {
    await db.doc('driver_calendar_busy/' + uid).set({ required: true, status: state === 'error' ? 'error' : 'ready',
        checked_at: admin.firestore.Timestamp.fromMillis(Date.now() - (state === 'stale' ? 120000 : 0)), from: new Date(Date.parse(start) - 60000).toISOString(), to: new Date(Date.parse(end) + 60000).toISOString(), busy: state === 'busy' ? [{ start, end }] : [] });
    await expect(acceptDelivery.run(request())).rejects.toMatchObject({ code: 'failed-precondition' });
});
test('cancelled mission releases slot even before asynchronous cleanup', async () => {
    await acceptDelivery.run(request());
    await db.doc('delivery_requests/' + m1).update({ status: 'cancelled' });
    await acceptDelivery.run(request(m2));
    await reconcileMissionSchedule(m1);
    expect((await db.doc('driver_agendas/' + uid + '/reservations/' + m1).get()).data()!.active).toBe(false);
    await reconcileMissionSchedule(m1);
    expect((await db.doc('calendar_sync_jobs/' + m1).get()).data()!.state).toBe('pending');
});
test('refusal is owned and idempotent', async () => {
    await declineDeliveryOffer.run(req(uid, { missionId: m1 }));
    await declineDeliveryOffer.run(req(uid, { missionId: m1 }));
    expect((await db.doc('delivery_offers/' + m1 + '_' + uid).get()).data()!.status).toBe('declined');
    await expect(declineDeliveryOffer.run(req('outsider', { missionId: m1 }))).rejects.toMatchObject({ code: 'permission-denied' });
});
test('dispatcher respects region and availability and never sends internal test missions', async () => {
    const old = await db.collection('delivery_offers').where('mission_id', '==', m1).get();
    await Promise.all(old.docs.map(d => d.ref.delete()));
    await db.doc('driver_agendas/' + uid2).update({ windows: [] });
    await dispatchScheduledMission(m1);
    const dispatched = await db.collection('delivery_offers').where('mission_id', '==', m1).get();
    expect(dispatched.docs.map(d => d.data().driver_id)).toEqual([uid]);
    await db.doc('delivery_requests/' + m2).update({ assignment_mode: 'internal_test' });
    const before = (await db.collection('delivery_offers').get()).size;
    await dispatchScheduledMission(m2);
    expect((await db.collection('delivery_offers').get()).size).toBe(before);
});
test('search stops explicitly after bounded retries', async () => {
    await db.doc('delivery_requests/' + m1).update({ dispatch_round: 3, status: 'offered' });
    const docs = await db.collection('delivery_offers').where('mission_id', '==', m1).get();
    for (const d of docs.docs)
        await d.ref.update({ expires_at: admin.firestore.Timestamp.fromMillis(0) });
    await sweepDriverOffers();
    expect((await db.doc('delivery_requests/' + m1).get()).data()!.dispatch_state).toBe('no_driver_available');
});
test('legacy active mission with unknown full end blocks a new slot', async () => {
    await db.doc('delivery_requests/' + m2).update({ driver_id: uid, status: 'in_transit' });
    await db.doc('driver_locations/' + uid).set({ active_delivery_id: m2 });
    await expect(acceptDelivery.run(request())).rejects.toMatchObject({ code: 'failed-precondition' });
    expect(fake.createdPaymentParams).toHaveLength(0);
});
test('concurrent cancellation is not overwritten by acceptance', async () => {
    await Promise.allSettled([acceptDelivery.run(request()), db.doc('delivery_requests/' + m1).update({ status: 'cancelled' })]);
    expect((await db.doc('delivery_requests/' + m1).get()).data()!.status).toBe('cancelled');
    await reconcileMissionSchedule(m1);
    const reservation = (await db.doc('driver_agendas/' + uid + '/reservations/' + m1).get()).data();
    expect(reservation?.active ?? false).toBe(false);
});
test('changed scheduling version requires renewed confirmation', async () => {
    await db.doc('system_config/driver_scheduling').update({ version: 'CHANGED' });
    await expect(acceptDelivery.run(request())).rejects.toMatchObject({ code: 'failed-precondition' });
    expect(fake.createdPaymentParams).toHaveLength(0);
});
test('new pauses update the reserved interval without altering mission prices', async () => {
    await acceptDelivery.run(request());
    const initial = (await db.doc('delivery_requests/' + m1).get()).data()!;
    const windows = (await db.doc('driver_agendas/' + uid).get()).data()!.windows;
    await saveDriverAgenda.run(req(uid, { revision: 0, agenda: { windows, blocked: [], recurrence: { time_zone: 'America/Toronto', weekly: [], exceptions: [], pause_before_minutes: 10, pause_after_minutes: 15 } } }));
    const reserved = (await db.doc('driver_agendas/' + uid + '/reservations/' + m1).get()).data()!;
    expect(Date.parse(reserved.start)).toBe(Date.parse(start) - 600000);
    expect(Date.parse(reserved.end)).toBe(Date.parse(end) + 900000);
    expect((await db.doc('delivery_requests/' + m1).get()).data()!.customer_total).toBe(initial.customer_total);
});
test('future start denied; validated interval adjustment allows departure and is concurrency protected', async () => {
    await acceptDelivery.run(request());
    await expect(updateMissionTrackingStatus.run(req(uid, { missionId: m1, targetStatus: 'driver_to_pickup' }))).rejects.toMatchObject({ code: 'failed-precondition' });
    const reservation = { ...request().data.reservation, start: new Date(Date.now() - 10000).toISOString() };
    const adjustment = req(uid, { missionId: m1, expectedStart: start, expectedEnd: end, reservation });
    await adjustDriverMissionSlot.run(adjustment);
    await expect(adjustDriverMissionSlot.run(adjustment)).rejects.toMatchObject({ code: 'failed-precondition' });
    await updateMissionTrackingStatus.run(req(uid, { missionId: m1, targetStatus: 'driver_to_pickup' }));
    expect((await db.doc('driver_locations/' + uid).get()).data()!.active_delivery_id).toBe(m1);
    expect((await db.doc('delivery_requests/' + m1).get()).data()!.schedule_state).toBe('in_progress');
});
test('administrative assignment cannot bypass full slot confirmation while scheduling is active', async () => {
    const { adminAssignDelivery } = await import('../../src/functions/adminAssignDelivery');
    await expect(adminAssignDelivery.run({ data: { missionId: m1, driverId: uid }, auth: { uid: 'synthetic_admin', token: { roles: ['admin'] } }, rawRequest: {}, acceptsStreaming: false } as any)).rejects.toMatchObject({ code: 'failed-precondition' });
    expect((await db.doc('delivery_requests/' + m1).get()).data()!.driver_id).toBeNull();
    expect(fake.createdPaymentParams).toHaveLength(0);
});

test('disabling scheduling does not bypass existing future reservations',async()=>{
 await acceptDelivery.run(request());
 await db.doc('system_config/driver_scheduling').update({enabled:false});
 const legacy=req(uid,{missionId:m2});
 await expect(acceptDelivery.run(legacy)).rejects.toMatchObject({code:'failed-precondition'});
 expect((await db.doc('delivery_requests/'+m2).get()).data()!.driver_id).toBeNull();
});
test('enabled but unapproved policy fails closed rather than reverting to legacy acceptance',async()=>{
 await db.doc('system_config/driver_scheduling').update({approved:false});
 await expect(acceptDelivery.run(req(uid,{missionId:m1}))).rejects.toMatchObject({code:'failed-precondition'});
 expect(fake.createdPaymentParams).toHaveLength(0);
});
