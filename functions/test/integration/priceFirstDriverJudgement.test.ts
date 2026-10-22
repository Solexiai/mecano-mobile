// Owner decision 2026-10-22: a price-before-assignment quote becomes a
// commercial booking judged by drivers. No booking_capacity, no measured
// vehicle, no service_zones document (Granby 40 km default applies).
import { testBookingPolicy, testBookingConsent } from '../testUtils/bookingPolicyFixture';
jest.mock('../../src/lib/pushNotifications', () => ({ sendDeliveryOfferPush: jest.fn(async () => ({ attempted: 0, sent: 0 })) }));
import { admin, db } from '../../src/lib/admin';
import { getBookingVehicleForAcceptance } from '../../src/functions/bookingJourney';
import { calculateDeliveryQuote } from '../../src/functions/calculateDeliveryQuote';
import { createDeliveryRequest } from '../../src/functions/createDeliveryRequest';
import { onMissionCreatedDispatch } from '../../src/functions/dispatchMissionToDrivers';
import { acceptDelivery } from '../../src/functions/acceptDelivery';
import { encodeGeohash } from '../../src/lib/geohash';
import { buildPricingConfig } from '../unit/fixtures';
import { seedDefaultRuntimeFlagsEnabled } from '../testUtils/runtimeFlagsFixture';
import { FakePaymentProvider, buildFakePaymentProfile } from '../testUtils/fakePaymentProvider';
import { setPaymentProviderForTesting } from '../../src/payment/paymentProviderFactory';

const customer = 'pf_customer', driver = 'pf_driver', vehicle = 'pf_vehicle', stranger = 'pf_stranger';
const draftId = 'price-first-draft';
const photo = `booking_photos/${customer}/${draftId}/item/0.jpg`;
const access = { floor: 0, stairs: false, elevator: false, help: false };
// Granby area (inside the 40 km default zone).
const stops = [
  { type: 'pickup', address: { line1: 'Synthetic pickup', city: 'Granby', postal_code: 'J2G0A1', lat: 45.4, lng: -72.7 } },
  { type: 'dropoff', address: { line1: 'Synthetic dropoff', city: 'Granby', postal_code: 'J2G0A2', lat: 45.41, lng: -72.71 } },
];
const contacts = { pickup_name: 'Synthetic Sender', pickup_phone: '+15145550100', dropoff_name: 'Synthetic Recipient', dropoff_phone: '+15145550101', instructions: '' };
const call = (data: any, uid = customer, roles = uid === customer ? ['customer'] : ['driver']) =>
  ({ data, auth: { uid, token: { email_verified: true, roles } }, rawRequest: {}, acceptsStreaming: false } as any);
const load = (): any => ({
  draft_id: draftId, intake_mode: 'photo_assisted', timing_mode: 'immediate', requested_at: null,
  pickup: access, dropoff: access, handlers: 1, equipment: [],
  items: [{ id: 'item', category: 'sofa', label: 'Synthetic sofa', quantity: 1, length: null, width: null, height: null, weight: null,
    dimension_unit: 'cm', weight_unit: 'kg', approximate: false, upright: true, photos: [photo],
    identification_confirmed: true, special_handling: false }],
});

