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
  ListProviderPaymentsResult,
  ListProviderPayoutsResult,
  ListProviderRefundsResult,
  ListProviderTransactionsParams,
  PaymentProvider,
  PaymentStatusResult,
  PayoutStatusResult,
  ProcessWebhookResult,
  ProviderPaymentSummary,
  ProviderPayoutSummary,
  ProviderRefundSummary,
  ReconcileTransactionParams,
  ReconcileTransactionResult,
  RefundPaymentParams,
  RefundPaymentResult,
} from "../../src/payment/paymentProvider";
import { StripeEnvironment } from "../../src/lib/stripeEnvironment";

export interface FakePaymentProviderOptions {
  /** Si vrai, `authorizePayment()` renvoie un échec déterministe (carte refusée simulée). */
  forceAuthorizeFailure?: boolean;
  /** Si vrai, `capturePayment()` renvoie un échec déterministe. */
  forceCaptureFailure?: boolean;
  /** Si vrai, `refundPayment()` renvoie un échec déterministe (refus provider simulé). */
  forceRefundFailure?: boolean;
  /** Si vrai, `createDriverPayout()` renvoie un échec déterministe (versement refusé simulé, ex: compte connecté invalide côté Stripe). */
  forceCreateDriverPayoutFailure?: boolean;
  /** Code d'échec renvoyé quand `forceAuthorizeFailure`/`forceCaptureFailure`/`forceRefundFailure`/`forceCreateDriverPayoutFailure` est actif. */
  failureCode?: string;
  /** Message d'échec renvoyé quand `forceAuthorizeFailure`/`forceCaptureFailure`/`forceRefundFailure` est actif. */
  failureMessage?: string;
  // ---- BLOC G (test uniquement) — simulation déterministe du "monde
  // Provider" pour tester le moteur de réconciliation (reconciliationEngine.ts)
  // SANS jamais appeler le réseau Stripe réel. Chaque tableau représente
  // EXACTEMENT ce que `listProviderPayments/Payouts/Refunds()` renverra ;
  // `reconcileTransaction()` résout aussi ses réponses depuis ces mêmes
  // tableaux (résolution par ID), garantissant une vue Provider cohérente
  // entre listing et vérification ponctuelle dans un même test.
  providerPayments?: ProviderPaymentSummary[];
  providerPayouts?: ProviderPayoutSummary[];
  providerRefunds?: ProviderRefundSummary[];
}

let counter = 0;
function nextId(prefix: string): string {
  counter += 1;
  return `fake_${prefix}_${Date.now()}_${counter}`;
}

export class FakePaymentProvider extends PaymentProvider {
  // 🔒 Phase 8B (item f, isolation d'environnement) — le FakePaymentProvider
  // ne manipule JAMAIS de fonds réels : toujours "test" par convention (voir
  // src/payment/paymentProvider.ts, doc du champ `environment`). Jamais
  // reconfigurable — un test qui aurait besoin de simuler un mélange
  // test/live doit construire deux FakePaymentProvider distincts et vérifier
  // le rejet via assertStripeReferenceEnvironmentConsistency() directement,
  // jamais en modifiant cette valeur.
  readonly environment: StripeEnvironment = "test";

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
    if (this.options.forceCreateDriverPayoutFailure) {
      return {
        success: false,
        providerPayoutId: null,
        status: "failed",
        failureCode: this.options.failureCode ?? "payout_provider_declined",
      };
    }
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
    params: ReconcileTransactionParams
  ): Promise<ReconcileTransactionResult> {
    if (params.providerPaymentIntentId) {
      const found = (this.options.providerPayments ?? []).find(
        (p) => p.providerPaymentIntentId === params.providerPaymentIntentId
      );
      if (found) {
        return { found: true, providerAmountMinor: found.amountMinor, providerStatus: found.status };
      }
    }
    if (params.providerPayoutId) {
      const found = (this.options.providerPayouts ?? []).find(
        (p) => p.providerPayoutId === params.providerPayoutId
      );
      if (found) {
        return { found: true, providerAmountMinor: found.amountMinor, providerStatus: found.status };
      }
    }
    if (params.providerRefundId) {
      const found = (this.options.providerRefunds ?? []).find(
        (r) => r.providerRefundId === params.providerRefundId
      );
      if (found) {
        return { found: true, providerAmountMinor: found.amountMinor, providerStatus: found.status };
      }
    }
    return { providerAmountMinor: null, providerStatus: null, found: false };
  }

  // ---- BLOC G (test uniquement) — listing simulé depuis les options ----
  async listProviderPayments(
    _params: ListProviderTransactionsParams
  ): Promise<ListProviderPaymentsResult> {
    return { payments: this.options.providerPayments ?? [], nextPageToken: null };
  }

  async listProviderPayouts(
    _params: ListProviderTransactionsParams
  ): Promise<ListProviderPayoutsResult> {
    return { payouts: this.options.providerPayouts ?? [], nextPageToken: null };
  }

  async listProviderRefunds(
    _params: ListProviderTransactionsParams
  ): Promise<ListProviderRefundsResult> {
    return { refunds: this.options.providerRefunds ?? [], nextPageToken: null };
  }
}

/**
 * 🔒 Phase 8B item 4 — variante de test EXPLICITEMENT dédiée à simuler un
 * provider actif en environnement LIVE, pour les tests d'intégration du
 * garde-fou d'isolation d'environnement (assertStripeReferenceEnvironmentConsistencyOrLog)
 * sur les 4 opérations financières. `FakePaymentProvider` reste
 * délibérément figé sur `"test"` (voir sa doc ci-dessus, jamais modifiée) —
 * cette sous-classe SÉPARÉE, réservée aux tests de garde-fou, ne redéfinit
 * QUE `environment`, en héritant de tout le reste (méthodes déterministes)
 * de `FakePaymentProvider` sans aucune duplication.
 */
export class FakeLivePaymentProvider extends FakePaymentProvider {
  readonly environment: StripeEnvironment = "live";
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
