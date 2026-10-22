const get = jest.fn();
jest.mock('../../src/lib/admin', () => ({ db: { doc: jest.fn(() => ({ get })) } }));
import { DEFAULT_SERVICE_ZONES, getServiceZonesConfig, isWithinServiceZones } from '../../src/lib/serviceZones';

beforeEach(() => get.mockReset());

test('missing document: price/booking paths fall back to Granby 40 km', async () => {
  get.mockResolvedValue({ exists: false });
  const config = await getServiceZonesConfig({ fallbackToLaunchZone: true });
  expect(config.enabled).toBe(true);
  expect(config.zones).toEqual(DEFAULT_SERVICE_ZONES.zones);
  expect(isWithinServiceZones(45.39856, -72.72225, config)).toBe(true); // Granby
  expect(isWithinServiceZones(45.5017, -73.5673, config)).toBe(false); // Montréal, ~ 66 km
});

test('missing document: legacy callers keep no restriction', async () => {
  get.mockResolvedValue({ exists: false });
  expect(await getServiceZonesConfig()).toEqual({ enabled: false, zones: [] });
});

test('admin document always takes precedence, including disabled', async () => {
  get.mockResolvedValue({ exists: true, data: () => ({ enabled: false, zones: [] }) });
  expect(await getServiceZonesConfig({ fallbackToLaunchZone: true })).toEqual({ enabled: false, zones: [] });
});

test('default is not mutated by callers', async () => {
  get.mockResolvedValue({ exists: false });
  const config = await getServiceZonesConfig({ fallbackToLaunchZone: true });
  config.zones.push({ name: 'x', min_lat: 0, max_lat: 1, min_lng: 0, max_lng: 1 });
  expect(DEFAULT_SERVICE_ZONES.zones).toHaveLength(1);
});
