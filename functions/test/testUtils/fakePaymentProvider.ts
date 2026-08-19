// -----------------------------------------------------------------------------
// FakePaymentProvider — double de test DÉTERMINISTE pour `PaymentProvider`.
//
// RÉSERVÉ AUX TESTS D'INTÉGRATION (test/integration/*.test.ts) exécutés
// contre l'émulateur Firestore/Auth, qui ne dispose d'AUCUNE vraie clé
// Stripe. Injecté via `setPaymentProviderForTesting()`
// (`src/payment/paymentProviderFactory.ts`) — CE MÉCANISME N'EST JAMAIS
// UTILISÉ PAR UN CHEMIN DE CODE DE PRODUCTION.
//
// Objectif : vérifier l'ORCHESTRATION réelle (transactions Firestore,
// machine d'état des paiements, écritures du ledger, compensation en cas
// d'échec) SANS jamais appeler le réseau Stripe réel. Chaque méthode réussit
// par défaut de façon prévisible ; les scénarios d'échec (carte refusée,
// capture refusée) sont simulés via les options du constructeur pour
// permettre des tests négatifs ciblés (Phase 6, points 5 et 22).
// -----------------------------------------------------------------------------

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
  PaymentProvider,
  PaymentStatusResult,
  PayoutStatusResult,
  ProcessWebhookResult,
  ReconcileTransactionParams,
  ReconcileTransactionResult,
  RefundPaymentParams,
  RefundPaymentResult,
} from "../../src/payment/paymentProvider";

export interface FakePaymentProviderOptions {
  /** Si vrai, `authorizePayment()` renvoie un échec déterministe (carte refusée simulée). */
  forceAuthorizeFailure?: boolean;
  /** Si vrai, `capturePayment()` renvoie un échec déterministe. */
  forceCaptureFailure?: boolean;
  /** Si vrai, `refundPayment()` renvoie un échec déterministe (refus provider simulé). */
  forceRefundFailure?: boolean;
  /** Code d'échec renvoyé quand `forceAuthorizeFailure`/`forceCaptureFailure`/`forceRefundFailure` est actif. */
  failureCode?: string;
  /** Message d'échec renvoyé quand `forceAuthorizeFailure`/`forceCaptureFailure`/`forceRefundFailure` est actif. */
  failureMessage?: string;
}

let counter = 0;
function nextId(prefix: string): string {
  counter += 1;
  return `fake_${prefix}_${Date.now()}_${counter}`;
}

export class FakePaymentProvider extends PaymentProvider {
  constructor(private readonly options: FakePaymentProviderOptions = {}) {
    super();
  }

  async createCustomer(params: CreateCustomerParams): Promise<CreateCustomerResult> {
    return { providerCustomerId: `fake_cus_${params.userId}` };
  }

  async attachPaymentMethod(
    params: AttachPaymentMethodParams
  ): Promise<AttachPaymentMethodResult> {
    return { success: true, providerPaymentMethodId: params.providerPaymentMethodId };
  }

  async createPayment(_params: CreatePaymentParams): Promise<CreatePaymentResult> {
    return { providerPaymentIntentId: nextId("pi"), status: "requires_capture" };
  }

  async authorizePayment(_params: AuthorizePaymentParams): Promise<AuthorizePaymentResult> {
    if (this.options.forceAuthorizeFailure) {
      return {
        success: false,
        status: "failed",
        authorizationExpiresAt: null,
        failureCode: this.options.failureCode ?? "card_declined",
        failureMessage: this.options.failureMessage ?? "Carte refusée (simulation de test).",
      };
    }
    return {
      success: true,
      status: "requires_capture",
      authorizationExpiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
    };
  }

  async capturePayment(params: CapturePaymentParams): Promise<CapturePaymentResult> {
    if (this.options.forceCaptureFailure) {
      return {
        success: false,
        status: "failed",
        amountCapturedMinor: 0,
        providerChargeId: null,
        failureCode: this.options.failureCode ?? "capture_failed",
        failureMessage: this.options.failureMessage ?? "Capture refusée (simulation de test).",
      };
    }
    return {
      success: true,
      status: "succeeded",
      amountCapturedMinor: params.amountToCaptureMinor,
      providerChargeId: nextId("ch"),
    };
  }

  async cancelAuthorization(
    _params: CancelAuthorizationParams
  ): Promise<CancelAuthorizationResult> {
    return { success: true, status: "canceled" };
  }

  async refundPayment(_params: RefundPaymentParams): Promise<RefundPaymentResult> {
    if (this.options.forceRefundFailure) {
      return {
        success: false,
        providerRefundId: null,
        status: "failed",
        failureCode: this.options.failureCode ?? "refund_failed",
      };
    }
    return {
      success: true,
      providerRefundId: nextId("re"),
      status: "succeeded",
    };
  }

  async createDriverAccount(
    params: CreateDriverAccountParams
  ): Promise<CreateDriverAccountResult> {
    return {
      connectedAccountId: `fake_acct_${params.driverId}`,
      onboardingUrl: null,
    };
  }

  async createDriverPayout(
    _params: CreateDriverPayoutParams
  ): Promise<CreateDriverPayoutResult> {
    return { success: true, providerPayoutId: nextId("po"), status: "paid" };
  }

  async getPaymentStatus(_providerPaymentIntentId: string): Promise<PaymentStatusResult> {
    return {
      status: "succeeded",
      amountAuthorizedMinor: 0,
      amountCapturedMinor: 0,
      amountRefundedMinor: 0,
    };
  }

  async getPayoutStatus(_providerPayoutId: string): Promise<PayoutStatusResult> {
    return { status: "paid", arrivalDate: new Date() };
  }

  async processWebhook(
    _rawBody: Buffer,
    _signatureHeader: string
  ): Promise<ProcessWebhookResult> {
    return { eventId: nextId("evt"), eventType: "fake.event", handled: true };
  }

  async reconcileTransaction(
    _params: ReconcileTransactionParams
  ): Promise<ReconcileTransactionResult> {
    return { providerAmountMinor: null, providerStatus: null, found: false };
  }
}

/**
 * Seed d'un `payment_profiles/{customerId}` minimal et cohérent, prêt à
 * satisfaire la précondition de `createDeliveryRequest.ts` (point 1/4) ET à
 * être consommé par `createAndAuthorizeMissionPayment()`
 * (`paymentOrchestration.ts`). Réutilisé par les 3 fichiers de test
 * d'intégration affectés par le câblage réel des paiements Phase 6.
 */
export function buildFakePaymentProfile(customerId: string): Record<string, unknown> {
  const now = new Date();
  return {
    customer_id: customerId,
    provider: "stripe",
    provider_customer_id: `fake_cus_${customerId}`,
    default_payment_method_id: `fake_pm_${customerId}`,
    created_at: now,
    updated_at: now,
  };
}
