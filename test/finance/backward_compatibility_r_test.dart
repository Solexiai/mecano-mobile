// ---------------------------------------------------------------------------
// Tests unitaires — BLOC R (Backward Compatibility), modèles finance.
//
// OBJECTIF : prouver que les deux GAPS réels identifiés lors de l'audit
// Bloc R (FoundingDriverQualification.fromJson et
// ManualDriverAdjustment.fromJson, tous deux effectuant auparavant des
// casts non-nullables `as String`/`DateTime.parse` sans repli) ne font plus
// planter l'application face à un document historique/partiel/corrompu.
//
// CONTEXTE (voir docs/PHASE7_QA_MATRIX.md — BLOC R) : ces deux modèles ne
// sont actuellement JAMAIS désérialisés depuis un VRAI document Firestore
// par un repository de ce projet (`FoundingDriverQualification.fromJson` et
// `ManualDriverAdjustment.fromJson` sont du code mort au sens strict —
// aucun `grep` ne trouve d'appelant hors de ce fichier de modèle et de ses
// propres tests). Le durcissement est fait PAR PRÉCAUTION (cohérence avec
// le reste du projet, coût de correction nul) et PAS parce qu'un vecteur
// d'exposition réel a été identifié en production — voir le tableau Bloc R
// pour la distinction complète GAP réel vs COUVERT-par-conception.
// ---------------------------------------------------------------------------

import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/finance/models/founding_driver.dart';
import 'package:movik_connect/finance/models/driver_compensation.dart';
import 'package:movik_connect/models/enums.dart';

void main() {
  group('BLOC R — FoundingDriverQualification.fromJson (document legacy/partiel)', () {
    test(
      'document minimal (driver_id/program_id/status uniquement, dates absentes) '
      'ne plante PAS : repli sur DateTime.now() au lieu d\'une exception',
      () {
        final legacy = {
          'driver_id': 'driver_001',
          'program_id': 'program_001',
          'status': 'qualified',
          // qualified_at et promotional_period_ends_at ABSENTS (simule un
          // document historique créé avant l'ajout de ces champs, ou un
          // export partiel).
        };

        final result = FoundingDriverQualification.fromJson(legacy);

        expect(result.driverId, 'driver_001');
        expect(result.programId, 'program_001');
        expect(result.status, FoundingDriverStatus.qualified);
        expect(result.qualifiedAt, isNotNull); // jamais null, jamais d'exception
        expect(result.promotionalPeriodEndsAt, isNotNull);
      },
    );

    test('document totalement vide ne plante pas (tous les champs replient sur une valeur sûre)', () {
      final result = FoundingDriverQualification.fromJson(const {});

      expect(result.driverId, '');
      expect(result.programId, '');
      expect(result.status, FoundingDriverStatus.candidate); // fallback orElse existant
      expect(result.qualifiedAt, isNotNull);
      expect(result.promotionalPeriodEndsAt, isNotNull);
      expect(result.statusChangedAt, isNull); // champ optionnel reste null
    });

    test('date au format Firestore Timestamp-like (.toDate()) ou String corrompue ne plante pas', () {
      final withCorruptedDate = {
        'driver_id': 'driver_002',
        'program_id': 'program_002',
        'status': 'qualified',
        'qualified_at': 'NOT_A_VALID_DATE',
        'promotional_period_ends_at': 'NOT_A_VALID_DATE_EITHER',
      };

      final result = FoundingDriverQualification.fromJson(withCorruptedDate);
      expect(result.qualifiedAt, isNotNull);
      expect(result.promotionalPeriodEndsAt, isNotNull);
    });
  });

  group('BLOC R — ManualDriverAdjustment.fromJson (document legacy/partiel)', () {
    test('document minimal sans aucun champ ne plante pas', () {
      final result = ManualDriverAdjustment.fromJson(const {});

      expect(result.id, '');
      expect(result.reason, '');
      expect(result.amount, 0);
      expect(result.createdByUserId, 'unknown');
      expect(result.createdAt, isNotNull);
    });

    test('ajustement complet reste correctement désérialisé (pas de régression)', () {
      final full = {
        'id': 'adj_001',
        'reason': 'bonus_ponctualite',
        'amount': 5.0,
        'created_by_user_id': 'admin_001',
        'created_at': DateTime(2025, 1, 1).toIso8601String(),
      };

      final result = ManualDriverAdjustment.fromJson(full);
      expect(result.id, 'adj_001');
      expect(result.reason, 'bonus_ponctualite');
      expect(result.amount, 5.0);
      expect(result.createdByUserId, 'admin_001');
      expect(result.createdAt, DateTime(2025, 1, 1));
    });
  });
}
