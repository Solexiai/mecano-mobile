// ---------------------------------------------------------------------------
// Tests unitaires — MissionFinancialBalance (Bloc J)
//
// Couvre : mapping EXACT des noms de champs Firestore réels (`*_minor`,
// voir MissionFinancialBalanceDoc dans functions/src/lib/types.ts) vers les
// champs Dart demandés par la directive Bloc J, aucun recalcul local, et
// rétro-compatibilité avec un document partiellement absent.
// ---------------------------------------------------------------------------

import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/finance/models/mission_financial_balance.dart';

Map<String, dynamic> _fullBalanceJson() => {
  'mission_id': 'mission_001',
  'customer_charged_minor': 11500,
  'customer_refunded_minor': 0,
  'platform_commission_minor': 1500,
  'customer_service_fee_minor': 500,
  'driver_earned_minor': 8500,
  'driver_paid_minor': 0,
  'driver_tip_minor': 1000,
  'driver_bonus_minor': 0,
  'adjustments_minor': 0,
  'outstanding_driver_balance_minor': 9500,
  'outstanding_customer_balance_minor': 11500,
  'provider_processing_cost_minor': 350,
  'contribution_margin_minor': 1650,
  'updated_at': '2025-06-15T10:05:00.000Z',
};

void main() {
  group(
    'MissionFinancialBalance.fromJson — mapping exact des champs serveur',
    () {
      test(
        'chaque champ Dart lit la clé Firestore *_minor correspondante, sans recalcul',
        () {
          final balance = MissionFinancialBalance.fromJson(
            'mission_001',
            _fullBalanceJson(),
          );

          expect(balance.missionId, 'mission_001');
          expect(balance.customerCharged, 11500);
          expect(balance.customerRefunded, 0);
          expect(balance.platformCommission, 1500);
          expect(balance.customerServiceFee, 500);
          expect(balance.driverEarned, 8500);
          expect(balance.driverPaid, 0);
          expect(balance.driverTip, 1000);
          expect(balance.driverBonus, 0);
          expect(balance.adjustments, 0);
          expect(balance.outstandingDriverBalance, 9500);
          expect(balance.outstandingCustomerBalance, 11500);
          expect(balance.processingCosts, 350);
          expect(balance.contributionMargin, 1650);
        },
      );

      test('round-trip toJson()/fromJson() préserve toutes les valeurs', () {
        final original = MissionFinancialBalance.fromJson(
          'mission_001',
          _fullBalanceJson(),
        );
        final roundTripped = MissionFinancialBalance.fromJson(
          'mission_001',
          original.toJson(),
        );

        expect(roundTripped.customerCharged, original.customerCharged);
        expect(roundTripped.customerRefunded, original.customerRefunded);
        expect(roundTripped.contributionMargin, original.contributionMargin);
      });
    },
  );

  group('MissionFinancialBalance — getters dérivés de remboursement', () {
    test('aucun remboursement -> hasBeenRefunded false', () {
      final balance = MissionFinancialBalance.fromJson(
        'mission_001',
        _fullBalanceJson(),
      );
      expect(balance.hasBeenRefunded, isFalse);
      expect(balance.isPartiallyRefunded, isFalse);
      expect(balance.isFullyRefunded, isFalse);
    });

    test('remboursement partiel détecté correctement', () {
      final json = _fullBalanceJson()..['customer_refunded_minor'] = 5000;
      final balance = MissionFinancialBalance.fromJson('mission_001', json);
      expect(balance.hasBeenRefunded, isTrue);
      expect(balance.isPartiallyRefunded, isTrue);
      expect(balance.isFullyRefunded, isFalse);
    });

    test('remboursement complet détecté correctement', () {
      final json = _fullBalanceJson()..['customer_refunded_minor'] = 11500;
      final balance = MissionFinancialBalance.fromJson('mission_001', json);
      expect(balance.hasBeenRefunded, isTrue);
      expect(balance.isPartiallyRefunded, isFalse);
      expect(balance.isFullyRefunded, isTrue);
    });
  });

  group(
    'MissionFinancialBalance.fromJson — rétro-compatibilité (document partiel/absent)',
    () {
      test('un document minimal (seulement mission_id) ne plante pas', () {
        final balance = MissionFinancialBalance.fromJson('mission_old', const {
          'mission_id': 'mission_old',
        });

        expect(balance.missionId, 'mission_old');
        expect(balance.customerCharged, 0);
        expect(balance.customerRefunded, 0);
        expect(balance.platformCommission, 0);
        expect(balance.driverEarned, 0);
        expect(balance.contributionMargin, 0);
        expect(balance.hasBeenRefunded, isFalse);
      });

      test(
        'un JSON totalement vide ne plante jamais et utilise le missionId fourni',
        () {
          final balance = MissionFinancialBalance.fromJson(
            'mission_fallback',
            const {},
          );
          expect(balance.missionId, 'mission_fallback');
          expect(balance.customerCharged, 0);
        },
      );
    },
  );
}