let provider: FakePaymentProvider, storage: jest.SpyInstance;
beforeEach(async () => {
  jest.clearAllMocks();
  provider = new FakePaymentProvider(); setPaymentProviderForTesting(provider);
  storage = jest.spyOn(admin.storage(), 'bucket').mockReturnValue({ file: (name: string) => ({
    getMetadata: async () => {
      if (name !== photo) throw Object.assign(Error('missing synthetic image'), { code: 404 });
      return [{ contentType: 'image/jpeg', size: 4, generation: '1' }];
    },
  }) } as any);
  await seedDefaultRuntimeFlagsEnabled();
  const pricing = buildPricingConfig({ pricing_version: 'PRICE-FIRST-TEST' });
  // Uniform pilot tariff required by the price-before-assignment path.
  pricing.vehicle_rules = ['pickup_truck', 'cargo_van', 'cube_truck'].map(category => ({ ...pricing.vehicle_rules[0], category }));
  pricing.handling_fees = { ...pricing.handling_fees, bulky_item_fee: 0 };
  await db.doc('pricing_configs/active').set({ active_pricing_version: pricing.pricing_version });
  await db.doc('pricing_versions/PRICE-FIRST-TEST').set(pricing);
  await db.doc('system_config/booking_policy').set(testBookingPolicy('PRICE-FIRST-TEST'));
  await db.doc('payment_profiles/' + customer).set(buildFakePaymentProfile(customer));
  const profile = { status: 'approved', online_status: 'online', documents_all_valid: true,
    current_geohash: encodeGeohash(45.4, -72.7, 6) };
  await db.doc('driver_profiles/' + driver).set({ ...profile, full_name: 'Synthetic Driver', accepted_vehicle_categories: ['cargoVan'] });
  await db.doc('driver_profiles/' + stranger).set({ ...profile, full_name: 'Synthetic Stranger', accepted_vehicle_categories: ['cargo_van'] });
  // Not measured, not capacity-verified: the driver judges the fit.
  await db.doc('driver_vehicles/' + vehicle).set({ driver_id: driver, category: 'cargo_van', is_verified: false });
  await db.doc('driver_vehicles/pf_stranger_vehicle').set({ driver_id: stranger, category: 'cargo_van', is_verified: false });
});
afterEach(async () => {
  storage.mockRestore(); setPaymentProviderForTesting(null);
  if (process.env.GCLOUD_PROJECT !== 'demo-movik-test' || process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8080') throw Error('cleanup isolation');
  for (const collection of ['delivery_quotes', 'delivery_requests', 'delivery_offers', 'financial_snapshots', 'payments', 'audit_logs',
    'booking_attempts', 'booking_photo_grants', 'users', 'driver_locations', 'driver_profiles', 'driver_vehicles', 'payment_profiles',
    'pricing_configs', 'pricing_versions', 'system_config', 'routing_rate_limits']) await db.recursiveDelete(db.collection(collection));
});

async function quoteAndBook() {
  const quote = await calculateDeliveryQuote.run(call({ quotePurpose: 'price_before_assignment', booking: load(), stops }));
  const input = { quoteId: quote.quoteId, booking: load(), stops, contacts, consent: testBookingConsent('PRICE-FIRST-TEST'),
    description: '', itemCategoryKey: '', requiredVehicleCategory: quote.vehicleCategory, customerDisplayName: 'Synthetic' };
  const created = await createDeliveryRequest.run(call(input));
  expect((await createDeliveryRequest.run(call(input))).missionId).toBe(created.missionId);
  return { quote, created };
}

test('price-first request: booking -> offer -> driver confirms fit -> card authorized for the exact quoted cents', async () => {
  const { quote, created } = await quoteAndBook();
  expect(created.internalTest).toBe(false);
  const ref = db.doc('delivery_requests/' + created.missionId);
  const mission = (await ref.get()).data()!;
  expect(mission.booking_snapshot).toMatchObject({ vehicle_assessment: 'driver_judgement',
    eligible_categories: ['pickup_truck', 'cargo_van', 'cube_truck'] });
  expect(mission.booking_snapshot.load.items[0].photos).toEqual([photo]);
  expect((await db.doc(`delivery_requests/${created.missionId}/private/booking`).get()).data()?.consent?.accepted).toBe(true);

  await onMissionCreatedDispatch.run({ data: { data: () => mission }, params: { missionId: created.missionId } } as any);
  const offers = await db.collection('delivery_offers').where('mission_id', '==', created.missionId).get();
  expect(offers.docs.map(o => o.data().driver_id).sort()).toEqual([driver, stranger].sort());
  expect((await ref.get()).data()!.offered_driver_ids).toEqual(expect.arrayContaining([driver]));

  const chosen = await getBookingVehicleForAcceptance.run(call({ missionId: created.missionId }, driver));
  expect(chosen.vehicle?.id).toBe(vehicle);

  // The driver must explicitly confirm that the load fits.
  await expect(acceptDelivery.run(call({ missionId: created.missionId, vehicleId: vehicle }, driver)))
    .rejects.toMatchObject({ code: 'failed-precondition' });
  const accepted = await acceptDelivery.run(call({ missionId: created.missionId, vehicleId: vehicle, fitConfirmed: true }, driver));
  expect(accepted.success).toBe(true);
  const final = (await ref.get()).data()!;
  expect(final).toMatchObject({ driver_id: driver, assigned_vehicle_id: vehicle, assigned_capacity_version: 'driver_judgement' });
  const quoteDoc = (await db.doc('delivery_quotes/' + quote.quoteId).get()).data()!;
  expect(provider.createdPaymentParams).toHaveLength(1);
  expect(provider.createdPaymentParams[0].amountMinor).toBe(quoteDoc.customer_total_minor);
});

test('SEC-S4: a driver without a live offer cannot accept a booking', async () => {
  const { created } = await quoteAndBook();
  const mission = (await db.doc('delivery_requests/' + created.missionId).get()).data()!;
  expect(mission.status).toBe('searching_driver'); // not dispatched: no offer exists
  await expect(acceptDelivery.run(call({ missionId: created.missionId, vehicleId: vehicle, fitConfirmed: true }, driver)))
    .rejects.toMatchObject({ code: 'failed-precondition' });
  expect(provider.createdPaymentParams).toHaveLength(0);
});

test('a price-first booking still requires the current terms to be accepted', async () => {
  const quote = await calculateDeliveryQuote.run(call({ quotePurpose: 'price_before_assignment', booking: load(), stops }));
  await expect(createDeliveryRequest.run(call({ quoteId: quote.quoteId, booking: load(), stops, contacts,
    description: '', itemCategoryKey: '', requiredVehicleCategory: quote.vehicleCategory, customerDisplayName: 'Synthetic' })))
    .rejects.toMatchObject({ code: 'failed-precondition' });
  expect((await db.doc('delivery_quotes/' + quote.quoteId).get()).data()!.is_consumed).toBe(false);
});

test('a request outside the Granby 40 km default zone is refused at price time', async () => {
  const montreal = stops.map(s => ({ ...s, address: { ...s.address, lat: 45.5017, lng: -73.5673, city: 'Montréal' } }));
  await expect(calculateDeliveryQuote.run(call({ quotePurpose: 'price_before_assignment', booking: load(), stops: montreal })))
    .rejects.toMatchObject({ code: 'failed-precondition', details: { quote_reason: 'outside_service_area' } });
});

test('a pickup more than 4 days ahead is refused at price time', async () => {
  const far = { ...load(), timing_mode: 'scheduled', requested_at: new Date(Date.now() + 5 * 24 * 3600000).toISOString() };
  await expect(calculateDeliveryQuote.run(call({ quotePurpose: 'price_before_assignment', booking: far, stops })))
    .rejects.toMatchObject({ code: 'failed-precondition', details: { quote_reason: 'requested_time_too_far' } });
});
