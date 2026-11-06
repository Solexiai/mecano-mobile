// ---------------------------------------------------------------------------
// Dépôt de réservation (décision Daniel, 2026-11-06) — lib/bookingDeposit.ts.
//
// 25 $ débités à la confirmation, avant la création de la mission ; déduits
// du prix ; remboursés automatiquement (annulation > 48 h, aucun chauffeur) ;
// gardés sur annulation tardive du client avec chauffeur accepté.
// ---------------------------------------------------------------------------
import type { CallableRequest } from 'firebase-functions/v2/https';
import { testBookingPolicy, testBookingConsent } from '../testUtils/bookingPolicyFixture';
import { setPaymentProviderForTesting } from '../../src/payment/paymentProviderFactory';
import { FakePaymentProvider, buildFakePaymentProfile } from '../testUtils/fakePaymentProvider';
import { admin, db } from '../../src/lib/admin';
import { normalizeLoad } from '../../src/lib/booking';
import { createDeliveryRequest } from '../../src/functions/createDeliveryRequest';
import { cancelDeliveryRequest } from '../../src/functions/cancelDeliveryRequest';
import { buildQuoteIntegrityEnvelope, computeQuoteIntegrityHash } from '../../src/lib/quoteIntegrity';
import { seedLockedQuote } from '../testUtils/officialQuoteFixture';
import { buildPricingConfig } from '../unit/fixtures';
import { seedDefaultRuntimeFlagsEnabled } from '../testUtils/runtimeFlagsFixture';
import { TEST_SCHEDULED_PICKUP } from '../testUtils/bookingTimeFixture';
import {
  BOOKING_DEPOSIT_POLICY, customerCancellationKeepsDeposit, depositPaymentId, refundBookingDeposit,
} from '../../src/lib/bookingDeposit';

const uid = 'deposit_customer_test';
const id = 'deposit_quote_test';
const request = (data: unknown, user = uid) => ({
  data, auth: { uid: user, token: { email: 'test@example.invalid', email_verified: true, roles: ['customer'] } },
  rawRequest: {}, acceptsStreaming: false,
} as unknown as CallableRequest<any>);
const access = { floor: 0, stairs: false, elevator: false, help: true };
const load = { draft_id: 'deposit-test', items: [{ id: 'box', category: 'boxes', label: 'Test box', quantity: 1, length: 50, width: 50, height: 50, weight: 10, dimension_unit: 'cm', weight_unit: 'kg', upright: true, approximate: false, photos: [] }], pickup: access, dropoff: access, handlers: 1, equipment: [], requested_at: TEST_SCHEDULED_PICKUP };
const capacity = { category: 'cargo_van', rank: 1, version: 'TEST-ONLY', verified: true, length_cm: 200, width_cm: 120, height_cm: 120, opening_width_cm: 100, opening_height_cm: 100, payload_kg: 200, handlers: 2, equipment: [], services: ['handling', 'stairs'] };
const snapshot = { load: normalizeLoad(load), rules_version: 'TEST-ONLY', category: 'cargo_van', capacity_version: 'TEST-ONLY' };
const stops = [{ type: 'pickup', address: { line1: 'Test pickup', city: 'Test city', postal_code: 'T0T0T0', lat: 45.5, lng: -73.6 } }, { type: 'dropoff', address: { line1: 'Test dropoff', city: 'Test city', postal_code: 'T0T0T0', lat: 45.6, lng: -73.7 } }];
const contacts = { pickup_name: 'Test pickup', pickup_phone: '+15145550100', dropoff_name: 'Test recipient', dropoff_phone: '+15145550101', instructions: '' };
const input = { quoteId: id, booking: load, contacts, consent: testBookingConsent('TEST-ONLY'), requiredVehicleCategory: 'cargo_van', stops, itemCategoryKey: 'forged', description: 'forged', customerDisplayName: 'Test' };

let provider: FakePaymentProvider;

async function seedQuote(quoteId = id): Promise<void> {
  const pricing = buildPricingConfig();
  await db.doc(`pricing_versions/${pricing.pricing_version}`).set(pricing);
  await seedLockedQuote({ quoteId, customerId: uid, pricingConfig: pricing, stops, vehicleCategory: 'cargoVan', distanceKm: 10, estimatedDurationMinutes: 20 });
  const quote = (await db.doc(`delivery_quotes/${quoteId}`).get()).data()!;
  quote.pricing_snapshot.booking = snapshot;
  quote.integrity_hash = computeQuoteIntegrityHash(buildQuoteIntegrityEnvelope({ quoteId, customerId: uid, createdAtMillis: quote.created_at.toMillis(), expiresAtMillis: quote.expires_at.toMillis(), stops, pricingSnapshot: quote.pricing_snapshot }));
  await db.doc(`delivery_quotes/${quoteId}`).set(quote);
}

