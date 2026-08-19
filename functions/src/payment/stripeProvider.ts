// -----------------------------------------------------------------------------
// StripeProvider — implémentation RÉELLE de PaymentProvider via Stripe Connect.
//
// Architecture retenue : voir docs/PAYMENT_ARCHITECTURE.md.
//   - Destination charges (charge sur le compte plateforme,
//     transfer_data.destination = compte chauffeur connecté).
//   - capture_method: 'manual' (autorisation puis capture explicite).
//   - Comptes chauffeur : Express accounts (Stripe Connect).
//
// 🔒 SECRETS : la clé secrète Stripe n'est JAMAIS codée en dur ni committée.
// Elle est lue exclusivement via `defineSecret("STRIPE_SECRET_KEY")`
// (Firebase Functions v2 params -> Secret Manager). Si le secret n'est pas
// configuré, `getStripeClient()` lève une erreur explicite — aucun appel
// Stripe silencieusement simulé.
// -----------------------------------------------------------------------------

import Stripe from "stripe";
import { defineSecret } from "firebase-functions/params";
import {
  AttachPaymentMethodResult,
  AuthorizePaymentResult,
  CancelAuthorizationResult,
  CapturePaymentResult,
  CreateCustomerResult,
  CreateDriverAccountResult,
  CreateDriverPayoutResult,
  CreatePaymentResult,
  PaymentProvider,
  PaymentStatusResult,
  PayoutStatusResult,
  ReconcileTransactionResult,
  RefundPaymentResult,
  WebhookProcessResult,
} from "./paymentProvider";

export const STRIPE_SECRET_KEY = defineSecret("STRIPE_SECRET_KEY");
export const STRIPE_WEBHOOK_SECRET = defineSecret("STRIPE_WEBHOOK_SECRET");

let cachedClient: Stripe | null = null;

/** Lève une erreur explicite si STRIPE_SECRET_KEY n'est pas configuré. */
export function getStripeClient(): Stripe {
  if (cachedClient) return cachedClient;
  let key: string;
  try {
    key = STRIPE_SECRET_KEY.value();
  } catch {
    key = "";
  }
  if (!key) {
    throw new Error(
      "STRIPE_SECRET_KEY n'est pas configuré dans Secret Manager. " +
        "Voir docs/PAYMENT_ARCHITECTURE.md §9 (action externe requise de Daniel)."
    );
  }
  cachedClient = new Stripe(key, { apiVersion: "2026-07-29.dahlia" });
  return cachedClient;
}

export function isStripeConfigured(): boolean {
  try {
    return !!STRIPE_SECRET_KEY.value();
  } catch {
    return false;
  }
}

export class StripeProvider implements PaymentProvider {
  private get client(): Stripe {
    return getStripeClient();
  }

  async createCustomer(params: {
    customerId: string;
    email?: string;
    fullName?: string;
  }): Promise<CreateCustomerResult> {
    try {
      const customer = await this.client.customers.create(
        { email: params.email, name: params.fullName, metadata: { movik_customer_id: params.customerId } },
        { idempotencyKey: `create_customer:${params.customerId}` }
      );
      return { success: true, providerCustomerId: customer.id };
    } catch (err) {
      return this.mapError(err);
    }
  }

  async attachPaymentMethod(params: {
    providerCustomerId: string;
    paymentMethodToken: string;
  }): Promise<AttachPaymentMethodResult> {
    try {
      const pm = await this.client.paymentMethods.attach(params.paymentMethodToken, {
        customer: params.providerCustomerId,
      });
      return { success: true, providerPaymentMethodId: pm.id };
    } catch (err) {
      return this.mapError(err);
    }
  }

  async createPayment(params: {
    missionId: string;
    customerId: string;
    providerCustomerId: string;
    providerPaymentMethodId: string;
    amountMinor: number;
    currency: string;
    connectedAccountId: string;
    applicationFeeMinor: number;
    idempotencyKey: string;
  }): Promise<CreatePaymentResult> {
    try {
      const intent = await this.client.paymentIntents.create(
        {
          amount: params.amountMinor,
          currency: params.currency.toLowerCase(),
          customer: params.providerCustomerId,
          payment_method: params.providerPaymentMethodId,
          capture_method: "manual",
          confirmation_method: "automatic",
          confirm: false,
          transfer_data: { destination: params.connectedAccountId },
          application_fee_amount: params.applicationFeeMinor,
          metadata: { movik_mission_id: params.missionId, movik_customer_id: params.customerId },
        },
        { idempotencyKey: params.idempotencyKey }
      );
      return { success: true, providerPaymentIntentId: intent.id, status: intent.status };
    } catch (err) {
      return this.mapError(err);
    }
  }

