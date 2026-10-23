// Mission fees (owner decision 2026-10-22): 30 $ = 25 $ driver + 5 $ Movi-K.
// - free before a driver accepts, free after acceptance when the pickup is
//   more than 2 hours away, otherwise a late cancellation fee;
// - a travel fee when Movi-K confirms the pickup failed because of the customer.
// Collected by a partial capture of the card hold placed at acceptance.
import { testBookingPolicy, testBookingConsent } from '../testUtils/bookingPolicyFixture';
jest.mock('../../src/lib/pushNotifications', () => ({ sendDeliveryOfferPush: jest.fn(async () => ({ attempted: 0, sent: 0 })) }));
import { admin, db } from '../../src/lib/admin';
import { calculateDeliveryQuote } from '../../src/functions/calculateDeliveryQuote';
import { createDeliveryRequest } from '../../src/functions/createDeliveryRequest';
import { onMissionCreatedDispatch } from '../../src/functions/dispatchMissionToDrivers';
import { acceptDelivery } from '../../src/functions/acceptDelivery';
import { cancelDeliveryRequest } from '../../src/functions/cancelDeliveryRequest';
import { chargeWastedTripFee } from '../../src/functions/chargeWastedTripFee';
import { onMissionEndedClearTracking } from '../../src/functions/onMissionEndedClearTracking';
import { missionFeeSnapshotId } from '../../src/payment/missionFeeOrchestration';
import { captureMissionPayment } from '../../src/payment/paymentOrchestration';
import { computeMissionFinancialBalance } from '../../src/lib/missionFinancialBalance';
import { encodeGeohash } from '../../src/lib/geohash';
import { buildPricingConfig } from '../unit/fixtures';
import { seedDefaultRuntimeFlagsEnabled } from '../testUtils/runtimeFlagsFixture';
import { FakePaymentProvider, buildFakePaymentProfile } from '../testUtils/fakePaymentProvider';
import { setPaymentProviderForTesting } from '../../src/payment/paymentProviderFactory';

const customer = 'fee_customer', driver = 'fee_driver', vehicle = 'fee_vehicle', staff = 'fee_admin';
const draftId = 'fee-draft';
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
async function runCancelTrigger(missionId: string, before: Record<string, unknown>) {
  const after = (await missionRef(missionId).get()).data()!;
  await onMissionEndedClearTracking.run({
    data: { before: { data: () => before, exists: true }, after: { data: () => after, exists: true } },
    params: { missionId },
  } as any);
}

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
  const pricing = buildPricingConfig({ pricing_version: 'FEE-TEST' });
  pricing.vehicle_rules = ['pickup_truck', 'cargo_van', 'cube_truck'].map(category => ({ ...pricing.vehicle_rules[0], category }));
  pricing.handling_fees = { ...pricing.handling_fees, bulky_item_fee: 0 };
  await db.doc('pricing_configs/active').set({ active_pricing_version: pricing.pricing_version });
  await db.doc('pricing_versions/FEE-TEST').set(pricing);
  await db.doc('system_config/booking_policy').set(testBookingPolicy('FEE-TEST'));
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
    consent: testBookingConsent('FEE-TEST'), description: '', itemCategoryKey: '', requiredVehicleCategory: quote.vehicleCategory,
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

