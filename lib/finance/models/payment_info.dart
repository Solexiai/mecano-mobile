// ---------------------------------------------------------------------------
// PaymentInfo — projection LECTURE SEULE du document `payments/{paymentId}`
// (Cloud Functions, voir `functions/src/lib/types.ts` -> `PaymentDoc`).
//
// RÈGLES CRITIQUES (Bloc J) :
// - Ce modèle ne fait QUE décrire la forme des données déjà écrites côté
//   serveur (`payment/paymentOrchestration.ts`, `processStripeWebhook.ts`).
//   Il ne recalcule JAMAIS un montant, un statut ou une date.
// - Toutes les valeurs monétaires sont en UNITÉS MINEURES ENTIÈRES (cents),
//   conformément à la convention `*_minor` de `PaymentDoc` (voir
//   `functions/src/lib/money.ts`) — contrairement à `FinancialSnapshot`
//   (unités majeures `double`), ce document Phase 6 est nativement en cents.
// - `refundedAt` n'existe PAS comme champ direct sur `PaymentDoc` — un
//   remboursement est un document `refunds/{refundId}` séparé (voir
//   `RefundInfo`). On expose donc ici `lastRefundAt`, dérivable UNIQUEMENT
//   en combinant ce paiement avec la liste de ses `RefundInfo` associés
//   (voir `MissionFinancePresenter` côté UI) — ce champ n'est PAS lu
//   directement depuis Firestore, il reste `null` par défaut au parsing
//   brut de `payments/{id}` et doit être renseigné explicitement par
//   l'appelant s'il dispose de cette information (voir `copyWith`).
// ---------------------------------------------------------------------------

import '../../models/enums.dart';
import '../../backend/models/firestore_date.dart';

class PaymentInfo {
  final String paymentId;
  final String missionId;
  final String customerId;

  /// Chauffeur assigné au moment de la création du paiement (`driver_id`
  /// sur `PaymentDoc`). Volontairement exposé mais NE DOIT PAS être utilisé
  /// pour un affichage financier détaillé côté client (voir exclusions
  /// Bloc J point 7 — aucune commission/payout chauffeur affichée).
  final String driverId;

  final PaymentStatus status;
  final String currency; // ex: 'CAD'

  final int amountAuthorizedMinor;
  final int amountCapturedMinor;
  final int amountRefundedMinor;

  /// Commission Movi-K + frais de service, en cents (`application_fee_minor`).
  /// Champ brut conservé pour complétude du modèle ; NE DOIT PAS être
  /// affiché tel quel au client (c'est un agrégat commission+frais côté
  /// plateforme, pas une ligne "frais client" — voir `customer_service_fee`
  /// du `FinancialSnapshot` pour la vraie ventilation client).
  final int applicationFeeMinor;

  final String provider; // 'stripe'
  final String? providerCustomerId;
  final String? providerPaymentMethodId;
  final String? providerPaymentIntentId;
  final String? providerChargeId;

  final String? failureCode;
  final String? failureMessage;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? authorizedAt;
  final DateTime? authorizationExpiresAt;
  final DateTime? capturedAt;
  final DateTime? cancelledAt;
  final DateTime? failedAt;

  /// Voir note d'en-tête : NON lu depuis `payments/{id}` — renseigné
  /// séparément par l'appelant à partir des `RefundInfo` associés, ou
  /// `null` si non calculé.
  final DateTime? lastRefundAt;

  const PaymentInfo({
    required this.paymentId,
    required this.missionId,
    required this.customerId,
    required this.driverId,
    required this.status,
    required this.currency,
    required this.amountAuthorizedMinor,
    required this.amountCapturedMinor,
    required this.amountRefundedMinor,
    required this.applicationFeeMinor,
    required this.provider,
    this.providerCustomerId,
    this.providerPaymentMethodId,
    this.providerPaymentIntentId,
    this.providerChargeId,
    this.failureCode,
    this.failureMessage,
    required this.createdAt,
    required this.updatedAt,
    this.authorizedAt,
    this.authorizationExpiresAt,
    this.capturedAt,
    this.cancelledAt,
    this.failedAt,
    this.lastRefundAt,
  });

  bool get isRefunded =>
      status == PaymentStatus.refunded || status == PaymentStatus.partiallyRefunded;
  bool get isPartiallyRefunded => status == PaymentStatus.partiallyRefunded;
  bool get isFailed => status == PaymentStatus.failed;
  bool get isCaptured => status == PaymentStatus.captured;
  bool get isAuthorized => status == PaymentStatus.authorized;
  bool get isPending =>
      status == PaymentStatus.pending; // valeur de repli fromFirestoreValue()

