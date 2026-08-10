// ---------------------------------------------------------------------------
// Platform Revenue Engine — modèles purs (Dart, sans dépendance Firebase).
//
// Calcule le revenu brut de la plateforme sur une mission, puis en déduit
// les coûts variables réels pour obtenir la marge de contribution.
//
// IMPORTANT : ces montants sont estimatifs jusqu'à ce qu'ils soient figés
// dans un FinancialSnapshot par une Cloud Function. Le frontend ne doit
// jamais présenter ce calcul comme un revenu confirmé.
// ---------------------------------------------------------------------------

/// Coûts variables réels associés à une mission, engagés par la plateforme
/// (frais de traitement de paiement, frais de payout, coûts d'assurance,
/// coûts liés aux remboursements/chargebacks, autres coûts variables).
class PlatformVariableCosts {
  final double paymentProcessingFee;
  final double payoutProcessingFee;
  final double refundProcessingCost;
  final double chargebackCost;
  final double insuranceCost;
  final double fraudCost;
  final double otherVariableCost;

  const PlatformVariableCosts({
    this.paymentProcessingFee = 0,
    this.payoutProcessingFee = 0,
    this.refundProcessingCost = 0,
    this.chargebackCost = 0,
    this.insuranceCost = 0,
    this.fraudCost = 0,
    this.otherVariableCost = 0,
  });

  double get total =>
      paymentProcessingFee +
      payoutProcessingFee +
      refundProcessingCost +
      chargebackCost +
      insuranceCost +
      fraudCost +
      otherVariableCost;

  factory PlatformVariableCosts.zero() => const PlatformVariableCosts();

  Map<String, dynamic> toJson() => {
        'payment_processing_fee': paymentProcessingFee,
        'payout_processing_fee': payoutProcessingFee,
        'refund_processing_cost': refundProcessingCost,
        'chargeback_cost': chargebackCost,
        'insurance_cost': insuranceCost,
        'fraud_cost': fraudCost,
        'other_variable_cost': otherVariableCost,
      };

  factory PlatformVariableCosts.fromJson(Map<String, dynamic> json) {
    return PlatformVariableCosts(
      paymentProcessingFee: (json['payment_processing_fee'] as num? ?? 0).toDouble(),
      payoutProcessingFee: (json['payout_processing_fee'] as num? ?? 0).toDouble(),
      refundProcessingCost: (json['refund_processing_cost'] as num? ?? 0).toDouble(),
      chargebackCost: (json['chargeback_cost'] as num? ?? 0).toDouble(),
      insuranceCost: (json['insurance_cost'] as num? ?? 0).toDouble(),
      fraudCost: (json['fraud_cost'] as num? ?? 0).toDouble(),
      otherVariableCost: (json['other_variable_cost'] as num? ?? 0).toDouble(),
    );
  }
}

/// Résultat du calcul de revenu plateforme pour une mission.
class PlatformRevenueResult {
  /// Commission brute prélevée par la plateforme (avant coûts variables).
  final double platformCommissionAmount;

  /// Frais de service client (customer_service_fee), qui va aussi à la
  /// plateforme (distinct de la commission chauffeur).
  final double customerServiceFeeAmount;

  /// Revenu brut plateforme = commission + frais de service.
  final double platformGrossRevenue;

  final PlatformVariableCosts variableCosts;

  /// Marge de contribution = platformGrossRevenue - variableCosts.total
  final double contributionMargin;

  final String pricingVersion;

  const PlatformRevenueResult({
    required this.platformCommissionAmount,
    required this.customerServiceFeeAmount,
    required this.platformGrossRevenue,
    required this.variableCosts,
    required this.contributionMargin,
    required this.pricingVersion,
  });

  factory PlatformRevenueResult.unconfigured() {
    return PlatformRevenueResult(
      platformCommissionAmount: 0,
      customerServiceFeeAmount: 0,
      platformGrossRevenue: 0,
      variableCosts: PlatformVariableCosts.zero(),
      contributionMargin: 0,
      pricingVersion: 'UNCONFIGURED',
    );
  }

  Map<String, dynamic> toJson() => {
        'platform_commission_amount': platformCommissionAmount,
        'customer_service_fee_amount': customerServiceFeeAmount,
        'platform_gross_revenue': platformGrossRevenue,
        'variable_costs': variableCosts.toJson(),
        'contribution_margin': contributionMargin,
        'pricing_version': pricingVersion,
      };
}
