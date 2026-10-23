import { testBookingPolicy, testBookingConsent } from '../testUtils/bookingPolicyFixture';
jest.mock('../../src/lib/pushNotifications', () => ({
  sendDeliveryOfferPush: jest.fn(async () => ({ attempted: 0, sent: 0 })),
}));
import {acceptDelivery} from '../../src/functions/acceptDelivery';
import { admin, db } from '../../src/lib/admin';
import { calculateDeliveryQuote } from '../../src/functions/calculateDeliveryQuote';
import { createDeliveryRequest } from '../../src/functions/createDeliveryRequest';
import { onMissionCreatedDispatch } from '../../src/functions/dispatchMissionToDrivers';
import { sendDeliveryOfferPush } from '../../src/lib/pushNotifications';
import { encodeGeohash } from '../../src/lib/geohash';
import { buildPricingConfig } from '../unit/fixtures';
import { seedDefaultRuntimeFlagsEnabled } from '../testUtils/runtimeFlagsFixture';
import { buildFakePaymentProfile, FakePaymentProvider } from '../testUtils/fakePaymentProvider';
import { setPaymentProviderForTesting } from '../../src/payment/paymentProviderFactory';
import { TEST_SCHEDULED_PICKUP } from '../testUtils/bookingTimeFixture';
import { cardHoldMinor } from '../../src/lib/missionFees';

// All data synthetic. Real callable and dispatch handlers, Firestore emulator.
// No Functions emulator, Eventarc delivery, FCM, Stripe or Routes requests.
const uid = 'timing_customer', driver = 'timing_driver';
const access = { floor: 0, stairs: false, elevator: false, help: false };
const capacity = { category: 'cargo_van', rank: 1, version: 'TIMING-TEST',
  verified: true, length_cm: 200, width_cm: 120, height_cm: 120,
  opening_width_cm: 100, opening_height_cm: 100, payload_kg: 200,
  handlers: 1, equipment: [], services: ['handling', 'stairs'] };
const stops = [
  { type: 'pickup', address: { line1: 'Synthetic pickup', city: 'Test city', postal_code: 'T0T0T0', lat: 45.5, lng: -73.6 } },
  { type: 'dropoff', address: { line1: 'Synthetic dropoff', city: 'Test city', postal_code: 'T0T0T0', lat: 45.6, lng: -73.7 } },
];
const contacts = { pickup_name: 'Test Sender', pickup_phone: '+15145550100',
  dropoff_name: 'Test Recipient', dropoff_phone: '+15145550101', instructions: '' };
function load(mode: 'immediate' | 'scheduled') { return {
  draft_id: 'timing-' + mode,
  items: [{ id: 'box', category: 'boxes', label: 'Test box', quantity: 1, length: 20,
    width: 20, height: 20, weight: 5, dimension_unit: 'cm', weight_unit: 'kg',
    approximate: false, upright: true, photos: [] }],
  pickup: access, dropoff: access, handlers: 1, equipment: [],
  timing_mode: mode, requested_at: mode === 'immediate' ? null : TEST_SCHEDULED_PICKUP,
}; }
const request = (data: unknown) => ({ data, auth: { uid, token: {
  email: 'test@example.invalid', email_verified: true, roles: ['customer'] } },
  rawRequest: {}, acceptsStreaming: false } as any);
