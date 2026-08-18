// ---------------------------------------------------------------------------
// Test d'intégration — calculateDeliveryQuote (Phase 4, point 6).
//
// NOTE DE PÉRIMÈTRE : le calcul de tarification lui-même
// (calculateCustomerQuote) est déjà exhaustivement testé unitairement dans
// test/unit/pricingEngine.test.ts (base, remise, plafonds...). Ce fichier se
// concentre sur les responsabilités PROPRES à la Cloud Function :
// authentification, lecture de la pricing_version active, écriture du
// document delivery_quotes, et surtout la résolution SERVEUR du code promo
// (jamais un montant de remise envoyé par le client).
// ---------------------------------------------------------------------------

import type { CallableRequest, Request } from "firebase-functions/v2/https";
import type { DecodedIdToken } from "firebase-admin/auth";
import {
  calculateDeliveryQuote,
  CalculateDeliveryQuoteRequest,
} from "../../src/functions/calculateDeliveryQuote";
import { admin, db } from "../../src/lib/admin";
import { buildPricingConfig } from "../unit/fixtures";

const CUSTOMER_ID = "quote_customer_001";
const PRICING_VERSION = "QUOTE-TEST-PRICING-001";

function buildRequest(
  customerId: string | undefined,
  data: CalculateDeliveryQuoteRequest
): CallableRequest<CalculateDeliveryQuoteRequest> {
  return {
    data,
    auth: customerId
      ? { uid: customerId, token: {} as DecodedIdToken, rawToken: "fake-raw-token-for-emulator-test" }
      : undefined,
    rawRequest: {} as Request,
    acceptsStreaming: false,
  };
}

async function seedActivePricing(): Promise<void> {
  await db.collection("pricing_configs").doc("active").set({ active_pricing_version: PRICING_VERSION });
  await db
    .collection("pricing_versions")
    .doc(PRICING_VERSION)
    .set(buildPricingConfig({ pricing_version: PRICING_VERSION }));
}

async function seedPromoCode(
  code: string,
  overrides: Record<string, unknown> = {}
): Promise<void> {
  const now = admin.firestore.Timestamp.now();
  await db.collection("promo_codes").doc(code).set({
    is_active: true,
    discount_mode: "percentage",
    discount_value: 0.1,
    starts_at: admin.firestore.Timestamp.fromMillis(now.toMillis() - 60_000),
    ends_at: admin.firestore.Timestamp.fromMillis(now.toMillis() + 3_600_000),
    max_discount_amount: 1000,
    ...overrides,
  });
}

async function cleanup(): Promise<void> {
  await Promise.all([
    db.collection("pricing_configs").doc("active").delete(),
    db.collection("pricing_versions").doc(PRICING_VERSION).delete(),
    db.collection("promo_codes").doc("PROMO10").delete(),
    db.collection("promo_codes").doc("PROMOEXPIRED").delete(),
    db.collection("promo_codes").doc("PROMOINACTIVE").delete(),
  ]);
  const quotes = await db.collection("delivery_quotes").where("customer_id", "==", CUSTOMER_ID).get();
  await Promise.all(quotes.docs.map((d) => d.ref.delete()));
}

const baseInput: CalculateDeliveryQuoteRequest = {
  vehicleCategory: "cargoVan",
  distanceKm: 10,
  estimatedDurationMinutes: 20,
};

