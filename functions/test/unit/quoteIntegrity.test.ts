import {
  LOCKED_QUOTE_SCHEMA_VERSION,
  LockedQuotePricingSnapshot,
  QuoteIntegrityEnvelope,
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

function buildEnvelopeFromQuote(quote: Record<string, unknown>): QuoteIntegrityEnvelope {
  return buildQuoteIntegrityEnvelope({
    quoteId: "quote-1",
    customerId: quote.customer_id as string,
    createdAtMillis: (quote.created_at as ReturnType<typeof timestamp>).toMillis(),
    expiresAtMillis: (quote.expires_at as ReturnType<typeof timestamp>).toMillis(),
    stops: quote.stops as unknown[],
    pricingSnapshot: quote.pricing_snapshot as LockedQuotePricingSnapshot,
  });
}

function reversePropertyOrder(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(reversePropertyOrder);
  if (value && typeof value === "object") {
    return Object.keys(value as Record<string, unknown>)
      .reverse()
      .reduce<Record<string, unknown>>((out, key) => {
        out[key] = reversePropertyOrder((value as Record<string, unknown>)[key]);
        return out;
      }, {});
  }
  return value;
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

  it("produit la même empreinte indépendamment de l'ordre des propriétés", () => {
    const envelope = buildEnvelopeFromQuote(buildLockedQuote());
    const reordered = reversePropertyOrder(envelope) as QuoteIntegrityEnvelope;
    expect(computeQuoteIntegrityHash(reordered)).toBe(computeQuoteIntegrityHash(envelope));
  });

  it("change l'empreinte pour chaque famille de données influençant le prix", () => {
    const originalEnvelope = buildEnvelopeFromQuote(buildLockedQuote());
    const originalHash = computeQuoteIntegrityHash(originalEnvelope);
    const mutations: Array<(snapshot: LockedQuotePricingSnapshot, envelope: QuoteIntegrityEnvelope) => void> = [
      (snapshot) => { snapshot.pricing_version = "P-2"; },
      (snapshot) => { snapshot.vehicle_category = "pickupTruck"; },
      (snapshot) => { snapshot.distance_km = 11; },
      (snapshot) => { snapshot.estimated_duration_minutes = 21; },
      (snapshot) => { snapshot.handling.isHeavyItem = false; },
      (snapshot) => { snapshot.total_waiting_minutes = 5; },
      (snapshot) => { snapshot.additional_stops_count = 1; },
      (snapshot) => { snapshot.applicable_surcharge_ids = ["peak"]; },
      (snapshot) => { snapshot.promotion.code = "PROMO"; },
      (snapshot) => { snapshot.promotion.discount_amount = 1; },
      (snapshot) => {
        snapshot.tax_snapshot = {
          tax_jurisdiction: "QC",
          tax_version_ids: ["QC_TEST_v1"],
          tax_rates: [{ tax_code: "TEST", rate: 0.05 }],
          taxable_base_minor: 9500,
          tax_amounts_minor: [{ tax_code: "TEST", amount_minor: 499 }],
          total_tax_minor: 499,
          snapshotted_at: timestamp(2_000),
        } as unknown as LockedQuotePricingSnapshot["tax_snapshot"];
      },
      (snapshot) => { snapshot.breakdown.handlingFeesTotal = 11; },
      (snapshot) => { snapshot.customer_total_minor = 10000; },
      (_snapshot, envelope) => { envelope.stops[0] = { type: "pickup", address: { lat: 46, lng: -73.6 } }; },
    ];

    for (const mutate of mutations) {
      const mutated = structuredClone(originalEnvelope);
      mutate(mutated.pricing_snapshot, mutated);
      expect(computeQuoteIntegrityHash(mutated)).not.toBe(originalHash);
    }
  });
});
