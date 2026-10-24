// Lecture admin d'un paiement : type, prix, blocage, libéré, répartition,
// totaux et export CSV. Données construites comme des documents
// `payments/{id}` réels (cents), sans Firebase.

import 'package:flutter_test/flutter_test.dart';

import 'package:movik_connect/finance/models/payment_info.dart';
import 'package:movik_connect/finance/presentation/admin_payment_presenter.dart';
import 'package:movik_connect/l10n/app_strings.dart';
import 'package:movik_connect/models/enums.dart';

PaymentInfo _payment({
  String id = 'pay_1',
  String missionId = 'igxZvCb4ICvy6LZSnTYM',
  String customerId = 'cust_1',
  PaymentStatus status = PaymentStatus.captured,
  int authorized = 3000,
  int captured = 2500,
  int refunded = 0,
  int applicationFee = 0,
  int? service = 2500,
  String? capturePurpose,
  String? feeKind,
  String? environment = 'test',
  String? connectedAccount,
}) {
  return PaymentInfo(
    paymentId: id,
    missionId: missionId,
    customerId: customerId,
    driverId: 'drv_1',
    status: status,
    currency: 'CAD',
    amountAuthorizedMinor: authorized,
    amountCapturedMinor: captured,
    amountRefundedMinor: refunded,
    applicationFeeMinor: applicationFee,
    serviceAmountMinor: service,
    capturePurpose: capturePurpose,
    feeKind: feeKind,
    stripeEnvironment: environment,
    connectedAccountId: connectedAccount,
    provider: 'stripe',
    createdAt: DateTime(2026, 10, 23, 14, 5),
    updatedAt: DateTime(2026, 10, 23, 14, 5),
  );
}

void main() {
  group('AdminPaymentView', () {
    test('livraison à 25 \$ : blocage 30 \$, capturé 25 \$, 5 \$ libérés', () {
      final view = AdminPaymentView(_payment());
      expect(view.kind, AdminPaymentKind.delivery);
      expect(view.deliveryPriceMinor, 2500);
      expect(view.holdMinor, 3000);
      expect(view.holdExceedsPrice, isTrue);
      expect(view.releasedMinor, 500);
      expect(view.isTestMode, isTrue);
      expect(view.shortMissionRef, 'IGXZVC');
    });

    test('frais d\'annulation tardive reconnus et répartis 5 \$ / 25 \$', () {
      final view = AdminPaymentView(
        _payment(
          captured: 3000,
          service: 1800,
          applicationFee: 500,
          capturePurpose: 'mission_fee',
          feeKind: 'late_cancellation',
          connectedAccount: 'acct_123',
        ),
      );
      expect(view.kind, AdminPaymentKind.lateCancellation);
      expect(view.isFee, isTrue);
      expect(view.releasedMinor, 0);
      expect(view.platformShareMinor, 500);
      expect(view.driverShareMinor, 2500);
    });

    test('ancien paiement de frais sans fee_kind : libellé générique', () {
      final view = AdminPaymentView(
        _payment(captured: 3000, capturePurpose: 'mission_fee'),
      );
      expect(view.kind, AdminPaymentKind.missionFee);
    });

    test('sans Stripe Connect, la répartition reste inconnue', () {
      final view = AdminPaymentView(_payment(applicationFee: 300));
      expect(view.viaStripeConnect, isFalse);
      expect(view.platformShareMinor, isNull);
      expect(view.driverShareMinor, isNull);
    });

    test('ancien paiement sans service_amount_minor : prix = autorisé', () {
      final view = AdminPaymentView(
        _payment(authorized: 4200, captured: 4200, service: null),
      );
      expect(view.deliveryPriceMinor, 4200);
      expect(view.holdExceedsPrice, isFalse);
      expect(view.releasedMinor, 0);
    });

    test('blocage annulé : tout le blocage est libéré', () {
      final view = AdminPaymentView(
        _payment(status: PaymentStatus.cancelled, captured: 0),
      );
      expect(view.captureDone, isFalse);
      expect(view.releasedMinor, 3000);
    });

    test('filtre par type', () {
      final delivery = AdminPaymentView(_payment());
      final fee = AdminPaymentView(_payment(capturePurpose: 'mission_fee'));
      expect(delivery.matches(AdminPaymentKindFilter.deliveries), isTrue);
      expect(delivery.matches(AdminPaymentKindFilter.fees), isFalse);
      expect(fee.matches(AdminPaymentKindFilter.fees), isTrue);
      expect(fee.matches(AdminPaymentKindFilter.all), isTrue);
    });
  });

  test('AdminPaymentsSummary additionne seulement ce qui est connu', () {
    final summary = AdminPaymentsSummary.from([
      _payment(applicationFee: 400, connectedAccount: 'acct_1'),
      _payment(id: 'pay_2'),
      _payment(id: 'pay_3', status: PaymentStatus.authorized, captured: 0),
    ]);
    expect(summary.count, 3);
    expect(summary.capturedMinor, 5000);
    expect(summary.platformMinor, 400);
    expect(summary.driverMinor, 2100);
    expect(summary.heldMinor, 3000);
    expect(summary.capturedWithoutSplitCount, 1);
  });

  test('export CSV : séparateur ; et virgule décimale en français', () {
    String t(String key) => AppStrings.t(key, 'fr');
    final csv = buildAdminPaymentsCsv(
      payments: [_payment()],
      customerEmails: const {'cust_1': 'client@exemple.ca'},
      locale: 'fr',
      t: t,
      statusLabel: (s) => s.name,
    );
    expect(csv.startsWith('﻿'), isTrue);
    final lines = csv.trim().split('\r\n');
    expect(lines, hasLength(2));
    expect(lines.first, contains('Courriel du client'));
    expect(lines[1], contains('client@exemple.ca'));
    expect(lines[1], contains(';25,00;30,00;25,00;5,00;0,00;'));
    expect(lines[1], contains(';test;pay_1'));
  });

  test('export CSV : séparateur , et point décimal en anglais', () {
    String t(String key) => AppStrings.t(key, 'en');
    final csv = buildAdminPaymentsCsv(
      payments: [_payment()],
      customerEmails: const {},
      locale: 'en',
      t: t,
      statusLabel: (s) => s.name,
    );
    expect(csv, contains(',25.00,30.00,25.00,5.00,0.00,'));
  });

  test('les nouveaux libellés existent en fr, en et es', () {
    const keys = [
      'admin_payments_kind_delivery',
      'admin_payments_kind_late_cancellation',
      'admin_payments_kind_failed_delivery',
      'admin_payments_kind_mission_fee',
      'admin_payments_price',
      'admin_payments_hold',
      'admin_payments_released',
      'admin_payments_summary_captured',
      'admin_payments_export_csv',
    ];
    for (final key in keys) {
      for (final locale in ['fr', 'en', 'es']) {
        expect(AppStrings.t(key, locale), isNot(key), reason: '$key/$locale');
      }
    }
  });
}