const confirm = (quoteId: string, booking: unknown) => request({
  quoteId, booking, contacts, consent: testBookingConsent('TIMING-TEST'),
  stops, itemCategoryKey: 'boxes', description: 'Test box', requiredVehicleCategory: 'cargo_van',
  customerDisplayName: 'Synthetic customer',
});
let fake:FakePaymentProvider;
beforeEach(async () => {
  fake=new FakePaymentProvider();setPaymentProviderForTesting(fake);
  jest.clearAllMocks();
  await seedDefaultRuntimeFlagsEnabled();
  const pricing = buildPricingConfig({ pricing_version: 'TIMING-TEST' });
  await db.doc('pricing_configs/active').set({ active_pricing_version: pricing.pricing_version });
  await db.doc('pricing_versions/TIMING-TEST').set(pricing);
  await db.doc('system_config/booking_policy').set(testBookingPolicy('TIMING-TEST'));
  await db.doc('system_config/booking_capacity').set({ approved: true, version: 'TIMING-TEST',
    capacities: [capacity], heavy_item_kg: 50, bulky_item_cm: 150, require_booking_details: true });
  await db.doc('system_config/service_zones').set({ enabled: true,
    zones: [{ name: 'TEST ONLY', min_lat: 45, max_lat: 46, min_lng: -74, max_lng: -73 }] });
  await db.doc('payment_profiles/' + uid).set(buildFakePaymentProfile(uid));
  await db.doc('driver_profiles/' + driver).set({ status: 'approved', online_status: 'online',
    documents_all_valid: true, accepted_vehicle_categories: ['cargoVan'],
    current_geohash: encodeGeohash(45.5, -73.6, 6) });
  await db.doc('driver_vehicles/timing_vehicle').set({ driver_id: driver, is_verified: true,
    verified_capacity: capacity, capacity_valid_until: admin.firestore.Timestamp.fromMillis(Date.now() + 86400000) });
});
afterEach(async () => {
  setPaymentProviderForTesting(null);
  for (const path of ['pricing_configs/active', 'pricing_versions/TIMING-TEST',
    'system_config/booking_policy', 'system_config/booking_capacity', 'system_config/service_zones',
    'payment_profiles/' + uid, 'driver_profiles/' + driver, 'driver_vehicles/timing_vehicle',
    'booking_attempts/' + uid + '_timing-immediate', 'booking_attempts/' + uid + '_timing-scheduled',
    'driver_agendas/'+driver,'driver_locations/'+driver,'driver_calendar_busy/'+driver,'system_config/driver_scheduling',
    'users/' + uid, 'users/' + driver]) await db.recursiveDelete(db.doc(path));
  for (const collection of ['delivery_quotes', 'delivery_requests', 'delivery_offers']) {
    const field = collection === 'delivery_offers' ? 'driver_id' : 'customer_id';
    const value = collection === 'delivery_offers' ? driver : uid;
    const docs = await db.collection(collection).where(field, '==', value).get();
    for (const doc of docs.docs) await db.recursiveDelete(doc.ref);
  }
});
test.each(['immediate', 'scheduled'] as const)('%s quote creates mission, driver offer and in-app notification with identical cents', async mode => {
  const booking = load(mode);
  const quoteResult = await calculateDeliveryQuote.run(request({ booking, stops }));
  const quote = (await db.doc('delivery_quotes/' + quoteResult.quoteId).get()).data()!;
  const created = await createDeliveryRequest.run(confirm(quoteResult.quoteId, booking));
  const ref = db.doc('delivery_requests/' + created.missionId);
  const mission = (await ref.get()).data()!;
  expect(mission.status).toBe('searching_driver');
  expect(mission.booking_snapshot.load.timing_mode).toBe(mode);
  expect(mission.booking_snapshot.load.requested_at).toBe(booking.requested_at);
  expect(mission.customer_total_minor).toBe(quote.customer_total_minor);
  expect(mission.pricing_snapshot.customer_total_minor).toBe(quote.customer_total_minor);
  await onMissionCreatedDispatch.run({ data: { data: () => mission },
    params: { missionId: created.missionId } } as any);
  expect((await ref.get()).data()?.status).toBe('offered');
  const offers = await db.collection('delivery_offers').where('mission_id', '==', created.missionId).get();
  expect(offers.size).toBe(1);
  expect(offers.docs[0].data()).toMatchObject({ driver_id: driver, status: 'pending' });
  const notification = await db.doc('users/' + driver + '/notifications/delivery_offer_' + created.missionId).get();
  expect(notification.data()?.related_mission_id).toBe(created.missionId);
  expect(sendDeliveryOfferPush).toHaveBeenCalledTimes(1);
  expect((await createDeliveryRequest.run(confirm(quoteResult.quoteId, booking))).missionId).toBe(created.missionId);
});
test('changing immediate to scheduled cannot reuse the official quote', async () => {
  const quote = await calculateDeliveryQuote.run(request({ booking: load('immediate'), stops }));
  const changed = { ...load('scheduled'), draft_id: 'timing-immediate' };
  await expect(createDeliveryRequest.run(confirm(quote.quoteId, changed))).rejects.toMatchObject({ code: 'failed-precondition' });
  expect((await db.collection('delivery_requests').where('customer_id', '==', uid).get()).empty).toBe(true);
});
test('timing choice alone does not change the financial result', async () => {
  const immediate = await calculateDeliveryQuote.run(request({ booking: load('immediate'), stops }));
  const scheduled = await calculateDeliveryQuote.run(request({ booking: load('scheduled'), stops }));
  const a = (await db.doc('delivery_quotes/' + immediate.quoteId).get()).data()!;
  const b = (await db.doc('delivery_quotes/' + scheduled.quoteId).get()).data()!;
  expect(a.customer_total_minor).toBe(b.customer_total_minor);
  expect(a.pricing_snapshot.breakdown).toEqual(b.pricing_snapshot.breakdown);
});

