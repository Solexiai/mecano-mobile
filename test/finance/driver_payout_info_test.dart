// ---------------------------------------------------------------------------
// Tests unitaires — DriverPayoutInfo (Bloc K)
//
// Couvre : mapping exact des champs Firestore réels (`DriverPayoutDoc`,
// voir functions/src/lib/types.ts), tous les statuts `PayoutStatuses`
// serveur, parsing de timestamps robuste (String ISO8601 ici — le
// Timestamp natif Firestore SDK est couvert par
// `parseFirestoreDate`/backend_models/firestore_date_test si présent),
// champs null explicites, et rétro-compatibilité avec un document
// partiellement absent (ancien payout).
// ---------------------------------------------------------------------------

import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/finance/models/driver_payout_info.dart';
import 'package:movik_connect/models/enums.dart';

Map<String, dynamic> _fullPayoutJson({String status = 'paid'}) => {
  'driver_id': 'driver_001',
  'financial_snapshot_ids': ['snap_001', 'snap_002'],
  'amount_minor': 15000,
  'currency': 'CAD',
  'status': status,
  'payout_hold_period_hours': 48,
  'payout_eligible_at': '2026-08-24T00:00:00.000Z',
  'provider_payout_id': 'po_test_123',
  'connected_account_id': 'acct_test_456',
  'created_at': '2026-08-20T10:00:00.000Z',
  'scheduled_at': '2026-08-24T01:00:00.000Z',
  'processing_at': '2026-08-24T02:00:00.000Z',
  'paid_at': '2026-08-24T03:00:00.000Z',
  'failed_at': null,
  'failure_reason': null,
  'reversed_at': null,
  'reversal_reason': null,
};

void main() {
  group(
    'DriverPayoutInfo.fromJson — mapping exact du schéma DriverPayoutDoc',
    () {
      test(
        'parse correctement tous les champs (unités mineures/cents, aucun recalcul)',
        () {
          final payout = DriverPayoutInfo.fromJson(
            'payout_001',
            _fullPayoutJson(),
          );

          expect(payout.payoutId, 'payout_001');
          expect(payout.driverId, 'driver_001');
          expect(payout.financialSnapshotIds, ['snap_001', 'snap_002']);
          expect(payout.amountMinor, 15000);
          expect(payout.currency, 'CAD');
          expect(payout.status, PayoutStatus.paid);
          expect(payout.payoutHoldPeriodHours, 48);
          expect(
            payout.payoutEligibleAt,
            DateTime.parse('2026-08-24T00:00:00.000Z'),
          );
          expect(payout.providerPayoutId, 'po_test_123');
          expect(payout.connectedAccountId, 'acct_test_456');
          expect(payout.createdAt, DateTime.parse('2026-08-20T10:00:00.000Z'));
          expect(
            payout.scheduledAt,
            DateTime.parse('2026-08-24T01:00:00.000Z'),
          );
          expect(
            payout.processingAt,
            DateTime.parse('2026-08-24T02:00:00.000Z'),
          );
          expect(payout.paidAt, DateTime.parse('2026-08-24T03:00:00.000Z'));
          expect(payout.failedAt, isNull);
          expect(payout.failureReason, isNull);
          expect(payout.reversedAt, isNull);
          expect(payout.reversalReason, isNull);
        },
      );

      test('round-trip toJson()/fromJson() préserve les champs essentiels', () {
        final original = DriverPayoutInfo.fromJson(
          'payout_001',
          _fullPayoutJson(),
        );
        final roundTripped = DriverPayoutInfo.fromJson(
          'payout_001',
          original.toJson(),
        );

        expect(roundTripped.driverId, original.driverId);
        expect(roundTripped.amountMinor, original.amountMinor);
        expect(roundTripped.status, original.status);
        expect(roundTripped.payoutEligibleAt, original.payoutEligibleAt);
        expect(
          roundTripped.financialSnapshotIds,
          original.financialSnapshotIds,
        );
      });

      test(
        'chaque valeur PayoutStatuses serveur est reconnue individuellement',
        () {
          const serverValues = [
            'pending',
            'eligible',
            'scheduled',
            'processing',
            'paid',
            'failed',
            'reversed',
            'held',
          ];
          const expectedEnums = [
            PayoutStatus.pending,
            PayoutStatus.eligible,
            PayoutStatus.scheduled,
            PayoutStatus.processing,
            PayoutStatus.paid,
            PayoutStatus.failed,
            PayoutStatus.reversed,
            PayoutStatus.held,
          ];

          for (var i = 0; i < serverValues.length; i++) {
            final payout = DriverPayoutInfo.fromJson(
              'payout_x',
              _fullPayoutJson(status: serverValues[i]),
            );
            expect(
              payout.status,
              expectedEnums[i],
              reason: 'status serveur "${serverValues[i]}"',
            );
          }
        },
      );
    },
  );

  group('DriverPayoutInfo — getters dérivés de statut', () {
    test('isPaid / isTerminal sont corrects pour un payout paid', () {
      final payout = DriverPayoutInfo.fromJson(
        'p',
        _fullPayoutJson(status: 'paid'),
      );
      expect(payout.isPaid, isTrue);
      expect(payout.isTerminal, isTrue);
      expect(payout.isFailed, isFalse);
      expect(payout.isReversed, isFalse);
    });

    test('isHeld / isPending ne sont PAS terminaux', () {
      final held = DriverPayoutInfo.fromJson(
        'p',
        _fullPayoutJson(status: 'held'),
      );
      final pending = DriverPayoutInfo.fromJson(
        'p',
        _fullPayoutJson(status: 'pending'),
      );
      expect(held.isHeld, isTrue);
      expect(held.isTerminal, isFalse);
      expect(pending.isPending, isTrue);
      expect(pending.isTerminal, isFalse);
    });

    test('failed / reversed sont bien détectés et terminaux', () {
      final failed = DriverPayoutInfo.fromJson(
        'p',
        _fullPayoutJson(status: 'failed'),
      );
      final reversed = DriverPayoutInfo.fromJson(
        'p',
        _fullPayoutJson(status: 'reversed'),
      );
      expect(failed.isFailed, isTrue);
      expect(failed.isTerminal, isTrue);
      expect(reversed.isReversed, isTrue);
      expect(reversed.isTerminal, isTrue);
    });
  });

  group('DriverPayoutInfo.fromJson — rétro-compatibilité (champs absents)', () {
    test('un document minimal (seulement driver_id) ne plante pas', () {
      final payout = DriverPayoutInfo.fromJson('payout_old', const {
        'driver_id': 'driver_001',
      });

      expect(payout.payoutId, 'payout_old');
      expect(payout.driverId, 'driver_001');
      expect(payout.financialSnapshotIds, isEmpty);
      expect(payout.amountMinor, 0);
      expect(payout.currency, 'CAD');
      // repli sûr sur le statut le plus prudent (pending) — jamais de
      // crash sur un status inconnu/absent.
      expect(payout.status, PayoutStatus.pending);
      expect(payout.payoutHoldPeriodHours, 0);
      expect(payout.providerPayoutId, isNull);
      expect(payout.failureReason, isNull);
      expect(payout.reversalReason, isNull);
    });

    test('un JSON totalement vide ne plante jamais (fail-safe absolu)', () {
      final payout = DriverPayoutInfo.fromJson('payout_fallback', const {});
      expect(payout.payoutId, 'payout_fallback');
      expect(payout.driverId, '');
      expect(payout.amountMinor, 0);
      expect(payout.status, PayoutStatus.pending);
    });
  });
}
