// Private pilot (owner decision 2026-10-22): the 4 public switches stay
// closed; accounts listed in system_config/pilot_access can book, accept, pay
// and be paid. Everyone else still gets the kill-switch refusal.
import { testBookingPolicy, testBookingConsent } from '../testUtils/bookingPolicyFixture';
jest.mock('../../src/lib/pushNotifications', () => ({ sendDeliveryOfferPush: jest.fn(async () => ({ attempted: 0, sent: 0 })) }));
import { admin, db } from '../../src/lib/admin';
import { calculateDeliveryQuote } from '../../src/functions/calculateDeliveryQuote';
import { createDeliveryRequest } from '../../src/functions/createDeliveryRequest';
import { onMissionCreatedDispatch } from '../../src/functions/dispatchMissionToDrivers';
import { acceptDelivery } from '../../src/functions/acceptDelivery';
import { encodeGeohash } from '../../src/lib/geohash';
import { buildPricingConfig } from '../unit/fixtures';
import { seedRuntimeFlags } from '../testUtils/runtimeFlagsFixture';
import { getPublicBookingConfiguration } from '../../src/lib/bookingAvailability';
import { isPilotUser } from '../../src/lib/runtimeFlags';
import { FakePaymentProvider, buildFakePaymentProfile } from '../testUtils/fakePaymentProvider';
import { setPaymentProviderForTesting } from '../../src/payment/paymentProviderFactory';

const customer = 'pilot_customer', driver = 'pilot_driver', vehicle = 'pilot_vehicle';
const draftId = 'pilot-draft';
const photo = `booking_photos/${customer}/${draftId}/item/0.jpg`;
const access = { floor: 0, stairs: false, elevator: false, help: false };
const stops = [
  { type: 'pickup', address: { line1: 'Synthetic pickup', city: 'Granby', postal_code: 'J2G0A1', lat: 45.4, lng: -72.7 } },
  { type: 'dropoff', address: { line1: 'Synthetic dropoff', city: 'Granby', postal_code: 'J2G0A2', lat: 45.41, lng: -72.71 } },
];
const contacts = { pickup_name: 'Synthetic Sender', pickup_phone: '+15145550100', dropoff_name: 'Synthetic Recipient', dropoff_phone: '+15145550101', instructions: '' };
const call = (data: any, uid: string, roles: string[]) =>
  ({ data, auth: { uid, token: { email_verified: true, roles, role: roles[0] } }, rawRequest: {}, acceptsStreaming: false } as any);
