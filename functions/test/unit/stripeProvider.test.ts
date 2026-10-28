import Stripe from "stripe";
import { StripeProvider, isIndeterminateStripeError } from "../../src/payment/stripeProvider";

describe("StripeProvider.createPayment", () => {
  it("désactive les moyens de paiement avec redirection", async () => {
    const create = jest.fn().mockResolvedValue({
      id: "pi_test_no_redirects",
      status: "requires_confirmation",
    });
    const provider = new StripeProvider("sk_test_unit_only", "");
    (
      provider as unknown as {
        stripe: { paymentIntents: { create: typeof create } };
      }
    ).stripe = { paymentIntents: { create } };

    await provider.createPayment({
      providerCustomerId: "cus_test",
      providerPaymentMethodId: "pm_test",
      amountMinor: 11912,
      currency: "CAD",
      connectedAccountId: null,
      applicationFeeMinor: 0,
      idempotencyKey: "create-payment-test",
      metadata: { movik_mission_id: "mission_test" },
    });

    expect(create).toHaveBeenCalledWith(
      expect.objectContaining<Partial<Stripe.PaymentIntentCreateParams>>({
        amount: 11912,
        currency: "cad",
        capture_method: "manual",
        confirm: false,
        automatic_payment_methods: {
          enabled: true,
          allow_redirects: "never",
        },
      }),
      { idempotencyKey: "create-payment-test" }
    );
  });
});

// ---- PAY-11 / PAY-03 / PAY-14 (2026-10-27) ----

describe("StripeProvider — erreurs non concluantes (PAY-11)", () => {
  it("classe timeout/réseau/5xx/rate-limit comme non concluants, les refus de carte comme concluants", () => {
    expect(isIndeterminateStripeError({ type: "StripeConnectionError", message: "ETIMEDOUT" })).toBe(true);
    expect(isIndeterminateStripeError({ type: "StripeAPIError", statusCode: 500 })).toBe(true);
    expect(isIndeterminateStripeError({ type: "StripeRateLimitError", statusCode: 429 })).toBe(true);
    expect(isIndeterminateStripeError(new Error("socket hang up"))).toBe(true);
    expect(isIndeterminateStripeError({ type: "StripeCardError", code: "card_declined", statusCode: 402 })).toBe(false);
    expect(isIndeterminateStripeError({ type: "StripeInvalidRequestError", code: "payment_intent_unexpected_state", statusCode: 400 })).toBe(false);
  });

  it("capturePayment marque indeterminate=true sur une erreur de connexion, false sur un refus", async () => {
    const provider = new StripeProvider("sk_test_unit_only", "");
    const capture = jest.fn()
      .mockRejectedValueOnce(Object.assign(new Error("timeout"), { type: "StripeConnectionError" }))
      .mockRejectedValueOnce(Object.assign(new Error("declined"), { type: "StripeCardError", code: "card_declined", statusCode: 402 }));
    (provider as unknown as { stripe: { paymentIntents: { capture: typeof capture } } }).stripe = {
      paymentIntents: { capture },
    };
    const first = await provider.capturePayment({ providerPaymentIntentId: "pi_1", amountToCaptureMinor: 1000, idempotencyKey: "k1" });
    expect(first.success).toBe(false);
    expect(first.indeterminate).toBe(true);
    const second = await provider.capturePayment({ providerPaymentIntentId: "pi_1", amountToCaptureMinor: 1000, idempotencyKey: "k1" });
    expect(second.success).toBe(false);
    expect(second.indeterminate).toBe(false);
    expect(second.failureCode).toBe("card_declined");
  });
});

describe("StripeProvider.chargeSavedPaymentMethod (PAY-03)", () => {
  it("crée un PaymentIntent off-session capturé immédiatement, même destination et mêmes frais", async () => {
    const create = jest.fn().mockResolvedValue({ id: "pi_retry_1", status: "succeeded", amount_received: 4500, latest_charge: "ch_retry_1" });
    const provider = new StripeProvider("sk_test_unit_only", "");
    (provider as unknown as { stripe: { paymentIntents: { create: typeof create } } }).stripe = { paymentIntents: { create } };
    const result = await provider.chargeSavedPaymentMethod({
      providerCustomerId: "cus_1", providerPaymentMethodId: "pm_1", amountMinor: 4500, currency: "CAD",
      connectedAccountId: "acct_1", applicationFeeMinor: 900, idempotencyKey: "captureRetry:pay_1:2",
      metadata: { movik_payment_id: "pay_1" },
    });
    expect(result).toMatchObject({ success: true, providerPaymentIntentId: "pi_retry_1", providerChargeId: "ch_retry_1", amountCapturedMinor: 4500 });
    expect(create).toHaveBeenCalledWith(
      expect.objectContaining<Partial<Stripe.PaymentIntentCreateParams>>({
        amount: 4500, currency: "cad", customer: "cus_1", payment_method: "pm_1",
        capture_method: "automatic", confirm: true, off_session: true,
        transfer_data: { destination: "acct_1" }, application_fee_amount: 900,
      }),
      { idempotencyKey: "captureRetry:pay_1:2" }
    );
  });
});

describe("StripeProvider.createDriverAccount (PAY-14)", () => {
  it("utilise une clé d'idempotence dérivée du chauffeur", async () => {
    const create = jest.fn().mockResolvedValue({ id: "acct_new" });
    const provider = new StripeProvider("sk_test_unit_only", "");
    (provider as unknown as { stripe: { accounts: { create: typeof create } }; createDriverOnboardingLink: () => Promise<string | null> }).stripe = {
      accounts: { create },
    };
    (provider as unknown as { createDriverOnboardingLink: () => Promise<string | null> }).createDriverOnboardingLink = async () => null;
    await provider.createDriverAccount({ driverId: "drv_1", email: "d@x.com", country: "CA" });
    expect(create).toHaveBeenCalledWith(expect.anything(), { idempotencyKey: "connect-account:test:drv_1" });
  });
});
