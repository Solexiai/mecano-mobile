import { admin, db } from "../../src/lib/admin";
import { calculateCustomerQuote } from "../../src/lib/pricingEngine";
import { PricingVersionDoc } from "../../src/lib/types";
import {
  DEFAULT_JURISDICTION,
  applyTaxSnapshotToQuote,
  resolveAndFreezeTaxSnapshot,
} from "../../src/lib/taxEngine";
import { toMinorUnits } from "../../src/lib/money";

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
