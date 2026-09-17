import { admin, db } from "../../src/lib/admin";
import { calculateCustomerQuote } from "../../src/lib/pricingEngine";
import { PricingVersionDoc } from "../../src/lib/types";
import {
  DEFAULT_JURISDICTION,
  applyTaxSnapshotToQuote,
  resolveAndFreezeTaxSnapshot,
} from "../../src/lib/taxEngine";
import { toMajorUnits, toMinorUnits } from "../../src/lib/money";
import {
  LOCKED_QUOTE_SCHEMA_VERSION,
  LockedQuotePricingSnapshot,
  buildQuoteIntegrityEnvelope,
  computeQuoteIntegrityHash,
} from "../../src/lib/quoteIntegrity";

export async function seedLockedQuote(params: {
  quoteId: string;
  customerId: string;
  pricingConfig: PricingVersionDoc;
  stops: unknown[];
  vehicleCategory?: string;
  distanceKm: number;
  estimatedDurationMinutes: number;
  expiresAtMillis?: number;
  isConsumed?: boolean;
  missionId?: string | null;
  status?: "active" | "consumed" | "cancelled";
  cancelledAt?: FirebaseFirestore.Timestamp | null;
}): Promise<{ pricingResult: ReturnType<typeof calculateCustomerQuote> }> {
  const rawPricingResult = calculateCustomerQuote(params.pricingConfig, {
    vehicleCategory: params.vehicleCategory ?? "cargoVan",
    distanceKm: params.distanceKm,
    estimatedDurationMinutes: params.estimatedDurationMinutes,
  });
  const customerTotalMinor = toMinorUnits(rawPricingResult.customerTotal);
  const pricingResult = {
    ...rawPricingResult,
    customerTotal: toMajorUnits(customerTotalMinor),
  };
  const now = admin.firestore.Timestamp.now();
  const expiresAt = admin.firestore.Timestamp.fromMillis(
    params.expiresAtMillis ?? now.toMillis() + 15 * 60_000
  );
  const pricingSnapshot: LockedQuotePricingSnapshot = {
    schema_version: LOCKED_QUOTE_SCHEMA_VERSION,
    currency: "CAD",
    pricing_version: pricingResult.pricingVersion,
    vehicle_category: params.vehicleCategory ?? "cargoVan",
    distance_km: params.distanceKm,
    estimated_duration_minutes: params.estimatedDurationMinutes,
    route_provider: "test_route_provider",
    route_result: {
      distance_km: params.distanceKm,
      estimated_duration_minutes: params.estimatedDurationMinutes,
    },
    handling: {
      isHeavyItem: false,
      isBulkyItem: false,
      needsStairs: false,
      noElevator: false,
      needsSecondHandler: false,
      needsSpecialEquipment: false,
    },
    total_waiting_minutes: 0,
    additional_stops_count: Math.max(0, params.stops.length - 2),
    applicable_surcharge_ids: [],
    promotion: { code: null, discount_amount: 0 },
    tax_snapshot: null,
    breakdown: pricingResult,
    customer_total_minor: customerTotalMinor,
  };
  const integrityHash = computeQuoteIntegrityHash(
    buildQuoteIntegrityEnvelope({
      quoteId: params.quoteId,
      customerId: params.customerId,
      createdAtMillis: now.toMillis(),
      expiresAtMillis: expiresAt.toMillis(),
      stops: params.stops,
      pricingSnapshot,
    })
  );
  await db.collection("delivery_quotes").doc(params.quoteId).set({
    id: params.quoteId,
    mission_id: params.missionId ?? null,
    customer_id: params.customerId,
    pricing_version: pricingResult.pricingVersion,
    customer_total: pricingResult.customerTotal,
    customer_total_minor: customerTotalMinor,
    quote_breakdown: pricingResult,
    pricing_snapshot: pricingSnapshot,
    stops: params.stops,
    tax_snapshot: null,
    created_at: now,
    expires_at: expiresAt,
    is_consumed: params.isConsumed ?? false,
    status: params.status ?? (params.isConsumed ? "consumed" : "active"),
    cancelled_at: params.cancelledAt ?? null,
    integrity_hash: integrityHash,
    integrity_algorithm: "sha256",
  });
  return { pricingResult };
}

export async function seedOfficialLegacyQuote(params: {
  missionId: string;
  customerId: string;
  pricingConfig: PricingVersionDoc;
  vehicleCategory?: string;
  distanceKm: number;
  estimatedDurationMinutes: number;
}): Promise<{ quoteId: string; pricingResult: ReturnType<typeof calculateCustomerQuote> }> {
  const flat = calculateCustomerQuote(params.pricingConfig, {
    vehicleCategory: params.vehicleCategory ?? "cargoVan",
    distanceKm: params.distanceKm,
    estimatedDurationMinutes: params.estimatedDurationMinutes,
  });
  const now = admin.firestore.Timestamp.now();
  const taxSnapshot = await resolveAndFreezeTaxSnapshot({
    jurisdiction: DEFAULT_JURISDICTION,
    taxableAmountMajor: flat.subtotal + flat.customerServiceFee,
    applyToTransport: true,
    applyToPlatformFees: true,
    atMillis: now.toMillis(),
  });
  const pricingResult = applyTaxSnapshotToQuote(flat, taxSnapshot);
  const quoteId = `quote_${params.missionId}`;
  await db.collection("delivery_quotes").doc(quoteId).set({
    id: quoteId,
    mission_id: params.missionId,
    customer_id: params.customerId,
    pricing_version: params.pricingConfig.pricing_version,
    customer_total: pricingResult.customerTotal,
    customer_total_minor: toMinorUnits(pricingResult.customerTotal),
    quote_breakdown: pricingResult,
    tax_snapshot: taxSnapshot,
    created_at: now,
    expires_at: admin.firestore.Timestamp.fromMillis(now.toMillis() + 15 * 60_000),
    is_consumed: true,
    status: "consumed",
  });
  return { quoteId, pricingResult };
}
