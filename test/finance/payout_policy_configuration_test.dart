// ---------------------------------------------------------------------------
// Tests unitaires — PayoutPolicyConfiguration (Bloc L)
//
// Couvre : mapping exact du document unique `payout_policy_configs/default`
// (`PayoutPolicyConfigDoc`, voir functions/src/lib/types.ts), le filet de
// sécurité `bootstrapDefault()` (72h pour les 3 catégories, cohérent avec
// `readPayoutPolicyConfig()` côté serveur), parsing de timestamps robuste,
// et rétro-compatibilité avec un document partiellement absent (repli sûr
// sur 72h par champ manquant).
// ---------------------------------------------------------------------------

import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/finance/models/payout_policy_configuration.dart';

Map<String, dynamic> _fullPolicyJson() => {
  'default_hold_period_hours': 48,
  'new_driver_hold_period_hours': 168,
  'risky_driver_hold_period_hours': 336,
  'updated_at': '2026-08-20T10:00:00.000Z',
  'updated_by_user_id': 'super_admin_001',
};

void main() {
  group(
    'PayoutPolicyConfiguration.fromJson — mapping exact du schéma PayoutPolicyConfigDoc',
    () {
      test('parse correctement tous les champs (aucun recalcul)', () {
        final policy = PayoutPolicyConfiguration.fromJson(_fullPolicyJson());

        expect(policy.defaultHoldPeriodHours, 48);
        expect(policy.newDriverHoldPeriodHours, 168);
        expect(policy.riskyDriverHoldPeriodHours, 336);
        expect(policy.updatedAt, DateTime.parse('2026-08-20T10:00:00.000Z'));
        expect(policy.updatedByUserId, 'super_admin_001');
      });

      test('round-trip toJson()/fromJson() préserve les champs essentiels', () {
        final original = PayoutPolicyConfiguration.fromJson(_fullPolicyJson());
        final roundTripped = PayoutPolicyConfiguration.fromJson(
          original.toJson(),
        );

        expect(
          roundTripped.defaultHoldPeriodHours,
          original.defaultHoldPeriodHours,
        );
        expect(
          roundTripped.newDriverHoldPeriodHours,
          original.newDriverHoldPeriodHours,
        );
        expect(
          roundTripped.riskyDriverHoldPeriodHours,
          original.riskyDriverHoldPeriodHours,
        );
        expect(roundTripped.updatedByUserId, original.updatedByUserId);
      });
    },
  );

  group('PayoutPolicyConfiguration.bootstrapDefault — filet de sécurité', () {
    test('retourne 72h pour les 3 catégories', () {
      final defaults = PayoutPolicyConfiguration.bootstrapDefault();

      expect(defaults.defaultHoldPeriodHours, 72);
      expect(defaults.newDriverHoldPeriodHours, 72);
      expect(defaults.riskyDriverHoldPeriodHours, 72);
    });

    test('utilise l\'epoch comme updatedAt et un updatedByUserId vide', () {
      final defaults = PayoutPolicyConfiguration.bootstrapDefault();

      expect(defaults.updatedAt, DateTime.fromMillisecondsSinceEpoch(0));
      expect(defaults.updatedByUserId, '');
    });
  });

  group(
    'PayoutPolicyConfiguration.fromJson — rétro-compatibilité (champs absents)',
    () {
      test(
        'un document partiel (seulement default_hold_period_hours) applique 72h aux autres',
        () {
          final policy = PayoutPolicyConfiguration.fromJson({
            'default_hold_period_hours': 96,
          });

          expect(policy.defaultHoldPeriodHours, 96);
          expect(policy.newDriverHoldPeriodHours, 72);
          expect(policy.riskyDriverHoldPeriodHours, 72);
          expect(policy.updatedByUserId, '');
        },
      );

      test(
        'un JSON totalement vide ne plante jamais (fail-safe absolu, repli 72h)',
        () {
          final policy = PayoutPolicyConfiguration.fromJson(const {});

          expect(policy.defaultHoldPeriodHours, 72);
          expect(policy.newDriverHoldPeriodHours, 72);
          expect(policy.riskyDriverHoldPeriodHours, 72);
          expect(policy.updatedByUserId, '');
        },
      );
    },
  );
}
