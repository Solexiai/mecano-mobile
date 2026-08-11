// ---------------------------------------------------------------------------
// Tests unitaires — CustomerPricingEngine
//
// Couvre (Étape 12) : le calcul de devis client de base ET la "promotion
// client" (customerDiscountAmount) — plafonnement au subtotal brut, jamais
// négatif, frais de service et taxes recalculés sur le subtotal APRÈS remise.
// ---------------------------------------------------------------------------

import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/finance/engines/customer_pricing_engine.dart';
import 'package:movik_connect/finance/models/pricing_config.dart';
import 'package:movik_connect/models/enums.dart';

PricingConfig _config({double taxRate = 0.0, double serviceFeeRate = 0.0}) {
  return PricingConfig(
    pricingVersion: 'TEST-PRICING-001',
    isActive: true,
    effectiveFrom: DateTime(2025, 1, 1),
    vehicleRules: const [
      VehiclePricingRule(
        category: VehicleCategory.cargoVan,
        baseFare: 20,
        ratePerKm: 1.5,
        ratePerMinute: 0.3,
        minimumCharge: 25,
      ),
    ],
    handlingFees: const HandlingFeeConfig(heavyItemFee: 10),
    waitingFee: const WaitingFeeConfig(freeWaitingMinutes: 10, waitingRatePerMinute: 0.5),
    additionalStopFee: const AdditionalStopFeeConfig(feePerStop: 5),
    surcharges: const [],
    customerServiceFee: CustomerServiceFeeConfig(serviceFeeRate: serviceFeeRate, minimumServiceFee: 0),
    commission: const CommissionConfig(
      standardCommissionRate: 0.15,
      minimumPlatformCommission: 0,
      maximumEffectiveCommissionRate: 1.0,
    ),
    tipPolicy: const TipPolicyConfig(),
    quoteConfig: const QuoteConfig(),
    taxRate: taxRate,
  );
}

void main() {
  group('CustomerPricingEngine.calculateQuote — calcul de base (sans remise)', () {
    test('calcule correctement missionBaseValue, frais et subtotal', () {
      final config = _config();
      final result = CustomerPricingEngine.calculateQuote(
        config: config,
        input: const CustomerPricingInput(
          vehicleCategory: VehicleCategory.cargoVan,
          distanceKm: 10,
          estimatedDurationMinutes: 20,
        ),
      );

      // base = 20 + 1.5*10 + 0.3*20 = 20 + 15 + 6 = 41 (> minimumCharge 25)
      expect(result.missionBaseValue, closeTo(41.0, 1e-9));
      expect(result.handlingFeesTotal, 0);
      expect(result.customerDiscountAmount, 0);
      expect(result.subtotal, closeTo(41.0, 1e-9));
      expect(result.customerTotal, closeTo(41.0, 1e-9));
    });

    test('applique le minimumCharge quand le tarif brut calculé est trop bas', () {
      final config = _config();
      final result = CustomerPricingEngine.calculateQuote(
        config: config,
        input: const CustomerPricingInput(
          vehicleCategory: VehicleCategory.cargoVan,
          distanceKm: 1,
          estimatedDurationMinutes: 1,
        ),
      );

      // base brute = 20 + 1.5 + 0.3 = 21.8 < minimumCharge 25 => plancher appliqué
      expect(result.missionBaseValue, closeTo(25.0, 1e-9));
    });

    test('retourne un résultat neutre (unconfigured) si la config est inactive', () {
      final config = _config();
      final inactiveConfig = PricingConfig(
        pricingVersion: config.pricingVersion,
        isActive: false,
        effectiveFrom: config.effectiveFrom,
        vehicleRules: config.vehicleRules,
        handlingFees: config.handlingFees,
        waitingFee: config.waitingFee,
        additionalStopFee: config.additionalStopFee,
        surcharges: config.surcharges,
        customerServiceFee: config.customerServiceFee,
        commission: config.commission,
        tipPolicy: config.tipPolicy,
        quoteConfig: config.quoteConfig,
      );

      final result = CustomerPricingEngine.calculateQuote(
        config: inactiveConfig,
        input: const CustomerPricingInput(
          vehicleCategory: VehicleCategory.cargoVan,
          distanceKm: 10,
          estimatedDurationMinutes: 10,
        ),
      );

      expect(result.pricingVersion, 'UNCONFIGURED');
      expect(result.customerTotal, 0);
    });
  });

  group('CustomerPricingEngine.calculateQuote — promotion client (customerDiscountAmount)', () {
    test('une remise valide réduit le subtotal, et les frais de service + taxes sont calculés APRÈS remise', () {
      final config = _config(taxRate: 0.10, serviceFeeRate: 0.05);

      final noDiscount = CustomerPricingEngine.calculateQuote(
        config: config,
        input: const CustomerPricingInput(
          vehicleCategory: VehicleCategory.cargoVan,
          distanceKm: 10,
          estimatedDurationMinutes: 20,
        ),
      );
      // rawSubtotal = 41 (voir test ci-dessus)
      expect(noDiscount.subtotal, closeTo(41.0, 1e-9));

      final withDiscount = CustomerPricingEngine.calculateQuote(
        config: config,
        input: const CustomerPricingInput(
          vehicleCategory: VehicleCategory.cargoVan,
          distanceKm: 10,
          estimatedDurationMinutes: 20,
          customerDiscountAmount: 10,
        ),
      );

      expect(withDiscount.customerDiscountAmount, closeTo(10.0, 1e-9));
      // subtotal après remise = 41 - 10 = 31
      expect(withDiscount.subtotal, closeTo(31.0, 1e-9));
      // customerServiceFee = 5% * 31 (post-remise), PAS 5% * 41
      expect(withDiscount.customerServiceFee, closeTo(31.0 * 0.05, 1e-9));
      // taxAmount = 10% * (subtotal + serviceFee) post-remise
      final expectedTax = (31.0 + 31.0 * 0.05) * 0.10;
      expect(withDiscount.taxAmount, closeTo(expectedTax, 1e-9));
      // Le total client avec remise doit être strictement inférieur au total sans remise.
      expect(withDiscount.customerTotal, lessThan(noDiscount.customerTotal));
    });

    test('une remise supérieure au subtotal brut est plafonnée exactement au subtotal (jamais négatif)', () {
      final config = _config();
      final result = CustomerPricingEngine.calculateQuote(
        config: config,
        input: const CustomerPricingInput(
          vehicleCategory: VehicleCategory.cargoVan,
          distanceKm: 10,
          estimatedDurationMinutes: 20,
          customerDiscountAmount: 999999, // largement supérieure au subtotal
        ),
      );

      // rawSubtotal = 41 => la remise appliquée doit être plafonnée à 41.
      expect(result.customerDiscountAmount, closeTo(41.0, 1e-9));
      expect(result.subtotal, closeTo(0.0, 1e-9));
      expect(result.customerTotal, greaterThanOrEqualTo(0));
    });

    test('une remise négative ou nulle est ignorée (aucun effet, pas de crash)', () {
      final config = _config();
      final result = CustomerPricingEngine.calculateQuote(
        config: config,
        input: const CustomerPricingInput(
          vehicleCategory: VehicleCategory.cargoVan,
          distanceKm: 10,
          estimatedDurationMinutes: 20,
          customerDiscountAmount: -50,
        ),
      );

      expect(result.customerDiscountAmount, 0);
      expect(result.subtotal, closeTo(41.0, 1e-9));
    });
  });
}
