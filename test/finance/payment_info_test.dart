// ---------------------------------------------------------------------------
// Tests unitaires — PaymentInfo (Bloc J)
//
// Couvre : parsing d'un document `payments/{id}` réel, rétro-compatibilité
// avec un document ancien/partiel (champs Phase 6 manquants), et le
// round-trip toJson/fromJson.
// ---------------------------------------------------------------------------

import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/finance/models/payment_info.dart';
import 'package:movik_connect/models/enums.dart';

Map<String, dynamic> _fullPaymentJson() => {
      'payment_id': 'payment_001',
      'mission_id': 'mission_001',
      'customer_id': 'customer_001',
      'driver_id': 'driver_001',
      'status': 'captured',
      'currency': 'CAD',
      'amount_authorized_minor': 11500,
      'amount_captured_minor': 11500,
      'amount_refunded_minor': 0,
      'application_fee_minor': 2000,
      'provider': 'stripe',
      'provider_customer_id': 'cus_123',
      'provider_payment_method_id': 'pm_123',
      'provider_payment_intent_id': 'pi_123',
      'provider_charge_id': 'ch_123',
      'failure_code': null,
      'failure_message': null,
      'created_at': '2025-06-15T10:00:00.000Z',
      'updated_at': '2025-06-15T10:05:00.000Z',
      'authorized_at': '2025-06-15T10:00:05.000Z',
      'authorization_expires_at': '2025-06-22T10:00:05.000Z',
      'captured_at': '2025-06-15T10:05:00.000Z',
      'cancelled_at': null,
      'failed_at': null,
    };

void main() {
  group('PaymentInfo.fromJson — document complet', () {
    test('parse correctement tous les champs (unités mineures/cents, aucun recalcul)', () {
      final payment = PaymentInfo.fromJson(_fullPaymentJson());

      expect(payment.paymentId, 'payment_001');
      expect(payment.missionId, 'mission_001');
      expect(payment.customerId, 'customer_001');
      expect(payment.status, PaymentStatus.captured);
      expect(payment.currency, 'CAD');
      expect(payment.amountAuthorizedMinor, 11500);
      expect(payment.amountCapturedMinor, 11500);
      expect(payment.amountRefundedMinor, 0);
      expect(payment.applicationFeeMinor, 2000);
      expect(payment.provider, 'stripe');
      expect(payment.isCaptured, isTrue);
      expect(payment.isRefunded, isFalse);
      expect(payment.capturedAt, DateTime.parse('2025-06-15T10:05:00.000Z'));
    });

    test('round-trip toJson()/fromJson() préserve les champs essentiels', () {
      final original = PaymentInfo.fromJson(_fullPaymentJson());
      final roundTripped = PaymentInfo.fromJson(original.toJson());

      expect(roundTripped.paymentId, original.paymentId);
      expect(roundTripped.status, original.status);
      expect(roundTripped.amountCapturedMinor, original.amountCapturedMinor);
      expect(roundTripped.createdAt, original.createdAt);
    });
  });

  group('PaymentInfo.fromJson — statuts Phase 6 complets (aucun repli silencieux)', () {
    test('chaque valeur PaymentStatuses serveur est reconnue individuellement', () {
      const serverValues = <String, PaymentStatus>{
        'created': PaymentStatus.created,
        'requires_payment_method': PaymentStatus.requiresPaymentMethod,
        'authorization_pending': PaymentStatus.authorizationPending,
        'authorized': PaymentStatus.authorized,
        'capture_pending': PaymentStatus.capturePending,
        'captured': PaymentStatus.captured,
        'failed': PaymentStatus.failed,
        'cancelled': PaymentStatus.cancelled,
        'refunded': PaymentStatus.refunded,
        'partially_refunded': PaymentStatus.partiallyRefunded,
        'disputed': PaymentStatus.disputed,
        'chargeback': PaymentStatus.chargeback,
      };

      for (final entry in serverValues.entries) {
        final json = _fullPaymentJson()..['status'] = entry.key;
        final payment = PaymentInfo.fromJson(json);
        expect(payment.status, entry.value, reason: 'status serveur "${entry.key}"');
      }
    });

    test('un statut refunded est bien détecté par isRefunded (partiel ET complet)', () {
      final partial = PaymentInfo.fromJson(_fullPaymentJson()..['status'] = 'partially_refunded');
      final full = PaymentInfo.fromJson(_fullPaymentJson()..['status'] = 'refunded');
      expect(partial.isRefunded, isTrue);
      expect(partial.isPartiallyRefunded, isTrue);
      expect(full.isRefunded, isTrue);
      expect(full.isPartiallyRefunded, isFalse);
    });
  });

  group('PaymentInfo.fromJson — rétro-compatibilité (ancienne mission, champs Phase 6 absents)', () {
    test("un document minimal (seulement les champs requis) ne plante pas", () {
      final minimal = <String, dynamic>{
        'payment_id': 'payment_old',
        'mission_id': 'mission_old',
        'customer_id': 'customer_old',
      };

      final payment = PaymentInfo.fromJson(minimal);

      expect(payment.paymentId, 'payment_old');
      expect(payment.driverId, ''); // absent -> repli sûr, jamais un crash
      expect(payment.status, PaymentStatus.pending); // valeur de repli
      expect(payment.currency, 'CAD');
      expect(payment.amountAuthorizedMinor, 0);
      expect(payment.amountCapturedMinor, 0);
      expect(payment.amountRefundedMinor, 0);
      expect(payment.authorizedAt, isNull);
      expect(payment.capturedAt, isNull);
      expect(payment.failedAt, isNull);
      expect(payment.lastRefundAt, isNull);
    });

    test('un JSON totalement vide ne plante jamais (fail-safe absolu)', () {
      expect(() => PaymentInfo.fromJson(const {}), returnsNormally);
    });
  });

  group('PaymentInfo.copyWithLastRefundAt', () {
    test('attache une date de dernier refund sans modifier les autres champs', () {
      final original = PaymentInfo.fromJson(_fullPaymentJson());
      final refundDate = DateTime(2025, 6, 20);
      final withRefund = original.copyWithLastRefundAt(refundDate);

      expect(withRefund.lastRefundAt, refundDate);
      expect(withRefund.paymentId, original.paymentId);
      expect(withRefund.amountCapturedMinor, original.amountCapturedMinor);
      // L'original reste inchangé (immuabilité).
      expect(original.lastRefundAt, isNull);
    });
  });
}
