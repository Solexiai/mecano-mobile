// LOCAL TESTS ONLY: real callable and pricing code, mocked route, Firestore
// and rate limit. Public estimate by postal codes (2026-11-26).
jest.mock('../../src/lib/admin', () => {
  const { Timestamp } = jest.requireActual('firebase-admin/firestore');
  return { admin: { firestore: { Timestamp } }, db: { collection: jest.fn(), doc: jest.fn() } };
});
jest.mock('../../src/lib/routingRateLimit', () => ({ consumePublicEstimateBudget: jest.fn(async () => {}) }));
jest.mock('../../src/functions/calculateRoute', () => ({
  calculatePostalCodeRoute: jest.fn(), setRouteFetcherForTesting: jest.fn(),
}));
jest.mock('../../src/lib/taxEngine', () => ({
  ...jest.requireActual('../../src/lib/taxEngine'), resolveAndFreezeTaxSnapshot: jest.fn(async () => null),
}));
import { db } from '../../src/lib/admin';
import {
  clearEstimateCachesForTesting,
  estimateDeliveryPrice,
  visitorIp,
} from '../../src/functions/estimateDeliveryPrice';
import { calculatePostalCodeRoute } from '../../src/functions/calculateRoute';
import { defaultItemClassFees } from '../../src/lib/itemClassFees';
import { consumePublicEstimateBudget } from '../../src/lib/routingRateLimit';
import { buildPricingConfig } from './fixtures';

let config = buildPricingConfig();
let reads: string[];

function request(data: Record<string, unknown>, forwardedFor = '203.0.113.7, 198.51.100.9') {
  return { data, rawRequest: { headers: { 'x-forwarded-for': forwardedFor } } };
}
const run = (data: Record<string, unknown>) => estimateDeliveryPrice.run(request(data) as any);
const valid = { fromPostalCode: 'j2g3v5', toPostalCode: 'J2L 1A1', weight: 'medium' };

beforeEach(() => {
  jest.clearAllMocks();
  clearEstimateCachesForTesting();
  reads = [];
  config = buildPricingConfig();
  config.vehicle_rules = ['pickupTruck', 'cargoVan', 'cubeTruck'].map((category) => ({ ...config.vehicle_rules[0], category }));
  config.handling_fees = { ...config.handling_fees, loading_fee: 10, unloading_fee: 10, stairs_fee: 5, no_elevator_fee: 5, second_handler_fee: 15 };
  config.item_class_fees = { ...defaultItemClassFees(), light: 0, medium: 10, heavy: 15 };
  (calculatePostalCodeRoute as jest.Mock).mockResolvedValue({ distanceKm: 12, estimatedDurationMinutes: 25, isApproximate: false });
  const ref = (path: string) => ({
    get: async () => {
      reads.push(path);
      if (path === 'pricing_configs/active') return { exists: true, data: () => ({ active_pricing_version: config.pricing_version }) };
      if (path === `pricing_versions/${config.pricing_version}`) return { exists: true, data: () => config };
      throw new Error(`UNEXPECTED_DEPENDENCY:${path}`);
    },
    set: async () => { throw new Error('UNEXPECTED_WRITE'); },
  });
  (db.doc as jest.Mock).mockImplementation(ref);
  (db.collection as jest.Mock).mockImplementation((name: string) => ({ doc: (id: string) => ref(`${name}/${id}`) }));
});

test('a range from the active grid, with no account and nothing written', async () => {
  // Base 20 + 12 km x 1.50 + 25 min x 0.30 = 45.50 ; aid 10 + 10 ; medium item 10 → 75.50.
  // High bound: + stairs 5 + no elevator 5 + second handler 15 → 100.50.
  await expect(run(valid)).resolves.toEqual({
    currency: 'CAD', low_dollars: 75, high_dollars: 101, distance_km: 12, taxes_included: true,
  });
  expect(calculatePostalCodeRoute).toHaveBeenCalledWith({ fromPostalCode: 'J2G 3V5', toPostalCode: 'J2L 1A1' });
  expect(reads).toEqual(['pricing_configs/active', `pricing_versions/${config.pricing_version}`]);
});

test('the weight changes the amount', async () => {
  const light = await run({ ...valid, weight: 'light' });
  const heavy = await run({ ...valid, weight: 'heavy' });
  expect(light).toMatchObject({ low_dollars: 65, high_dollars: 91 });
  expect(heavy).toMatchObject({ low_dollars: 80, high_dollars: 106 });
});

test('the same trip costs one route call and one budget unit', async () => {
  await run(valid);
  await run({ ...valid, weight: 'heavy' });
  await run({ fromPostalCode: 'J2G 3V5', toPostalCode: 'j2l1a1', weight: 'light' });
  expect(calculatePostalCodeRoute).toHaveBeenCalledTimes(1);
  expect(consumePublicEstimateBudget).toHaveBeenCalledTimes(1);
  expect(consumePublicEstimateBudget).toHaveBeenCalledWith('198.51.100.9');
});

test('invalid input is refused before any route call', async () => {
  await expect(run({ ...valid, fromPostalCode: 'Granby' })).rejects.toMatchObject({ code: 'invalid-argument' });
  await expect(run({ ...valid, toPostalCode: '' })).rejects.toMatchObject({ code: 'invalid-argument' });
  await expect(run({ ...valid, weight: 'very_heavy' })).rejects.toMatchObject({ code: 'invalid-argument' });
  expect(calculatePostalCodeRoute).not.toHaveBeenCalled();
  expect(consumePublicEstimateBudget).not.toHaveBeenCalled();
});

test('an unknown trip is not-found and is not cached', async () => {
  (calculatePostalCodeRoute as jest.Mock).mockResolvedValueOnce(null);
  await expect(run(valid)).rejects.toMatchObject({ code: 'not-found' });
  await expect(run(valid)).resolves.toMatchObject({ low_dollars: 75 });
  expect(calculatePostalCodeRoute).toHaveBeenCalledTimes(2);
});

test('an exhausted budget stops before the route call', async () => {
  (consumePublicEstimateBudget as jest.Mock).mockRejectedValueOnce(Object.assign(new Error('limit'), { code: 'resource-exhausted' }));
  await expect(run(valid)).rejects.toMatchObject({ code: 'resource-exhausted' });
  expect(calculatePostalCodeRoute).not.toHaveBeenCalled();
});

test('no active grid: unavailable, never an invented amount', async () => {
  (db.collection as jest.Mock).mockImplementation(() => ({ doc: () => ({ get: async () => ({ exists: false, data: () => undefined }) }) }));
  await expect(run(valid)).rejects.toMatchObject({ code: 'failed-precondition' });
});

describe('visitorIp', () => {
  test('the last forwarded address is the one Google saw', () => {
    expect(visitorIp(request({}, '1.2.3.4, 203.0.113.7') as any)).toBe('203.0.113.7');
    expect(visitorIp(request({}, '203.0.113.7') as any)).toBe('203.0.113.7');
  });

  test('falls back to the socket address, then to a shared bucket', () => {
    expect(visitorIp({ rawRequest: { headers: {}, ip: '10.0.0.1' } } as any)).toBe('10.0.0.1');
    expect(visitorIp({ rawRequest: {} } as any)).toBe('unknown');
    expect(visitorIp({ rawRequest: { headers: { 'x-forwarded-for': 'x'.repeat(80) } } } as any)).toBe('unknown');
  });
});