const asCustomer = (data: any) => call(data, customer, ['customer']);
const load = (requestedAt: string | null): any => ({
  draft_id: draftId, intake_mode: 'photo_assisted', timing_mode: requestedAt ? 'scheduled' : 'immediate', requested_at: requestedAt,
  pickup: access, dropoff: access, handlers: 1, equipment: [],
  items: [{ id: 'item', category: 'sofa', label: 'Synthetic sofa', quantity: 1, length: null, width: null, height: null, weight: null,
    dimension_unit: 'cm', weight_unit: 'kg', approximate: false, upright: true, photos: [photo],
    identification_confirmed: true, special_handling: false }],
});
const missionRef = (id: string) => db.doc('delivery_requests/' + id);
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
  // Public switches all closed.
  await seedRuntimeFlags({ accept_new_delivery_requests: false, allow_driver_acceptance: false,
    payments_enabled: false, driver_payouts_enabled: false });
  const pricing = buildPricingConfig({ pricing_version: 'PILOT-TEST' });
  pricing.vehicle_rules = ['pickup_truck', 'cargo_van', 'cube_truck'].map(category => ({ ...pricing.vehicle_rules[0], category }));
  pricing.handling_fees = { ...pricing.handling_fees, bulky_item_fee: 0 };
  await db.doc('pricing_configs/active').set({ active_pricing_version: pricing.pricing_version });
  await db.doc('pricing_versions/PILOT-TEST').set(pricing);
  await db.doc('system_config/booking_policy').set(testBookingPolicy('PILOT-TEST'));
  await db.doc('payment_profiles/' + customer).set(buildFakePaymentProfile(customer));
  await db.doc('driver_profiles/' + driver).set({ status: 'approved', online_status: 'online', documents_all_valid: true,
    current_geohash: encodeGeohash(45.4, -72.7, 6), full_name: 'Synthetic Driver', accepted_vehicle_categories: ['cargo_van'],
    stripe_connected_account_id: 'acct_synthetic_driver' });
  await db.doc('driver_vehicles/' + vehicle).set({ driver_id: driver, category: 'cargo_van', is_verified: false });
});
afterEach(async () => {
  storage.mockRestore(); setPaymentProviderForTesting(null);
  if (process.env.GCLOUD_PROJECT !== 'demo-movik-test' || process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8080') throw Error('cleanup isolation');
  for (const collection of ['delivery_quotes', 'delivery_requests', 'delivery_offers', 'financial_snapshots', 'payments', 'audit_logs',
    'booking_attempts', 'booking_photo_grants', 'users', 'driver_locations', 'driver_profiles', 'driver_vehicles', 'payment_profiles',
    'pricing_configs', 'pricing_versions', 'system_config', 'routing_rate_limits', 'transaction_ledger', 'mission_financial_balance',
    'mission_outcome_reviews']) await db.recursiveDelete(db.collection(collection));
});

/** Books a price-first request and has the driver accept it (card hold placed). */
async function bookAndAccept(requestedAt: string | null, accept = true) {
  const quote = await calculateDeliveryQuote.run(asCustomer({ quotePurpose: 'price_before_assignment', booking: load(requestedAt), stops }));
  const created = await createDeliveryRequest.run(asCustomer({ quoteId: quote.quoteId, booking: load(requestedAt), stops, contacts,
    consent: testBookingConsent('PILOT-TEST'), description: '', itemCategoryKey: '', requiredVehicleCategory: quote.vehicleCategory,
    customerDisplayName: 'Synthetic' }));
  const id = created.missionId as string;
  if (!accept) return id;
  const mission = (await missionRef(id).get()).data()!;
  await onMissionCreatedDispatch.run({ data: { data: () => mission }, params: { missionId: id } } as any);
  const accepted = await acceptDelivery.run(call({ missionId: id, vehicleId: vehicle, fitConfirmed: true }, driver, ['driver']));
  expect(accepted.success).toBe(true);
  const payment = (await db.doc('payments/' + (await missionRef(id).get()).data()!.active_payment_id).get()).data()!;
  expect(payment.status).toBe('authorized');
  return id;
}

const pilot = (user_ids: string[], enabled = true) => db.doc('system_config/pilot_access').set({ enabled, user_ids });

test('pilot access is fail-closed: no document, disabled or malformed list means nobody', async () => {
  expect(await isPilotUser(customer)).toBe(false);
  await pilot([customer], false);
  expect(await isPilotUser(customer)).toBe(false);
  await db.doc('system_config/pilot_access').set({ enabled: true, user_ids: customer });
  expect(await isPilotUser(customer)).toBe(false);
  await pilot([customer]);
  expect(await isPilotUser(customer)).toBe(true);
  expect(await isPilotUser('someone_else')).toBe(false);
  expect(await isPilotUser(null)).toBe(false);
});

test('booking availability opens only for a pilot account', async () => {
  await pilot([customer]);
  expect((await getPublicBookingConfiguration(customer)).availability).toMatchObject({ booking_enabled: true, payment_enabled: true });
  expect((await getPublicBookingConfiguration('someone_else')).availability).toMatchObject({ booking_enabled: false, payment_enabled: false });
  expect((await getPublicBookingConfiguration(null)).availability).toMatchObject({ booking_enabled: false, payment_enabled: false });
});

test('switches closed: a non-pilot customer is refused, a pilot customer and driver complete booking and card hold', async () => {
  const quote = await calculateDeliveryQuote.run(asCustomer({ quotePurpose: 'price_before_assignment', booking: load(null), stops }));
  const input = { quoteId: quote.quoteId, booking: load(null), stops, contacts, consent: testBookingConsent('PILOT-TEST'),
    description: '', itemCategoryKey: '', requiredVehicleCategory: quote.vehicleCategory, customerDisplayName: 'Synthetic' };
  await expect(createDeliveryRequest.run(asCustomer(input)))
    .rejects.toMatchObject({ code: 'failed-precondition', message: 'service_temporarily_unavailable' });

  await pilot([customer]);
  // Customer is pilot, driver is not: the driver cannot accept yet.
  const id = await bookAndAccept(null, false);
  const mission = (await missionRef(id).get()).data()!;
  await onMissionCreatedDispatch.run({ data: { data: () => mission }, params: { missionId: id } } as any);
  await expect(acceptDelivery.run(call({ missionId: id, vehicleId: vehicle, fitConfirmed: true }, driver, ['driver'])))
    .rejects.toMatchObject({ message: 'service_temporarily_unavailable' });
  expect(provider.createdPaymentParams).toHaveLength(0);

  await pilot([customer, driver]);
  const accepted = await acceptDelivery.run(call({ missionId: id, vehicleId: vehicle, fitConfirmed: true }, driver, ['driver']));
  expect(accepted.success).toBe(true);
  const payment = (await db.doc('payments/' + (await missionRef(id).get()).data()!.active_payment_id).get()).data()!;
  expect(payment.status).toBe('authorized');
});
