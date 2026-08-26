// ---------------------------------------------------------------------------
// Founding Drivers — modèles purs (Dart, sans dépendance Firebase).
//
// Programme promotionnel limité : commission réduite pendant une durée
// définie, puis maintien conditionnel d'un taux préférentiel selon des
// critères de qualification continue (jamais un acquis à vie automatique).
//
// IMPORTANT : la qualification/révocation d'un statut Founding Driver doit
// être décidée et écrite UNIQUEMENT côté serveur (Cloud Functions
// `qualifyFoundingDriver()` / `revokeFoundingDriverStatus()`). Ces modèles
// définissent seulement la structure de données.
// ---------------------------------------------------------------------------

import '../../models/enums.dart';

/// Configuration globale du programme Founding Drivers (nombre de places,
/// durée de la période promotionnelle, taux appliqué).
class FoundingDriverProgramConfig {
  final String programId;
  final bool isActive;
  final int totalSlots;
  final int slotsTaken;
  final double promotionalCommissionRate; // ex: 0.10 pour 10%
  final int promotionalDurationMonths; // ex: 3
  final double preferredCommissionRate; // taux préférentiel après la promo,
  // sous réserve de qualification continue
  final DateTime? programOpensAt;
  final DateTime? programClosesAt;

  const FoundingDriverProgramConfig({
    required this.programId,
    required this.isActive,
    required this.totalSlots,
    required this.slotsTaken,
    required this.promotionalCommissionRate,
    required this.promotionalDurationMonths,
    required this.preferredCommissionRate,
    this.programOpensAt,
    this.programClosesAt,
  });

  bool get hasAvailableSlots => slotsTaken < totalSlots;

  factory FoundingDriverProgramConfig.unconfigured() {
    return const FoundingDriverProgramConfig(
      programId: 'UNCONFIGURED',
      isActive: false,
      totalSlots: 0,
      slotsTaken: 0,
      promotionalCommissionRate: 0,
      promotionalDurationMonths: 0,
      preferredCommissionRate: 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'program_id': programId,
        'is_active': isActive,
        'total_slots': totalSlots,
        'slots_taken': slotsTaken,
        'promotional_commission_rate': promotionalCommissionRate,
        'promotional_duration_months': promotionalDurationMonths,
        'preferred_commission_rate': preferredCommissionRate,
        'program_opens_at': programOpensAt?.toIso8601String(),
        'program_closes_at': programClosesAt?.toIso8601String(),
      };

  factory FoundingDriverProgramConfig.fromJson(Map<String, dynamic> json) {
    return FoundingDriverProgramConfig(
      programId: json['program_id'] as String,
      isActive: json['is_active'] as bool? ?? false,
      totalSlots: json['total_slots'] as int? ?? 0,
      slotsTaken: json['slots_taken'] as int? ?? 0,
      promotionalCommissionRate: (json['promotional_commission_rate'] as num? ?? 0).toDouble(),
      promotionalDurationMonths: json['promotional_duration_months'] as int? ?? 0,
      preferredCommissionRate: (json['preferred_commission_rate'] as num? ?? 0).toDouble(),
      programOpensAt: json['program_opens_at'] != null
          ? DateTime.parse(json['program_opens_at'] as String)
          : null,
      programClosesAt: json['program_closes_at'] != null
          ? DateTime.parse(json['program_closes_at'] as String)
          : null,
    );
  }
}

/// Qualification individuelle d'un chauffeur au programme Founding Driver.
class FoundingDriverQualification {
  final String driverId;
  final String programId;
  final FoundingDriverStatus status;
  final DateTime qualifiedAt;
  final DateTime promotionalPeriodEndsAt;
  final String? suspensionReason;
  final String? revocationReason;
  final DateTime? statusChangedAt;
  final String? statusChangedByUserId; // toujours un admin/analyste/super_admin

  const FoundingDriverQualification({
    required this.driverId,
    required this.programId,
    required this.status,
    required this.qualifiedAt,
    required this.promotionalPeriodEndsAt,
    this.suspensionReason,
    this.revocationReason,
    this.statusChangedAt,
    this.statusChangedByUserId,
  });

  /// Le chauffeur profite-t-il toujours du taux promotionnel initial (vs.
  /// taux préférentiel post-promo) ?
  bool isWithinPromotionalPeriod(DateTime now) => now.isBefore(promotionalPeriodEndsAt);

  bool get isEligibleForPreferredRate =>
      status == FoundingDriverStatus.qualified;

  Map<String, dynamic> toJson() => {
        'driver_id': driverId,
        'program_id': programId,
        'status': status.name,
        'qualified_at': qualifiedAt.toIso8601String(),
        'promotional_period_ends_at': promotionalPeriodEndsAt.toIso8601String(),
        'suspension_reason': suspensionReason,
        'revocation_reason': revocationReason,
        'status_changed_at': statusChangedAt?.toIso8601String(),
        'status_changed_by_user_id': statusChangedByUserId,
      };

  factory FoundingDriverQualification.fromJson(Map<String, dynamic> json) {
    // Bloc R (rétrocompatibilité) : `driver_id`/`program_id` sont garantis
    // par `qualifyFoundingDriver()` (Cloud Function, seul point d'écriture)
    // depuis la création de la collection — mais `qualified_at`/
    // `promotional_period_ends_at` sont défensivement parsés avec repli
    // (jamais de crash) au cas où un document historique/corrompu manquerait
    // ces champs : repli sur `DateTime.now()` plutôt qu'une exception, pour
    // qu'un écran d'admin listant les qualifications ne plante jamais.
    return FoundingDriverQualification(
      driverId: json['driver_id'] as String? ?? '',
      programId: json['program_id'] as String? ?? '',
      status: FoundingDriverStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => FoundingDriverStatus.candidate,
      ),
      qualifiedAt: json['qualified_at'] != null
          ? (DateTime.tryParse(json['qualified_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      promotionalPeriodEndsAt: json['promotional_period_ends_at'] != null
          ? (DateTime.tryParse(json['promotional_period_ends_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      suspensionReason: json['suspension_reason'] as String?,
      revocationReason: json['revocation_reason'] as String?,
      statusChangedAt: json['status_changed_at'] != null
          ? DateTime.tryParse(json['status_changed_at'].toString())
          : null,
      statusChangedByUserId: json['status_changed_by_user_id'] as String?,
    );
  }
}
