// -----------------------------------------------------------------------------
// Vehicle category normalization shared by server-authoritative pricing.
//
// Flutter persists/sends VehicleCategory values in snake_case (for example
// `cargo_van`) while some historical pricing versions/tests used the Dart/TS
// enum-style camelCase form (`cargoVan`). Pricing must remain backward
// compatible with already-published immutable pricing_versions, so matching is
// done on a normalized representation but the exact configured value is
// returned to the pricing engine.
// -----------------------------------------------------------------------------

/** Normalize camelCase, snake_case, kebab-case or spaced values to snake_case. */
export function normalizeVehicleCategory(value: string): string {
  return value
    .trim()
    .replace(/([a-z0-9])([A-Z])/g, "$1_$2")
    .replace(/[\s-]+/g, "_")
    .replace(/_+/g, "_")
    .toLowerCase();
}

/**
 * Resolve a client-supplied vehicle category against categories actually
 * present in the active pricing version. Returns the exact configured value so
 * `pricingEngine` can continue doing a strict lookup without mutating an
 * immutable pricing version.
 */
export function resolveConfiguredVehicleCategory(
  configuredCategories: string[],
  requestedCategory: string
): string | null {
  const requested = normalizeVehicleCategory(requestedCategory);
  if (!requested) return null;

  return (
    configuredCategories.find(
      (configured) => normalizeVehicleCategory(configured) === requested
    ) ?? null
  );
}

/**
 * Check whether a driver category list supports the category required by a
 * mission, including historical camelCase values already stored in profiles.
 */
export function supportsVehicleCategory(
  acceptedCategories: string[],
  requiredCategory: string
): boolean {
  const required = normalizeVehicleCategory(requiredCategory);
  if (!required) return false;

  return acceptedCategories.some(
    (accepted) => normalizeVehicleCategory(accepted) === required
  );
}

/**
 * Category gate shared by dispatch and acceptance. A driver-judgement mission
 * (price before assignment, 2026-10-22) accepts any of its eligible pilot
 * categories; every other mission keeps its single required category.
 */
export function driverServesMissionCategory(
  acceptedCategories: unknown,
  mission: { required_vehicle_category?: unknown; booking_snapshot?: unknown }
): boolean {
  const accepted = Array.isArray(acceptedCategories)
    ? acceptedCategories.filter((c): c is string => typeof c === "string")
    : [];
  const snapshot = mission.booking_snapshot as
    | { vehicle_assessment?: unknown; eligible_categories?: unknown }
    | undefined;
  if (snapshot?.vehicle_assessment === "driver_judgement" && Array.isArray(snapshot.eligible_categories)) {
    return snapshot.eligible_categories.some(
      (category) => typeof category === "string" && supportsVehicleCategory(accepted, category)
    );
  }
  return typeof mission.required_vehicle_category === "string" &&
    supportsVehicleCategory(accepted, mission.required_vehicle_category);
}
