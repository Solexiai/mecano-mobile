// ---------------------------------------------------------------------------
// admin_payment_presenter.dart — lecture humaine d'un paiement pour la page
// admin « Centre financier > Paiements ».
//
// Affichage uniquement : aucun montant n'est recalculé ni réécrit. On ne fait
// que nommer ce que le serveur a déjà enregistré sur `payments/{id}` :
//   - le prix de la livraison (`service_amount_minor`) ;
//   - le blocage de carte (`amount_authorized_minor`), au moins 30 $ depuis
//     la décision du 23 octobre 2026 ;
//   - le montant capturé, et donc ce qui a été libéré sur la carte ;
//   - le motif de la capture (`capture_purpose`, `fee_kind`) ;
//   - la part Movi-K (`application_fee_minor`) quand le versement passe par
//     Stripe Connect.
// ---------------------------------------------------------------------------

import '../../models/enums.dart';
import '../models/payment_info.dart';

/// Nombre de paiements chargés par la page admin (les plus récents).
/// Partagé avec l'écran de détail, qui retrouve le paiement dans le même
/// flux.
const int kAdminPaymentsLimit = 200;

enum AdminPaymentKind { delivery, lateCancellation, failedDelivery, missionFee }

/// Filtre « type » de la page Paiements.
enum AdminPaymentKindFilter { all, deliveries, fees }

class AdminPaymentView {
  const AdminPaymentView(this.payment);

  final PaymentInfo payment;

  AdminPaymentKind get kind {
    if (payment.capturePurpose != 'mission_fee') {
      return AdminPaymentKind.delivery;
    }
    switch (payment.feeKind) {
      case 'late_cancellation':
        return AdminPaymentKind.lateCancellation;
      case 'customer_failed_delivery':
        return AdminPaymentKind.failedDelivery;
      default:
        return AdminPaymentKind.missionFee;
    }
  }

  bool get isFee => kind != AdminPaymentKind.delivery;

  bool matches(AdminPaymentKindFilter filter) {
    switch (filter) {
      case AdminPaymentKindFilter.all:
        return true;
      case AdminPaymentKindFilter.deliveries:
        return !isFee;
      case AdminPaymentKindFilter.fees:
        return isFee;
    }
  }

  /// Prix de la livraison. Sur un ancien paiement sans
  /// `service_amount_minor`, le prix est le montant autorisé.
  int get deliveryPriceMinor {
    final service = payment.serviceAmountMinor;
    if (service != null &&
        service > 0 &&
        service <= payment.amountAuthorizedMinor) {
      return service;
    }
    return payment.amountAuthorizedMinor;
  }

  int get holdMinor => payment.amountAuthorizedMinor;

  /// Le blocage dépasse le prix (minimum de 30 $ pour couvrir les frais).
  bool get holdExceedsPrice => holdMinor > deliveryPriceMinor;

  /// La capture a eu lieu (même si un remboursement ou un litige a suivi).
  bool get captureDone {
    switch (payment.status) {
      case PaymentStatus.captured:
      case PaymentStatus.refunded:
      case PaymentStatus.partiallyRefunded:
      case PaymentStatus.disputed:
      case PaymentStatus.chargeback:
        return payment.amountCapturedMinor > 0;
      default:
        return false;
    }
  }

  /// Blocage encore actif sur la carte du client.
  bool get holdActive =>
      payment.status == PaymentStatus.authorized ||
      payment.status == PaymentStatus.capturePending;

  /// Montant rendu disponible sur la carte du client : la partie du blocage
  /// non capturée, ou tout le blocage s'il a été annulé.
  int get releasedMinor {
    if (payment.status == PaymentStatus.cancelled) return holdMinor;
    if (!captureDone) return 0;
    final released = holdMinor - payment.amountCapturedMinor;
    return released > 0 ? released : 0;
  }

  bool get viaStripeConnect =>
      (payment.connectedAccountId ?? '').isNotEmpty;

  /// Part Movi-K retenue par Stripe à la capture (commission + frais de
  /// service, ou 5 $ sur des frais d'annulation). Connue seulement avec
  /// Stripe Connect.
  int? get platformShareMinor {
    if (!captureDone || !viaStripeConnect) return null;
    final fee = payment.applicationFeeMinor;
    if (fee < 0 || fee > payment.amountCapturedMinor) return null;
    return fee;
  }

  /// Montant transféré par Stripe au chauffeur à la capture.
  int? get driverShareMinor {
    final platform = platformShareMinor;
    if (platform == null) return null;
    return payment.amountCapturedMinor - platform;
  }

  /// `true` = test, `false` = live, `null` = environnement non enregistré.
  bool? get isTestMode {
    switch (payment.stripeEnvironment) {
      case 'test':
        return true;
      case 'live':
        return false;
      default:
        return null;
    }
  }

  /// Référence courte, lisible à voix haute (les 6 premiers caractères de
  /// l'identifiant de mission, en majuscules). L'identifiant complet reste
  /// dans le détail et dans l'export.
  String get shortMissionRef {
    final id = payment.missionId.trim();
    if (id.isEmpty) return '—';
    return id.length <= 6 ? id.toUpperCase() : id.substring(0, 6).toUpperCase();
  }
}