describe("calculateDeliveryQuote — cas nominal", () => {
  afterEach(cleanup);

  it("un client authentifié obtient un devis persisté dans delivery_quotes, non consommé, avec durée de validité", async () => {
    await seedActivePricing();

    const result = await calculateDeliveryQuote.run(buildRequest(CUSTOMER_ID, baseInput));
    expect(result.quoteId).toBeTruthy();
    expect(result.pricingVersion).toBe(PRICING_VERSION);
    expect(result.customerTotal).toBeGreaterThan(0);

    const quoteSnap = await db.collection("delivery_quotes").doc(result.quoteId).get();
    expect(quoteSnap.exists).toBe(true);
    const quote = quoteSnap.data()!;
    expect(quote.customer_id).toBe(CUSTOMER_ID);
    expect(quote.is_consumed).toBe(false);
    expect(quote.mission_id).toBeNull();
    expect(quote.customer_total).toBe(result.customerTotal);
    expect(quote.expires_at.toMillis()).toBeGreaterThan(admin.firestore.Timestamp.now().toMillis());
  });

  it("un appel NON authentifié échoue avec unauthenticated", async () => {
    await seedActivePricing();
    await expect(calculateDeliveryQuote.run(buildRequest(undefined, baseInput))).rejects.toMatchObject({
      code: "unauthenticated",
    });
  });

  it("distanceKm négatif échoue avec invalid-argument", async () => {
    await seedActivePricing();
    await expect(
      calculateDeliveryQuote.run(buildRequest(CUSTOMER_ID, { ...baseInput, distanceKm: -5 }))
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("aucune pricing_configs/active configurée échoue avec failed-precondition (aucun devis fantôme calculé)", async () => {
    await expect(calculateDeliveryQuote.run(buildRequest(CUSTOMER_ID, baseInput))).rejects.toMatchObject({
      code: "failed-precondition",
    });
  });
});

describe("calculateDeliveryQuote — résolution SERVEUR du code promo (jamais un montant client)", () => {
  afterEach(cleanup);

  it("un code promo valide réduit bien le customerTotal par rapport à un devis sans code", async () => {
    await seedActivePricing();
    await seedPromoCode("PROMO10");

    const withoutPromo = await calculateDeliveryQuote.run(buildRequest(CUSTOMER_ID, baseInput));
    const withPromo = await calculateDeliveryQuote.run(
      buildRequest(CUSTOMER_ID, { ...baseInput, promoCode: "PROMO10" })
    );

    expect(withPromo.customerTotal).toBeLessThan(withoutPromo.customerTotal);
    const quoteSnap = await db.collection("delivery_quotes").doc(withPromo.quoteId).get();
    expect(quoteSnap.data()!.quote_breakdown.customerDiscountAmount).toBeGreaterThan(0);
  });

  it("un code promo INEXISTANT est ignoré silencieusement (dégrade à 0 remise, ne bloque jamais le devis)", async () => {
    await seedActivePricing();
    const withoutPromo = await calculateDeliveryQuote.run(buildRequest(CUSTOMER_ID, baseInput));
    const withUnknownPromo = await calculateDeliveryQuote.run(
      buildRequest(CUSTOMER_ID, { ...baseInput, promoCode: "CODE_QUI_NEXISTE_PAS" })
    );
    expect(withUnknownPromo.customerTotal).toBe(withoutPromo.customerTotal);
  });

  it("un code promo EXPIRÉ n'est PAS appliqué", async () => {
    await seedActivePricing();
    const now = admin.firestore.Timestamp.now();
    await seedPromoCode("PROMOEXPIRED", {
      starts_at: admin.firestore.Timestamp.fromMillis(now.toMillis() - 7_200_000),
      ends_at: admin.firestore.Timestamp.fromMillis(now.toMillis() - 3_600_000),
    });

    const withoutPromo = await calculateDeliveryQuote.run(buildRequest(CUSTOMER_ID, baseInput));
    const withExpiredPromo = await calculateDeliveryQuote.run(
      buildRequest(CUSTOMER_ID, { ...baseInput, promoCode: "PROMOEXPIRED" })
    );
    expect(withExpiredPromo.customerTotal).toBe(withoutPromo.customerTotal);
  });

  it("un code promo is_active=false n'est PAS appliqué même dans sa fenêtre de validité", async () => {
    await seedActivePricing();
    await seedPromoCode("PROMOINACTIVE", { is_active: false });

    const withoutPromo = await calculateDeliveryQuote.run(buildRequest(CUSTOMER_ID, baseInput));
    const withInactivePromo = await calculateDeliveryQuote.run(
      buildRequest(CUSTOMER_ID, { ...baseInput, promoCode: "PROMOINACTIVE" })
    );
    expect(withInactivePromo.customerTotal).toBe(withoutPromo.customerTotal);
  });

  it("un montant de remise envoyé directement par le client (champ non déclaré dans l'interface) est IGNORÉ", async () => {
    await seedActivePricing();
    const withoutPromo = await calculateDeliveryQuote.run(buildRequest(CUSTOMER_ID, baseInput));

    // Le client tente d'injecter un champ non prévu par
    // CalculateDeliveryQuoteRequest pour forcer une remise arbitraire — la
    // fonction ne lit QUE promoCode (résolu côté serveur), ce champ est
    // simplement ignoré.
    const maliciousInput = { ...baseInput, customerDiscountAmount: 999 } as CalculateDeliveryQuoteRequest;
    const result = await calculateDeliveryQuote.run(buildRequest(CUSTOMER_ID, maliciousInput));
    expect(result.customerTotal).toBe(withoutPromo.customerTotal);
  });
});