beforeEach(async () => {
  provider = new FakePaymentProvider();
  setPaymentProviderForTesting(provider);
  await seedDefaultRuntimeFlagsEnabled();
  await db.doc('system_config/booking_policy').set(testBookingPolicy('TEST-ONLY'));
  await db.doc('system_config/booking_capacity').set({ approved: true, version: 'TEST-ONLY', capacities: [capacity], heavy_item_kg: 50, bulky_item_cm: 150, require_booking_details: true });
  await db.doc('system_config/service_zones').set({ enabled: true, zones: [{ name: 'TEST ONLY', min_lat: 45, max_lat: 46, min_lng: -74, max_lng: -73 }] });
  await db.doc(`payment_profiles/${uid}`).set(buildFakePaymentProfile(uid));
  await seedQuote();
});

afterEach(async () => {
  setPaymentProviderForTesting(null);
  for (const path of ['system_config/booking_policy', 'system_config/booking_capacity', 'system_config/service_zones', `payment_profiles/${uid}`, `booking_attempts/${uid}_deposit-test`, `delivery_quotes/${id}`, `payments/${depositPaymentId(id)}`, `users/${uid}`]) await db.doc(path).delete();
  const missions = await db.collection('delivery_requests').where('customer_id', '==', uid).get();
  for (const m of missions.docs) await db.recursiveDelete(m.ref);
  const ledger = await db.collection('transaction_ledger').where('transaction_id', '==', depositPaymentId(id)).get();
  for (const r of ledger.docs) await r.ref.delete();
  const refunds = await db.collection('refunds').where('payment_id', '==', depositPaymentId(id)).get();
  for (const r of refunds.docs) await r.ref.delete();
});

test('la confirmation débite 25 $ une seule fois, avant la mission, et l’inscrit au registre', async () => {
  const first = await createDeliveryRequest.run(request(input));
  const second = await createDeliveryRequest.run(request(input));
  expect(second.missionId).toBe(first.missionId);
  expect(provider.chargedSavedMethodParams).toHaveLength(1);
  expect(provider.chargedSavedMethodParams[0]).toMatchObject({ amountMinor: 2500, connectedAccountId: null, applicationFeeMinor: 0 });

  const mission = (await db.doc(`delivery_requests/${first.missionId}`).get()).data()!;
  expect(mission.deposit).toMatchObject({ status: 'captured', amount_minor: 2500, payment_id: depositPaymentId(id), policy_version: BOOKING_DEPOSIT_POLICY.version });
  const payment = (await db.doc(`payments/${depositPaymentId(id)}`).get()).data()!;
  expect(payment).toMatchObject({ purpose: 'deposit', status: 'captured', amount_captured_minor: 2500, mission_id: first.missionId, customer_id: uid });
  const ledger = await db.collection('transaction_ledger').where('transaction_id', '==', depositPaymentId(id)).get();
  expect(ledger.size).toBe(1);
  expect(ledger.docs[0].data()).toMatchObject({ type: 'customer_charge', purpose: 'deposit', amount_minor: 2500, mission_id: first.missionId, party: 'customer', direction: 'debit' });
});

test('dépôt refusé : aucune mission ; un nouvel essai avec une carte acceptée réserve', async () => {
  provider = new FakePaymentProvider({ chargeFailuresBeforeSuccess: 1 });
  setPaymentProviderForTesting(provider);
  await expect(createDeliveryRequest.run(request(input))).rejects.toMatchObject({ code: 'failed-precondition' });
  expect((await db.collection('delivery_requests').where('customer_id', '==', uid).get()).empty).toBe(true);
  expect((await db.doc(`payments/${depositPaymentId(id)}`).get()).data()).toMatchObject({ status: 'capture_failed', capture_attempt_count: 1 });

  const created = await createDeliveryRequest.run(request(input));
  expect(provider.chargedSavedMethodParams).toHaveLength(2);
  expect(provider.chargedSavedMethodParams[1].idempotencyKey).not.toBe(provider.chargedSavedMethodParams[0].idempotencyKey);
  expect((await db.doc(`payments/${depositPaymentId(id)}`).get()).data()).toMatchObject({ status: 'captured', capture_attempt_count: 2, mission_id: created.missionId });
});

