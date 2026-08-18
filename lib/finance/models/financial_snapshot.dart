// ---------------------------------------------------------------------------
// FinancialSnapshot — l'enregistrement contractuel IMMUABLE d'une mission.
//
// Ce modèle représente le contrat financier figé au moment où il devient
// ferme (typiquement à l'acceptation de la mission par un chauffeur).
//
// RÈGLES CRITIQUES :
// - Ce document ne doit être créé QUE côté serveur (Cloud Function
//   `createFinancialSnapshot()`), jamais depuis Flutter.
// - Une fois `status = confirmed`, aucun champ ne doit plus être modifié.
//   Toute correction ultérieure doit passer par une entrée compensatoire
//   dans le `transaction_ledger`, jamais par une réécriture de ce document.
// - Ce fichier Dart ne fait QUE décrire la forme des données (sérialisation
//   / désérialisation) pour que le frontend puisse LIRE un snapshot déjà
//   créé côté serveur et l'afficher correctement. Il ne contient aucune
//   logique d'écriture financière.
// ---------------------------------------------------------------------------

import '../../models/enums.dart';
import '../../backend/models/firestore_date.dart';

class FinancialSnapshot {
  final String snapshotId;
  final String missionId;
  final String customerId;
  final String driverId;

  /// Version de la grille tarifaire utilisée (traçabilité complète).
  final String pricingVersion;

  /// Valeur de base de la mission avant frais/commission/taxes.
  final double missionBaseValue;

  /// Montant brut destiné au chauffeur avant ajustements/pourboire.
  final double driverGrossEarnings;

  /// Montant réellement offert/affiché au chauffeur au moment de
  /// l'acceptation — figé, ne changera plus pour cette mission.
  final double driverOfferAmount;

  final double commissionRate;
  final CommissionProgramType commissionProgram;
  final double minimumPlatformCommission;
  final double maximumEffectiveCommissionRate;
  final double platformCommissionAmount;
  final double customerServiceFee;

  /// Autres frais facturés au client (ex: attente, arrêt supplémentaire,
  /// majoration horaire).
  final double customerFees;

  final double customerDiscount;
  final double customerTax;

  final double driverBonus;
  final double tipAmount;

  /// Gain net final du chauffeur pour cette mission (offer + tip + bonus).
  final double driverNetMissionEarnings;

  /// Total effectivement versé au chauffeur (peut inclure des ajustements
  /// manuels ultérieurs enregistrés séparément dans le ledger).
  final double driverTotalPayout;

  final double paymentProcessingCost;
  final double insuranceCost;

  /// Montant total facturé au client (mission + frais + taxes - remise).
  final double customerTotal;

  /// Revenu brut de la plateforme sur cette mission.
  final double platformGrossRevenue;

  /// Marge de contribution prévisionnelle (revenu brut - coûts variables).
  final double contributionMargin;

  final DateTime createdAt;
  final DateTime? confirmedAt;

  /// pending : créé mais pas encore confirmé (ex: devis, avant acceptation)
  /// confirmed : figé définitivement, immuable
  final String status; // 'pending' | 'confirmed'

  const FinancialSnapshot({
    required this.snapshotId,
    required this.missionId,
    required this.customerId,
    required this.driverId,
    required this.pricingVersion,
    required this.missionBaseValue,
    required this.driverGrossEarnings,
    required this.driverOfferAmount,
    required this.commissionRate,
    required this.commissionProgram,
    required this.minimumPlatformCommission,
    required this.maximumEffectiveCommissionRate,
    required this.platformCommissionAmount,
    required this.customerServiceFee,
    required this.customerFees,
    required this.customerDiscount,
    required this.customerTax,
    required this.driverBonus,
    required this.tipAmount,
    required this.driverNetMissionEarnings,
    required this.driverTotalPayout,
    required this.paymentProcessingCost,
    required this.insuranceCost,
    required this.customerTotal,
    required this.platformGrossRevenue,
    required this.contributionMargin,
    required this.createdAt,
    this.confirmedAt,
    required this.status,
  });

  bool get isImmutable => status == 'confirmed';

