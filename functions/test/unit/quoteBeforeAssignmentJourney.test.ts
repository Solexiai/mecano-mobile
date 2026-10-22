jest.mock('../../src/lib/pushNotifications', () => ({ sendDeliveryOfferPush: jest.fn() }));
// Real callable chain; in-memory Firestore/route/storage/flags. NO production requests.
jest.mock('../../src/lib/admin', () => {
  const { Timestamp } = jest.requireActual('firebase-admin/firestore');
  return { admin: { firestore: { Timestamp } }, db: { collection: jest.fn(), doc: jest.fn(), runTransaction: jest.fn() } };
});
jest.mock('../../src/lib/bookingPhotoValidation', () => ({ validateBookingPhotos: jest.fn(async () => {}) }));
jest.mock('../../src/lib/serviceZones', () => ({ getServiceZonesConfig: jest.fn(async () => ({ enabled: true, zones: [{}] })), isWithinServiceZones: jest.fn(() => true) }));
jest.mock('../../src/lib/routingRateLimit', () => ({ consumeRoutingBudget: jest.fn(async () => {}) }));
jest.mock('../../src/functions/calculateRoute', () => ({ calculateAuthoritativeRoute: jest.fn(async () => ({ distanceKm: 12, estimatedDurationMinutes: 25, isApproximate: false })), setRouteFetcherForTesting: jest.fn() }));
jest.mock('../../src/lib/taxEngine', () => ({ ...jest.requireActual('../../src/lib/taxEngine'), resolveAndFreezeTaxSnapshot: jest.fn(async () => null) }));
jest.mock('../../src/lib/runtimeFlags', () => ({ ...jest.requireActual('../../src/lib/runtimeFlags'), isRuntimeFlagEnabled: jest.fn(async () => false) }));
jest.mock('../../src/payment/paymentOrchestration', () => ({ createAndAuthorizeMissionPayment: jest.fn(async () => { throw new Error('PAYMENT_MUST_NOT_RUN'); }) }));
jest.mock('../../src/lib/audit', () => ({ writeAuditLogInTransaction: jest.fn() }));
import { db } from '../../src/lib/admin';
import { calculateDeliveryQuote } from '../../src/functions/calculateDeliveryQuote';
import { createDeliveryRequest } from '../../src/functions/createDeliveryRequest';
import { adminAssignDelivery } from '../../src/functions/adminAssignDelivery';
import { acceptDelivery } from '../../src/functions/acceptDelivery';
import { getBookingQuote, getBookingConfiguration } from '../../src/functions/bookingJourney';
import { onMissionCreatedDispatch, onMissionReopenedDispatch } from '../../src/functions/dispatchMissionToDrivers';
import { sendDeliveryOfferPush } from '../../src/lib/pushNotifications';
import { isRuntimeFlagEnabled } from '../../src/lib/runtimeFlags';
import { createAndAuthorizeMissionPayment } from '../../src/payment/paymentOrchestration';
import { resolveLockedQuote } from '../../src/lib/quoteIntegrity';
import { buildPricingConfig } from './fixtures';

const uid = 'synthetic-price-customer';
const driverId = 'synthetic-driver';
const auth = (role = 'customer', user = uid) => ({ uid: user, token: { role, email_verified: true } });
const stops = [
  { type: 'pickup', address: { line1: 'Synthetic pickup', city: 'Granby', postal_code: 'J2G1A1', lat: 45.4, lng: -72.7 } },
  { type: 'dropoff', address: { line1: 'Synthetic dropoff', city: 'Granby', postal_code: 'J2G1A2', lat: 45.41, lng: -72.71 } },
];
const contacts = { pickup_name: 'Synthetic customer', pickup_phone: '+15145550100', dropoff_name: 'Synthetic recipient', dropoff_phone: '+15145550101', instructions: 'SIMULATION ONLY' };
function load() { return { draft_id: 'price-before-driver-test', intake_mode: 'photo_assisted', timing_mode: 'immediate', requested_at: null,
  items: [{ id: 'test-sofa', category: 'sofa', label: 'Synthetic sofa', quantity: 1, length: null, width: null, height: null, weight: null,
    dimension_unit: 'cm', weight_unit: 'kg', approximate: false, upright: true, identification_confirmed: true, special_handling: false,
    photos: [`booking_photos/${uid}/price-before-driver-test/test-sofa/0.jpg`] }],
  pickup: { floor: 0, stairs: false, elevator: false, help: false }, dropoff: { floor: 0, stairs: false, elevator: false, help: false }, handlers: 1, equipment: [] }; }
