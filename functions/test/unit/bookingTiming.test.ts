import { normalizeLoad, recommend, Capacity } from '../../src/lib/booking';

// Synthetic capacities only; never used as production configuration.
const access = { floor: 0, stairs: false, elevator: false, help: false };
const input = () => ({
  draft_id: 'timing-test-draft',
  items: [{ id: 'box', category: 'boxes', label: 'Test box', quantity: 1,
    length: 20, width: 20, height: 20, weight: 5, dimension_unit: 'cm',
    weight_unit: 'kg', approximate: false, upright: true, photos: [] }],
  pickup: access, dropoff: access, handlers: 1, equipment: [],
  requested_at: '2099-01-01T12:00:00Z',
});
const capacity: Capacity = { category: 'cargo_van', rank: 1, version: 'TEST',
  verified: true, length_cm: 100, width_cm: 100, height_cm: 100,
  opening_width_cm: 100, opening_height_cm: 100, payload_kg: 100,
  handlers: 1, equipment: [], services: [] };
const rules = { approved: true, version: 'TEST', capacities: [capacity],
  heavy_item_kg: 50, bulky_item_cm: 150 };

test('explicit immediate request needs no fabricated future timestamp', () => {
  const raw = { ...input(), timing_mode: 'immediate', requested_at: null };
  const before = JSON.stringify(raw);
  const load = normalizeLoad(raw);
  expect(load).toMatchObject({ timing_mode: 'immediate', requested_at: null });
  expect(recommend(load, rules).status).toBe('ready');
  expect(JSON.stringify(raw)).toBe(before);
});
test('explicit scheduled request preserves the exact requested instant', () => {
  const raw = { ...input(), timing_mode: 'scheduled' };
  expect(normalizeLoad(raw)).toMatchObject({ timing_mode: 'scheduled', requested_at: raw.requested_at });
});
test('legacy scheduled loads retain their original normalized representation', () => {
  const load = normalizeLoad(input());
  expect(load).not.toHaveProperty('timing_mode');
  expect(load.requested_at).toBe(input().requested_at);
  expect(recommend(load, rules).status).toBe('ready');
});
test.each([undefined, 'scheduled'])('missing time is not implicitly immediate: %s', (mode) => {
  const load = normalizeLoad({ ...input(), requested_at: null, ...(mode ? { timing_mode: mode } : {}) });
  expect(recommend(load, rules).reasons).toContain('requested_time_missing');
});
test.each(['now', '', 1, null])('rejects unknown explicit timing mode: %s', (mode) => {
  expect(() => normalizeLoad({ ...input(), timing_mode: mode })).toThrow();
});
test('immediate mode cannot carry a contradictory scheduled date', () => {
  expect(() => normalizeLoad({ ...input(), timing_mode: 'immediate' })).toThrow();
});
test('immediate mode does not bypass approved capacity', () => {
  const load = normalizeLoad({ ...input(), timing_mode: 'immediate', requested_at: null });
  expect(recommend(load, { ...rules, approved: false }).reasons).toContain('capacity_unconfigured');
});