  Map<String, dynamic> toJson() => {
        'snapshot_id': snapshotId,
        'mission_id': missionId,
        'customer_id': customerId,
        'driver_id': driverId,
        'pricing_version': pricingVersion,
        'mission_base_value': missionBaseValue,
        'driver_gross_earnings': driverGrossEarnings,
        'driver_offer_amount': driverOfferAmount,
        'commission_rate': commissionRate,
        'commission_program': commissionProgram.name,
        'minimum_platform_commission': minimumPlatformCommission,
        'maximum_effective_commission_rate': maximumEffectiveCommissionRate,
        'platform_commission_amount': platformCommissionAmount,
        'customer_service_fee': customerServiceFee,
        'customer_fees': customerFees,
        'customer_discount': customerDiscount,
        'customer_tax': customerTax,
        'driver_bonus': driverBonus,
        'tip_amount': tipAmount,
        'driver_net_mission_earnings': driverNetMissionEarnings,
        'driver_total_payout': driverTotalPayout,
        'payment_processing_cost': paymentProcessingCost,
        'insurance_cost': insuranceCost,
        'customer_total': customerTotal,
        'platform_gross_revenue': platformGrossRevenue,
        'contribution_margin': contributionMargin,
        'created_at': createdAt.toIso8601String(),
        'confirmed_at': confirmedAt?.toIso8601String(),
        'status': status,
      };

  factory FinancialSnapshot.fromJson(Map<String, dynamic> json) {
    return FinancialSnapshot(
      snapshotId: json['snapshot_id'] as String,
      missionId: json['mission_id'] as String,
      customerId: json['customer_id'] as String,
      driverId: json['driver_id'] as String,
      pricingVersion: json['pricing_version'] as String,
      missionBaseValue: (json['mission_base_value'] as num? ?? 0).toDouble(),
      driverGrossEarnings: (json['driver_gross_earnings'] as num? ?? 0).toDouble(),
      driverOfferAmount: (json['driver_offer_amount'] as num? ?? 0).toDouble(),
      commissionRate: (json['commission_rate'] as num? ?? 0).toDouble(),
      // Le champ est écrit côté serveur en snake_case (ex: 'founding_preferred',
      // voir functions/src/lib/pricingEngine.ts resolveCommission()) — on
      // utilise donc fromFirestoreValue(), jamais une comparaison directe à
      // enum.name (camelCase).
      commissionProgram:
          CommissionProgramTypeX.fromFirestoreValue(json['commission_program'] as String?),
      minimumPlatformCommission: (json['minimum_platform_commission'] as num? ?? 0).toDouble(),
      maximumEffectiveCommissionRate:
          (json['maximum_effective_commission_rate'] as num? ?? 0).toDouble(),
      platformCommissionAmount: (json['platform_commission_amount'] as num? ?? 0).toDouble(),
      customerServiceFee: (json['customer_service_fee'] as num? ?? 0).toDouble(),
      customerFees: (json['customer_fees'] as num? ?? 0).toDouble(),
      customerDiscount: (json['customer_discount'] as num? ?? 0).toDouble(),
      customerTax: (json['customer_tax'] as num? ?? 0).toDouble(),
      driverBonus: (json['driver_bonus'] as num? ?? 0).toDouble(),
      tipAmount: (json['tip_amount'] as num? ?? 0).toDouble(),
      driverNetMissionEarnings: (json['driver_net_mission_earnings'] as num? ?? 0).toDouble(),
      driverTotalPayout: (json['driver_total_payout'] as num? ?? 0).toDouble(),
      paymentProcessingCost: (json['payment_processing_cost'] as num? ?? 0).toDouble(),
      insuranceCost: (json['insurance_cost'] as num? ?? 0).toDouble(),
      customerTotal: (json['customer_total'] as num? ?? 0).toDouble(),
      platformGrossRevenue: (json['platform_gross_revenue'] as num? ?? 0).toDouble(),
      contributionMargin: (json['contribution_margin'] as num? ?? 0).toDouble(),
      createdAt: parseFirestoreDate(json['created_at']) ?? DateTime.now(),
      confirmedAt: parseFirestoreDate(json['confirmed_at']),
      status: json['status'] as String? ?? 'pending',
    );
  }
}
