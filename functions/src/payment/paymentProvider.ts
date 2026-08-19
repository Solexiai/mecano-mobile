// -----------------------------------------------------------------------------
// PaymentProvider (serveur) — abstraction provider-agnostic, PHASE 6.
//
// Équivalent server-side de `lib/backend/payment/payment_provider.dart`
// (qui documente le CONTRAT côté client, jamais instancié avec une vraie
// clé). CETTE interface, elle, EST implémentée réellement côté serveur
// (voir `stripeProvider.ts`), et c'est la SEULE porte d'entrée que les
// Cloud Functions utilisent pour tout mouvement d'argent réel.
//
// Changer de fournisseur de paiement plus tard = écrire une nouvelle classe
// qui implémente `PaymentProvider`, sans toucher à la logique métier des
// Cloud Functions (acceptDelivery, completeDelivery, processRefund, etc.).
//
// Toutes les valeurs monétaires sont en UNITÉS MINEURES ENTIÈRES (cents) —
// voir `lib/money.ts`. Aucune méthode ne prend/retourne un montant flottant.
// -----------------------------------------------------------------------------

export interface CreateCustomerResult {
  success: boolean;
  providerCustomerId?: string;
  errorCode?: string;
  errorMessage?: string;
}

export interface AttachPaymentMethodResult {
  success: boolean;
  providerPaymentMethodId?: string;
  errorCode?: string;
  errorMessage?: string;
}

export interface CreatePaymentResult {
  success: boolean;
  providerPaymentIntentId?: string;
  status?: string;
  errorCode?: string;
  errorMessage?: string;
}

export interface AuthorizePaymentResult {
  success: boolean;
  providerPaymentIntentId?: string;
  status?: string;
  authorizationExpiresAtMillis?: number;
  errorCode?: string;
  errorMessage?: string;
}

export interface CapturePaymentResult {
  success: boolean;
  providerChargeId?: string;
  amountCapturedMinor?: number;
  status?: string;
  errorCode?: string;
  errorMessage?: string;
}

export interface CancelAuthorizationResult {
  success: boolean;
  errorCode?: string;
  errorMessage?: string;
}

export interface RefundPaymentResult {
  success: boolean;
  providerRefundId?: string;
  amountRefundedMinor?: number;
  errorCode?: string;
  errorMessage?: string;
}

export interface CreateDriverAccountResult {
  success: boolean;
  connectedAccountId?: string;
  onboardingUrl?: string;
  errorCode?: string;
  errorMessage?: string;
}

export interface CreateDriverPayoutResult {
  success: boolean;
  providerPayoutId?: string;
  status?: string;
  errorCode?: string;
  errorMessage?: string;
}

export interface PaymentStatusResult {
  status: string;
  amountCapturedMinor?: number;
  amountRefundedMinor?: number;
  raw?: unknown;
}

export interface PayoutStatusResult {
  status: string;
  raw?: unknown;
}

export interface ReconcileTransactionResult {
  matches: boolean;
  providerAmountMinor?: number;
  ledgerAmountMinor?: number;
  discrepancyMinor?: number;
  details?: string;
}

export interface WebhookProcessResult {
  eventType: string;
  providerEventId: string;
  handled: boolean;
  relatedPaymentId?: string | null;
  relatedMissionId?: string | null;
}

/**
 * Contrat complet requis par la Phase 6 (point 2 du cahier des charges) —
 * 13 méthodes minimum.
 */
export interface PaymentProvider {
  createCustomer(params: {
    customerId: string;
    email?: string;
    fullName?: string;
  }): Promise<CreateCustomerResult>;

  attachPaymentMethod(params: {
    providerCustomerId: string;
    paymentMethodToken: string; // token opaque généré côté client par le SDK fournisseur, jamais une carte brute
  }): Promise<AttachPaymentMethodResult>;

  createPayment(params: {
    missionId: string;
    customerId: string;
    providerCustomerId: string;
    providerPaymentMethodId: string;
    amountMinor: number;
    currency: string;
    connectedAccountId: string;
    applicationFeeMinor: number;
    idempotencyKey: string;
  }): Promise<CreatePaymentResult>;

  authorizePayment(params: {
    providerPaymentIntentId: string;
    idempotencyKey: string;
  }): Promise<AuthorizePaymentResult>;

  capturePayment(params: {
    providerPaymentIntentId: string;
    amountToCaptureMinor: number;
    idempotencyKey: string;
  }): Promise<CapturePaymentResult>;

  cancelAuthorization(params: {
    providerPaymentIntentId: string;
    idempotencyKey: string;
  }): Promise<CancelAuthorizationResult>;

  refundPayment(params: {
    providerChargeId: string;
    amountMinor: number;
    reverseTransfer: boolean;
    refundApplicationFee: boolean;
    idempotencyKey: string;
  }): Promise<RefundPaymentResult>;

  createDriverAccount(params: {
    driverId: string;
    email?: string;
    country?: string;
  }): Promise<CreateDriverAccountResult>;

  createDriverPayout(params: {
    connectedAccountId: string;
    amountMinor: number;
    currency: string;
    idempotencyKey: string;
  }): Promise<CreateDriverPayoutResult>;

  getPaymentStatus(providerPaymentIntentId: string): Promise<PaymentStatusResult>;

  getPayoutStatus(providerPayoutId: string): Promise<PayoutStatusResult>;

  processWebhook(rawBody: Buffer | string, signatureHeader: string): Promise<WebhookProcessResult>;

  reconcileTransaction(params: {
    providerPaymentIntentId: string;
    ledgerAmountMinor: number;
  }): Promise<ReconcileTransactionResult>;
}

/**
 * Stub explicite — utilisé si aucune clé Stripe n'est configurée dans
 * Secret Manager. Échoue proprement (jamais de simulation de succès).
 */
export class NotConfiguredPaymentProvider implements PaymentProvider {
  private fail<T extends { success?: boolean }>(): Promise<T> {
    return Promise.resolve({
      success: false,
      errorCode: "payment_provider_not_configured",
      errorMessage:
        "Aucune clé Stripe configurée dans Secret Manager (STRIPE_SECRET_KEY). Voir docs/PAYMENT_ARCHITECTURE.md §9.",
    } as unknown as T);
  }

  createCustomer() {
    return this.fail<CreateCustomerResult>();
  }
  attachPaymentMethod() {
    return this.fail<AttachPaymentMethodResult>();
  }
  createPayment() {
    return this.fail<CreatePaymentResult>();
  }
  authorizePayment() {
    return this.fail<AuthorizePaymentResult>();
  }
  capturePayment() {
    return this.fail<CapturePaymentResult>();
  }
  cancelAuthorization() {
    return this.fail<CancelAuthorizationResult>();
  }
  refundPayment() {
    return this.fail<RefundPaymentResult>();
  }
  createDriverAccount() {
    return this.fail<CreateDriverAccountResult>();
  }
  createDriverPayout() {
    return this.fail<CreateDriverPayoutResult>();
  }
  getPaymentStatus(): Promise<PaymentStatusResult> {
    return Promise.resolve({ status: "unknown" });
  }
  getPayoutStatus(): Promise<PayoutStatusResult> {
    return Promise.resolve({ status: "unknown" });
  }
  processWebhook(): Promise<WebhookProcessResult> {
    return Promise.resolve({
      eventType: "unknown",
      providerEventId: "unknown",
      handled: false,
    });
  }
  reconcileTransaction(): Promise<ReconcileTransactionResult> {
    return Promise.resolve({ matches: false, details: "payment_provider_not_configured" });
  }
}
