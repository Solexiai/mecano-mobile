// -----------------------------------------------------------------------------
// paymentProvider.ts — Abstraction PaymentProvider CÔTÉ SERVEUR (point 2 du
// cahier des charges Phase 6).
//
// 13 méthodes explicitement requises :
//  1. createCustomer
//  2. attachPaymentMethod
//  3. createPayment
//  4. authorizePayment
//  5. capturePayment
//  6. cancelAuthorization
//  7. refundPayment
//  8. createDriverAccount
//  9. createDriverPayout
// 10. getPaymentStatus
// 11. getPayoutStatus
// 12. processWebhook
// 13. reconcileTransaction
//
// Toutes les montants en paramètre/retour sont en UNITÉS MINEURES ENTIÈRES
// (cents) — voir lib/money.ts. Aucune implémentation ne doit jamais stocker
// de données de carte sensibles (numéro complet, CVC) — uniquement des
// références opaques fournies par le fournisseur (point 4).
//
// Cette interface est l'équivalent serveur EXACT de
// `lib/backend/payment/payment_provider.dart` (qui documente le contrat
// côté Flutter, jamais instancié avec une vraie clé secrète). Toute
// implémentation réelle (StripeProvider) vit exclusivement ici.
// -----------------------------------------------------------------------------

import { Currency } from "../lib/money";

export interface CreateCustomerParams {
  userId: string;
  email: string;
  displayName: string;
}
export interface CreateCustomerResult {
  providerCustomerId: string;
}

export interface AttachPaymentMethodParams {
  providerCustomerId: string;
  providerPaymentMethodId: string;
}
export interface AttachPaymentMethodResult {
  success: boolean;
  providerPaymentMethodId: string;
}

export interface CreatePaymentParams {
  providerCustomerId: string;
  providerPaymentMethodId: string;
  amountMinor: number;
  currency: Currency;
  connectedAccountId: string | null;
  applicationFeeMinor: number;
  idempotencyKey: string;
  metadata: Record<string, string>;
}
export interface CreatePaymentResult {
  providerPaymentIntentId: string;
  status: string; // statut brut du provider, mappé par l'appelant vers PaymentStatus
}

export interface AuthorizePaymentParams {
  providerPaymentIntentId: string;
  idempotencyKey: string;
}
export interface AuthorizePaymentResult {
  success: boolean;
  status: string;
  authorizationExpiresAt: Date | null;
  failureCode?: string | null;
  failureMessage?: string | null;
}

export interface CapturePaymentParams {
  providerPaymentIntentId: string;
  amountToCaptureMinor: number; // peut être <= montant autorisé (capture partielle)
  idempotencyKey: string;
}
export interface CapturePaymentResult {
  success: boolean;
  status: string;
  amountCapturedMinor: number;
  providerChargeId: string | null;
  failureCode?: string | null;
  failureMessage?: string | null;
}

export interface CancelAuthorizationParams {
  providerPaymentIntentId: string;
  idempotencyKey: string;
}
export interface CancelAuthorizationResult {
  success: boolean;
  status: string;
}

export interface RefundPaymentParams {
  providerPaymentIntentId: string;
  amountMinor: number;
  reverseTransfer: boolean;
  refundApplicationFee: boolean;
  idempotencyKey: string;
}
export interface RefundPaymentResult {
  success: boolean;
  providerRefundId: string | null;
  status: string;
  failureCode?: string | null;
}

export interface CreateDriverAccountParams {
  driverId: string;
  email: string;
  country: string; // 'CA'
}
export interface CreateDriverAccountResult {
  connectedAccountId: string;
  onboardingUrl: string | null; // lien d'onboarding hébergé Stripe (Express)
}

export interface CreateDriverPayoutParams {
  connectedAccountId: string;
  amountMinor: number;
  currency: Currency;
  idempotencyKey: string;
}
export interface CreateDriverPayoutResult {
  success: boolean;
  providerPayoutId: string | null;
  status: string;
  failureCode?: string | null;
}

export interface PaymentStatusResult {
  status: string;
  amountAuthorizedMinor: number;
  amountCapturedMinor: number;
  amountRefundedMinor: number;
}

export interface PayoutStatusResult {
  status: string;
  arrivalDate: Date | null;
  failureCode?: string | null;
}

