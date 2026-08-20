// -----------------------------------------------------------------------------
// stripeProvider.ts — Implémentation RÉELLE de PaymentProvider via Stripe
// Connect. Voir docs/PAYMENT_ARCHITECTURE.md pour la justification complète
// de chaque choix (destination charges, capture manuelle, comptes Express).
//
// 🔒 Ce fichier ne s'exécute QUE côté Cloud Functions. La clé secrète est
// injectée via Secret Manager (`STRIPE_SECRET_KEY`, voir lib/secrets.ts) —
// jamais codée en dur, jamais journalisée.
//
// SOURCES VÉRIFIÉES (aucune capacité inventée) :
// - Destination charges : docs.stripe.com/connect/destination-charges
// - Capture manuelle : docs.stripe.com/payments/capture-later
// - Comptes Express : docs.stripe.com/connect/express-accounts
// - Refund/reverse_transfer : docs.stripe.com/connect/destination-charges
// - Webhooks/signature : docs.stripe.com/connect/webhooks
// -----------------------------------------------------------------------------

import Stripe from "stripe";
import {
  AttachPaymentMethodParams,
  AttachPaymentMethodResult,
  AuthorizePaymentParams,
  AuthorizePaymentResult,
  CancelAuthorizationParams,
  CancelAuthorizationResult,
  CapturePaymentParams,
  CapturePaymentResult,
  CreateCustomerParams,
  CreateCustomerResult,
  CreateDriverAccountParams,
  CreateDriverAccountResult,
  CreateDriverPayoutParams,
  CreateDriverPayoutResult,
  CreatePaymentParams,
  CreatePaymentResult,
  ListProviderPaymentsResult,
  ListProviderPayoutsResult,
  ListProviderRefundsResult,
  ListProviderTransactionsParams,
  PaymentProvider,
  PaymentStatusResult,
  PayoutStatusResult,
  ProcessWebhookResult,
  ReconcileTransactionParams,
  ReconcileTransactionResult,
  RefundPaymentParams,
  RefundPaymentResult,
} from "./paymentProvider";

export class StripeProvider extends PaymentProvider {
  private readonly stripe: Stripe;
  private readonly webhookSecret: string;

  constructor(secretKey: string, webhookSecret: string) {
    super();
    if (!secretKey) {
      throw new Error("StripeProvider requiert une STRIPE_SECRET_KEY non vide.");
    }
    this.stripe = new Stripe(secretKey, { apiVersion: "2026-07-29.dahlia" });
    this.webhookSecret = webhookSecret;
  }

  // ---- 1. createCustomer ----
  async createCustomer(params: CreateCustomerParams): Promise<CreateCustomerResult> {
    const customer = await this.stripe.customers.create({
      email: params.email,
      name: params.displayName,
      metadata: { movik_user_id: params.userId },
    });
    return { providerCustomerId: customer.id };
  }

  // ---- 2. attachPaymentMethod ----
  async attachPaymentMethod(
    params: AttachPaymentMethodParams
  ): Promise<AttachPaymentMethodResult> {
    await this.stripe.paymentMethods.attach(params.providerPaymentMethodId, {
      customer: params.providerCustomerId,
    });
    return { success: true, providerPaymentMethodId: params.providerPaymentMethodId };
  }

  // ---- 3. createPayment ----
  // Crée un PaymentIntent en mode "destination charge" + capture manuelle.
  async createPayment(params: CreatePaymentParams): Promise<CreatePaymentResult> {
    const createParams: Stripe.PaymentIntentCreateParams = {
      amount: params.amountMinor,
      currency: params.currency.toLowerCase(),
      customer: params.providerCustomerId,
      payment_method: params.providerPaymentMethodId,
      capture_method: "manual",
      confirm: false,
      metadata: params.metadata,
    };
    if (params.connectedAccountId) {
      createParams.transfer_data = { destination: params.connectedAccountId };
      createParams.application_fee_amount = params.applicationFeeMinor;
    }
    const intent = await this.stripe.paymentIntents.create(createParams, {
      idempotencyKey: params.idempotencyKey,
    });
    return { providerPaymentIntentId: intent.id, status: intent.status };
  }

