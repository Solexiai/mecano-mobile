// ---------------------------------------------------------------------------
// MissionFinancialBalance — projection LECTURE SEULE du document
// `mission_financial_balance/{missionId}` (Cloud Functions, voir
// `functions/src/lib/types.ts` -> `MissionFinancialBalanceDoc` et
// `functions/src/lib/missionFinancialBalance.ts`).
//
// RÈGLES CRITIQUES (Bloc J) :
// - Cache SERVEUR recalculé, dérivé du `transaction_ledger` — jamais une
//   source d'audit stricte (voir commentaire `MissionFinancialBalanceDoc`
//   dans types.ts), mais parfaitement adapté à un AFFICHAGE synthétique
//   client/chauffeur.
// - Tous les champs sont des UNITÉS MINEURES ENTIÈRES (cents), suffixe
//   `_minor` côté Firestore. Les noms Dart ci-dessous reprennent les noms
//   demandés par la directive Bloc J (SANS suffixe "Minor" dans le nom du
//   champ métier), mais restent des `int` en cents et le mapping
//   `fromJson` lit bien les clés Firestore réelles `*_minor`.
// - AUCUN calcul local : chaque champ est une lecture directe du document
//   serveur, jamais une addition/soustraction Flutter.
// - Champs `driver_*`/`processingCosts`/`contributionMargin` sont des
//   détails INTERNES plateforme/chauffeur — voir Bloc J point 7 : la vue
//   financière CLIENT ne doit JAMAIS les afficher (réservés Bloc K/L).
// ---------------------------------------------------------------------------

import '../../backend/models/firestore_date.dart';

class MissionFinancialBalance {
  final String missionId;

  // ---- Client (affichables côté client) ----
  /// = `customer_charged_minor` (= amount_captured_minor du PaymentDoc).
  final int customerCharged;

  /// = `customer_refunded_minor` (somme des RefundDoc SUCCEEDED liés).
  final int customerRefunded;

  /// = `customer_service_fee_minor`.
  final int customerServiceFee;

  /// = `outstanding_customer_balance_minor` (customer_charged - customer_refunded).
  final int outstandingCustomerBalance;

  // ---- Interne plateforme/chauffeur (JAMAIS affiché côté client — Bloc K/L) ----
  final int platformCommission; // platform_commission_minor
  final int driverEarned; // driver_earned_minor
  final int driverPaid; // driver_paid_minor
  final int driverTip; // driver_tip_minor
  final int driverBonus; // driver_bonus_minor
  final int adjustments; // adjustments_minor
  final int outstandingDriverBalance; // outstanding_driver_balance_minor
  final int processingCosts; // provider_processing_cost_minor
  final int contributionMargin; // contribution_margin_minor

  final DateTime updatedAt;

  const MissionFinancialBalance({
    required this.missionId,
    required this.customerCharged,
    required this.customerRefunded,
    required this.customerServiceFee,
    required this.outstandingCustomerBalance,
    required this.platformCommission,
    required this.driverEarned,
    required this.driverPaid,
    required this.driverTip,
    required this.driverBonus,
    required this.adjustments,
    required this.outstandingDriverBalance,
    required this.processingCosts,
    required this.contributionMargin,
    required this.updatedAt,
  });

  bool get hasBeenRefunded => customerRefunded > 0;
  bool get isFullyRefunded => customerRefunded >= customerCharged && customerCharged > 0;
  bool get isPartiallyRefunded => customerRefunded > 0 && customerRefunded < customerCharged;

  Map<String, dynamic> toJson() => {
        'mission_id': missionId,
        'customer_charged_minor': customerCharged,
        'customer_refunded_minor': customerRefunded,
        'customer_service_fee_minor': customerServiceFee,
        'outstanding_customer_balance_minor': outstandingCustomerBalance,
        'platform_commission_minor': platformCommission,
        'driver_earned_minor': driverEarned,
        'driver_paid_minor': driverPaid,
        'driver_tip_minor': driverTip,
        'driver_bonus_minor': driverBonus,
        'adjustments_minor': adjustments,
        'outstanding_driver_balance_minor': outstandingDriverBalance,
        'provider_processing_cost_minor': processingCosts,
        'contribution_margin_minor': contributionMargin,
        'updated_at': updatedAt.toIso8601String(),
      };

  /// Parse un document `mission_financial_balance/{missionId}` réel.
  /// Repli sûr `as num? ?? 0` sur chaque champ : une ancienne mission ou un
  /// document partiellement recalculé ne doit jamais faire planter l'UI.
  factory MissionFinancialBalance.fromJson(String missionId, Map<String, dynamic> json) {
    return MissionFinancialBalance(
      missionId: json['mission_id'] as String? ?? missionId,
      customerCharged: (json['customer_charged_minor'] as num? ?? 0).toInt(),
      customerRefunded: (json['customer_refunded_minor'] as num? ?? 0).toInt(),
      customerServiceFee: (json['customer_service_fee_minor'] as num? ?? 0).toInt(),
      outstandingCustomerBalance: (json['outstanding_customer_balance_minor'] as num? ?? 0).toInt(),
      platformCommission: (json['platform_commission_minor'] as num? ?? 0).toInt(),
      driverEarned: (json['driver_earned_minor'] as num? ?? 0).toInt(),
      driverPaid: (json['driver_paid_minor'] as num? ?? 0).toInt(),
      driverTip: (json['driver_tip_minor'] as num? ?? 0).toInt(),
      driverBonus: (json['driver_bonus_minor'] as num? ?? 0).toInt(),
      adjustments: (json['adjustments_minor'] as num? ?? 0).toInt(),
      outstandingDriverBalance: (json['outstanding_driver_balance_minor'] as num? ?? 0).toInt(),
      processingCosts: (json['provider_processing_cost_minor'] as num? ?? 0).toInt(),
      contributionMargin: (json['contribution_margin_minor'] as num? ?? 0).toInt(),
      updatedAt: parseFirestoreDate(json['updated_at']) ?? DateTime.now(),
    );
  }
}