let store: Map<string, any>, reads: string[], writes: string[], serial: number;
function ref(path: string): any {
  return { path, id: path.split('/').pop(),
    get: async () => { reads.push(path); return { exists: store.has(path), id: path.split('/').pop(), data: () => store.get(path) }; },
    set: async (value: any, options?: any) => { writes.push(path); store.set(path, options?.merge ? { ...store.get(path), ...value } : value); },
    collection: (name: string) => collection(path + '/' + name),
  };
}
function collection(name: string): any { return { doc: (id?: string) => ref(name + '/' + (id ?? 'generated-' + ++serial)) }; }
beforeEach(() => {
  jest.clearAllMocks(); store = new Map(); reads = []; writes = []; serial = 0;
  (isRuntimeFlagEnabled as jest.Mock).mockResolvedValue(false);
  const config = buildPricingConfig();
  config.vehicle_rules = ['pickupTruck','cargoVan','cubeTruck'].map(category => ({ ...config.vehicle_rules[0], category }));
  store.set('pricing_configs/active', { active_pricing_version: config.pricing_version });
  store.set('pricing_versions/' + config.pricing_version, config);
  (db.doc as jest.Mock).mockImplementation(ref); (db.collection as jest.Mock).mockImplementation(collection);
  (db.runTransaction as jest.Mock).mockImplementation(async (callback: any) => {
    const commit: (() => void)[] = [];
    const tx = { get: (r: any) => r.get(),
      set: (r: any, value: any, options?: any) => commit.push(() => { writes.push(r.path); store.set(r.path, options?.merge ? { ...store.get(r.path), ...value } : value); }),
      update: (r: any, patch: any) => commit.push(() => { writes.push(r.path); store.set(r.path, { ...store.get(r.path), ...patch }); }),
      create: (r: any, value: any) => commit.push(() => { if (store.has(r.path)) throw new Error('ALREADY_EXISTS'); writes.push(r.path); store.set(r.path, value); }),
    };
    const result = await callback(tx); commit.forEach(apply => apply()); return result;
  });
});
async function quote() { return calculateDeliveryQuote.run({ auth: auth(), data: { quotePurpose: 'price_before_assignment', booking: load(), stops } } as any); }
function createRequest(q: any, role = 'super_admin') { return { auth: auth(role), data: { quoteId: q.quoteId, booking: load(), contacts, stops,
  requiredVehicleCategory: q.vehicleCategory, description: '', itemCategoryKey: '', customerDisplayName: '' } }; }
function addDriver() { store.set('driver_profiles/' + driverId, { status: 'approved', documents_all_valid: true, full_name: 'Synthetic driver',
  accepted_vehicle_categories: ['cargo_van'], online_status: 'offline' }); }

