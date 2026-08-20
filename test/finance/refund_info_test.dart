// ---------------------------------------------------------------------------
// Tests unitaires — RefundInfo (Bloc J)
//
// Couvre : parsing d'un document `refunds/{id}` réel, toutes les valeurs
// RefundStatuses/RefundReasons serveur, rétro-compatibilité champs absents,
// et le round-trip toJson/fromJson.
// ---------------------------------------------------------------------------

import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/finance/models/refund_info.dart';
import 'package:movik_connect/models/enums.dart';

Map<String, dynamic> _fullRefundJson() => {
      'refund_id': 'refund_001',
      'payment_id': 'payment_001',
      'mission_id': 'mission_001',
      'amount_minor': 2500,
      'reason': 'customer_request',
      'initiated_by_user_id': 'customer_001',
      'initiated_by_role': 'customer',
      'is_admin_initiated': false,
      'is_post_payout': false,
      'related_payout_id': null,
      'status': 'succeeded',
      'provider_refund_id': 're_123',
      'reverse_transfer': true,
      'refund_application_fee': false,
      'created_at': '2025-06-16T09:00:00.000Z',
      'processing_at': '2025-06-16T09:00:05.000Z',
      'completed_at': '2025-06-16T09:00:10.000Z',
      'failed_reason': null,
    };

void main() {
  group('RefundInfo.fromJson — document complet', () {
    test('parse correctement tous les champs', () {
      final refund = RefundInfo.fromJson(_fullRefundJson());

      expect(refund.refundId, 'refund_001');
      expect(refund.paymentId, 'payment_001');
      expect(refund.missionId, 'mission_001');
      expect(refund.amountMinor, 2500);
      expect(refund.reason, RefundReason.customerRequest);
      expect(refund.status, RefundStatus.succeeded);
      expect(refund.isSucceeded, isTrue);
      expect(refund.isFailed, isFalse);
      expect(refund.isInProgress, isFalse);
      expect(refund.displayDate, DateTime.parse('2025-06-16T09:00:10.000Z'));
    });

    test('round-trip toJson()/fromJson() préserve les champs essentiels', () {
      final original = RefundInfo.fromJson(_fullRefundJson());
      final roundTripped = RefundInfo.fromJson(original.toJson());

      expect(roundTripped.refundId, original.refundId);
      expect(roundTripped.status, original.status);
      expect(roundTripped.amountMinor, original.amountMinor);
      expect(roundTripped.reason, original.reason);
    });
  });

  group('RefundInfo.fromJson — statuts et raisons Phase 6 complets', () {
    test('chaque valeur RefundStatuses serveur est reconnue', () {
      const values = <String, RefundStatus>{
        'requested': RefundStatus.requested,
        'processing': RefundStatus.processing,
        'succeeded': RefundStatus.succeeded,
        'failed': RefundStatus.failed,
      };
      for (final entry in values.entries) {
        final json = _fullRefundJson()..['status'] = entry.key;
        expect(RefundInfo.fromJson(json).status, entry.value, reason: entry.key);
      }
    });

    test('chaque valeur RefundReasons serveur est reconnue', () {
      const values = <String, RefundReason>{
        'customer_request': RefundReason.customerRequest,
        'cancelled_before_pickup': RefundReason.cancelledBeforePickup,
        'cancelled_after_pickup': RefundReason.cancelledAfterPickup,
        'payment_error': RefundReason.paymentError,
        'goodwill': RefundReason.goodwill,
        'administrative': RefundReason.administrative,
        'mission_impossible': RefundReason.missionImpossible,
        'partial_delivery': RefundReason.partialDelivery,
        'no_show': RefundReason.noShow,
      };
      for (final entry in values.entries) {
        final json = _fullRefundJson()..['reason'] = entry.key;
        expect(RefundInfo.fromJson(json).reason, entry.value, reason: entry.key);
      }
    });

    test('un refund échoué expose failedReason et n\'est pas isSucceeded', () {
      final json = _fullRefundJson()
        ..['status'] = 'failed'
        ..['completed_at'] = null
        ..['failed_reason'] = 'card_declined';
      final refund = RefundInfo.fromJson(json);

      expect(refund.isFailed, isTrue);
      expect(refund.isSucceeded, isFalse);
      expect(refund.failedReason, 'card_declined');
      // displayDate retombe sur createdAt quand completedAt est absent.
      expect(refund.displayDate, refund.createdAt);
    });
  });

  group('RefundInfo.fromJson — rétro-compatibilité (champs absents)', () {
    test('un document minimal ne plante pas et retombe sur des valeurs sûres', () {
      final refund = RefundInfo.fromJson(const {
        'refund_id': 'refund_old',
        'payment_id': 'payment_old',
        'mission_id': 'mission_old',
        'amount_minor': 1000,
      });

      expect(refund.refundId, 'refund_old');
      expect(refund.status, RefundStatus.requested); // valeur de repli
      expect(refund.reason, RefundReason.administrative); // valeur de repli
      expect(refund.isAdminInitiated, isFalse);
      expect(refund.isPostPayout, isFalse);
      expect(refund.relatedPayoutId, isNull);
      expect(refund.processingAt, isNull);
      expect(refund.completedAt, isNull);
      expect(refund.failedReason, isNull);
    });

    test('un JSON totalement vide ne plante jamais (fail-safe absolu)', () {
      expect(() => RefundInfo.fromJson(const {}), returnsNormally);
    });
  });
}
