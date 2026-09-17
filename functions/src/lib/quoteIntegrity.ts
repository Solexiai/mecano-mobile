import { createHash } from "crypto";

import { failedPrecondition } from "./errors";
import { toMinorUnits } from "./money";
import { CustomerPricingResult } from "./pricingEngine";
import { TaxSnapshot } from "./types";

export const LOCKED_QUOTE_SCHEMA_VERSION = 1;

export interface LockedQuotePricingSnapshot {
  schema_version: typeof LOCKED_QUOTE_SCHEMA_VERSION;
  currency: "CAD";
  pricing_version: string;
  vehicle_category: string;
  distance_km: number;
  estimated_duration_minutes: number;
  route_provider: string;
  route_result: {
    distance_km: number;
    estimated_duration_minutes: number;
  };
  handling: Record<string, boolean>;
  total_waiting_minutes: number;
  additional_stops_count: number;
  applicable_surcharge_ids: string[];
  promotion: {
    code: string | null;
    discount_amount: number;
  };
  tax_snapshot: TaxSnapshot | null;
  breakdown: CustomerPricingResult;
  customer_total_minor: number;
}

export interface QuoteIntegrityEnvelope {
  quote_id: string;
  customer_id: string;
  created_at_millis: number;
  expires_at_millis: number;
  stops: unknown[];
  pricing_snapshot: LockedQuotePricingSnapshot;
}

export interface ResolvedLockedQuote {
  pricingVersion: string;
  pricingResult: CustomerPricingResult;
  customerTotalMinor: number;
  pricingSnapshot: LockedQuotePricingSnapshot | null;
  integrityHash: string | null;
  isLockedSchema: boolean;
}

function canonicalize(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(canonicalize);
  if (value && typeof value === "object") {
    const maybeTimestamp = value as { toMillis?: () => number };
    if (typeof maybeTimestamp.toMillis === "function") {
      return { __timestamp_millis: maybeTimestamp.toMillis() };
    }
    const record = value as Record<string, unknown>;
    return Object.keys(record)
      .sort()
      .reduce<Record<string, unknown>>((out, key) => {
        out[key] = canonicalize(record[key]);
        return out;
      }, {});
  }
  return value;
}

export function computeQuoteIntegrityHash(envelope: QuoteIntegrityEnvelope): string {
  return createHash("sha256")
    .update(JSON.stringify(canonicalize(envelope)), "utf8")
    .digest("hex");
}

export function buildQuoteIntegrityEnvelope(params: {
  quoteId: string;
  customerId: string;
  createdAtMillis: number;
  expiresAtMillis: number;
  stops: unknown[];
  pricingSnapshot: LockedQuotePricingSnapshot;
}): QuoteIntegrityEnvelope {
  return {
    quote_id: params.quoteId,
    customer_id: params.customerId,
    created_at_millis: params.createdAtMillis,
    expires_at_millis: params.expiresAtMillis,
    stops: params.stops,
    pricing_snapshot: params.pricingSnapshot,
  };
}

function assertFiniteNonNegative(value: unknown, label: string): asserts value is number {
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0) {
    throw failedPrecondition(`Devis invalide : ${label} est absent ou invalide.`);
  }
}

export function assertValidPricingResult(value: unknown): asserts value is CustomerPricingResult {
  if (!value || typeof value !== "object") {
    throw failedPrecondition("Devis invalide : ventilation tarifaire absente.");
  }
  const result = value as Record<string, unknown>;
  if (typeof result.pricingVersion !== "string" || !result.pricingVersion.trim()) {
    throw failedPrecondition("Devis invalide : version tarifaire absente.");
  }
  for (const field of [
    "missionBaseValue",
    "handlingFeesTotal",
    "waitingFee",
    "additionalStopsFee",
    "surchargesTotal",
    "subtotal",
    "customerDiscountAmount",
    "customerServiceFee",
    "taxAmount",
    "customerTotal",
  ]) {
    assertFiniteNonNegative(result[field], `quote_breakdown.${field}`);
  }

  const recomposed =
    (result.subtotal as number) +
    (result.customerServiceFee as number) +
    (result.taxAmount as number);
  if (toMinorUnits(recomposed) !== toMinorUnits(result.customerTotal as number)) {
    throw failedPrecondition("Devis invalide : le total ne correspond pas à sa ventilation.");
  }

  const rawSubtotal =
    (result.missionBaseValue as number) +
    (result.handlingFeesTotal as number) +
    (result.waitingFee as number) +
    (result.additionalStopsFee as number) +
    (result.surchargesTotal as number);
  if ((result.customerDiscountAmount as number) > rawSubtotal) {
    throw failedPrecondition("Devis invalide : la promotion dépasse le sous-total brut.");
  }
  const expectedSubtotal = rawSubtotal - (result.customerDiscountAmount as number);
  if (toMinorUnits(expectedSubtotal) !== toMinorUnits(result.subtotal as number)) {
    throw failedPrecondition("Devis invalide : le sous-total ne correspond pas à sa ventilation.");
  }
}

/**
 * Valide un devis et retourne son prix figé. Les devis historiques restent
 * lisibles à partir de `quote_breakdown`; les nouveaux devis verrouillés
 * exigent en plus une empreinte SHA-256 valide sur tout leur contenu utile.
 */
