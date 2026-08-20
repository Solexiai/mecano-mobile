// ---------------------------------------------------------------------------
// Tests unitaires — DriverCompensationEngine
//
// Couvre (Étape 12) : pourboire 100% redirigé au chauffeur, ajustements
// manuels (bonus), et cohérence avec la commission résolue.
// ---------------------------------------------------------------------------

import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/finance/engines/commission_resolver.dart';
import 'package:movik_connect/finance/engines/customer_pricing_engine.dart';
import 'package:movik_connect/finance/engines/driver_compensation_engine.dart';
import 'package:movik_connect/finance/models/driver_compensation.dart';
import 'package:movik_connect/finance/models/pricing_config.dart';
import 'package:movik_connect/models/enums.dart';

const _commissionConfig = CommissionConfig(
  standardCommissionRate: 0.15,
  minimumPlatformCommission: 0,
  maximumEffectiveCommissionRate: 1.0,
);

const _pricingResult = CustomerPricingResult(
  pricingVersion: 'TEST-PRICING-001',
  missionBaseValue: 100,
  handlingFeesTotal: 0,
  waitingFee: 0,
  additionalStopsFee: 0,
  surchargesTotal: 0,
  subtotal: 100, // base de calcul commission
  customerServiceFee: 5,
  taxAmount: 10,
  customerTotal: 115,
);

const _resolvedStandard = ResolvedCommission(
  rate: 0.15,
  program: CommissionProgramType.standard,
  reason: 'standard_rate',
);

