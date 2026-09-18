import Stripe from "stripe";
import { StripeProvider } from "../../src/payment/stripeProvider";

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
