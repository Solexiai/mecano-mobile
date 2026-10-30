// Passage au vrai argent (2026-10-30). With the LIVE key active:
// - the admin sees which drivers still carry a test payout account and which
//   test payments are still open, and can archive the stale accounts;
// - a driver who redoes the Stripe setup gets a live-tagged account, the old
//   one archived;
// - a driver without a live payout account cannot accept a paid delivery;
//   a driver with one accepts, and the transfer goes to the live account.
import { testBookingPolicy, testBookingConsent } from '../testUtils/bookingPolicyFixture';
jest.mock('../../src/lib/pushNotifications', () => ({ sendDeliveryOfferPush: jest.fn(async () => ({ attempted: 0, sent: 0 })) }));
import { admin, db } from '../../src/lib/admin';
import { calculateDeliveryQuote } from '../../src/functions/calculateDeliveryQuote';
import { createDeliveryRequest } from '../../src/functions/createDeliveryRequest';
import { onMissionCreatedDispatch } from '../../src/functions/dispatchMissionToDrivers';
import { acceptDelivery } from '../../src/functions/acceptDelivery';
import { adminStripeEnvironment } from '../../src/functions/adminStripeEnvironment';
import { createDriverStripeAccount } from '../../src/functions/createDriverStripeAccount';
import { encodeGeohash } from '../../src/lib/geohash';
import { buildPricingConfig } from '../unit/fixtures';
import { seedDefaultRuntimeFlagsEnabled } from '../testUtils/runtimeFlagsFixture';
import { FakeLivePaymentProvider, buildFakePaymentProfile } from '../testUtils/fakePaymentProvider';
import { setPaymentProviderForTesting } from '../../src/payment/paymentProviderFactory';

const customer = 'live_customer', driver = 'live_driver', vehicle = 'live_vehicle', staff = 'live_staff';
const draftId = 'live-draft';
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
const asAdmin = (data: any) => call(data, staff, ['admin']);
const load: any = {
  draft_id: draftId, intake_mode: 'photo_assisted', timing_mode: 'immediate', requested_at: null,
  pickup: access, dropoff: access, handlers: 1, equipment: [],
  items: [{ id: 'item', category: 'sofa', label: 'Synthetic sofa', quantity: 1, length: null, width: null, height: null, weight: null,
    dimension_unit: 'cm', weight_unit: 'kg', approximate: false, upright: true, photos: [photo],
    identification_confirmed: true, special_handling: false }],
};
const driverDoc = () => db.doc('driver_profiles/' + driver);
let provider: FakeLivePaymentProvider, storage: jest.SpyInstance;

