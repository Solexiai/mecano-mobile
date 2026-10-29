import type { CardSetup } from "../lib/bookingPayment";
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
import { StripeEnvironment } from "../lib/stripeEnvironment";

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
  /**
   * Optional Movi-K share for a PARTIAL capture of a destination charge (mission
   * fees, see lib/missionFees.ts). Omitted for a normal capture, which keeps the
   * application fee fixed when the payment was created.
   */
  applicationFeeMinor?: number;
  idempotencyKey: string;
}
export interface CapturePaymentResult {
  success: boolean;
  status: string;
  amountCapturedMinor: number;
  providerChargeId: string | null;
  failureCode?: string | null;
  failureMessage?: string | null;
  /**
   * PAY-11 (2026-10-27) — true quand le provider n'a PAS répondu (timeout,
   * erreur réseau, 5xx, rate limit) : la carte a peut-être été débitée. Ce
   * n'est PAS un refus ; l'appelant doit relire le statut provider plus tard
   * (même clé d'idempotence) au lieu de conclure à un échec.
   */
  indeterminate?: boolean;
}

/**
 * PAY-03 (2026-10-27) — débit DIRECT (sans autorisation préalable) du moyen
 * de paiement enregistré du client, utilisé UNIQUEMENT pour reprendre une
 * capture refusée après livraison : l'autorisation initiale est perdue ou
 * expirée, on crée un nouveau paiement off-session capturé immédiatement,
 * avec la même répartition (destination chauffeur + frais plateforme).
 */
export interface ChargeSavedPaymentMethodParams {
  providerCustomerId: string;
  providerPaymentMethodId: string;
  amountMinor: number;
  currency: Currency;
  connectedAccountId: string | null;
  applicationFeeMinor: number;
  idempotencyKey: string;
  metadata: Record<string, string>;
}
export interface ChargeSavedPaymentMethodResult {
  success: boolean;
  status: string;
  providerPaymentIntentId: string | null;
  providerChargeId: string | null;
  amountCapturedMinor: number;
  failureCode?: string | null;
  failureMessage?: string | null;
  /** Voir CapturePaymentResult.indeterminate. */
  indeterminate?: boolean;
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
  // 🔒 BLOC G (point 27) — extension du contrat reconcileTransaction() pour
  // couvrir aussi les remboursements individuels (anomalie 5 : "refund
  // Movi-K absent du provider"). N'existait pas dans le contrat initial des
  // 13 méthodes (qui ne couvrait que payment/payout) ; ajout MINIMAL et
  // rétro-compatible (paramètre optionnel supplémentaire, aucune signature
  // existante modifiée).
  providerRefundId?: string | null;
}
export interface ReconcileTransactionResult {
  providerAmountMinor: number | null;
  providerStatus: string | null;
  found: boolean;
}

// -----------------------------------------------------------------------------
// BLOC G (point 27, directive 38 points) — capacités de LISTING nécessaires
// à la réconciliation bidirectionnelle. `reconcileTransaction()` ne permet
// de vérifier QU'un identifiant déjà connu côté Movi-K (anomalies 2/3/5/8).
// Pour détecter une transaction qui existe chez le PROVIDER mais est
// TOTALEMENT ABSENTE de Movi-K (anomalies 1 et 4 — "provider payment/refund
// absent de Movi-K"), il faut pouvoir ÉNUMÉRER les transactions du provider
// sur une fenêtre temporelle, indépendamment de tout identifiant Movi-K.
// Ces méthodes sont un ajout EXPLICITE et documenté du contrat
// PaymentProvider (au-delà des 13 méthodes historiques) — jamais une
// capacité inventée : elles s'appuient exclusivement sur les endpoints de
// listing standard de Stripe (`paymentIntents.list`, `payouts.list`,
// `refunds.list`, tous documentés docs.stripe.com/api).
// -----------------------------------------------------------------------------

export interface ListProviderTransactionsParams {
  /** Borne inférieure (incluse) de la fenêtre de création, en millisecondes epoch. */
  sinceMillis: number;
  /** Borne supérieure (incluse) de la fenêtre de création, en millisecondes epoch. */
  untilMillis: number;
  /** Pagination — jeton de continuation renvoyé par un appel précédent. */
  pageToken?: string | null;
}

export interface ProviderPaymentSummary {
  providerPaymentIntentId: string;
  amountMinor: number;
  status: string;
  createdAtMillis: number;
}
export interface ListProviderPaymentsResult {
  payments: ProviderPaymentSummary[];
  nextPageToken: string | null;
}

export interface ProviderPayoutSummary {
  providerPayoutId: string;
  connectedAccountId: string | null;
  amountMinor: number;
  status: string;
  createdAtMillis: number;
}
export interface ListProviderPayoutsResult {
  payouts: ProviderPayoutSummary[];
  nextPageToken: string | null;
}

export interface ProviderRefundSummary {
  providerRefundId: string;
  providerPaymentIntentId: string | null;
  amountMinor: number;
  status: string;
  createdAtMillis: number;
}
export interface ListProviderRefundsResult {
  refunds: ProviderRefundSummary[];
  nextPageToken: string | null;
}

/** Frais de traitement d'un paiement, en unités mineures de `currency`. */
export interface ChargeProcessingFee {
  feeMinor: number;
  currency: string;
}

