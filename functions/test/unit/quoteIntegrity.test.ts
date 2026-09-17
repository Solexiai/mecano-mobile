import {
  LOCKED_QUOTE_SCHEMA_VERSION,
  LockedQuotePricingSnapshot,
  buildQuoteIntegrityEnvelope,
  computeQuoteIntegrityHash,
  resolveLockedQuote,
} from "../../src/lib/quoteIntegrity";

const timestamp = (millis: number) => ({ toMillis: () => millis });

function buildLockedQuote() {
  const pricingSnapshot: LockedQuotePricingSnapshot = {
    schema_version: LOCKED_QUOTE_SCHEMA_VERSION,
    currency: "CAD",
    pricing_version: "P-1",
    vehicle_category: "cargoVan",
    distance_km: 10,
    estimated_duration_minutes: 20,
    route_provider: "google_routes",
    route_result: { distance_km: 10, estimated_duration_minutes: 20 },
    handling: { isHeavyItem: true },
    total_waiting_minutes: 0,
    additional_stops_count: 0,
    applicable_surcharge_ids: [],
    promotion: { code: null, discount_amount: 0 },
    tax_snapshot: null,
    breakdown: {
      pricingVersion: "P-1",
      missionBaseValue: 80,
      handlingFeesTotal: 10,
      waitingFee: 0,
      additionalStopsFee: 0,
      surchargesTotal: 0,
      subtotal: 90,
      customerDiscountAmount: 0,
      customerServiceFee: 5,
      taxAmount: 4.99,
      customerTotal: 99.99,
    },
    customer_total_minor: 9999,
  };
  const quote = {
    customer_id: "customer-1",
    pricing_version: "P-1",
    customer_total: 99.99,
    customer_total_minor: 9999,
    quote_breakdown: pricingSnapshot.breakdown,
    pricing_snapshot: pricingSnapshot,
    stops: [
      { type: "pickup", address: { lat: 45.5, lng: -73.6 } },
      { type: "dropoff", address: { lat: 45.6, lng: -73.7 } },
    ],
    created_at: timestamp(1_000),
    expires_at: timestamp(601_000),
  } as Record<string, unknown>;
  quote.integrity_hash = computeQuoteIntegrityHash(
    buildQuoteIntegrityEnvelope({
      quoteId: "quote-1",
      customerId: "customer-1",
      createdAtMillis: 1_000,
      expiresAtMillis: 601_000,
      stops: quote.stops as unknown[],
      pricingSnapshot,
    })
  );
  return quote;
}

describe("quoteIntegrity", () => {
  it("valide un devis verrouillé et retourne le total entier Stripe", () => {
    const resolved = resolveLockedQuote("quote-1", buildLockedQuote());
    expect(resolved.customerTotalMinor).toBe(9999);
    expect(resolved.pricingResult.customerTotal).toBe(99.99);
    expect(resolved.isLockedSchema).toBe(true);
  });

  it("refuse une modification du prix après création de l'empreinte", () => {
    const quote = buildLockedQuote();
    (quote.pricing_snapshot as LockedQuotePricingSnapshot).breakdown.customerTotal = 1;
    expect(() => resolveLockedQuote("quote-1", quote)).toThrow();
  });

  it("refuse une ventilation dont les composantes ne reforment pas le total", () => {
    const quote = buildLockedQuote();
    const snapshot = quote.pricing_snapshot as LockedQuotePricingSnapshot;
    snapshot.breakdown.customerServiceFee = 500;
    snapshot.customer_total_minor = 9999;
    expect(() => resolveLockedQuote("quote-1", quote)).toThrow();
  });
});
