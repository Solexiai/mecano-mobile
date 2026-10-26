// LOCAL TESTS ONLY: real callable/pricing/hash code, mocked route/Firestore/Storage.
jest.mock('../../src/lib/admin', () => {
  const { Timestamp } = jest.requireActual('firebase-admin/firestore');
  return { admin: { firestore: { Timestamp } }, db: { collection: jest.fn(), doc: jest.fn() } };
});
jest.mock('../../src/lib/bookingServer', () => ({
  reviewBooking: jest.fn(async () => ({ review: { status: 'review_required', snapshot: null,
    compatible_categories: [], reasons: ['photo_policy_unconfigured','capacity_unconfigured','photo_category_unconfigured'] } })),
}));
jest.mock('../../src/lib/bookingPhotoValidation', () => ({ validateBookingPhotos: jest.fn(async () => {}) }));
jest.mock('../../src/lib/serviceZones', () => ({ getServiceZonesConfig: jest.fn(async () => ({ enabled: true, zones: [{}] })), isWithinServiceZones: jest.fn(() => true) }));
jest.mock('../../src/lib/routingRateLimit', () => ({ consumeRoutingBudget: jest.fn(async () => {}) }));
jest.mock('../../src/functions/calculateRoute', () => ({ calculateAuthoritativeRoute: jest.fn(), setRouteFetcherForTesting: jest.fn() }));
jest.mock('../../src/lib/taxEngine', () => ({ ...jest.requireActual('../../src/lib/taxEngine'), resolveAndFreezeTaxSnapshot: jest.fn(async () => null) }));
import { db } from '../../src/lib/admin';
import { calculateDeliveryQuote } from '../../src/functions/calculateDeliveryQuote';
import { calculateAuthoritativeRoute } from '../../src/functions/calculateRoute';
import { reviewBooking } from '../../src/lib/bookingServer';
import { validateBookingPhotos } from '../../src/lib/bookingPhotoValidation';
import { isWithinServiceZones } from '../../src/lib/serviceZones';
import { resolveLockedQuote } from '../../src/lib/quoteIntegrity';
import { buildPricingConfig } from './fixtures';

const uid = 'customer-price-first-test';
function rawLoad() { return { draft_id: 'price-first-test-draft', intake_mode: 'photo_assisted', timing_mode: 'immediate', requested_at: null,
  items: [{ id: 'sofa-test', category: 'sofa', label: 'Fictitious sofa', quantity: 1, length: null, width: null, height: null, weight: null,
    dimension_unit: 'cm', weight_unit: 'kg', approximate: false, upright: true,
    photos: [`booking_photos/${uid}/price-first-test-draft/sofa-test/0.jpg`], identification_confirmed: true, special_handling: false }],
  pickup: { floor: 0, stairs: false, elevator: false, help: false }, dropoff: { floor: 0, stairs: false, elevator: false, help: false }, handlers: 1, equipment: [] }; }
function request() { return { auth: { uid, token: { role: 'customer', email_verified: true } }, data: { quotePurpose: 'price_before_assignment', booking: rawLoad(),
  stops: [{ type: 'pickup', address: { line1: 'Synthetic pickup', city: 'Granby', postal_code: 'J2G1A1', lat: 45.4, lng: -72.7 } },
    { type: 'dropoff', address: { line1: 'Synthetic dropoff', city: 'Granby', postal_code: 'J2G1A2', lat: 45.41, lng: -72.71 } }] } }; }
let config = buildPricingConfig();
let written: Record<string, any>;
let reads: string[];
beforeEach(() => {
  jest.clearAllMocks(); written = {}; reads = [];
  config = buildPricingConfig();
  config.vehicle_rules = ['pickupTruck','cargoVan','cubeTruck'].map(category => ({ ...config.vehicle_rules[0], category }));
  (calculateAuthoritativeRoute as jest.Mock).mockResolvedValue({ distanceKm: 12, estimatedDurationMinutes: 25, isApproximate: false });
  (isWithinServiceZones as jest.Mock).mockReturnValue(true);
  (validateBookingPhotos as jest.Mock).mockResolvedValue(undefined);
  const ref = (path: string) => ({ id: path.split('/').pop(),
    get: async () => {
      reads.push(path);
      if (path === 'pricing_configs/active') return { exists: true, data: () => ({ active_pricing_version: config.pricing_version }) };
      if (path === `pricing_versions/${config.pricing_version}`) return { exists: true, data: () => config };
      throw new Error(`UNEXPECTED_DEPENDENCY:${path}`);
    },
    set: async (value: any) => { if (!path.startsWith('delivery_quotes/')) throw new Error('UNEXPECTED_WRITE'); written[path] = value; },
  });
  (db.doc as jest.Mock).mockImplementation(ref);
  (db.collection as jest.Mock).mockImplementation((name: string) => ({ doc: (id = 'quote-first-test') => ref(`${name}/${id}`) }));
});
const run = (r = request()) => calculateDeliveryQuote.run(r as any);

