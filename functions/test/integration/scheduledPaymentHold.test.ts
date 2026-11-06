// ---------------------------------------------------------------------------
// Réservation lointaine (décision Daniel, 2026-11-06) : jusqu'à 30 jours, le
// blocage du solde est posé 4 jours avant le ramassage par la tâche
// planifiée (lib/scheduledPaymentHold.ts), pas à l'acceptation.
// ---------------------------------------------------------------------------
import { testBookingPolicy, testBookingConsent } from '../testUtils/bookingPolicyFixture';
jest.mock('../../src/lib/pushNotifications', () => ({
  sendDeliveryOfferPush: jest.fn(async () => ({ attempted: 0, sent: 0 })),
  sendCustomerMissionStatusPush: jest.fn(async () => ({ attempted: 0, sent: 0 })),
}));
import { admin, db } from '../../src/lib/admin';
import { calculateDeliveryQuote } from '../../src/functions/calculateDeliveryQuote';
import { createDeliveryRequest } from '../../src/functions/createDeliveryRequest';
import { onMissionCreatedDispatch } from '../../src/functions/dispatchMissionToDrivers';
import { acceptDelivery } from '../../src/functions/acceptDelivery';
import { placeScheduledHold, processScheduledPaymentHolds, SCHEDULED_HOLD_POLICY } from '../../src/lib/scheduledPaymentHold';
import { cardHoldMinor } from '../../src/lib/missionFees';
import { BOOKING_DEPOSIT_POLICY } from '../../src/lib/bookingDeposit';
import { encodeGeohash } from '../../src/lib/geohash';
import { buildPricingConfig } from '../unit/fixtures';
import { seedDefaultRuntimeFlagsEnabled } from '../testUtils/runtimeFlagsFixture';
import { FakePaymentProvider, buildFakePaymentProfile } from '../testUtils/fakePaymentProvider';
import { setPaymentProviderForTesting } from '../../src/payment/paymentProviderFactory';

const customer = 'hold_customer', driver = 'hold_driver', vehicle = 'hold_vehicle';
const draftId = 'hold-draft';
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
const load = (requestedAt: string): any => ({
  draft_id: draftId, intake_mode: 'photo_assisted', timing_mode: 'scheduled', requested_at: requestedAt,
  pickup: access, dropoff: access, handlers: 1, equipment: [],
  items: [{ id: 'item', category: 'sofa', label: 'Synthetic sofa', quantity: 1, length: null, width: null, height: null, weight: null,
    dimension_unit: 'cm', weight_unit: 'kg', approximate: false, upright: true, photos: [photo],
    identification_confirmed: true, special_handling: false }],
});
const missionRef = (id: string) => db.doc('delivery_requests/' + id);
const DAY = 24 * 60 * 60 * 1000;

/** Un ramassage dans ~10 jours, à une heure ouverte à Granby (13 h locale). */
function pickupInTenDays(): string {
  const base = new Date(Date.now() + 10 * DAY);
  base.setUTCMinutes(0, 0, 0);
  for (let i = 0; i < 48; i += 1) {
    const candidate = new Date(base.getTime() + i * 60 * 60 * 1000);
    const hour = Number(new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Toronto', hour: '2-digit', hourCycle: 'h23' })
      .formatToParts(candidate).find(p => p.type === 'hour')?.value);
    if (hour === 13) return candidate.toISOString();
  }
  throw new Error('no 13:00 slot found');
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
  const pricing = buildPricingConfig({ pricing_version: 'HOLD-TEST' });
  pricing.vehicle_rules = ['pickup_truck', 'cargo_van', 'cube_truck'].map(category => ({ ...pricing.vehicle_rules[0], category }));
  pricing.handling_fees = { ...pricing.handling_fees, bulky_item_fee: 0 };
  await db.doc('pricing_configs/active').set({ active_pricing_version: pricing.pricing_version });
  await db.doc('pricing_versions/HOLD-TEST').set(pricing);
  await db.doc('system_config/booking_policy').set(testBookingPolicy('HOLD-TEST'));
  // « Où et quand ? » : 30 jours à l'avance, 13 h offert, tous les jours.
  await db.doc('system_config/booking_hours').set({ slot_hours: [9, 11, 13, 15, 17, 19], lead_minutes: 60, days_ahead: 30, open_weekdays: [1, 2, 3, 4, 5, 6, 7] });
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
    'mission_outcome_reviews', 'refunds']) await db.recursiveDelete(db.collection(collection));
});

async function bookAndAccept(requestedAt: string): Promise<string> {
  const quote = await calculateDeliveryQuote.run(asCustomer({ quotePurpose: 'price_before_assignment', booking: load(requestedAt), stops }));
  const created = await createDeliveryRequest.run(asCustomer({ quoteId: quote.quoteId, booking: load(requestedAt), stops, contacts,
    consent: testBookingConsent('HOLD-TEST'), description: '', itemCategoryKey: '', requiredVehicleCategory: quote.vehicleCategory,
    customerDisplayName: 'Synthetic' }));
  const id = created.missionId as string;
  const mission = (await missionRef(id).get()).data()!;
  await onMissionCreatedDispatch.run({ data: { data: () => mission }, params: { missionId: id } } as any);
  const accepted = await acceptDelivery.run(call({ missionId: id, vehicleId: vehicle, fitConfirmed: true }, driver, ['driver']));
  expect(accepted.success).toBe(true);
  return id;
}

