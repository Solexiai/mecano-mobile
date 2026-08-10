// ---------------------------------------------------------------------------
// CommissionResolver — détermine le taux de commission EFFECTIF applicable
// à une mission donnée, selon la hiérarchie :
//
//   1. Founding Driver (taux promotionnel actif, puis préférentiel si
//      qualification maintenue)
//   2. Promotion active spécifique au chauffeur (driver_promotions)
//   3. Taux standard (CommissionConfig.standardCommissionRate)
//
// Le taux résolu est ensuite borné par :
//   - minimumPlatformCommission (plancher, exprimé en $ pas en %, appliqué
//     par le PricingEngine, pas ici)
//   - maximumEffectiveCommissionRate (plafond en %, protège les petites
//     missions contre un taux effectif disproportionné dû au plancher $)
//
// Ce résolveur est PUR (aucun effet de bord, aucun accès réseau). Le calcul
// final "officiel" doit être rejoué et confirmé côté serveur au moment de
// l'acceptation de la mission.
// ---------------------------------------------------------------------------

import '../../models/enums.dart';
import '../models/founding_driver.dart';
import '../models/pricing_config.dart';

class ResolvedCommission {
  final double rate;
  final CommissionProgramType program;
  final String reason;

  const ResolvedCommission({
    required this.rate,
    required this.program,
    required this.reason,
  });
}

class DriverPromotion {
  final String driverId;
  final double promotionalCommissionRate;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool isActive;

  const DriverPromotion({
    required this.driverId,
    required this.promotionalCommissionRate,
    required this.startsAt,
    required this.endsAt,
    required this.isActive,
  });

  bool isCurrentlyValid(DateTime now) =>
      isActive && now.isAfter(startsAt) && now.isBefore(endsAt);
}

class CommissionResolver {
  /// Résout le taux de commission effectif pour un chauffeur donné, à un
  /// instant donné, en tenant compte de son éventuel statut Founding Driver
  /// et de ses promotions actives, avec repli sur le taux standard.
  static ResolvedCommission resolve({
    required CommissionConfig standardConfig,
    required DateTime now,
    FoundingDriverQualification? foundingQualification,
    FoundingDriverProgramConfig? foundingProgram,
    DriverPromotion? activePromotion,
  }) {
    // 1. Founding Driver (priorité la plus haute)
    if (foundingQualification != null &&
        foundingQualification.status == FoundingDriverStatus.qualified &&
        foundingProgram != null) {
      final withinPromo = foundingQualification.isWithinPromotionalPeriod(now);
      final rate = withinPromo
          ? foundingProgram.promotionalCommissionRate
          : foundingProgram.preferredCommissionRate;
      return ResolvedCommission(
        rate: rate,
        program: CommissionProgramType.foundingPreferred,
        reason: withinPromo
            ? 'founding_driver_promotional_period'
            : 'founding_driver_preferred_rate',
      );
    }

    // 2. Promotion active spécifique au chauffeur
    if (activePromotion != null && activePromotion.isCurrentlyValid(now)) {
      return ResolvedCommission(
        rate: activePromotion.promotionalCommissionRate,
        program: CommissionProgramType.promotional,
        reason: 'active_driver_promotion',
      );
    }

    // 3. Taux standard
    return ResolvedCommission(
      rate: standardConfig.standardCommissionRate,
      program: CommissionProgramType.standard,
      reason: 'standard_rate',
    );
  }

  /// Applique le plafond de taux effectif protégeant les petites missions.
  /// Le taux effectif réel = platformCommissionAmount / missionBaseValue.
  /// Si ce ratio dépasse `maximumEffectiveCommissionRate` (car le plancher
  /// $ minimumPlatformCommission a été appliqué), le plafond prévaut.
  static double capEffectiveRate({
    required double resolvedRate,
    required double missionBaseValue,
    required double minimumPlatformCommission,
    required double maximumEffectiveCommissionRate,
  }) {
    if (missionBaseValue <= 0) return resolvedRate;
    final rawCommission = missionBaseValue * resolvedRate;
    final appliedCommission =
        rawCommission < minimumPlatformCommission ? minimumPlatformCommission : rawCommission;
    final effectiveRate = appliedCommission / missionBaseValue;
    if (effectiveRate > maximumEffectiveCommissionRate) {
      return maximumEffectiveCommissionRate;
    }
    return effectiveRate;
  }
}