  // ---- 4. authorizePayment ----
  // Confirme le PaymentIntent (déclenche l'autorisation réseau réelle).
  async authorizePayment(params: AuthorizePaymentParams): Promise<AuthorizePaymentResult> {
    try {
      const intent = await this.stripe.paymentIntents.confirm(params.providerPaymentIntentId, {}, {
        idempotencyKey: params.idempotencyKey,
      });
      const success = intent.status === "requires_capture";
      return {
        success,
        status: intent.status,
        // Stripe ne renvoie pas directement une date d'expiration
        // d'autorisation ; la fenêtre réseau (Visa ~5j, Mastercard/Amex/
        // Discover 7j pour card-not-present) est documentée mais pas
        // exposée par l'API — voir docs.stripe.com/payments/capture-later.
        // On ne calcule PAS une date arbitraire ici : ce champ reste null,
        // et la Cloud Function appelante applique une fenêtre de sécurité
        // CONFIGURABLE (jamais une capacité Stripe inventée).
        authorizationExpiresAt: null,
        failureCode: intent.last_payment_error?.code ?? null,
        failureMessage: intent.last_payment_error?.message ?? null,
      };
    } catch (err) {
      const stripeErr = err as Stripe.errors.StripeError;
      return {
        success: false,
        status: "failed",
        authorizationExpiresAt: null,
        failureCode: stripeErr.code ?? "unknown_error",
        failureMessage: stripeErr.message,
      };
    }
  }

  // ---- 5. capturePayment ----
  async capturePayment(params: CapturePaymentParams): Promise<CapturePaymentResult> {
    try {
      const intent = await this.stripe.paymentIntents.capture(
        params.providerPaymentIntentId,
        { amount_to_capture: params.amountToCaptureMinor },
        { idempotencyKey: params.idempotencyKey }
      );
      const charge = intent.latest_charge;
      const chargeId = typeof charge === "string" ? charge : charge?.id ?? null;
      return {
        success: intent.status === "succeeded",
        status: intent.status,
        amountCapturedMinor: intent.amount_received ?? 0,
        providerChargeId: chargeId,
      };
    } catch (err) {
      const stripeErr = err as Stripe.errors.StripeError;
      return {
        success: false,
        status: "failed",
        amountCapturedMinor: 0,
        providerChargeId: null,
        failureCode: stripeErr.code ?? "unknown_error",
        failureMessage: stripeErr.message,
      };
    }
  }

  // ---- 6. cancelAuthorization ----
  async cancelAuthorization(
    params: CancelAuthorizationParams
  ): Promise<CancelAuthorizationResult> {
    const intent = await this.stripe.paymentIntents.cancel(
      params.providerPaymentIntentId,
      {},
      { idempotencyKey: params.idempotencyKey }
    );
    return { success: intent.status === "canceled", status: intent.status };
  }

  // ---- 7. refundPayment ----
  async refundPayment(params: RefundPaymentParams): Promise<RefundPaymentResult> {
    try {
      const refund = await this.stripe.refunds.create(
        {
          payment_intent: params.providerPaymentIntentId,
          amount: params.amountMinor,
          reverse_transfer: params.reverseTransfer,
          refund_application_fee: params.refundApplicationFee,
        },
        { idempotencyKey: params.idempotencyKey }
      );
      return { success: true, providerRefundId: refund.id, status: refund.status ?? "unknown" };
    } catch (err) {
      const stripeErr = err as Stripe.errors.StripeError;
      return {
        success: false,
        providerRefundId: null,
        status: "failed",
        failureCode: stripeErr.code ?? "unknown_error",
      };
    }
  }

