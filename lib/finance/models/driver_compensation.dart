// ---------------------------------------------------------------------------
// Driver Compensation Engine — modèles purs (Dart, sans dépendance Firebase).
//
// Ce fichier définit les structures nécessaires pour calculer combien un
// chauffeur reçoit réellement pour une mission donnée.
//
// IMPORTANT (sécurité financière) :
// - Ces modèles ne représentent QUE des structures de calcul. Le résultat
//   final "officiel" d'une mission est un `FinancialSnapshot` (voir
//   financial_snapshot.dart), créé et figé côté serveur (Cloud Function)
//   au moment de l'acceptation. Le calcul effectué ici en local (Flutter)
//   ne doit jamais être traité comme une vérité financière : il sert
//   uniquement à afficher une ESTIMATION au chauffeur avant acceptation.
// - Après acceptation, la valeur qui compte est celle figée côté serveur.
// ---------------------------------------------------------------------------

import 'pricing_config.dart';

/// Ligne d'ajustement manuel (bonus, pénalité, correction) appliquée par un
/// admin/analyste. Toujours tracée : qui, quand, pourquoi.
class ManualDriverAdjustment {
  final String id;
  final String reason;
  final double amount; // positif = bonus, négatif = pénalité
  final String createdByUserId;
  final DateTime createdAt;

  const ManualDriverAdjustment({
    required this.id,
    required this.reason,
    required this.amount,
    required this.createdByUserId,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'reason': reason,
        'amount': amount,
        'created_by_user_id': createdByUserId,
        'created_at': createdAt.toIso8601String(),
      };

  factory ManualDriverAdjustment.fromJson(Map<String, dynamic> json) {
    // Bloc R (rétrocompatibilité) : bien qu'aucun repository actuel ne
    // désérialise encore de document Firestore réel via ce constructeur,
    // il reste défensif par cohérence avec le reste du projet (jamais de
    // cast non-nullable brut sur des champs pouvant théoriquement manquer
    // dans un ajustement historique/corrigé manuellement).
    return ManualDriverAdjustment(
      id: json['id'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      createdByUserId: json['created_by_user_id'] as String? ?? 'unknown',
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}

/// Résultat du calcul de compensation d'un chauffeur pour une mission.
///
/// `driverOfferAmount` est la valeur qui doit être GELÉE dans le
/// FinancialSnapshot dès l'acceptation de la mission (elle ne doit plus
/// bouger même si la configuration de pricing change ensuite).
class DriverCompensationResult {
  /// Montant brut offert au chauffeur pour la mission (avant pourboire,
  /// avant bonus), déterminé par le pricing engine (part chauffeur du prix
  /// client, après commission).
  final double driverGrossEarnings;

  /// Montant réellement proposé/affiché au chauffeur au moment de l'offre
  /// (peut inclure des incitatifs de dispatch, égal à driverGrossEarnings
  /// dans le cas standard).
  final double driverOfferAmount;

  /// Pourboire client, toujours 100% redirigé vers le chauffeur (politique
  /// protégée, voir TipPolicyConfig).
  final double tipAmount;

  /// Somme des ajustements manuels (bonus/pénalités) approuvés par un
  /// admin/analyste pour cette mission.
  final double manualAdjustmentsTotal;

  final List<ManualDriverAdjustment> adjustments;

  /// Gain net final du chauffeur pour cette mission = driverOfferAmount
  /// + tipAmount + manualAdjustmentsTotal.
  final double driverNetMissionEarnings;

  /// pricing_version utilisée pour ce calcul (traçabilité).
  final String pricingVersion;

  const DriverCompensationResult({
    required this.driverGrossEarnings,
    required this.driverOfferAmount,
    required this.tipAmount,
    required this.manualAdjustmentsTotal,
    required this.adjustments,
    required this.driverNetMissionEarnings,
    required this.pricingVersion,
  });

  /// Construit un résultat "vide" à utiliser uniquement pour l'affichage
  /// avant qu'un vrai calcul serveur ait eu lieu (jamais pour un paiement réel).
  factory DriverCompensationResult.unconfigured() {
    return const DriverCompensationResult(
      driverGrossEarnings: 0,
      driverOfferAmount: 0,
      tipAmount: 0,
      manualAdjustmentsTotal: 0,
      adjustments: [],
      driverNetMissionEarnings: 0,
      pricingVersion: 'UNCONFIGURED',
    );
  }

  Map<String, dynamic> toJson() => {
        'driver_gross_earnings': driverGrossEarnings,
        'driver_offer_amount': driverOfferAmount,
        'tip_amount': tipAmount,
        'manual_adjustments_total': manualAdjustmentsTotal,
        'adjustments': adjustments.map((a) => a.toJson()).toList(),
        'driver_net_mission_earnings': driverNetMissionEarnings,
        'pricing_version': pricingVersion,
      };
}

/// Profil de compensation d'un chauffeur donné pour une mission donnée :
/// regroupe tout ce qui est nécessaire pour que le
/// DriverCompensationEngine calcule un résultat.
class DriverCompensationInput {
  final String driverId;
  final String missionId;
  final double customerSubtotal; // avant frais de service, avant taxes
  final double effectiveCommissionRate; // taux résolu (founding/promo/standard)
  final double tipAmountFromCustomer;
  final TipPolicyConfig tipPolicy;
  final List<ManualDriverAdjustment> manualAdjustments;
  final String pricingVersion;

  const DriverCompensationInput({
    required this.driverId,
    required this.missionId,
    required this.customerSubtotal,
    required this.effectiveCommissionRate,
    required this.tipAmountFromCustomer,
    required this.tipPolicy,
    required this.manualAdjustments,
    required this.pricingVersion,
  });
}