test.each(['immediate','scheduled'] as const)('%s complete local quote -> dispatch -> acceptance -> agenda keeps identical official cents',async mode=>{
  await db.doc('system_config/driver_scheduling').set({enabled:true,approved:true,duration_confirmation_approved:true,version:'SCHED-TIMING-TEST',max_advance_minutes:1440});
  await db.doc('driver_profiles/'+driver).update({base_location_verified:true,base_lat:45.5,base_lng:-73.6,verified_base_lat:45.5,verified_base_lng:-73.6,service_radius_km:40});
  await db.doc('driver_agendas/'+driver).set({revision:0,windows:[{start:new Date(Date.now()-3600000).toISOString(),end:new Date(Date.now()+86400000).toISOString()}],blocked:[]});
  const booking={...load(mode),requested_at:mode==='scheduled'?new Date(Date.now()+3600000).toISOString():null};
  const quoteResult=await calculateDeliveryQuote.run(request({booking,stops}));
  const created=await createDeliveryRequest.run(confirm(quoteResult.quoteId,booking));
  const ref=db.doc('delivery_requests/'+created.missionId),mission=(await ref.get()).data()!;
  await onMissionCreatedDispatch.run({data:{data:()=>mission},params:{missionId:created.missionId}} as any);
  const pickup=booking.requested_at??new Date().toISOString();
  const end=new Date(Date.parse(pickup)+(Math.ceil(mission.estimated_duration_minutes)+45)*60000).toISOString();
  const accepted=await acceptDelivery.run({data:{missionId:created.missionId,vehicleId:'timing_vehicle',acceptanceRequestId:'timing-'+created.missionId,
    reservation:{start:pickup,pickup_at:pickup,end,policy_version:'SCHED-TIMING-TEST',full_duration_confirmed:true}},
    auth:{uid:driver,token:{roles:['driver']}},rawRequest:{},acceptsStreaming:false} as any);
  expect(accepted.success).toBe(true);
  const after=(await ref.get()).data()!,quote=(await db.doc('delivery_quotes/'+quoteResult.quoteId).get()).data()!;
  const snapshot=(await db.doc('financial_snapshots/'+accepted.snapshotId).get()).data()!;
  expect(after.customer_total_minor).toBe(quote.customer_total_minor);
  expect(snapshot.customer_total_minor).toBe(quote.customer_total_minor);
  expect(fake.createdPaymentParams).toHaveLength(1);
  expect(fake.createdPaymentParams[0].amountMinor).toBe(cardHoldMinor(quote.customer_total_minor));
  expect((await db.doc('driver_agendas/'+driver+'/reservations/'+created.missionId).get()).data()!.active).toBe(true);
  expect(after.duration_confirmation.driver_id).toBe(driver);
  expect(after.duration_confirmation.confirmed_at.toMillis()).toBeGreaterThan(0);
  await db.recursiveDelete(db.doc('calendar_sync_jobs/'+created.missionId));
});