void main() {
  group('DriverCompensationEngine.calculate — commission de base', () {
    test('driverGrossEarnings = subtotal - commission plateforme (15%)', () {
      final result = DriverCompensationEngine.calculate(
        pricingResult: _pricingResult,
        resolvedCommission: _resolvedStandard,
        commissionConfig: _commissionConfig,
      );

      // commission = 100 * 15% = 15 => driverGrossEarnings = 100 - 15 = 85
      expect(result.driverGrossEarnings, closeTo(85.0, 1e-9));
      expect(result.driverOfferAmount, closeTo(85.0, 1e-9));
      expect(result.tipAmount, 0);
      expect(result.manualAdjustmentsTotal, 0);
      expect(result.driverNetMissionEarnings, closeTo(85.0, 1e-9));
    });

    test(
      'retourne un résultat neutre (unconfigured) si le pricingResult est UNCONFIGURED',
      () {
        final result = DriverCompensationEngine.calculate(
          pricingResult: CustomerPricingResult.unconfigured(),
          resolvedCommission: _resolvedStandard,
          commissionConfig: _commissionConfig,
        );

        expect(result.pricingVersion, 'UNCONFIGURED');
        expect(result.driverNetMissionEarnings, 0);
      },
    );
  });

  group(
    'DriverCompensationEngine.calculate — pourboire 100% (politique protégée)',
    () {
      test(
        'un pourboire de 20\$ est intégralement redirigé au chauffeur (100%, pas de ponction)',
        () {
          final result = DriverCompensationEngine.calculate(
            pricingResult: _pricingResult,
            resolvedCommission: _resolvedStandard,
            commissionConfig: _commissionConfig,
            tipAmount: 20,
          );

          // driverOfferAmount reste 85 (commission calculée SUR le subtotal, pas
          // sur le pourboire) ; le pourboire s'ajoute intégralement au net.
          expect(result.driverOfferAmount, closeTo(85.0, 1e-9));
          expect(result.tipAmount, closeTo(20.0, 1e-9));
          // net = offer + tip (100% du tip, aucune commission prélevée dessus)
          expect(result.driverNetMissionEarnings, closeTo(85.0 + 20.0, 1e-9));
        },
      );

      test('un pourboire de 0\$ ne change rien au résultat', () {
        final result = DriverCompensationEngine.calculate(
          pricingResult: _pricingResult,
          resolvedCommission: _resolvedStandard,
          commissionConfig: _commissionConfig,
          tipAmount: 0,
        );

        expect(result.driverNetMissionEarnings, closeTo(85.0, 1e-9));
      });
    },
  );

  group('DriverCompensationEngine.calculate — bonus / ajustements manuels', () {
    test(
      'un bonus manuel positif est ajouté intégralement au gain net du chauffeur',
      () {
        final bonus = ManualDriverAdjustment(
          id: 'adj_001',
          reason: 'Bonus ponctualité',
          amount: 15,
          createdByUserId: 'admin_001',
          createdAt: DateTime(2025, 6, 15),
        );

        final result = DriverCompensationEngine.calculate(
          pricingResult: _pricingResult,
          resolvedCommission: _resolvedStandard,
          commissionConfig: _commissionConfig,
          manualAdjustments: [bonus],
        );

        expect(result.manualAdjustmentsTotal, closeTo(15.0, 1e-9));
        expect(result.adjustments, hasLength(1));
        expect(result.adjustments.first.reason, 'Bonus ponctualité');
        // net = offer(85) + tip(0) + bonus(15)
        expect(result.driverNetMissionEarnings, closeTo(100.0, 1e-9));
      },
    );

    test(
      'une pénalité manuelle (montant négatif) réduit le gain net du chauffeur',
      () {
        final penalty = ManualDriverAdjustment(
          id: 'adj_002',
          reason: 'Retard signalé par le client',
          amount: -10,
          createdByUserId: 'admin_001',
          createdAt: DateTime(2025, 6, 15),
        );

        final result = DriverCompensationEngine.calculate(
          pricingResult: _pricingResult,
          resolvedCommission: _resolvedStandard,
          commissionConfig: _commissionConfig,
          manualAdjustments: [penalty],
        );

        expect(result.manualAdjustmentsTotal, closeTo(-10.0, 1e-9));
        // net = offer(85) - 10 = 75
        expect(result.driverNetMissionEarnings, closeTo(75.0, 1e-9));
      },
    );

    test(
      'plusieurs ajustements manuels (bonus + pourboire) se cumulent correctement',
      () {
        final bonus = ManualDriverAdjustment(
          id: 'adj_003',
          reason: 'Bonus événement spécial',
          amount: 25,
          createdByUserId: 'admin_002',
          createdAt: DateTime(2025, 6, 15),
        );

        final result = DriverCompensationEngine.calculate(
          pricingResult: _pricingResult,
          resolvedCommission: _resolvedStandard,
          commissionConfig: _commissionConfig,
          tipAmount: 30,
          manualAdjustments: [bonus],
        );

        // net = offer(85) + tip(30) + bonus(25) = 140
        expect(result.driverNetMissionEarnings, closeTo(140.0, 1e-9));
      },
    );
  });

  group(
    'DriverCompensationEngine.calculate — cohérence avec Founding Driver / commission réduite',
    () {
      test(
        'un taux de commission Founding Driver (5%) augmente le gain net du chauffeur par rapport au taux standard',
        () {
          const resolvedFounding = ResolvedCommission(
            rate: 0.05,
            program: CommissionProgramType.foundingPreferred,
            reason: 'founding_driver_promotional_period',
          );

          final standardResult = DriverCompensationEngine.calculate(
            pricingResult: _pricingResult,
            resolvedCommission: _resolvedStandard,
            commissionConfig: _commissionConfig,
          );

          final foundingResult = DriverCompensationEngine.calculate(
            pricingResult: _pricingResult,
            resolvedCommission: resolvedFounding,
            commissionConfig: _commissionConfig,
          );

          expect(
            foundingResult.driverNetMissionEarnings,
            greaterThan(standardResult.driverNetMissionEarnings),
          );
          // commission Founding = 100 * 5% = 5 => driverOfferAmount = 95
          expect(foundingResult.driverOfferAmount, closeTo(95.0, 1e-9));
        },
      );
    },
  );
}