test('late cancellation (immediate delivery, driver accepted): fee shown, confirmed, then captured 30 $ = 25 $ driver + 5 $ Movi-K', async () => {
  const id = await bookAndAccept(null);
  const before = (await missionRef(id).get()).data()!;

  const preview = await cancelDeliveryRequest.run(asCustomer({ missionId: id, dryRun: true }));
  expect(preview).toMatchObject({ feeMinor: 3000, feeKind: 'late_cancellation', cancelled: false });
  expect((await missionRef(id).get()).data()!.status).toBe('assigned');

  // Never charged without the customer confirming that exact amount.
  await expect(cancelDeliveryRequest.run(asCustomer({ missionId: id })))
    .rejects.toMatchObject({ code: 'failed-precondition', details: { reason: 'fee_confirmation_required', fee_minor: 3000 } });
  await expect(cancelDeliveryRequest.run(asCustomer({ missionId: id, acceptedFeeMinor: 2000 })))
    .rejects.toMatchObject({ code: 'failed-precondition' });
  await expect(cancelDeliveryRequest.run(call({ missionId: id, acceptedFeeMinor: 3000 }, 'someone_else', ['customer'])))
    .rejects.toMatchObject({ code: 'permission-denied' });

  const done = await cancelDeliveryRequest.run(asCustomer({ missionId: id, acceptedFeeMinor: 3000 }));
  expect(done).toMatchObject({ cancelled: true, feeMinor: 3000 });
  const cancelled = (await missionRef(id).get()).data()!;
  expect(cancelled).toMatchObject({ status: 'cancelled', cancelled_by: 'customer',
    cancellation_fee: { kind: 'late_cancellation', status: 'pending', total_minor: 3000, driver_minor: 2500, platform_minor: 500 } });

  await runCancelTrigger(id, before);
  expect(provider.cancelledAuthorizationCount).toBe(0);
  expect(provider.capturedPaymentParams).toHaveLength(1);
  expect(provider.capturedPaymentParams[0]).toMatchObject({ amountToCaptureMinor: 3000, applicationFeeMinor: 500 });

  const payment = (await db.doc('payments/' + cancelled.active_payment_id).get()).data()!;
  expect(payment).toMatchObject({ status: 'captured', amount_captured_minor: 3000, application_fee_minor: 500, capture_purpose: 'mission_fee' });
  expect((await missionRef(id).get()).data()!.cancellation_fee).toMatchObject({ status: 'captured', captured_minor: 3000 });

  const feeSnapshot = (await db.doc('financial_snapshots/' + missionFeeSnapshotId(id)).get()).data()!;
  expect(feeSnapshot).toMatchObject({ snapshot_kind: 'mission_fee', status: 'confirmed', driver_id: driver,
    driver_net_mission_earnings: 25, platform_commission_amount: 5, customer_total_minor: 3000 });
  const ledger = await db.collection('transaction_ledger').where('mission_id', '==', id).get();
  expect(ledger.docs.map(d => [d.data().type, d.data().amount_minor]).sort()).toEqual(
    [['customer_charge', 3000], ['driver_earning', 2500], ['platform_commission', 500]].sort());
  const balance = await computeMissionFinancialBalance(id);
  expect(balance).toMatchObject({ customer_charged_minor: 3000, driver_earned_minor: 2500, platform_commission_minor: 500 });

  // A replayed trigger never captures twice.
  await runCancelTrigger(id, before);
  expect(provider.capturedPaymentParams).toHaveLength(1);
});

test('cancellation more than 2 hours before a scheduled pickup is free and releases the card hold', async () => {
  const id = await bookAndAccept(new Date(Date.now() + 24 * 3600000).toISOString());
  const before = (await missionRef(id).get()).data()!;
  expect(await cancelDeliveryRequest.run(asCustomer({ missionId: id, dryRun: true }))).toMatchObject({ feeMinor: 0 });
  await cancelDeliveryRequest.run(asCustomer({ missionId: id }));
  expect((await missionRef(id).get()).data()!).toMatchObject({ status: 'cancelled', cancellation_fee: null });
  await runCancelTrigger(id, before);
  expect(provider.capturedPaymentParams).toHaveLength(0);
  expect(provider.cancelledAuthorizationCount).toBe(1);
});

test('cancellation before any driver accepts is free', async () => {
  const id = await bookAndAccept(null, false);
  expect(await cancelDeliveryRequest.run(asCustomer({ missionId: id, dryRun: true }))).toMatchObject({ feeMinor: 0 });
  await cancelDeliveryRequest.run(asCustomer({ missionId: id }));
  expect((await missionRef(id).get()).data()!).toMatchObject({ status: 'cancelled', cancellation_fee: null });
  expect(provider.capturedPaymentParams).toHaveLength(0);
});