  // ---- BLOC G (point 27) — listing pour réconciliation bidirectionnelle ----
  // 🔒 Pagination : Stripe `.list()` renvoie au plus 100 objets par page
  // (docs.stripe.com/api/pagination) — le paramètre `pageToken` correspond
  // directement à `starting_after` (curseur = ID du dernier objet vu). Le
  // filtrage temporel utilise `created: { gte, lte }` (secondes epoch,
  // Stripe n'accepte pas les millisecondes — voir docs.stripe.com/api/payment_intents/list).
  async listProviderPayments(
    params: ListProviderTransactionsParams
  ): Promise<ListProviderPaymentsResult> {
    const page = await this.stripe.paymentIntents.list({
      created: {
        gte: Math.floor(params.sinceMillis / 1000),
        lte: Math.floor(params.untilMillis / 1000),
      },
      limit: 100,
      starting_after: params.pageToken ?? undefined,
    });
    return {
      payments: page.data.map((intent) => ({
        providerPaymentIntentId: intent.id,
        amountMinor: intent.amount_received || intent.amount,
        status: intent.status,
        createdAtMillis: intent.created * 1000,
      })),
      nextPageToken: page.has_more ? page.data[page.data.length - 1]?.id ?? null : null,
    };
  }

  async listProviderPayouts(
    params: ListProviderTransactionsParams
  ): Promise<ListProviderPayoutsResult> {
    const page = await this.stripe.payouts.list({
      created: {
        gte: Math.floor(params.sinceMillis / 1000),
        lte: Math.floor(params.untilMillis / 1000),
      },
      limit: 100,
      starting_after: params.pageToken ?? undefined,
    });
    return {
      payouts: page.data.map((payout) => ({
        providerPayoutId: payout.id,
        // 🔒 Le compte connecté n'est pas exposé sur l'objet Payout lui-même
        // (il est implicite dans le contexte d'appel `stripeAccount` —
        // docs.stripe.com/api/payouts/object) — non résolu ici pour éviter
        // un appel réseau supplémentaire par payout ; le moteur de
        // réconciliation associe par `providerPayoutId`, jamais par ce champ.
        connectedAccountId: null,
        amountMinor: payout.amount,
        status: payout.status,
        createdAtMillis: payout.created * 1000,
      })),
      nextPageToken: page.has_more ? page.data[page.data.length - 1]?.id ?? null : null,
    };
  }

  async listProviderRefunds(
    params: ListProviderTransactionsParams
  ): Promise<ListProviderRefundsResult> {
    const page = await this.stripe.refunds.list({
      created: {
        gte: Math.floor(params.sinceMillis / 1000),
        lte: Math.floor(params.untilMillis / 1000),
      },
      limit: 100,
      starting_after: params.pageToken ?? undefined,
    });
    return {
      refunds: page.data.map((refund) => ({
        providerRefundId: refund.id,
        providerPaymentIntentId:
          typeof refund.payment_intent === "string"
            ? refund.payment_intent
            : refund.payment_intent?.id ?? null,
        amountMinor: refund.amount,
        status: refund.status ?? "unknown",
        createdAtMillis: refund.created * 1000,
      })),
      nextPageToken: page.has_more ? page.data[page.data.length - 1]?.id ?? null : null,
    };
  }

  // ---- 8. createDriverAccount ----
  // Compte Express (Accounts v1) + lien d'onboarding hébergé Stripe.
  // Voir docs/PAYMENT_ARCHITECTURE.md §1/§8 pour la justification et le
  // point de vérification ouvert (v1 Express vs v2 API).
  async createDriverAccount(
    params: CreateDriverAccountParams
  ): Promise<CreateDriverAccountResult> {
    const account = await this.stripe.accounts.create({
      type: "express",
      country: params.country,
      email: params.email,
      capabilities: {
        card_payments: { requested: true },
        transfers: { requested: true },
      },
      business_type: "individual",
      metadata: { movik_driver_id: params.driverId },
    });

    let onboardingUrl: string | null = null;
    try {
      const accountLink = await this.stripe.accountLinks.create({
        account: account.id,
        refresh_url: "https://movik.ca/chauffeur/onboarding/refresh",
        return_url: "https://movik.ca/chauffeur/onboarding/complete",
        type: "account_onboarding",
      });
      onboardingUrl = accountLink.url;
    } catch {
      onboardingUrl = null;
    }

    return { connectedAccountId: account.id, onboardingUrl };
  }