test('réservation à 10 jours : acceptée sans blocage, blocage posé à J-4 sur le solde', async () => {
  const pickup = pickupInTenDays();
  const id = await bookAndAccept(pickup);
  const mission = (await missionRef(id).get()).data()!;
  expect(mission.status).toBe('assigned');
  expect(mission.payment_status).toBe('hold_scheduled');
  expect(mission.active_payment_id ?? null).toBeNull();
  expect(mission.scheduled_hold).toMatchObject({ status: 'scheduled', attempts: 0 });
  expect(mission.scheduled_hold.due_at.toMillis()).toBe(Date.parse(pickup) - SCHEDULED_HOLD_POLICY.lead_ms);
  expect(provider.createdPaymentParams).toHaveLength(0);
  expect(mission.deposit).toMatchObject({ status: 'captured', amount_minor: 2500 });

  // Trop tôt : rien ne se passe.
  expect((await processScheduledPaymentHolds(Date.now())).examined).toBe(0);

  // À l'échéance : blocage posé sur le solde (prix − dépôt).
  const due = mission.scheduled_hold.due_at.toMillis() + 60 * 1000;
  const batch = await processScheduledPaymentHolds(due);
  expect(batch).toMatchObject({ examined: 1, placed: 1 });
  const after = (await missionRef(id).get()).data()!;
  expect(after.payment_status).toBe('authorized');
  expect(after.scheduled_hold).toMatchObject({ status: 'placed', attempts: 1, next_attempt_at: null });
  expect(after.scheduled_hold.placed_payment_id).toBe(after.active_payment_id);
  expect(provider.createdPaymentParams).toHaveLength(1);
  expect(provider.createdPaymentParams[0].amountMinor).toBe(cardHoldMinor(after.customer_total_minor - BOOKING_DEPOSIT_POLICY.amount_minor));

  // Idempotent : une deuxième passe ne crée rien.
  expect(await placeScheduledHold(id, due)).toBe('skipped');
  expect(provider.createdPaymentParams).toHaveLength(1);
});

test('carte refusée à J-4 : relance le lendemain, annulation la veille avec dépôt gardé et chauffeur averti', async () => {
  const pickup = pickupInTenDays();
  const id = await bookAndAccept(pickup);
  const due = Date.parse(pickup) - SCHEDULED_HOLD_POLICY.lead_ms + 60 * 1000;

  setPaymentProviderForTesting(new FakePaymentProvider({ forceAuthorizeFailure: true, failureCode: 'card_declined' }));
  expect(await placeScheduledHold(id, due)).toBe('retry_scheduled');
  let mission = (await missionRef(id).get()).data()!;
  expect(mission.status).toBe('assigned');
  expect(mission.driver_id).toBe(driver);
  expect(mission.scheduled_hold).toMatchObject({ status: 'failed', attempts: 1, last_failure_code: 'failed' });
  expect(mission.scheduled_hold.next_attempt_at.toMillis()).toBe(due + SCHEDULED_HOLD_POLICY.retry_ms);

  // Le lendemain, encore refusée.
  expect(await placeScheduledHold(id, due + DAY)).toBe('retry_scheduled');
  mission = (await missionRef(id).get()).data()!;
  expect(mission.scheduled_hold.attempts).toBe(2);

  // La veille : annulation, dépôt gardé, chauffeur averti.
  expect(await placeScheduledHold(id, Date.parse(pickup) - 12 * 60 * 60 * 1000)).toBe('cancelled');
  mission = (await missionRef(id).get()).data()!;
  expect(mission).toMatchObject({ status: 'cancelled', cancelled_by: 'system', cancellation_reason: 'payment_hold_failed',
    cancellation_fee: null, deposit: { status: 'kept', kept_reason: 'payment_hold_failed' }, scheduled_hold: { status: 'cancelled', attempts: 3 } });
  const driverNotifs = await db.collection('users').doc(driver).collection('notifications').where('related_mission_id', '==', id).get();
  expect(driverNotifs.docs.map(d => d.data().type)).toContain('mission_cancelled_payment');
});

test('carte corrigée après un refus : le blocage passe à la relance suivante', async () => {
  const pickup = pickupInTenDays();
  const id = await bookAndAccept(pickup);
  const due = Date.parse(pickup) - SCHEDULED_HOLD_POLICY.lead_ms + 60 * 1000;
  setPaymentProviderForTesting(new FakePaymentProvider({ forceAuthorizeFailure: true }));
  expect(await placeScheduledHold(id, due)).toBe('retry_scheduled');
  setPaymentProviderForTesting(provider);
  expect((await processScheduledPaymentHolds(due + DAY))).toMatchObject({ examined: 1, placed: 1 });
  const mission = (await missionRef(id).get()).data()!;
  expect(mission.payment_status).toBe('authorized');
  expect(mission.scheduled_hold).toMatchObject({ status: 'placed', attempts: 2 });
});

test('réservation à 2-3 jours : blocage immédiat comme avant', async () => {
  const soon = new Date(Date.now() + 2 * DAY);
  soon.setUTCMinutes(0, 0, 0);
  // Même recherche d'une heure ouverte, entre 2 et 3 jours (sous les 4 jours).
  let requested = soon.toISOString();
  for (let i = 0; i < 24; i += 1) {
    const candidate = new Date(soon.getTime() + i * 60 * 60 * 1000);
    const hour = Number(new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Toronto', hour: '2-digit', hourCycle: 'h23' })
      .formatToParts(candidate).find(p => p.type === 'hour')?.value);
    if (hour === 13) { requested = candidate.toISOString(); break; }
  }
  const id = await bookAndAccept(requested);
  const mission = (await missionRef(id).get()).data()!;
  expect(mission.payment_status).toBe('authorized');
  expect(mission.scheduled_hold ?? null).toBeNull();
  expect(provider.createdPaymentParams).toHaveLength(1);
});
