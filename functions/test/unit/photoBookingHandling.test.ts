import { bookingHandling, BookingLoad, BookingRules, recommend } from '../../src/lib/booking';
import { calculateCustomerQuote } from '../../src/lib/pricingEngine';
import { buildPricingConfig } from './fixtures';

// Synthetic configuration: never copied to production.
const rules: BookingRules = { approved: true, version: 'TEST-ONLY', heavy_item_kg: 50,
  bulky_item_cm: 150, capacities: [{ category: 'cargo_van', rank: 1, version: 'TEST-ONLY', verified: true,
    length_cm: 300, width_cm: 200, height_cm: 200, opening_width_cm: 190, opening_height_cm: 190,
    payload_kg: 500, handlers: 2, equipment: [], services: ['handling', 'stairs'] }] };
function load(category = 'sofa'): BookingLoad {
  return { schema_version: 1, draft_id: 'fictitious-photo-draft', timing_mode: 'immediate', requested_at: null,
    items: [{ id: 'object-1', category, label: 'Fictitious object', quantity: 1,
      length_cm: null, width_cm: null, height_cm: null, weight_kg: null,
      approximate: false, upright: true, photos: ['booking_photos/fake/fictitious-photo-draft/object-1/0.jpg'] }],
    pickup: { floor: 0, stairs: false, elevator: false, help: false },
    dropoff: { floor: 0, stairs: false, elevator: false, help: false }, handlers: 1, equipment: [] };
}
function pricing() {
  const config = buildPricingConfig();
  config.handling_fees.heavy_item_fee = 10;
  config.handling_fees.bulky_item_fee = 11;
  config.handling_fees.loading_fee = 7;
  config.handling_fees.unloading_fee = 9;
  return config;
}
const route = { vehicleCategory: 'cargoVan', distanceKm: 10, estimatedDurationMinutes: 20 };
test.each(['sofa', 'armchair', 'fridge', 'washer', 'table', 'tv', 'boxes'])(
  '%s with unknown measurements does not invent heavy/bulky charges or alter source data', category => {
    const cargo = load(category); const config = pricing();
    const before = JSON.stringify({ cargo, config, rules });
    const flags = bookingHandling(cargo, rules);
    expect(flags.isHeavyItem).toBe(false); expect(flags.isBulkyItem).toBe(false);
    expect(calculateCustomerQuote(config, { ...route, handling: flags })).toEqual(calculateCustomerQuote(config, route));
    expect(JSON.stringify({ cargo, config, rules })).toBe(before);
  });
test('known weight no longer adds the retired heavy surcharge', () => {
  const cargo = load(); cargo.items[0].weight_kg = 60;
  const flags = bookingHandling(cargo, rules);
  expect(flags.isHeavyItem).toBe(false); expect(flags.isBulkyItem).toBe(false);
  expect(calculateCustomerQuote(pricing(), { ...route, handling: flags }).handlingFeesTotal).toBe(0);
});
test('known bulky dimension remains chargeable even when weight is unknown', () => {
  const cargo = load(); cargo.items[0].length_cm = 160;
  const flags = bookingHandling(cargo, rules);
  expect(flags.isHeavyItem).toBe(false); expect(flags.isBulkyItem).toBe(true);
  expect(calculateCustomerQuote(pricing(), { ...route, handling: flags }).handlingFeesTotal).toBe(11);
});
test('unknown measurements do not suppress loading and unloading fees', () => {
  const cargo = load(); cargo.pickup.help = true; cargo.dropoff.help = true;
  const flags = bookingHandling(cargo, rules);
  expect(calculateCustomerQuote(pricing(), { ...route, handling: flags }).handlingFeesTotal).toBe(16);
});
test('unknown object does not suppress the remaining bulky fee in a mixed load', () => {
  const cargo = load(); cargo.items.push({ ...cargo.items[0], id: 'object-2', weight_kg: 60, length_cm: 160 });
  expect(calculateCustomerQuote(pricing(), { ...route, handling: bookingHandling(cargo, rules) }).handlingFeesTotal).toBe(11);
});
test('quantity alone does not fabricate an unknown item weight', () => {
  const cargo = load('boxes'); cargo.items[0].quantity = 20;
  expect(bookingHandling(cargo, rules).isHeavyItem).toBe(false);
});
test('unknown measurements marked approximate remain unknown', () => {
  const cargo = load(); cargo.items[0].approximate = true;
  expect(bookingHandling(cargo, rules).isHeavyItem).toBe(false);
  expect(bookingHandling(cargo, rules).isBulkyItem).toBe(false);
});
test('pricing flags are not proof of vehicle compatibility or an authorized booking', () => {
  const result = recommend(load(), rules);
  expect(result.status).toBe('review_required'); expect(result.snapshot).toBeNull();
  expect(result.reasons).toEqual(expect.arrayContaining(['dimensions_unknown', 'weight_unknown']));
});
