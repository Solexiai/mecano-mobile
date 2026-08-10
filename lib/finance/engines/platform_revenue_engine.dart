// ---------------------------------------------------------------------------
// PlatformRevenueEngine — calcule le revenu brut et la marge de
// contribution de la plateforme sur une mission.
//
// Moteur PUR. Combine le résultat du CustomerPricingEngine (frais de
// service client) avec la commission effectivement prélevée (calculée par
// le DriverCompensationEngine, qui applique déjà le plancher/plafond), puis
// déduit les coûts variables réels.
// ---------------------------------------------------------------------------

import '../models/platform_revenue.dart';
import 'customer_pricing_engine.dart';

class PlatformRevenueEngine {
  static PlatformRevenueResult calculate({
    required CustomerPricingResult pricingResult,
    required double platformCommissionAmount,
    PlatformVariableCosts variableCosts = const PlatformVariableCosts(),
  }) {
    if (pricingResult.pricingVersion == 'UNCONFIGURED') {
      return PlatformRevenueResult.unconfigured();
    }

    final platformGrossRevenue =
        platformCommissionAmount + pricingResult.customerServiceFee;

    final contributionMargin = platformGrossRevenue - variableCosts.total;

    return PlatformRevenueResult(
      platformCommissionAmount: platformCommissionAmount,
      customerServiceFeeAmount: pricingResult.customerServiceFee,
      platformGrossRevenue: platformGrossRevenue,
      variableCosts: variableCosts,
      contributionMargin: contributionMargin,
      pricingVersion: pricingResult.pricingVersion,
    );
  }
}
