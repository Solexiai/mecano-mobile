// ---------------------------------------------------------------------------
// FoundingDriverEngine — logique de calcul PURE liée au programme Founding
// Drivers : places disponibles, fin de période promotionnelle, éligibilité
// au taux préférentiel.
//
// IMPORTANT : ce moteur ne DÉCIDE ni n'ÉCRIT jamais un changement de statut
// Founding Driver. Il ne fait que calculer des faits dérivés (ex: "la
// période promo est-elle terminée ?", "reste-t-il des places ?") que
// l'interface peut afficher. La décision réelle de qualifier/suspendre/
// révoquer un chauffeur doit être prise par les Cloud Functions
// `qualifyFoundingDriver()` / `revokeFoundingDriverStatus()`.
// ---------------------------------------------------------------------------

import '../../models/enums.dart';
import '../models/founding_driver.dart';

class FoundingDriverEligibility {
  final bool programHasAvailableSlots;
  final bool driverIsWithinPromotionalPeriod;
  final bool driverIsEligibleForPreferredRate;
  final double applicableRate;
  final String explanation;

  const FoundingDriverEligibility({
    required this.programHasAvailableSlots,
    required this.driverIsWithinPromotionalPeriod,
    required this.driverIsEligibleForPreferredRate,
    required this.applicableRate,
    required this.explanation,
  });

  factory FoundingDriverEligibility.notConfigured() {
    return const FoundingDriverEligibility(
      programHasAvailableSlots: false,
      driverIsWithinPromotionalPeriod: false,
      driverIsEligibleForPreferredRate: false,
      applicableRate: 0,
      explanation: 'not_configured',
    );
  }
}

class FoundingDriverEngine {
  static FoundingDriverEligibility evaluate({
    required FoundingDriverProgramConfig program,
    FoundingDriverQualification? qualification,
    required DateTime now,
  }) {
    if (program.programId == 'UNCONFIGURED') {
      return FoundingDriverEligibility.notConfigured();
    }

    if (qualification == null) {
      return FoundingDriverEligibility(
        programHasAvailableSlots: program.hasAvailableSlots,
        driverIsWithinPromotionalPeriod: false,
        driverIsEligibleForPreferredRate: false,
        applicableRate: program.hasAvailableSlots
            ? program.promotionalCommissionRate
            : 0,
        explanation: program.hasAvailableSlots
            ? 'candidate_eligible_no_slots_taken_yet'
            : 'program_full',
      );
    }

    if (qualification.status != FoundingDriverStatus.qualified) {
      return FoundingDriverEligibility(
        programHasAvailableSlots: program.hasAvailableSlots,
        driverIsWithinPromotionalPeriod: false,
        driverIsEligibleForPreferredRate: false,
        applicableRate: 0,
        explanation: 'driver_status_${qualification.status.name}',
      );
    }

    final withinPromo = qualification.isWithinPromotionalPeriod(now);
    return FoundingDriverEligibility(
      programHasAvailableSlots: program.hasAvailableSlots,
      driverIsWithinPromotionalPeriod: withinPromo,
      driverIsEligibleForPreferredRate: true,
      applicableRate: withinPromo
          ? program.promotionalCommissionRate
          : program.preferredCommissionRate,
      explanation: withinPromo
          ? 'within_promotional_period'
          : 'preferred_rate_post_promotion',
    );
  }
}