  /// Copie superficielle permettant à l'appelant d'attacher la date du
  /// dernier remboursement connu (dérivée de `RefundInfo`), sans jamais
  /// modifier les autres champs source-de-vérité serveur.
  PaymentInfo copyWithLastRefundAt(DateTime? value) => PaymentInfo(
        paymentId: paymentId,
        missionId: missionId,
        customerId: customerId,
        driverId: driverId,
        status: status,
        currency: currency,
        amountAuthorizedMinor: amountAuthorizedMinor,
        amountCapturedMinor: amountCapturedMinor,
        amountRefundedMinor: amountRefundedMinor,
        applicationFeeMinor: applicationFeeMinor,
        provider: provider,
        providerCustomerId: providerCustomerId,
        providerPaymentMethodId: providerPaymentMethodId,
        providerPaymentIntentId: providerPaymentIntentId,
        providerChargeId: providerChargeId,
        failureCode: failureCode,
        failureMessage: failureMessage,
        createdAt: createdAt,
        updatedAt: updatedAt,
        authorizedAt: authorizedAt,
        authorizationExpiresAt: authorizationExpiresAt,
        capturedAt: capturedAt,
        cancelledAt: cancelledAt,
        failedAt: failedAt,
        lastRefundAt: value,
      );

  Map<String, dynamic> toJson() => {
        'payment_id': paymentId,
        'mission_id': missionId,
        'customer_id': customerId,
        'driver_id': driverId,
        'status': status.firestoreValue,
        'currency': currency,
        'amount_authorized_minor': amountAuthorizedMinor,
        'amount_captured_minor': amountCapturedMinor,
        'amount_refunded_minor': amountRefundedMinor,
        'application_fee_minor': applicationFeeMinor,
        'provider': provider,
        'provider_customer_id': providerCustomerId,
        'provider_payment_method_id': providerPaymentMethodId,
        'provider_payment_intent_id': providerPaymentIntentId,
        'provider_charge_id': providerChargeId,
        'failure_code': failureCode,
        'failure_message': failureMessage,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'authorized_at': authorizedAt?.toIso8601String(),
        'authorization_expires_at': authorizationExpiresAt?.toIso8601String(),
        'captured_at': capturedAt?.toIso8601String(),
        'cancelled_at': cancelledAt?.toIso8601String(),
        'failed_at': failedAt?.toIso8601String(),
      };

  /// Parse un document `payments/{id}` réel. Toutes les lectures numériques
  /// utilisent un repli sûr (`as num? ?? 0`) et les statuts inconnus/absents
  /// retombent sur `PaymentStatus.pending` (voir `PaymentStatusX.fromFirestoreValue`)
  /// pour ne JAMAIS planter sur une ancienne mission ou un champ manquant.
  factory PaymentInfo.fromJson(Map<String, dynamic> json) {
    return PaymentInfo(
      paymentId: json['payment_id'] as String? ?? '',
      missionId: json['mission_id'] as String? ?? '',
      customerId: json['customer_id'] as String? ?? '',
      driverId: json['driver_id'] as String? ?? '',
      status: PaymentStatusX.fromFirestoreValue(json['status'] as String?),
      currency: json['currency'] as String? ?? 'CAD',
      amountAuthorizedMinor: (json['amount_authorized_minor'] as num? ?? 0).toInt(),
      amountCapturedMinor: (json['amount_captured_minor'] as num? ?? 0).toInt(),
      amountRefundedMinor: (json['amount_refunded_minor'] as num? ?? 0).toInt(),
      applicationFeeMinor: (json['application_fee_minor'] as num? ?? 0).toInt(),
      provider: json['provider'] as String? ?? 'stripe',
      providerCustomerId: json['provider_customer_id'] as String?,
      providerPaymentMethodId: json['provider_payment_method_id'] as String?,
      providerPaymentIntentId: json['provider_payment_intent_id'] as String?,
      providerChargeId: json['provider_charge_id'] as String?,
      failureCode: json['failure_code'] as String?,
      failureMessage: json['failure_message'] as String?,
      createdAt: parseFirestoreDate(json['created_at']) ?? DateTime.now(),
      updatedAt: parseFirestoreDate(json['updated_at']) ?? DateTime.now(),
      authorizedAt: parseFirestoreDate(json['authorized_at']),
      authorizationExpiresAt: parseFirestoreDate(json['authorization_expires_at']),
      capturedAt: parseFirestoreDate(json['captured_at']),
      cancelledAt: parseFirestoreDate(json['cancelled_at']),
      failedAt: parseFirestoreDate(json['failed_at']),
      lastRefundAt: null,
    );
  }
}