test('annulation sans chauffeur : dépôt remboursé automatiquement, aucuns frais', async () => {
  const { missionId } = await createDeliveryRequest.run(request(input));
  const preview = await cancelDeliveryRequest.run(request({ missionId, dryRun: true }));
  expect(preview).toMatchObject({ feeMinor: 0, depositMinor: 2500, depositKept: false, depositRefundMinor: 2500 });
  const cancelled = await cancelDeliveryRequest.run(request({ missionId }));
  expect(cancelled).toMatchObject({ cancelled: true, depositKept: false });
  expect((await db.doc(`delivery_requests/${missionId}`).get()).data()!.deposit.status).toBe('captured');

  // Le trigger onMissionEndedClearTracking appelle refundBookingDeposit.
  expect(await refundBookingDeposit(missionId, { reason: 'customer_request', actorUserId: 'system', actorRole: 'system' })).toBe('refunded');
  expect(await refundBookingDeposit(missionId, { reason: 'customer_request', actorUserId: 'system', actorRole: 'system' })).toBe('already_done');
  const mission = (await db.doc(`delivery_requests/${missionId}`).get()).data()!;
  expect(mission.deposit).toMatchObject({ status: 'refunded', refund_reason: 'customer_request' });
  expect(mission.deposit.refund_id).toBeTruthy();
  const refund = (await db.doc(`refunds/${mission.deposit.refund_id}`).get()).data()!;
  expect(refund).toMatchObject({ payment_id: depositPaymentId(id), amount_minor: 2500, status: 'succeeded' });
});

test('annulation tardive avec chauffeur accepté : dépôt gardé, pas de frais sur le blocage', async () => {
  const { missionId } = await createDeliveryRequest.run(request(input));
  const inOneHour = new Date(Date.now() + 60 * 60 * 1000).toISOString();
  await db.doc(`delivery_requests/${missionId}`).update({
    driver_id: 'driver_test', status: 'assigned', 'booking_snapshot.load.requested_at': inOneHour,
  });
  const preview = await cancelDeliveryRequest.run(request({ missionId, dryRun: true }));
  expect(preview).toMatchObject({ feeMinor: 0, depositMinor: 2500, depositKept: true, depositRefundMinor: 0 });
  await cancelDeliveryRequest.run(request({ missionId }));
  const mission = (await db.doc(`delivery_requests/${missionId}`).get()).data()!;
  expect(mission.status).toBe('cancelled');
  expect(mission.cancellation_fee).toBeNull();
  expect(mission.deposit).toMatchObject({ status: 'kept', kept_reason: 'customer_late_cancellation' });
  // Gardé : jamais remboursé ensuite.
  expect(await refundBookingDeposit(missionId, { reason: 'customer_request', actorUserId: 'system', actorRole: 'system' })).toBe('already_done');
});

test('règle des 48 h', () => {
  const now = Date.parse('2026-11-10T12:00:00Z');
  const base = { driver_id: 'd', status: 'assigned', booking_snapshot: { load: { requested_at: '2026-11-13T12:00:00Z' } } };
  expect(customerCancellationKeepsDeposit(base, now)).toBe(false); // 72 h
  expect(customerCancellationKeepsDeposit({ ...base, booking_snapshot: { load: { requested_at: '2026-11-12T11:00:00Z' } } }, now)).toBe(true); // 47 h
  expect(customerCancellationKeepsDeposit({ ...base, driver_id: null }, now)).toBe(false);
  expect(customerCancellationKeepsDeposit({ ...base, status: 'searching_driver' }, now)).toBe(false);
  expect(customerCancellationKeepsDeposit({ ...base, booking_snapshot: undefined }, now)).toBe(true); // dès que possible
  expect(customerCancellationKeepsDeposit({ ...base, status: 'driver_to_pickup', booking_snapshot: { load: { requested_at: '2026-11-20T12:00:00Z' } } }, now)).toBe(true);
  expect(customerCancellationKeepsDeposit({ ...base, assignment_mode: 'internal_test' }, now)).toBe(false);
});

test('les missions de test interne n’ont pas de dépôt', async () => {
  const created = await createDeliveryRequest.run({
    ...request(input), auth: { uid, token: { email: 'test@example.invalid', email_verified: true, roles: ['super_admin'], internal_tester: true } },
  } as unknown as CallableRequest<any>);
  expect(created.internalTest).toBe(true);
  expect(provider.chargedSavedMethodParams).toHaveLength(0);
  expect((await db.doc(`delivery_requests/${created.missionId}`).get()).data()!.deposit).toBeNull();
  await admin.firestore().doc(`payments/${depositPaymentId(id)}`).delete().catch(() => undefined);
});
