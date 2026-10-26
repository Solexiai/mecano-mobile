// Supplement by item class (owner decision 2026-10-26, Centre de commande).
import { calculateCustomerQuote, calculateDriverCompensation } from "../../src/lib/pricingEngine";
import {
  defaultItemClassFees, itemClassFeeFor, parseItemClassFees, PROPOSED_ITEM_CLASSES,
} from "../../src/lib/itemClassFees";
import { asPricingVersion, validatePricingDraft } from "../../src/lib/pricingConfigValidation";
import { PHOTO_CATEGORIES } from "../../src/lib/photoIntake";
import { buildCommissionConfig, buildPricingConfig } from "./fixtures";

const fees = { light: 0, medium: 10, heavy: 20, very_heavy: 30, order_cap: 60, driver_keeps_all: true,
  classes: { ...PROPOSED_ITEM_CLASSES } };
const commission = { rate: 0.2, program: "standard" as const, reason: "standard_rate" };

test("every item type has a proposed class", () => {
  for (const c of PHOTO_CATEGORIES) expect(PROPOSED_ITEM_CLASSES[c]).toBeDefined();
  expect(PROPOSED_ITEM_CLASSES.sofa).toBe("heavy");
  expect(PROPOSED_ITEM_CLASSES.materials).toBe("very_heavy");
  expect(PROPOSED_ITEM_CLASSES.boxes).toBe("light");
});

test("per item, times the quantity, capped per order", () => {
  const config = { item_class_fees: fees };
  expect(itemClassFeeFor(config, [{ category: "sofa", quantity: 1 }])).toEqual({
    total: 20, capped: false, lines: [{ category: "sofa", item_class: "heavy", quantity: 1, amount: 20 }],
  });
  expect(itemClassFeeFor(config, [{ category: "washer", quantity: 2 }, { category: "boxes", quantity: 5 }]).total).toBe(40);
  const big = itemClassFeeFor(config, [{ category: "materials", quantity: 3 }]);
  expect(big.total).toBe(60);
  expect(big.capped).toBe(true);
  expect(itemClassFeeFor({ item_class_fees: { ...fees, order_cap: 0 } }, [{ category: "materials", quantity: 3 }]).total).toBe(90);
});

test("an older version without the section: no supplement at all", () => {
  expect(itemClassFeeFor({}, [{ category: "sofa", quantity: 4 }])).toEqual({ total: 0, lines: [], capped: false });
});

test("zero supplement: the quote is exactly the same object as before", () => {
  const config = buildPricingConfig();
  const before = calculateCustomerQuote(config, { vehicleCategory: "cargoVan", distanceKm: 10, estimatedDurationMinutes: 20 });
  const after = calculateCustomerQuote(config, { vehicleCategory: "cargoVan", distanceKm: 10, estimatedDurationMinutes: 20,
    itemClassFee: 0, itemClassFeeToDriver: true });
  expect(after).toEqual(before);
});

test("the supplement is a handling fee the customer sees, and the driver keeps it all", () => {
  const config = buildPricingConfig();
  const plain = calculateCustomerQuote(config, { vehicleCategory: "cargoVan", distanceKm: 10, estimatedDurationMinutes: 20 });
  const withFee = calculateCustomerQuote(config, { vehicleCategory: "cargoVan", distanceKm: 10, estimatedDurationMinutes: 20,
    itemClassFee: 20, itemClassFeeToDriver: true });
  expect(withFee.handlingFeesTotal).toBeCloseTo(plain.handlingFeesTotal + 20, 9);
  expect(withFee.subtotal).toBeCloseTo(plain.subtotal + 20, 9);
  expect(withFee.itemClassFeesTotal).toBe(20);
  expect(withFee.driverOnlyAmount).toBe(20);
  const cc = buildCommissionConfig({ standard_commission_rate: 0.2, minimum_platform_commission: 0, maximum_effective_commission_rate: 0.4 });
  const a = calculateDriverCompensation({ pricingResult: plain, resolvedCommission: commission, commissionConfig: cc });
  const b = calculateDriverCompensation({ pricingResult: withFee, resolvedCommission: commission, commissionConfig: cc });
  expect(b.platformCommissionAmount).toBeCloseTo(a.platformCommissionAmount, 9);
  expect(b.driverGrossEarnings).toBeCloseTo(a.driverGrossEarnings + 20, 9);
});

test("when the admin chooses so, the commission applies to the supplement too", () => {
  const config = buildPricingConfig();
  const withFee = calculateCustomerQuote(config, { vehicleCategory: "cargoVan", distanceKm: 10, estimatedDurationMinutes: 20,
    itemClassFee: 20, itemClassFeeToDriver: false });
  expect(withFee.driverOnlyAmount).toBeUndefined();
  const cc = buildCommissionConfig({ standard_commission_rate: 0.2, minimum_platform_commission: 0, maximum_effective_commission_rate: 0.4 });
  const b = calculateDriverCompensation({ pricingResult: withFee, resolvedCommission: commission, commissionConfig: cc });
  expect(b.platformCommissionAmount).toBeCloseTo(withFee.subtotal * 0.2, 9);
});

test("admin values are validated; missing means zero", () => {
  const errors: string[] = [];
  expect(parseItemClassFees(undefined, errors)).toEqual(defaultItemClassFees());
  expect(parseItemClassFees({ ...fees, classes: { sofa: "medium" } }, errors).classes.sofa).toBe("medium");
  expect(errors).toEqual([]);
  for (const bad of [{ ...fees, heavy: -1 }, { ...fees, heavy: 999 }, { ...fees, classes: { piano: "heavy" } },
    { ...fees, classes: { sofa: "huge" } }, "x"]) {
    const e: string[] = [];
    parseItemClassFees(bad, e);
    expect(e.length).toBeGreaterThan(0);
  }
});

test("a published version carries the section; an older grid publishes zeros", () => {
  const validation = validatePricingDraft({ ...draftFrom(buildPricingConfig()) });
  expect(validation.errors).toEqual([]);
  const version = asPricingVersion(validation.draft!, { tax_rate: 0, tip_policy: { driver_tip_percentage: 100 } }, "v-test");
  expect(version.item_class_fees).toEqual(defaultItemClassFees());
  const withFees = validatePricingDraft({ ...draftFrom(buildPricingConfig()), item_class_fees: fees });
  expect(withFees.errors).toEqual([]);
  expect(withFees.draft!.item_class_fees.heavy).toBe(20);
});

function draftFrom(config: ReturnType<typeof buildPricingConfig>) {
  return {
    vehicle_rules: ["pickup_truck", "cargo_van", "cube_truck"].map((category) => ({ ...config.vehicle_rules[0], category })),
    handling_fees: { ...config.handling_fees, bulky_item_fee: 0 },
    waiting_fee: config.waiting_fee,
    additional_stop_fee: config.additional_stop_fee,
    surcharges: config.surcharges,
    customer_service_fee: config.customer_service_fee,
    commission: config.commission,
    quote_config: config.quote_config,
    mission_fee_policy: { total_minor: 3000, driver_minor: 2500, platform_minor: 500 },
  };
}