  // ---- 9. createDriverPayout ----
  // Payout depuis le solde du compte CONNECTÉ (pas la plateforme) — doit
  // être appelé "as the connected account" (docs.stripe.com/connect/authentication).
  async createDriverPayout(
    params: CreateDriverPayoutParams
  ): Promise<CreateDriverPayoutResult> {
    try {
      const payout = await this.stripe.payouts.create(
        { amount: params.amountMinor, currency: params.currency.toLowerCase() },
        {
          stripeAccount: params.connectedAccountId,
          idempotencyKey: params.idempotencyKey,
        }
      );
      return { success: true, providerPayoutId: payout.id, status: payout.status };
    } catch (err) {
      const stripeErr = err as Stripe.errors.StripeError;
      return {
        success: false,
        providerPayoutId: null,
        status: "failed",
        failureCode: stripeErr.code ?? "unknown_error",
      };
    }
  }

  // ---- 10. getPaymentStatus ----
  async getPaymentStatus(providerPaymentIntentId: string): Promise<PaymentStatusResult> {
    const intent = await this.stripe.paymentIntents.retrieve(providerPaymentIntentId);
    const totalRefunded = intent.latest_charge && typeof intent.latest_charge !== "string"
      ? intent.latest_charge.amount_refunded ?? 0
      : 0;
    return {
      status: intent.status,
      amountAuthorizedMinor: intent.amount,
      amountCapturedMinor: intent.amount_received ?? 0,
      amountRefundedMinor: totalRefunded,
    };
  }

  // ---- 11. getPayoutStatus ----
  async getPayoutStatus(providerPayoutId: string): Promise<PayoutStatusResult> {
    const payout = await this.stripe.payouts.retrieve(providerPayoutId);
    return {
      status: payout.status,
      arrivalDate: payout.arrival_date ? new Date(payout.arrival_date * 1000) : null,
      failureCode: payout.failure_code ?? null,
    };
  }

  // ---- 12. processWebhook ----
  // Vérifie la signature (docs.stripe.com/webhooks#verify-events) AVANT de
  // faire confiance au payload. Ne retourne QUE l'évènement vérifié ;
  // l'idempotence/le routage métier sont gérés par
  // functions/src/functions/processPaymentWebhook.ts (appelant), jamais ici.
  async processWebhook(rawBody: Buffer, signatureHeader: string): Promise<ProcessWebhookResult> {
    const event = this.stripe.webhooks.constructEvent(
      rawBody,
      signatureHeader,
      this.webhookSecret
    );
    return { eventId: event.id, eventType: event.type, handled: false };
  }

  /** Expose l'évènement Stripe complet vérifié (usage interne du handler). */
  constructVerifiedEvent(rawBody: Buffer, signatureHeader: string): Stripe.Event {
    return this.stripe.webhooks.constructEvent(rawBody, signatureHeader, this.webhookSecret);
  }

  // ---- 13. reconcileTransaction ----
  async reconcileTransaction(
    params: ReconcileTransactionParams
  ): Promise<ReconcileTransactionResult> {
    if (params.providerPaymentIntentId) {
      try {
        const intent = await this.stripe.paymentIntents.retrieve(params.providerPaymentIntentId);
        return {
          found: true,
          providerAmountMinor: intent.amount_received || intent.amount,
          providerStatus: intent.status,
        };
      } catch {
        return { found: false, providerAmountMinor: null, providerStatus: null };
      }
    }
    if (params.providerPayoutId) {
      try {
        const payout = await this.stripe.payouts.retrieve(params.providerPayoutId);
        return { found: true, providerAmountMinor: payout.amount, providerStatus: payout.status };
      } catch {
        return { found: false, providerAmountMinor: null, providerStatus: null };
      }
    }
    if (params.providerRefundId) {
      try {
        const refund = await this.stripe.refunds.retrieve(params.providerRefundId);
        return {
          found: true,
          providerAmountMinor: refund.amount,
          providerStatus: refund.status ?? "unknown",
        };
      } catch {
        return { found: false, providerAmountMinor: null, providerStatus: null };
      }
    }
    return { found: false, providerAmountMinor: null, providerStatus: null };
  }
}