beforeEach(async () => {
  jest.clearAllMocks();
  provider = new FakeLivePaymentProvider(); setPaymentProviderForTesting(provider);
  storage = jest.spyOn(admin.storage(), 'bucket').mockReturnValue({ file: (name: string) => ({
    getMetadata: async () => {
      if (name !== photo) throw Object.assign(Error('missing synthetic image'), { code: 404 });
      return [{ contentType: 'image/jpeg', size: 4, generation: '1' }];
    },
  }) } as any);
  await seedDefaultRuntimeFlagsEnabled();
  const pricing = buildPricingConfig({ pricing_version: 'LIVE-TEST' });
  pricing.vehicle_rules = ['pickup_truck', 'cargo_van', 'cube_truck'].map(category => ({ ...pricing.vehicle_rules[0], category }));
  pricing.handling_fees = { ...pricing.handling_fees, bulky_item_fee: 0 };
  await db.doc('pricing_configs/active').set({ active_pricing_version: pricing.pricing_version });
  await db.doc('pricing_versions/LIVE-TEST').set(pricing);
  await db.doc('system_config/booking_policy').set(testBookingPolicy('LIVE-TEST'));
  // A card saved in live.
  await db.doc('payment_profiles/' + customer).set({ ...buildFakePaymentProfile(customer), stripe_environment: 'live' });
  // The driver's payout account was created in test (before the tag existed).
  await driverDoc().set({ status: 'approved', online_status: 'online', documents_all_valid: true,
    current_geohash: encodeGeohash(45.4, -72.7, 6), full_name: 'Synthetic Driver', accepted_vehicle_categories: ['cargo_van'],
    stripe_connected_account_id: 'acct_test_old', stripe_charges_enabled: true, stripe_payouts_enabled: true });
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

async function bookAndDispatch(): Promise<string> {
  const quote = await calculateDeliveryQuote.run(asCustomer({ quotePurpose: 'price_before_assignment', booking: load, stops }));
  const created = await createDeliveryRequest.run(asCustomer({ quoteId: quote.quoteId, booking: load, stops, contacts,
    consent: testBookingConsent('LIVE-TEST'), description: '', itemCategoryKey: '', requiredVehicleCategory: quote.vehicleCategory,
    customerDisplayName: 'Synthetic' }));
  const id = created.missionId as string;
  const mission = (await db.doc('delivery_requests/' + id).get()).data()!;
  await onMissionCreatedDispatch.run({ data: { data: () => mission }, params: { missionId: id } } as any);
  return id;
}
const accept = (id: string) => acceptDelivery.run(call({ missionId: id, vehicleId: vehicle, fitConfirmed: true }, driver, ['driver']));

test('admin sees the live environment, the stale test account and the open test payments; archiving clears the account', async () => {
  await db.collection('payments').doc('pay_test_open').set({ mission_id: 'm_old', status: 'authorized', stripe_environment: 'test' });
  await db.collection('payments').doc('pay_test_done').set({ mission_id: 'm_done', status: 'captured', stripe_environment: 'test' });
  await db.collection('payments').doc('pay_live_open').set({ mission_id: 'm_live', status: 'authorized', stripe_environment: 'live' });
  await expect(adminStripeEnvironment.run(call({ action: 'get' }, customer, ['customer']))).rejects.toMatchObject({ code: 'permission-denied' });

  const status = (await adminStripeEnvironment.run(asAdmin({ action: 'get' }))) as any;
  expect(status).toMatchObject({ configured: true, environment: 'live' });
  expect(status.stale_drivers).toEqual([{ uid: driver, name: 'Synthetic Driver', environment: 'test' }]);
  expect(status.open_payments_other_environment).toEqual([{ payment_id: 'pay_test_open', mission_id: 'm_old', status: 'authorized', environment: 'test' }]);

  const archived = (await adminStripeEnvironment.run(asAdmin({ action: 'archive_stale_driver_accounts' }))) as any;
  expect(archived).toMatchObject({ success: true, archived: 1 });
  const after = (await driverDoc().get()).data()!;
  expect(after).toMatchObject({ stripe_connected_account_id: null, stripe_charges_enabled: false, stripe_payouts_enabled: false });
  expect(after.stripe_previous_accounts).toHaveLength(1);
  expect(after.stripe_previous_accounts[0]).toMatchObject({ account_id: 'acct_test_old', environment: 'test', archived_by: 'admin' });
  expect((await adminStripeEnvironment.run(asAdmin({ action: 'get' })) as any).stale_drivers).toEqual([]);
  const audits = await db.collection('audit_logs').where('source_function', '==', 'adminStripeEnvironment').get();
  expect(audits.size).toBe(1);
  // Running it again changes nothing.
  expect((await adminStripeEnvironment.run(asAdmin({ action: 'archive_stale_driver_accounts' })) as any).archived).toBe(0);
});

test('a driver who redoes the Stripe setup in live gets a live-tagged account; the test one is archived', async () => {
  const uid = (await admin.auth().createUser({ email: 'live.driver@example.com', password: 'synthetic-password' })).uid;
  try {
    await db.doc('driver_profiles/' + uid).set({ status: 'approved', stripe_connected_account_id: 'acct_test_old',
      stripe_charges_enabled: true, stripe_payouts_enabled: true });
    const result = await createDriverStripeAccount.run(call({}, uid, ['driver']));
    expect(result).toMatchObject({ success: true, alreadyExisted: false, active: false, connectedAccountId: `fake_acct_${uid}` });
    const doc = (await db.doc('driver_profiles/' + uid).get()).data()!;
    expect(doc).toMatchObject({ stripe_connected_account_id: `fake_acct_${uid}`, stripe_connected_account_environment: 'live',
      stripe_charges_enabled: false, stripe_payouts_enabled: false });
    expect(doc.stripe_previous_accounts[0]).toMatchObject({ account_id: 'acct_test_old', environment: 'test', archived_by: 'driver' });
  } finally {
    await admin.auth().deleteUser(uid).catch(() => undefined);
  }
});

test('in live, a driver whose payout account is not live cannot accept; with a live account the transfer goes to it', async () => {
  const id = await bookAndDispatch();
  await expect(accept(id)).rejects.toMatchObject({ code: 'failed-precondition', message: expect.stringContaining('Configurez vos versements') });
  expect(provider.createdPaymentParams).toHaveLength(0);
  expect((await db.doc('delivery_requests/' + id).get()).data()!.driver_id ?? null).toBeNull();

  // Setup redone at Stripe in live, finished (synced by the Connect webhook).
  await driverDoc().set({ stripe_connected_account_id: 'acct_live_new', stripe_connected_account_environment: 'live',
    stripe_charges_enabled: true, stripe_payouts_enabled: true }, { merge: true });
  const accepted = await accept(id);
  expect(accepted.success).toBe(true);
  expect(provider.createdPaymentParams).toHaveLength(1);
  expect(provider.createdPaymentParams[0].connectedAccountId).toBe('acct_live_new');
  const payment = (await db.doc('payments/' + (await db.doc('delivery_requests/' + id).get()).data()!.active_payment_id).get()).data()!;
  expect(payment).toMatchObject({ status: 'authorized', stripe_environment: 'live', connected_account_id: 'acct_live_new' });
});
