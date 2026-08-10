// ---------------------------------------------------------------------------
// DriverCompensationEngine — calcule combien un chauffeur reçoit réellement
// pour une mission, à partir du devis client et du taux de commission
// résolu (CommissionResolver).
//
// Moteur PUR. Le résultat produit ici est une ESTIMATION affichable au
// chauffeur AVANT acceptation. Le montant qui compte réellement est celui
// figé par la Cloud Function au moment de l'acceptation (FinancialSnapshot).
// ---------------------------------------------------------------------------

import 'commission_resolver.dart';
import '../models/driver_compensation.dart';
import '../models/pricing_config.dart';
import 'customer_pricing_engine.dart';

class DriverCompensationEngine {
  /// Calcule la compensation chauffeur à partir d'un devis client déjà
  /// calculé et d'une commission déjà résolue.
  static DriverCompensationResult calculate({
    required CustomerPricingResult pricingResult,
    required ResolvedCommission resolvedCommission,
    required CommissionConfig commissionConfig,
    double tipAmount = 0,
    List<ManualDriverAdjustment> manualAdjustments = const [],
  }) {
    if (pricingResult.pricingVersion == 'UNCONFIGURED') {
      return DriverCompensationResult.unconfigured();
    }

    // Base sur laquelle la commission est calculée : le prix mission +
    // manutention + attente + arrêts + majorations (hors frais de service
    // client et hors taxes, qui restent 100% à la plateforme/gouvernement).
    final commissionBase = pricingResult.subtotal;

    final effectiveRate = CommissionResolver.capEffectiveRate(
      resolvedRate: resolvedCommission.rate,
      missionBaseValue: commissionBase,
      minimumPlatformCommission: commissionConfig.minimumPlatformCommission,
      maximumEffectiveCommissionRate: commissionConfig.maximumEffectiveCommissionRate,
    );

    final rawCommission = commissionBase * effectiveRate;
    final platformCommissionAmount = rawCommission < commissionConfig.minimumPlatformCommission
        ? (commissionBase <= 0 ? 0.0 : commissionConfig.minimumPlatformCommission)
        : rawCommission;

    final driverGrossEarnings = commissionBase - platformCommissionAmount;
    final driverOfferAmount = driverGrossEarnings; // pas d'incitatif dispatch pour l'instant

    final manualAdjustmentsTotal =
        manualAdjustments.fold<double>(0, (sum, a) => sum + a.amount);

    final driverNetMissionEarnings =
        driverOfferAmount + tipAmount + manualAdjustmentsTotal;

    return DriverCompensationResult(
      driverGrossEarnings: driverGrossEarnings,
      driverOfferAmount: driverOfferAmount,
      tipAmount: tipAmount,
      manualAdjustmentsTotal: manualAdjustmentsTotal,
      adjustments: manualAdjustments,
      driverNetMissionEarnings: driverNetMissionEarnings,
      pricingVersion: pricingResult.pricingVersion,
    );
  }
}