  async authorizePayment(params: {
    providerPaymentIntentId: string;
    idempotencyKey: string;
  }): Promise<AuthorizePaymentResult> {
    try {
      const intent = await this.client.paymentIntents.confirm(
        params.providerPaymentIntentId,
        {},
        { idempotencyKey: params.idempotencyKey }
      );
      // Fenêtre de validité d'autorisation typique (réseau-dépendant, voir
      // docs.stripe.com/payments/capture-later) — 7 jours retenu comme
      // borne prudente (Mastercard/Amex/Discover 7j, Visa ~5j pour
      // card-not-present) ; la valeur réelle est celle renvoyée par le
      // réseau, ce champ est indicatif pour nos propres rappels internes.
      const authorizationExpiresAtMillis = Date.now() + 7 * 24 * 60 * 60 * 1000;
      return {
        success: intent.status === "requires_capture",
        providerPaymentIntentId: intent.id,
        status: intent.status,
        authorizationExpiresAtMillis,
      };
    } catch (err) {
      return this.mapError(err);
    }
  }

  async capturePayment(params: {
    providerPaymentIntentId: string;
    amountToCaptureMinor: number;
    idempotencyKey: string;
  }): Promise<CapturePaymentResult> {
    try {
      const intent = await this.client.paymentIntents.capture(
        params.providerPaymentIntentId,
        { amount_to_capture: params.amountToCaptureMinor },
        { idempotencyKey: params.idempotencyKey }
      );
      const chargeId =
        typeof intent.latest_charge === "string" ? intent.latest_charge : intent.latest_charge?.id;
      return {
        success: intent.status === "succeeded",
        providerChargeId: chargeId,
        amountCapturedMinor: intent.amount_received,
        status: intent.status,
      };
    } catch (err) {
      return this.mapError(err);
    }
  }

  async cancelAuthorization(params: {
    providerPaymentIntentId: string;
    idempotencyKey: string;
  }): Promise<CancelAuthorizationResult> {
    try {
      await this.client.paymentIntents.cancel(
        params.providerPaymentIntentId,
        {},
        { idempotencyKey: params.idempotencyKey }
      );
      return { success: true };
    } catch (err) {
      return this.mapError(err);
    }
  }

  async refundPayment(params: {
    providerChargeId: string;
    amountMinor: number;
    reverseTransfer: boolean;
    refundApplicationFee: boolean;
    idempotencyKey: string;
  }): Promise<RefundPaymentResult> {
    try {
      const refund = await this.client.refunds.create(
        {
          charge: params.providerChargeId,
          amount: params.amountMinor,
          reverse_transfer: params.reverseTransfer,
          refund_application_fee: params.refundApplicationFee,
        },
        { idempotencyKey: params.idempotencyKey }
      );
      return { success: refund.status !== "failed", providerRefundId: refund.id, amountRefundedMinor: refund.amount };
    } catch (err) {
      return this.mapError(err);
    }
  }

  async createDriverAccount(params: {
    driverId: string;
    email?: string;
    country?: string;
  }): Promise<CreateDriverAccountResult> {
    try {
      // Express account (Accounts v1 API) — voir docs/PAYMENT_ARCHITECTURE.md
      // §1 pour la justification et le point de vérification ouvert
      // (Accounts v2 recommandé pour les nouveaux intégrateurs).
      const account = await this.client.accounts.create(
        {
          type: "express",
          country: params.country ?? "CA",
          email: params.email,
          capabilities: { card_payments: { requested: true }, transfers: { requested: true } },
          metadata: { movik_driver_id: params.driverId },
        },
        { idempotencyKey: `create_driver_account:${params.driverId}` }
      );
      const link = await this.client.accountLinks.create({
        account: account.id,
        refresh_url: "https://movik.ca/chauffeur/onboarding/refresh",
        return_url: "https://movik.ca/chauffeur/onboarding/complete",
        type: "account_onboarding",
      });
      return { success: true, connectedAccountId: account.id, onboardingUrl: link.url };
    } catch (err) {
      return this.mapError(err);
    }
  }

