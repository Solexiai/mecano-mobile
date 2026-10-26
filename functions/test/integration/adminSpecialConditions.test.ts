// Conditions spéciales (Centre de commande, 2026-10-26): the storm supplement
// with its reason, locked in the quote, and the service pause.
import type { CallableRequest, Request } from "firebase-functions/v2/https";
import type { DecodedIdToken } from "firebase-admin/auth";
import { db } from "../../src/lib/admin";
import { adminSpecialConditions } from "../../src/functions/adminSpecialConditions";
import { calculateDeliveryQuote, CalculateDeliveryQuoteRequest } from "../../src/functions/calculateDeliveryQuote";
import { setRouteFetcherForTesting } from "../../src/functions/calculateRoute";
import { buildPricingConfig } from "../unit/fixtures";

const PRICING_VERSION = "CONDITIONS-TEST-PRICING-001";
const CUSTOMER = "conditions_customer_001";

const call = (data: unknown, uid = "cond_staff", roles = ["admin"]) =>
  ({ data, auth: { uid, token: { roles, role: roles[0] } }, rawRequest: {}, acceptsStreaming: false } as any);

const quoteCall = (data: CalculateDeliveryQuoteRequest): CallableRequest<CalculateDeliveryQuoteRequest> => ({
  data,
  auth: { uid: CUSTOMER, token: {} as DecodedIdToken, rawToken: "fake" },
  rawRequest: {} as Request,
  acceptsStreaming: false,
});

const quoteInput = (): CalculateDeliveryQuoteRequest => ({
  vehicleCategory: "cargoVan",
  stops: [
    { type: "pickup", address: { line1: "123 Test", city: "Granby", postal_code: "J2G1A1", lat: 45.4, lng: -72.73 } },
    { type: "dropoff", address: { line1: "456 Cible", city: "Granby", postal_code: "J2G1A2", lat: 45.41, lng: -72.7 } },
  ],
});

const conditions = (over: { surcharge?: Record<string, unknown>; pause?: Record<string, unknown> } = {}) => {
  const now = Date.now();
  return {
    surcharge: {
      active: true, reason: "snow", mode: "percentage", value: 0.15,
      starts_at_ms: now - 60_000, ends_at_ms: now + 6 * 3600_000, ...over.surcharge,
    },
    pause: { active: false, message: "", ...over.pause },
  };
};

beforeEach(async () => {
  setRouteFetcherForTesting(async () => ({ distanceKm: 12, estimatedDurationMinutes: 25, isApproximate: false }));
  await db.collection("pricing_configs").doc("active").set({ active_pricing_version: PRICING_VERSION });
  await db.collection("pricing_versions").doc(PRICING_VERSION).set(buildPricingConfig({ pricing_version: PRICING_VERSION }));
});

afterEach(async () => {
  if (process.env.GCLOUD_PROJECT !== "demo-movik-test" || process.env.FIRESTORE_EMULATOR_HOST !== "127.0.0.1:8080") throw Error("cleanup isolation");
  for (const c of ["system_config", "audit_logs", "pricing_configs", "pricing_versions"]) await db.recursiveDelete(db.collection(c));
  const quotes = await db.collection("delivery_quotes").where("customer_id", "==", CUSTOMER).get();
  await Promise.all(quotes.docs.map((d) => d.ref.delete()));
});

afterAll(() => setRouteFetcherForTesting(null));

test("admins only", async () => {
  await expect(adminSpecialConditions.run(call({ action: "get" }, "x", ["customer"]))).rejects.toMatchObject({ code: "permission-denied" });
});

test("get: nothing saved, no supplement in force", async () => {
  const r = (await adminSpecialConditions.run(call({ action: "get" }))) as any;
  expect(r).toMatchObject({ saved: false, surchargeInForce: false, conditions: { surcharge: { active: false }, pause: { active: false } } });
});

test("storm supplement: added to the price with its reason, locked; old quotes keep their price", async () => {
  const before = await calculateDeliveryQuote.run(quoteCall(quoteInput()));
  expect(before.breakdown.conditionSurcharge).toBeUndefined();

  const saved = (await adminSpecialConditions.run(call({ action: "save", conditions: conditions() }))) as any;
  expect(saved.surchargeInForce).toBe(true);
  const during = await calculateDeliveryQuote.run(quoteCall(quoteInput()));
  expect(during.customerTotal).toBeGreaterThan(before.customerTotal);
  expect(during.breakdown.surchargesTotal).toBeGreaterThan(0);
  expect(during.breakdown.conditionSurcharge).toEqual({ reason: "snow", mode: "percentage", value: 0.15 });

  const old = (await db.collection("delivery_quotes").doc(before.quoteId).get()).data()!;
  expect(old.customer_total).toBe(before.customerTotal);

  const audits = await db.collection("audit_logs").where("source_function", "==", "adminSpecialConditions").get();
  expect(audits.size).toBe(1);
});

test("an ended supplement no longer applies", async () => {
  const now = Date.now();
  await adminSpecialConditions.run(call({
    action: "save", conditions: conditions({ surcharge: { starts_at_ms: now - 7200_000, ends_at_ms: now - 60_000 } }),
  }));
  const q = await calculateDeliveryQuote.run(quoteCall(quoteInput()));
  expect(q.breakdown.conditionSurcharge).toBeUndefined();
  const r = (await adminSpecialConditions.run(call({ action: "get" }))) as any;
  expect(r.surchargeInForce).toBe(false);
});

test("pause: no new price, the customer gets the message", async () => {
  await adminSpecialConditions.run(call({
    action: "save", conditions: conditions({ surcharge: { active: false }, pause: { active: true, message: "Verglas : de retour demain." } }),
  }));
  await expect(calculateDeliveryQuote.run(quoteCall(quoteInput()))).rejects.toMatchObject({
    code: "failed-precondition",
    message: "Verglas : de retour demain.",
    details: { quote_reason: "service_paused", pause_message: "Verglas : de retour demain." },
  });
});

test.each([
  conditions({ surcharge: { value: 0.9 } }),
  conditions({ surcharge: { mode: "fixed_amount", value: 500 } }),
  conditions({ surcharge: { reason: "nope" } }),
  conditions({ surcharge: { ends_at_ms: Date.now() + 100 * 3600_000 } }),
  conditions({ surcharge: { value: 0 } }),
  conditions({ surcharge: { active: false }, pause: { active: true, message: "  " } }),
  null,
])("invalid save refused, nothing written: %p", async (payload) => {
  await expect(adminSpecialConditions.run(call({ action: "save", conditions: payload }))).rejects.toMatchObject({ code: "invalid-argument" });
  expect((await db.doc("system_config/special_conditions").get()).exists).toBe(false);
});