/// Totaux de la page, calculés sur les paiements affichés.
class AdminPaymentsSummary {
  const AdminPaymentsSummary({
    required this.count,
    required this.capturedMinor,
    required this.refundedMinor,
    required this.platformMinor,
    required this.driverMinor,
    required this.heldMinor,
    required this.capturedWithoutSplitCount,
  });

  final int count;
  final int capturedMinor;
  final int refundedMinor;

  /// Somme des parts Movi-K connues (Stripe Connect).
  final int platformMinor;

  /// Somme des parts chauffeur connues (Stripe Connect).
  final int driverMinor;

  /// Blocages de carte encore actifs (pas encore capturés ni libérés).
  final int heldMinor;

  /// Paiements capturés sans Stripe Connect : l'argent est chez Movi-K et la
  /// part chauffeur n'est pas répartie automatiquement.
  final int capturedWithoutSplitCount;

  factory AdminPaymentsSummary.from(Iterable<PaymentInfo> payments) {
    var count = 0;
    var captured = 0;
    var refunded = 0;
    var platform = 0;
    var driver = 0;
    var held = 0;
    var withoutSplit = 0;
    for (final p in payments) {
      final view = AdminPaymentView(p);
      count++;
      refunded += p.amountRefundedMinor;
      if (view.holdActive) held += view.holdMinor;
      if (view.captureDone) {
        captured += p.amountCapturedMinor;
        final platformShare = view.platformShareMinor;
        final driverShare = view.driverShareMinor;
        if (platformShare != null && driverShare != null) {
          platform += platformShare;
          driver += driverShare;
        } else {
          withoutSplit++;
        }
      }
    }
    return AdminPaymentsSummary(
      count: count,
      capturedMinor: captured,
      refundedMinor: refunded,
      platformMinor: platform,
      driverMinor: driver,
      heldMinor: held,
      capturedWithoutSplitCount: withoutSplit,
    );
  }
}

/// Export CSV pour le comptable. Séparateur `;` et décimales à virgule en
/// français et en espagnol (ouverture directe dans Excel au Québec),
/// séparateur `,` et point décimal en anglais.
String buildAdminPaymentsCsv({
  required List<PaymentInfo> payments,
  required Map<String, String> customerEmails,
  required String locale,
  required String Function(String key) t,
  required String Function(PaymentStatus status) statusLabel,
}) {
  final lang = locale.split(RegExp('[-_]')).first;
  final separator = lang == 'en' ? ',' : ';';
  final decimal = lang == 'en' ? '.' : ',';

  String amount(int? minor) {
    if (minor == null) return '';
    final negative = minor < 0;
    final abs = negative ? -minor : minor;
    final units = abs ~/ 100;
    final cents = (abs % 100).toString().padLeft(2, '0');
    return '${negative ? '-' : ''}$units$decimal$cents';
  }

  String cell(String value) {
    final needsQuotes = value.contains(separator) ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    if (!needsQuotes) return value;
    return '"${value.replaceAll('"', '""')}"';
  }

  String date(DateTime dt) {
    final local = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  final header = [
    t('admin_payments_csv_date'),
    t('admin_payments_csv_type'),
    t('admin_payments_col_status'),
    t('admin_payments_col_mission'),
    t('admin_payments_csv_customer_email'),
    t('admin_payments_csv_customer_id'),
    t('admin_payments_price'),
    t('admin_payments_hold'),
    t('admin_payments_col_captured'),
    t('admin_payments_released'),
    t('admin_payments_col_refunded'),
    t('admin_payments_share_platform'),
    t('admin_payments_share_driver'),
    t('admin_payments_csv_environment'),
    t('admin_payments_col_id'),
  ];

  final lines = <String>[header.map(cell).join(separator)];
  for (final p in payments) {
    final view = AdminPaymentView(p);
    final env = view.isTestMode;
    lines.add(
      [
        date(p.createdAt),
        t(adminPaymentKindKey(view.kind)),
        statusLabel(p.status),
        p.missionId,
        customerEmails[p.customerId] ?? '',
        p.customerId,
        view.isFee ? '' : amount(view.deliveryPriceMinor),
        amount(view.holdMinor),
        amount(p.amountCapturedMinor),
        amount(view.releasedMinor),
        amount(p.amountRefundedMinor),
        amount(view.platformShareMinor),
        amount(view.driverShareMinor),
        env == null ? '' : (env ? 'test' : 'live'),
        p.paymentId,
      ].map(cell).join(separator),
    );
  }
  // BOM UTF-8 : Excel affiche alors correctement les accents.
  return '﻿${lines.join('\r\n')}\r\n';
}

String adminPaymentKindKey(AdminPaymentKind kind) {
  switch (kind) {
    case AdminPaymentKind.delivery:
      return 'admin_payments_kind_delivery';
    case AdminPaymentKind.lateCancellation:
      return 'admin_payments_kind_late_cancellation';
    case AdminPaymentKind.failedDelivery:
      return 'admin_payments_kind_failed_delivery';
    case AdminPaymentKind.missionFee:
      return 'admin_payments_kind_mission_fee';
  }
}