export abstract class PaymentProvider {
  /** Stripe's hosted receipt for a captured charge (2026-10-26). Read only:
   * never creates, captures or refunds anything. Null when Stripe has none. */
  async getChargeReceiptUrl(_providerChargeId: string): Promise<string | null> {
    void _providerChargeId;
    throw new PaymentProviderNotConfiguredError();
  }
  /** Frais réellement prélevés par le fournisseur sur un paiement encaissé
   * (2026-10-29). Lecture seule : ne crée, ne capture et ne rembourse rien.
   * Null quand l'information n'est pas (encore) disponible. */
  async getChargeProcessingFee(_providerChargeId: string): Promise<ChargeProcessingFee | null> {
    void _providerChargeId;
    return null;
  }
  async createCardSetup(_params: { customerId: string; userId: string; quoteId: string; returnUrl: string; locale: string }): Promise<CardSetup> {
    void _params;
    throw new PaymentProviderNotConfiguredError();
  }
  async getCardSetup(_id: string): Promise<CardSetup> { void _id; throw new PaymentProviderNotConfiguredError(); }

  // ---------------------------------------------------------------------
  // 🔒 Phase 8B (item f, isolation d'environnement) — CHAQUE implémentation
  // concrète DOIT exposer l'environnement Stripe (test|live) qu'elle
  // représente RÉELLEMENT, dérivé UNE SEULE FOIS à la construction (jamais
  // recalculé à la volée depuis une source qui pourrait diverger). C'est
  // LA source de vérité unique pour "quel est l'environnement actif en ce
  // moment" — voir lib/stripeEnvironment.ts,
  // `assertStripeReferenceEnvironmentConsistency()`, qui compare TOUJOURS
  // contre `getPaymentProvider().environment`, jamais contre une lecture
  // séparée de STRIPE_SECRET_KEY.
  //
  // `NotConfiguredPaymentProvider` (ci-dessous) et `FakePaymentProvider`
  // (test uniquement, voir test/testUtils/fakePaymentProvider.ts) exposent
  // tous deux "test" — aucun des deux ne manipule jamais de fonds réels,
  // et aucune donnée qu'ils produisent ne doit jamais être traitée comme
  // "live" par le garde-fou d'isolation.
  // ---------------------------------------------------------------------
  abstract readonly environment: StripeEnvironment;

  abstract createCustomer(params: CreateCustomerParams): Promise<CreateCustomerResult>;

  abstract attachPaymentMethod(
    params: AttachPaymentMethodParams
  ): Promise<AttachPaymentMethodResult>;

  abstract createPayment(params: CreatePaymentParams): Promise<CreatePaymentResult>;

  abstract authorizePayment(params: AuthorizePaymentParams): Promise<AuthorizePaymentResult>;

  abstract capturePayment(params: CapturePaymentParams): Promise<CapturePaymentResult>;

  /** PAY-03 — voir ChargeSavedPaymentMethodParams. Non abstraite pour ne pas
   *  casser les doubles de test existants ; StripeProvider l'implémente. */
  async chargeSavedPaymentMethod(_params: ChargeSavedPaymentMethodParams): Promise<ChargeSavedPaymentMethodResult> {
    void _params;
    throw new PaymentProviderNotConfiguredError();
  }

  abstract cancelAuthorization(
    params: CancelAuthorizationParams
  ): Promise<CancelAuthorizationResult>;

  abstract refundPayment(params: RefundPaymentParams): Promise<RefundPaymentResult>;

  abstract createDriverAccount(
    params: CreateDriverAccountParams
  ): Promise<CreateDriverAccountResult>;

  /** New hosted onboarding link for an existing connected account. Stripe
   *  links expire after a few minutes and work once, so a stored link can
   *  never be reused (2026-10-23). Null when the provider cannot make one. */
  abstract createDriverOnboardingLink(connectedAccountId: string): Promise<string | null>;

  abstract createDriverPayout(
    params: CreateDriverPayoutParams
  ): Promise<CreateDriverPayoutResult>;

  abstract getPaymentStatus(providerPaymentIntentId: string): Promise<PaymentStatusResult>;

  abstract getPayoutStatus(providerPayoutId: string): Promise<PayoutStatusResult>;

  abstract processWebhook(rawBody: Buffer, signatureHeader: string): Promise<ProcessWebhookResult>;

  abstract reconcileTransaction(
    params: ReconcileTransactionParams
  ): Promise<ReconcileTransactionResult>;

  // ---- BLOC G (point 27) — listing pour réconciliation bidirectionnelle ----
  abstract listProviderPayments(
    params: ListProviderTransactionsParams
  ): Promise<ListProviderPaymentsResult>;

  abstract listProviderPayouts(
    params: ListProviderTransactionsParams
  ): Promise<ListProviderPayoutsResult>;

  abstract listProviderRefunds(
    params: ListProviderTransactionsParams
  ): Promise<ListProviderRefundsResult>;
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
  // 🔒 Jamais utilisé pour une opération financière réelle (chaque méthode
  // lève immédiatement) — "test" par convention documentée ci-dessus.
  readonly environment: StripeEnvironment = "test";

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
  async createDriverOnboardingLink(): Promise<string | null> {
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
  async listProviderPayments(): Promise<ListProviderPaymentsResult> {
    throw new PaymentProviderNotConfiguredError();
  }
  async listProviderPayouts(): Promise<ListProviderPayoutsResult> {
    throw new PaymentProviderNotConfiguredError();
  }
  async listProviderRefunds(): Promise<ListProviderRefundsResult> {
    throw new PaymentProviderNotConfiguredError();
  }
}