test('travel fee: only an admin, only after the failed pickup is confirmed, then captured like a late cancellation', async () => {
  const id = await bookAndAccept(new Date(Date.now() + 24 * 3600000).toISOString());
  const before = (await missionRef(id).get()).data()!;
  const input = { missionId: id, expectedStatus: 'assigned', reason: 'Client absent au ramassage' };

  await expect(chargeWastedTripFee.run(call(input, driver, ['driver']))).rejects.toMatchObject({ code: 'permission-denied' });
  await expect(chargeWastedTripFee.run(call(input, staff, ['admin']))).rejects.toMatchObject({ code: 'failed-precondition' });

  await db.doc('mission_outcome_reviews/' + id).set({ mission_id: id, confirmed: true, revision: 1 });
  await expect(chargeWastedTripFee.run(call({ ...input, expectedStatus: 'driver_to_pickup' }, staff, ['admin'])))
    .rejects.toMatchObject({ code: 'aborted' });
  expect(await chargeWastedTripFee.run(call(input, staff, ['admin']))).toMatchObject({ success: true, feeMinor: 3000 });
  expect((await missionRef(id).get()).data()!).toMatchObject({ status: 'cancelled', cancelled_by: 'admin',
    cancellation_fee: { kind: 'customer_failed_delivery', status: 'pending', total_minor: 3000 } });

  await runCancelTrigger(id, before);
  expect(provider.capturedPaymentParams[0]).toMatchObject({ amountToCaptureMinor: 3000, applicationFeeMinor: 500 });
  expect((await missionRef(id).get()).data()!.cancellation_fee.status).toBe('captured');
});

test('a refused fee capture is recorded for follow-up and never retried silently', async () => {
  const id = await bookAndAccept(null);
  const before = (await missionRef(id).get()).data()!;
  await cancelDeliveryRequest.run(asCustomer({ missionId: id, acceptedFeeMinor: 3000 }));
  setPaymentProviderForTesting(new FakePaymentProvider({ forceCaptureFailure: true }));
  await runCancelTrigger(id, before);
  const mission = (await missionRef(id).get()).data()!;
  expect(mission.cancellation_fee.status).toBe('failed');
  expect((await db.doc('payments/' + mission.active_payment_id).get()).data()!.status).toBe('failed');
  expect((await db.doc('financial_snapshots/' + missionFeeSnapshotId(id)).get()).exists).toBe(false);
});

test('owner decision 2026-10-23: a delivery under 30 $ holds 30 $, captures only its price at completion, and a late fee is still the full 30 $', async () => {
  // Cheap synthetic pricing so the delivery costs less than the 30 $ fee.
  const pricing = (await db.doc('pricing_versions/FEE-TEST').get()).data()!;
  await db.doc('pricing_versions/FEE-TEST').set({
    ...pricing,
    vehicle_rules: pricing.vehicle_rules.map((r: any) => ({ ...r, base_fare: 5, rate_per_km: 1, rate_per_minute: 0, minimum_charge: 10 })),
    handling_fees: { ...pricing.handling_fees, heavy_item_fee: 0, bulky_item_fee: 0 },
  });
  const id = await bookAndAccept(null);
  const mission = (await missionRef(id).get()).data()!;
  const priceMinor = mission.customer_total_minor as number;
  expect(priceMinor).toBeGreaterThan(0);
  expect(priceMinor).toBeLessThan(3000);
  expect(provider.createdPaymentParams.at(-1)!.amountMinor).toBe(3000);
  const paymentId = mission.active_payment_id as string;
  expect((await db.doc('payments/' + paymentId).get()).data()).toMatchObject({
    status: 'authorized', amount_requested_minor: 3000, amount_authorized_minor: 3000, service_amount_minor: priceMinor });

  // The late cancellation fee is the full 30 $ (25 $ driver + 5 $ Movi-K).
  const preview = await cancelDeliveryRequest.run(asCustomer({ missionId: id, dryRun: true }));
  expect(preview).toMatchObject({ feeMinor: 3000, feeKind: 'late_cancellation', cancelled: false });

  // A completed delivery captures only its price; Stripe releases the rest.
  const outcome = await captureMissionPayment(id, paymentId);
  expect(outcome.success).toBe(true);
  expect(provider.capturedPaymentParams.at(-1)).toMatchObject({ amountToCaptureMinor: priceMinor });
  expect((await db.doc('payments/' + paymentId).get()).data()).toMatchObject({ status: 'captured', amount_captured_minor: priceMinor });
});
