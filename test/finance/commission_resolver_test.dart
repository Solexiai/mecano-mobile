// ---------------------------------------------------------------------------
// Tests unitaires — CommissionResolver
//
// Couvre (Étape 12, liste exacte demandée) :
//   - Taux de commission standard 10% / 12% / 15%
//   - Commission minimum (plancher $)
//   - Maximum effectif (plafond % protégeant les petites missions)
//   - Founding Driver (période promotionnelle ET taux préférentiel post-promo)
//   - Promotion chauffeur expirée (ne doit jamais s'appliquer)
// ---------------------------------------------------------------------------

import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/finance/engines/commission_resolver.dart';
import 'package:movik_connect/finance/models/founding_driver.dart';
import 'package:movik_connect/finance/models/pricing_config.dart';
import 'package:movik_connect/models/enums.dart';

CommissionConfig _standardConfig(double rate) => CommissionConfig(
  standardCommissionRate: rate,
  minimumPlatformCommission: 0,
  maximumEffectiveCommissionRate: 1.0,
);

void main() {
  final now = DateTime(2025, 6, 15, 12, 0, 0);

  group('CommissionResolver.resolve — taux standard par palier', () {
    for (final rate in [0.10, 0.12, 0.15]) {
      test('applique le taux standard configuré ($rate)', () {
        final result = CommissionResolver.resolve(
          standardConfig: _standardConfig(rate),
          now: now,
        );

        expect(result.rate, rate);
        expect(result.program, CommissionProgramType.standard);
        expect(result.reason, 'standard_rate');
      });
    }
  });

  group(
    'CommissionResolver.capEffectiveRate — plancher (minimum) et plafond (maximum effectif)',
    () {
      test(
        'la commission minimum en \$ est appliquée quand le taux brut ne suffit pas',
        () {
          // Petite mission : 10$ * 10% = 1$ de commission brute, mais le plancher
          // est de 5$ => le taux effectif réel doit refléter le plancher, pas le
          // taux nominal.
          final effectiveRate = CommissionResolver.capEffectiveRate(
            resolvedRate: 0.10,
            missionBaseValue: 10,
            minimumPlatformCommission: 5,
            maximumEffectiveCommissionRate:
                1.0, // pas de plafond actif dans ce cas
          );

          // 5$ / 10$ = 50% de taux effectif réel (plancher appliqué).
          expect(effectiveRate, closeTo(0.50, 1e-9));
        },
      );

      test(
        'le taux effectif ne dépasse jamais le maximum effectif configuré',
        () {
          // Même scénario que ci-dessus (taux effectif brut = 50%), mais cette
          // fois le plafond de protection est fixé à 30% : le plafond doit
          // prévaloir sur le plancher $ pour protéger les petites missions.
          final effectiveRate = CommissionResolver.capEffectiveRate(
            resolvedRate: 0.10,
            missionBaseValue: 10,
            minimumPlatformCommission: 5,
            maximumEffectiveCommissionRate: 0.30,
          );

          expect(effectiveRate, closeTo(0.30, 1e-9));
        },
      );

      test(
        'quand le taux brut dépasse déjà le plancher, le taux nominal est conservé (sous le plafond)',
        () {
          // 100$ * 15% = 15$ >= plancher 5$ => pas de plancher appliqué ; et 15%
          // < 30% de plafond => aucun plafonnement non plus.
          final effectiveRate = CommissionResolver.capEffectiveRate(
            resolvedRate: 0.15,
            missionBaseValue: 100,
            minimumPlatformCommission: 5,
            maximumEffectiveCommissionRate: 0.30,
          );

          expect(effectiveRate, closeTo(0.15, 1e-9));
        },
      );

      test(
        'missionBaseValue <= 0 retourne le taux résolu sans division par zéro',
        () {
          final effectiveRate = CommissionResolver.capEffectiveRate(
            resolvedRate: 0.12,
            missionBaseValue: 0,
            minimumPlatformCommission: 5,
            maximumEffectiveCommissionRate: 0.30,
          );

          expect(effectiveRate, 0.12);
        },
      );
    },
  );

  group('CommissionResolver.resolve — Founding Driver', () {
    final program = const FoundingDriverProgramConfig(
      programId: 'founding-2025',
      isActive: true,
      totalSlots: 100,
      slotsTaken: 42,
      promotionalCommissionRate: 0.05, // taux promo très avantageux
      promotionalDurationMonths: 3,
      preferredCommissionRate: 0.08, // taux préférentiel post-promo
    );

    test(
      'applique le taux PROMOTIONNEL quand la qualification est dans la période promo',
      () {
        final qualification = FoundingDriverQualification(
          driverId: 'driver_001',
          programId: program.programId,
          status: FoundingDriverStatus.qualified,
          qualifiedAt: now.subtract(const Duration(days: 10)),
          // La période promo se termine dans le futur => on est DANS la promo.
          promotionalPeriodEndsAt: now.add(const Duration(days: 20)),
        );

        final result = CommissionResolver.resolve(
          standardConfig: _standardConfig(0.15),
          now: now,
          foundingQualification: qualification,
          foundingProgram: program,
        );

        expect(result.rate, program.promotionalCommissionRate);
        expect(result.program, CommissionProgramType.foundingPreferred);
        expect(result.reason, 'founding_driver_promotional_period');
      },
    );

    test(
      'applique le taux PRÉFÉRENTIEL une fois la période promo terminée (qualification maintenue)',
      () {
        final qualification = FoundingDriverQualification(
          driverId: 'driver_001',
          programId: program.programId,
          status: FoundingDriverStatus.qualified,
          qualifiedAt: now.subtract(const Duration(days: 200)),
          // La période promo est terminée dans le passé => taux préférentiel.
          promotionalPeriodEndsAt: now.subtract(const Duration(days: 10)),
        );

        final result = CommissionResolver.resolve(
          standardConfig: _standardConfig(0.15),
          now: now,
          foundingQualification: qualification,
          foundingProgram: program,
        );

        expect(result.rate, program.preferredCommissionRate);
        expect(result.program, CommissionProgramType.foundingPreferred);
        expect(result.reason, 'founding_driver_preferred_rate');
      },
    );

    test(
      'un Founding Driver RÉVOQUÉ retombe sur le taux standard (pas de priorité founding)',
      () {
        final qualification = FoundingDriverQualification(
          driverId: 'driver_001',
          programId: program.programId,
          status: FoundingDriverStatus.revoked,
          qualifiedAt: now.subtract(const Duration(days: 200)),
          promotionalPeriodEndsAt: now.add(const Duration(days: 20)),
        );

        final result = CommissionResolver.resolve(
          standardConfig: _standardConfig(0.15),
          now: now,
          foundingQualification: qualification,
          foundingProgram: program,
        );

        expect(result.rate, 0.15);
        expect(result.program, CommissionProgramType.standard);
        expect(result.reason, 'standard_rate');
      },
    );
  });

  group('CommissionResolver.resolve — promotion chauffeur expirée', () {
    test(
      'une driver_promotion EXPIRÉE (endsAt dans le passé) ne doit JAMAIS être appliquée',
      () {
        final expiredPromotion = DriverPromotion(
          driverId: 'driver_002',
          promotionalCommissionRate: 0.05,
          startsAt: now.subtract(const Duration(days: 60)),
          endsAt: now.subtract(const Duration(days: 1)), // expirée hier
          isActive: true, // même si le flag is_active n'a pas encore été
          // rafraîchi par le cron expireDriverPromotions(), la fenêtre
          // temporelle doit primer : isCurrentlyValid() doit retourner false.
        );

        final result = CommissionResolver.resolve(
          standardConfig: _standardConfig(0.15),
          now: now,
          activePromotion: expiredPromotion,
        );

        expect(result.rate, 0.15);
        expect(result.program, CommissionProgramType.standard);
        expect(result.reason, 'standard_rate');
        // Confirme explicitement que la fenêtre temporelle est bien invalide.
        expect(expiredPromotion.isCurrentlyValid(now), isFalse);
      },
    );

    test(
      'une driver_promotion is_active=false ne doit JAMAIS être appliquée, même dans sa fenêtre temporelle',
      () {
        final deactivatedPromotion = DriverPromotion(
          driverId: 'driver_002',
          promotionalCommissionRate: 0.05,
          startsAt: now.subtract(const Duration(days: 5)),
          endsAt: now.add(const Duration(days: 5)),
          isActive: false, // désactivée manuellement par un admin
        );

        final result = CommissionResolver.resolve(
          standardConfig: _standardConfig(0.15),
          now: now,
          activePromotion: deactivatedPromotion,
        );

        expect(result.rate, 0.15);
        expect(result.program, CommissionProgramType.standard);
      },
    );

    test(
      'une driver_promotion VALIDE (active et dans sa fenêtre) est bien appliquée',
      () {
        final validPromotion = DriverPromotion(
          driverId: 'driver_002',
          promotionalCommissionRate: 0.05,
          startsAt: now.subtract(const Duration(days: 5)),
          endsAt: now.add(const Duration(days: 5)),
          isActive: true,
        );

        final result = CommissionResolver.resolve(
          standardConfig: _standardConfig(0.15),
          now: now,
          activePromotion: validPromotion,
        );

        expect(result.rate, 0.05);
        expect(result.program, CommissionProgramType.promotional);
        expect(result.reason, 'active_driver_promotion');
      },
    );
  });
}
