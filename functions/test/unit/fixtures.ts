// ---------------------------------------------------------------------------
// Fixtures partagées pour les tests unitaires du pricingEngine.ts (Étape 12).
// ---------------------------------------------------------------------------

import { CommissionConfigDoc, PricingVersionDoc } from "../../src/lib/types";

export function buildCommissionConfig(
  overrides: Partial<CommissionConfigDoc> = {}
): CommissionConfigDoc {
  return {
    standard_commission_rate: 0.15,
    minimum_platform_commission: 0,
    maximum_effective_commission_rate: 1.0,
    ...overrides,
  };
}

export function buildPricingConfig(
  overrides: Partial<PricingVersionDoc> = {}
): PricingVersionDoc {
  return {
    pricing_version: "TEST-PRICING-001",
    is_active: true,
    effective_from: null,
    vehicle_rules: [
      {
        category: "cargoVan",
        base_fare: 20,
        rate_per_km: 1.5,
        rate_per_minute: 0.3,
        minimum_charge: 25,
      },
    ],
    handling_fees: {
      loading_fee: 0,
      unloading_fee: 0,
      heavy_item_fee: 10,
      bulky_item_fee: 0,
      stairs_fee: 0,
      no_elevator_fee: 0,
      second_handler_fee: 0,
      special_equipment_fee: 0,
    },
    waiting_fee: {
      free_waiting_minutes: 10,
      waiting_rate_per_minute: 0.5,
    },
    additional_stop_fee: {
      fee_per_stop: 5,
    },
    surcharges: [],
    customer_service_fee: {
      service_fee_rate: 0,
      minimum_service_fee: 0,
    },
    commission: buildCommissionConfig(),
    tip_policy: {
      driver_tip_percentage: 100,
    },
    quote_config: {
      quote_validity_minutes: 15,
    },
    tax_rate: 0,
    ...overrides,
  };
}