test('price is issued with no capacity, photo policy, driver, booking policy or runtime flags', async () => {
  const result = await run();
  expect(result).toMatchObject({ quoteId: 'quote-first-test', customerTotal: 45.5, assignmentPending: true, booking: null });
  expect(reviewBooking).not.toHaveBeenCalled();
  expect(validateBookingPhotos).toHaveBeenCalledTimes(1);
  expect(reads).toEqual(['pricing_configs/active', `pricing_versions/${config.pricing_version}`]);
  expect(Object.keys(written)).toEqual(['delivery_quotes/quote-first-test']);
  const saved = written['delivery_quotes/quote-first-test'];
  expect(saved.mission_id).toBeNull(); expect(saved.is_consumed).toBe(false);
  expect(resolveLockedQuote('quote-first-test', saved).customerTotalMinor).toBe(4550);
  expect(saved.pricing_snapshot.pre_assignment.vehicle_assignment).toBe('pending');
  expect(saved.pricing_snapshot.booking).toBeUndefined();
});
test('untrusted client amount, route, category and heavy flag cannot change the official price', async () => {
  const r: any = request(); Object.assign(r.data, { customerTotal: 0.01, distanceKm: 0.01, estimatedDurationMinutes: 0.01, vehicleCategory: 'car', handling: { isHeavyItem: true } });
  const result = await run(r); expect(result.customerTotal).toBe(45.5);
  expect(written['delivery_quotes/quote-first-test'].pricing_snapshot.handling.isHeavyItem).toBe(false);
});
test('other approved handling fees are not erased', async () => {
  config.handling_fees.loading_fee = 7;
  const r = request(); r.data.booking.pickup.help = true;
  expect((await run(r)).customerTotal).toBe(52.5);
});
test('different category tariffs fail explicitly instead of choosing an arbitrary price', async () => {
  config.vehicle_rules[1].base_fare += 1;
  await expect(run()).rejects.toMatchObject({ code: 'failed-precondition', details: { quote_reason: 'pricing_category_required' } });
  expect(Object.keys(written)).toHaveLength(0);
});
test('a missing pilot tariff is not replaced by an invented rate', async () => {
  config.vehicle_rules.pop(); await expect(run()).rejects.toMatchObject({ code: 'failed-precondition' });
  expect(Object.keys(written)).toHaveLength(0);
});
test('a nonzero bulky fee needs its own approved pricing condition, not a fictitious capacity threshold', async () => {
  config.handling_fees.bulky_item_fee = 5;
  await expect(run()).rejects.toMatchObject({ code: 'failed-precondition', details: { quote_reason: 'pricing_handling_required' } });
});
test('object confirmation is still required', async () => {
  const r = request(); r.data.booking.items[0].identification_confirmed = false;
  await expect(run(r)).rejects.toMatchObject({ code: 'failed-precondition', details: { quote_reason: 'object_confirmation_required' } });
});
test('photo ownership is still enforced', async () => {
  const r = request(); r.data.booking.items[0].photos = ['booking_photos/another-account/draft/item/0.jpg'];
  await expect(run(r)).rejects.toMatchObject({ code: 'invalid-argument' });
});
test('missing photo is refused', async () => {
  const r = request(); r.data.booking.items[0].photos = [];
  await expect(run(r)).rejects.toMatchObject({ code: 'failed-precondition', details: { quote_reason: 'photo_required' } });
});
// Owner decision 2026-10-25: no measurements required, the driver judges.
test('a special object is priced without customer measurements', async () => {
  const r = request(); r.data.booking.items[0].special_handling = true;
  await expect(run(r)).resolves.toBeDefined();
});
test('zone and scheduled date validations are not bypassed', async () => {
  (isWithinServiceZones as jest.Mock).mockReturnValue(false);
  await expect(run()).rejects.toMatchObject({ code: 'failed-precondition', details: { quote_reason: 'outside_service_area' } });
  expect(Object.keys(written)).toHaveLength(0);
});
test('route failure never produces an invented price', async () => {
  (calculateAuthoritativeRoute as jest.Mock).mockRejectedValue(new Error('SIMULATED_ROUTE_UNAVAILABLE'));
  await expect(run()).rejects.toThrow('SIMULATED_ROUTE_UNAVAILABLE'); expect(Object.keys(written)).toHaveLength(0);
});
test('frozen description is covered by the existing integrity hash', async () => {
  await run(); const saved = written['delivery_quotes/quote-first-test'];
  saved.pricing_snapshot.pre_assignment.load.items[0].quantity = 2;
  expect(() => resolveLockedQuote('quote-first-test', saved)).toThrow(/intégrité/);
});
test('legacy callers retain their strict booking review', async () => {
  const r: any = request(); delete r.data.quotePurpose;
  await expect(run(r)).rejects.toMatchObject({ code: 'failed-precondition' }); expect(reviewBooking).toHaveBeenCalledTimes(1);
});
