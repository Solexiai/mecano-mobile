// Conditions spéciales (2026-10-26): storm supplement and service pause.
import { calculateCustomerQuote } from '../../src/lib/pricingEngine';
import {
  activeConditionSurcharge, defaultSpecialConditions, parseSpecialConditions, pauseMessage,
} from '../../src/lib/specialConditions';
import { buildPricingConfig } from './fixtures';

const now = Date.parse('2026-12-01T15:00:00Z');
const storm = {
  surcharge: { active: true, reason: 'snow', mode: 'percentage', value: 0.15, starts_at_ms: now - 3600_000, ends_at_ms: now + 3600_000 },
  pause: { active: false, message: '' },
};

test('nothing saved: no supplement, no pause', () => {
  expect(activeConditionSurcharge(null, now)).toBeNull();
  expect(activeConditionSurcharge(defaultSpecialConditions(), now)).toBeNull();
  expect(pauseMessage(null)).toBeNull();
});

test('a storm supplement applies only during its period', () => {
  const c = parseSpecialConditions(storm, []);
  expect(activeConditionSurcharge(c, now)).toEqual({ id: 'condition_snow', mode: 'percentage', value: 0.15, enabled: true, reason: 'snow' });
  expect(activeConditionSurcharge(c, now + 2 * 3600_000)).toBeNull();
  expect(activeConditionSurcharge(c, now - 2 * 3600_000)).toBeNull();
});

test('the supplement is a surcharge on the transport and handling, before service fee and taxes', () => {
  const config = buildPricingConfig({ tax_rate: 0.1 });
  const plain = calculateCustomerQuote(config, { vehicleCategory: 'cargoVan', distanceKm: 10, estimatedDurationMinutes: 20 });
  const rule = activeConditionSurcharge(parseSpecialConditions(storm, []), now)!;
  const withStorm = calculateCustomerQuote({ ...config, surcharges: [rule] },
    { vehicleCategory: 'cargoVan', distanceKm: 10, estimatedDurationMinutes: 20, applicableSurchargeIds: [rule.id] });
  expect(withStorm.surchargesTotal).toBeCloseTo(plain.missionBaseValue * 0.15, 9);
  expect(withStorm.customerTotal).toBeGreaterThan(plain.customerTotal);
});

test('pause with its message', () => {
  const c = parseSpecialConditions({ ...storm, pause: { active: true, message: ' Verglas : de retour demain. ' } }, []);
  expect(pauseMessage(c)).toBe('Verglas : de retour demain.');
});

test.each([
  { ...storm, surcharge: { ...storm.surcharge, value: 0.9 } },
  { ...storm, surcharge: { ...storm.surcharge, mode: 'fixed_amount', value: 500 } },
  { ...storm, surcharge: { ...storm.surcharge, value: 0 } },
  { ...storm, surcharge: { ...storm.surcharge, reason: 'tornado' } },
  { ...storm, surcharge: { ...storm.surcharge, ends_at_ms: storm.surcharge.starts_at_ms } },
  { ...storm, surcharge: { ...storm.surcharge, ends_at_ms: storm.surcharge.starts_at_ms + 100 * 3600_000 } },
  { ...storm, pause: { active: true, message: '' } },
])('invalid settings refused %#', (raw) => {
  const errors: string[] = [];
  parseSpecialConditions(raw, errors);
  expect(errors.length).toBeGreaterThan(0);
});
