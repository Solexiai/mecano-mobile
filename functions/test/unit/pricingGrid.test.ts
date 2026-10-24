// Grille de tarifs admin : garde-fous de validation et frais d'annulation
// figés par paiement.

import {
  cardHoldMinor,
  DEFAULT_MISSION_FEE_POLICY,
  missionFeeAmounts,
  missionFeeAmountsError,
  missionFeePolicyFrom,
} from '../../src/lib/missionFees';
import { asPricingVersion, validatePricingDraft } from '../../src/lib/pricingConfigValidation';

function pilotRule(category: string) {
  return { category, base_fare: 20, rate_per_km: 1.5, rate_per_minute: 0.3, minimum_charge: 25 };
}

function draft(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    vehicle_rules: [pilotRule('pickup_truck'), pilotRule('cargo_van'), pilotRule('cube_truck')],
    handling_fees: {
      loading_fee: 0, unloading_fee: 0, heavy_item_fee: 10, bulky_item_fee: 0,
      stairs_fee: 15, no_elevator_fee: 0, second_handler_fee: 20, special_equipment_fee: 0,
    },
    waiting_fee: { free_waiting_minutes: 10, waiting_rate_per_minute: 0.5 },
    additional_stop_fee: { fee_per_stop: 5 },
    surcharges: [],
    customer_service_fee: { service_fee_rate: 0, minimum_service_fee: 0 },
    commission: { standard_commission_rate: 0.15, minimum_platform_commission: 0, maximum_effective_commission_rate: 1 },
    quote_config: { quote_validity_minutes: 15 },
    mission_fee_policy: { total_minor: 3000, driver_minor: 2500, platform_minor: 500 },
    ...overrides,
  };
}

describe('validatePricingDraft', () => {
  test('accepts a coherent pilot grid', () => {
    const result = validatePricingDraft(draft());
    expect(result.errors).toEqual([]);
    expect(result.draft?.vehicle_rules).toHaveLength(3);
  });

  test('refuses a 150 % commission typo', () => {
    const result = validatePricingDraft(draft({
      commission: { standard_commission_rate: 1.5, minimum_platform_commission: 0, maximum_effective_commission_rate: 1 },
    }));
    expect(result.draft).toBeNull();
    expect(result.errors.join(' ')).toMatch(/Commission sur le chauffeur/);
  });

  test('refuses negative amounts and a zero minimum price', () => {
    const rules = [pilotRule('pickup_truck'), pilotRule('cargo_van'), pilotRule('cube_truck')]
      .map((r) => ({ ...r, base_fare: -1, minimum_charge: 0 }));
    const errors = validatePricingDraft(draft({ vehicle_rules: rules })).errors.join(' ');
    expect(errors).toMatch(/prix de base/);
    expect(errors).toMatch(/prix minimum : doit être supérieur à 0/);
  });

  test('pilot vehicles must share one tariff', () => {
    const rules = [pilotRule('pickup_truck'), { ...pilotRule('cargo_van'), rate_per_km: 2 }, pilotRule('cube_truck')];
    expect(validatePricingDraft(draft({ vehicle_rules: rules })).errors.join(' ')).toMatch(/même tarif/);
    expect(validatePricingDraft(draft({ vehicle_rules: [pilotRule('pickup_truck')] })).errors.join(' '))
      .toMatch(/doivent tous avoir un tarif/);
  });

  test('bulky item fee must stay at 0 $', () => {
    const d = draft();
    (d.handling_fees as Record<string, number>).bulky_item_fee = 10;
    expect(validatePricingDraft(d).errors.join(' ')).toMatch(/encombrant/);
  });

  test('the driver must always receive something at the minimum price', () => {
    const result = validatePricingDraft(draft({
      commission: { standard_commission_rate: 0.1, minimum_platform_commission: 30, maximum_effective_commission_rate: 1 },
    }));
    expect(result.errors.join(' ')).toMatch(/recevrait 0 \$/);
  });

  test('fee parts must add up and stay within 5 $ – 100 $', () => {
    expect(validatePricingDraft(draft({
      mission_fee_policy: { total_minor: 3000, driver_minor: 2000, platform_minor: 500 },
    })).errors.join(' ')).toMatch(/égaler exactement/);
    expect(missionFeeAmountsError({ total_minor: 20000, driver_minor: 19000, platform_minor: 1000 }))
      .toMatch(/entre 5 \$ et 100 \$/);
  });

  test('unknown keys and taxes never reach the published version', () => {
    const result = validatePricingDraft(draft({ tax_rate: 0.5, hacked: true }));
    expect(result.errors).toEqual([]);
    const version = asPricingVersion(result.draft!, { tax_rate: 0.14975, tip_policy: { driver_tip_percentage: 100 } }, 'V2');
    expect(version.tax_rate).toBe(0.14975);
    expect((version as unknown as Record<string, unknown>).hacked).toBeUndefined();
    expect(version.mission_fee_policy).toEqual({ total_minor: 3000, driver_minor: 2500, platform_minor: 500, version: 'V2' });
  });
});

describe('frozen mission fee policy', () => {
  test('payments without a stored policy keep the 30 $ defaults', () => {
    expect(missionFeePolicyFrom(undefined)).toEqual(DEFAULT_MISSION_FEE_POLICY);
    expect(missionFeePolicyFrom({ total_minor: 1 })).toEqual(DEFAULT_MISSION_FEE_POLICY);
  });

  test('a 40 $ policy (32 $ driver + 8 $ Movi-K) drives the hold and the split', () => {
    const policy = missionFeePolicyFrom({ total_minor: 4000, driver_minor: 3200, platform_minor: 800 }, 'V9');
    expect(policy.version).toBe('V9');
    expect(cardHoldMinor(2500, policy)).toBe(4000);
    expect(missionFeeAmounts(4000, policy)).toEqual({ total_minor: 4000, driver_minor: 3200, platform_minor: 800 });
    expect(missionFeeAmounts(2000, policy)).toEqual({ total_minor: 2000, driver_minor: 1600, platform_minor: 400 });
  });
});
