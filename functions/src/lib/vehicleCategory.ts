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