export function resolveLockedQuote(quoteId: string, quote: Record<string, unknown>): ResolvedLockedQuote {
  const snapshot = quote.pricing_snapshot as LockedQuotePricingSnapshot | undefined;
  const isLockedSchema = snapshot?.schema_version === LOCKED_QUOTE_SCHEMA_VERSION;
  const pricingResult = isLockedSchema ? snapshot.breakdown : quote.quote_breakdown;
  assertValidPricingResult(pricingResult);

  const pricingVersion = isLockedSchema
    ? snapshot.pricing_version
    : (quote.pricing_version as string | undefined);
  if (typeof pricingVersion !== "string" || !pricingVersion.trim()) {
    throw failedPrecondition("Devis invalide : version tarifaire absente.");
  }
  if (pricingResult.pricingVersion !== pricingVersion) {
    throw failedPrecondition("Devis invalide : divergence de version tarifaire.");
  }

  const customerTotal = quote.customer_total;
  assertFiniteNonNegative(customerTotal, "customer_total");
  const expectedMinor = toMinorUnits(pricingResult.customerTotal);
  if (toMinorUnits(customerTotal) !== expectedMinor) {
    throw failedPrecondition("Devis invalide : divergence entre le total et la ventilation.");
  }

  if (!isLockedSchema) {
    return {
      pricingVersion,
      pricingResult,
      customerTotalMinor: expectedMinor,
      pricingSnapshot: null,
      integrityHash: null,
      isLockedSchema: false,
    };
  }

  if (!Number.isInteger(snapshot.customer_total_minor) || snapshot.customer_total_minor < 0) {
    throw failedPrecondition("Devis invalide : total monétaire verrouillé absent.");
  }
  if (snapshot.customer_total_minor !== expectedMinor) {
    throw failedPrecondition("Devis invalide : divergence du total monétaire verrouillé.");
  }
  if (
    !Number.isInteger(quote.customer_total_minor) ||
    quote.customer_total_minor !== expectedMinor
  ) {
    throw failedPrecondition("Devis verrouillé invalide : total monétaire du devis divergent.");
  }
  if (quote.pricing_version !== snapshot.pricing_version) {
    throw failedPrecondition("Devis verrouillé invalide : version tarifaire du devis divergente.");
  }
  assertValidPricingResult(quote.quote_breakdown);
  const publicBreakdown = quote.quote_breakdown as CustomerPricingResult;
  if (publicBreakdown.pricingVersion !== pricingResult.pricingVersion) {
    throw failedPrecondition("Devis verrouillé invalide : version de ventilation divergente.");
  }
  for (const field of [
    "missionBaseValue",
    "handlingFeesTotal",
    "waitingFee",
    "additionalStopsFee",
    "surchargesTotal",
    "subtotal",
    "customerDiscountAmount",
    "customerServiceFee",
    "taxAmount",
    "customerTotal",
  ] as const) {
    if (toMinorUnits(publicBreakdown[field]) !== toMinorUnits(pricingResult[field])) {
      throw failedPrecondition("Devis verrouillé invalide : ventilation publique divergente.");
    }
  }
  if (snapshot.currency !== "CAD") {
    throw failedPrecondition("Devis verrouillé invalide : devise non prise en charge.");
  }
  assertFiniteNonNegative(snapshot.distance_km, "pricing_snapshot.distance_km");
  assertFiniteNonNegative(
    snapshot.estimated_duration_minutes,
    "pricing_snapshot.estimated_duration_minutes"
  );
  if (
    snapshot.route_result?.distance_km !== snapshot.distance_km ||
    snapshot.route_result?.estimated_duration_minutes !== snapshot.estimated_duration_minutes
  ) {
    throw failedPrecondition("Devis verrouillé invalide : itinéraire incohérent.");
  }
  if (
    toMinorUnits(snapshot.promotion?.discount_amount ?? -1) !==
    toMinorUnits(pricingResult.customerDiscountAmount)
  ) {
    throw failedPrecondition("Devis verrouillé invalide : promotion incohérente.");
  }
  if (
    snapshot.tax_snapshot &&
    snapshot.tax_snapshot.total_tax_minor !== toMinorUnits(pricingResult.taxAmount)
  ) {
    throw failedPrecondition("Devis verrouillé invalide : taxes incohérentes.");
  }

  const storedHash = quote.integrity_hash;
  const customerId = quote.customer_id;
  const stops = quote.stops;
  const createdAt = quote.created_at as { toMillis?: () => number } | undefined;
  const expiresAt = quote.expires_at as { toMillis?: () => number } | undefined;
  if (
    typeof storedHash !== "string" ||
    typeof customerId !== "string" ||
    !Array.isArray(stops) ||
    typeof createdAt?.toMillis !== "function" ||
    typeof expiresAt?.toMillis !== "function"
  ) {
    throw failedPrecondition("Devis verrouillé invalide : données d'intégrité incomplètes.");
  }
  const actualHash = computeQuoteIntegrityHash(
    buildQuoteIntegrityEnvelope({
      quoteId,
      customerId,
      createdAtMillis: createdAt.toMillis(),
      expiresAtMillis: expiresAt.toMillis(),
      stops,
      pricingSnapshot: snapshot,
    })
  );
  if (actualHash !== storedHash) {
    throw failedPrecondition("Devis verrouillé invalide : empreinte d'intégrité divergente.");
  }

  return {
    pricingVersion,
    pricingResult,
    customerTotalMinor: expectedMinor,
    pricingSnapshot: snapshot,
    integrityHash: storedHash,
    isLockedSchema: true,
  };
}