  async createDriverPayout(params: {
    connectedAccountId: string;
    amountMinor: number;
    currency: string;
    idempotencyKey: string;
  }): Promise<CreateDriverPayoutResult> {
    try {
      // Payout déclenché explicitement sur le compte CONNECTÉ (schedule
      // manuel côté Movi-K, voir docs/PAYMENT_ARCHITECTURE.md §6).
      const payout = await this.client.payouts.create(
        { amount: params.amountMinor, currency: params.currency.toLowerCase() },
        { stripeAccount: params.connectedAccountId, idempotencyKey: params.idempotencyKey }
      );
      return { success: true, providerPayoutId: payout.id, status: payout.status };
    } catch (err) {
      return this.mapError(err);
    }
  }

  async getPaymentStatus(providerPaymentIntentId: string): Promise<PaymentStatusResult> {
    const intent = await this.client.paymentIntents.retrieve(providerPaymentIntentId);
    return {
      status: intent.status,
      amountCapturedMinor: intent.amount_received,
    };
  }

  async getPayoutStatus(providerPayoutId: string): Promise<PayoutStatusResult> {
    const payout = await this.client.payouts.retrieve(providerPayoutId);
    return { status: payout.status };
  }

  /**
   * Vérifie la signature du webhook (obligatoire — point 11) puis retourne
   * l'évènement décodé. L'idempotence effective (ne jamais traiter deux
   * fois le même `event.id`) est gérée par l'appelant
   * (`processPaymentWebhook.ts`), pas ici.
   */
  async processWebhook(rawBody: Buffer | string, signatureHeader: string): Promise<WebhookProcessResult> {
    let webhookSecret: string;
    try {
      webhookSecret = STRIPE_WEBHOOK_SECRET.value();
    } catch {
      webhookSecret = "";
    }
    if (!webhookSecret) {
      throw new Error("STRIPE_WEBHOOK_SECRET n'est pas configuré dans Secret Manager.");
    }
    // Lève si signature invalide — l'appelant HTTP doit répondre 400.
    const event = this.client.webhooks.constructEvent(rawBody, signatureHeader, webhookSecret);

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const obj = event.data.object as any;
    const relatedPaymentIntentId: string | undefined =
      obj?.payment_intent ?? (event.type.startsWith("payment_intent.") ? obj?.id : undefined);
    const missionId: string | null = obj?.metadata?.movik_mission_id ?? null;

    return {
      eventType: event.type,
      providerEventId: event.id,
      handled: true,
      relatedPaymentId: relatedPaymentIntentId ?? null,
      relatedMissionId: missionId,
    };
  }

  async reconcileTransaction(params: {
    providerPaymentIntentId: string;
    ledgerAmountMinor: number;
  }): Promise<ReconcileTransactionResult> {
    const intent = await this.client.paymentIntents.retrieve(params.providerPaymentIntentId);
    const providerAmountMinor = intent.amount_received;
    const discrepancyMinor = providerAmountMinor - params.ledgerAmountMinor;
    return {
      matches: discrepancyMinor === 0,
      providerAmountMinor,
      ledgerAmountMinor: params.ledgerAmountMinor,
      discrepancyMinor,
    };
  }

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  private mapError(err: any): { success: false; errorCode: string; errorMessage: string } {
    const code = err?.code || err?.type || "stripe_error";
    const message = err?.message || "Erreur Stripe inconnue.";
    return { success: false, errorCode: code, errorMessage: message };
  }
}

/**
 * Factory — retourne StripeProvider si configuré, sinon
 * NotConfiguredPaymentProvider (jamais de simulation silencieuse).
 */
export function getPaymentProvider(): PaymentProvider {
  if (isStripeConfigured()) {
    return new StripeProvider();
  }
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const { NotConfiguredPaymentProvider } = require("./paymentProvider");
  return new NotConfiguredPaymentProvider();
}