test('customer obtains and restores exact server price before any driver exists', async () => {
  const q = await quote();
  expect(reads.some(p => /driver|booking_capacity|booking_policy/.test(p))).toBe(false);
  expect(writes).toEqual(['delivery_quotes/' + q.quoteId]);
  const restored = await getBookingQuote.run({ auth: auth(), data: { quoteId: q.quoteId } } as any);
  expect(restored).toMatchObject({ customerTotal: 45.5, booking: null, assignmentPending: true, missionId: null });
  expect(createAndAuthorizeMissionPayment).not.toHaveBeenCalled();
});
test('quote cannot be restored by another customer', async () => {
  const q = await quote();
  await expect(getBookingQuote.run({ auth: auth('customer','other'), data: { quoteId: q.quoteId } } as any)).rejects.toMatchObject({ code: 'permission-denied' });
});
test('authorized internal request and manual admin assignment preserve exact quoted amount with no payment', async () => {
  const q = await quote();
  const created = await createDeliveryRequest.run(createRequest(q) as any);
  const path = 'delivery_requests/' + created.missionId;
  expect(created.internalTest).toBe(true);
  expect(store.get(path)).toMatchObject({ driver_id: null, customer_total_minor: 4550,
    internal_test_authorized: true, assignment_mode: 'internal_test' });
  expect(store.get(path).active_payment_id).toBeUndefined();
  expect(store.get(path + '/private/booking').contacts).toEqual(contacts);
  expect(store.get('booking_photo_grants/' + uid + '_price-before-driver-test').mission_id).toBe(created.missionId);
  const retried = await createDeliveryRequest.run(createRequest(q) as any);
  expect(retried.missionId).toBe(created.missionId);
  addDriver();
  const assigned = await adminAssignDelivery.run({ auth: auth('super_admin','synthetic-admin'), data: { missionId: created.missionId, driverId, assignmentMode: 'internal_test' } } as any);
  expect(assigned).toMatchObject({ success: true, paymentSkipped: true, internalTest: true });
  expect(store.get(path)).toMatchObject({ driver_id: driverId, status: 'assigned', required_vehicle_category: 'cargo_van', customer_total_minor: 4550, active_financial_snapshot_id: null });
  expect(resolveLockedQuote(q.quoteId, store.get('delivery_quotes/' + q.quoteId)).customerTotalMinor).toBe(4550);
  expect(writes.some(p => p.startsWith('payments/') || p.startsWith('financial_snapshots/'))).toBe(false);
  expect(createAndAuthorizeMissionPayment).not.toHaveBeenCalled();
});
// Since 2026-10-22 an ordinary customer CAN book a price-first request, but only
// with published booking terms accepted (see integration/priceFirstDriverJudgement).
test('ordinary customer cannot book a price-first request without published, accepted terms', async () => {
  const q = await quote();
  (isRuntimeFlagEnabled as jest.Mock).mockResolvedValue(true);
  store.set('payment_profiles/' + uid, { default_payment_method_id: 'SYNTHETIC_PM' });
  const before = [...writes];
  await expect(createDeliveryRequest.run(createRequest(q,'customer') as any)).rejects.toMatchObject({ code: 'failed-precondition' });
  expect(writes).toEqual(before); expect(createAndAuthorizeMissionPayment).not.toHaveBeenCalled();
});
test('modified load cannot consume the frozen quote even in an authorized internal test', async () => {
  const q = await quote(); const r = createRequest(q); r.data.booking.items[0].quantity = 2;
  await expect(createDeliveryRequest.run(r as any)).rejects.toMatchObject({ code: 'failed-precondition' });
  expect(store.get('delivery_quotes/' + q.quoteId).is_consumed).toBe(false);
});
test('pending internal mission cannot be silently converted to paid standard assignment', async () => {
  const q = await quote(); const created = await createDeliveryRequest.run(createRequest(q) as any); addDriver();
  (isRuntimeFlagEnabled as jest.Mock).mockResolvedValue(true);
  await expect(adminAssignDelivery.run({ auth: auth('super_admin'), data: { missionId: created.missionId, driverId, assignmentMode: 'standard' } } as any)).rejects.toMatchObject({ code: 'failed-precondition' });
  expect(store.get('delivery_requests/' + created.missionId).driver_id).toBeNull();
  expect(createAndAuthorizeMissionPayment).not.toHaveBeenCalled();
});
test('driver cannot commercialize a price-only mission with a false internal authorization marker', async () => {
  const q = await quote(); const created = await createDeliveryRequest.run(createRequest(q) as any); addDriver();
  store.get('delivery_requests/' + created.missionId).internal_test_authorized = false;
  (isRuntimeFlagEnabled as jest.Mock).mockResolvedValue(true);
  await expect(acceptDelivery.run({ auth: auth('driver', driverId), data: { missionId: created.missionId } } as any)).rejects.toMatchObject({ code: 'failed-precondition' });
  expect(createAndAuthorizeMissionPayment).not.toHaveBeenCalled();
});
test('internal test button capability is returned only for existing server-authorized roles', async () => {
  const guest = await getBookingConfiguration.run({ data: {} } as any);
  const customer = await getBookingConfiguration.run({ auth: auth(), data: {} } as any);
  const admin = await getBookingConfiguration.run({ auth: auth('super_admin'), data: {} } as any);
  expect(guest.internal_test_request).toBe(false); expect(customer.internal_test_request).toBe(false); expect(admin.internal_test_request).toBe(true);
});

test('price-first internal requests never broadcast automatic offers on creation or reopening', async () => {
  const q = await quote(); const created = await createDeliveryRequest.run(createRequest(q) as any);
  const mission = store.get('delivery_requests/' + created.missionId);
  const priorWrites = [...writes], priorReads = [...reads];
  await onMissionCreatedDispatch.run({ params: { missionId: created.missionId }, data: { data: () => mission } } as any);
  await onMissionReopenedDispatch.run({ params: { missionId: created.missionId }, data: {
    before: { data: () => ({ ...mission, status: 'offered' }) }, after: { data: () => mission },
  } } as any);
  expect(writes).toEqual(priorWrites); expect(reads).toEqual(priorReads);
  expect(sendDeliveryOfferPush).not.toHaveBeenCalled();
  expect(createAndAuthorizeMissionPayment).not.toHaveBeenCalled();
});