export interface ProcessWebhookResult {
  eventId: string;
  eventType: string;
  handled: boolean;
}

export interface ReconcileTransactionParams {
  providerPaymentIntentId?: string | null;
  providerPayoutId?: string | null;
}
export interface ReconcileTransactionResult {
  providerAmountMinor: number | null;
  providerStatus: string | null;
  found: boolean;
}

export abstract class PaymentProvider {
  abstract createCustomer(params: CreateCustomerParams): Promise<CreateCustomerResult>;

  abstract attachPaymentMethod(
    params: AttachPaymentMethodParams
  ): Promise<AttachPaymentMethodResult>;

  abstract createPayment(params: CreatePaymentParams): Promise<CreatePaymentResult>;

  abstract authorizePayment(params: AuthorizePaymentParams): Promise<AuthorizePaymentResult>;

  abstract capturePayment(params: CapturePaymentParams): Promise<CapturePaymentResult>;

  abstract cancelAuthorization(
    params: CancelAuthorizationParams
  ): Promise<CancelAuthorizationResult>;

  abstract refundPayment(params: RefundPaymentParams): Promise<RefundPaymentResult>;

  abstract createDriverAccount(
    params: CreateDriverAccountParams
  ): Promise<CreateDriverAccountResult>;

  abstract createDriverPayout(
    params: CreateDriverPayoutParams
  ): Promise<CreateDriverPayoutResult>;

  abstract getPaymentStatus(providerPaymentIntentId: string): Promise<PaymentStatusResult>;

  abstract getPayoutStatus(providerPayoutId: string): Promise<PayoutStatusResult>;

  abstract processWebhook(rawBody: Buffer, signatureHeader: string): Promise<ProcessWebhookResult>;

  abstract reconcileTransaction(
    params: ReconcileTransactionParams
  ): Promise<ReconcileTransactionResult>;
}

/**
 * Erreur explicite levée quand aucun fournisseur n'est configuré
 * (STRIPE_SECRET_KEY absent de Secret Manager). Toute tentative
 * d'utilisation échoue PROPREMENT — jamais de simulation silencieuse d'un
 * paiement réussi. Voir docs/PAYMENT_ARCHITECTURE.md §9.
 */
export class PaymentProviderNotConfiguredError extends Error {
  constructor() {
    super(
      "Aucun fournisseur de paiement n'est configuré (STRIPE_SECRET_KEY absent). " +
        "Aucune opération financière réelle ne peut être exécutée."
    );
    this.name = "PaymentProviderNotConfiguredError";
  }
}

export class NotConfiguredPaymentProvider extends PaymentProvider {
  async createCustomer(): Promise<CreateCustomerResult> {
    throw new PaymentProviderNotConfiguredError();
  }
  async attachPaymentMethod(): Promise<AttachPaymentMethodResult> {
    throw new PaymentProviderNotConfiguredError();
  }
  async createPayment(): Promise<CreatePaymentResult> {
    throw new PaymentProviderNotConfiguredError();
  }
  async authorizePayment(): Promise<AuthorizePaymentResult> {
    throw new PaymentProviderNotConfiguredError();
  }
  async capturePayment(): Promise<CapturePaymentResult> {
    throw new PaymentProviderNotConfiguredError();
  }
  async cancelAuthorization(): Promise<CancelAuthorizationResult> {
    throw new PaymentProviderNotConfiguredError();
  }
  async refundPayment(): Promise<RefundPaymentResult> {
    throw new PaymentProviderNotConfiguredError();
  }
  async createDriverAccount(): Promise<CreateDriverAccountResult> {
    throw new PaymentProviderNotConfiguredError();
  }
  async createDriverPayout(): Promise<CreateDriverPayoutResult> {
    throw new PaymentProviderNotConfiguredError();
  }
  async getPaymentStatus(): Promise<PaymentStatusResult> {
    throw new PaymentProviderNotConfiguredError();
  }
  async getPayoutStatus(): Promise<PayoutStatusResult> {
    throw new PaymentProviderNotConfiguredError();
  }
  async processWebhook(): Promise<ProcessWebhookResult> {
    throw new PaymentProviderNotConfiguredError();
  }
  async reconcileTransaction(): Promise<ReconcileTransactionResult> {
    throw new PaymentProviderNotConfiguredError();
  }
}
