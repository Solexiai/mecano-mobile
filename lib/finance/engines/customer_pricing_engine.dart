// ---------------------------------------------------------------------------
// CustomerPricingEngine — calcule le prix affiché au client pour une
// mission de livraison, à partir d'une PricingConfig versionnée.
//
// Moteur PUR : aucun effet de bord, aucun accès réseau/Firestore. Le devis
// produit ici est une ESTIMATION affichable immédiatement au client. Le
// devis "officiel" (Quote) et le prix final gelé (FinancialSnapshot)
// doivent être calculés et confirmés par la Cloud Function
// `calculateDeliveryQuote()` côté serveur, en rejouant exactement la même
// logique avec la pricing_version active côté serveur.
// ---------------------------------------------------------------------------

import '../../models/enums.dart';
import '../models/pricing_config.dart';

/// Caractéristiques de manutention d'une mission, utilisées pour calculer
/// les frais de manutention.
class HandlingFlags {
  final bool isHeavyItem;
  final bool isBulkyItem;
  final bool needsStairs;
  final bool noElevator;
  final bool needsSecondHandler;
  final bool needsSpecialEquipment;

  const HandlingFlags({
    this.isHeavyItem = false,
    this.isBulkyItem = false,
    this.needsStairs = false,
    this.noElevator = false,
    this.needsSecondHandler = false,
    this.needsSpecialEquipment = false,
  });
}

class CustomerPricingInput {
  final VehicleCategory vehicleCategory;
  final double distanceKm;
  final double estimatedDurationMinutes;
  final HandlingFlags handling;
  final int totalWaitingMinutes;
  final int additionalStopsCount;

  /// Identifiants des surcharges applicables (ex: majoration nocturne,
  /// weekend). Doivent correspondre à des `SurchargeRule.id` actifs dans la
  /// config.
  final List<String> applicableSurchargeIds;

  /// Remise client (ex: code promo) déjà VALIDÉE en amont (jamais un montant
  /// arbitraire saisi par le client) — voir `customer_discount` dans
  /// FinancialSnapshot. Montant fixe en $, appliqué avant frais de service et
  /// taxes (réduit la base taxable, cohérent avec les règles fiscales QC/CA
  /// applicables aux remises). Jamais négatif après application (plancher 0).
  final double customerDiscountAmount;

  const CustomerPricingInput({
    required this.vehicleCategory,
    required this.distanceKm,
    required this.estimatedDurationMinutes,
    this.handling = const HandlingFlags(),
    this.totalWaitingMinutes = 0,
    this.additionalStopsCount = 0,
    this.applicableSurchargeIds = const [],
    this.customerDiscountAmount = 0,
  });
}

class CustomerPricingResult {
  final String pricingVersion;
  final double missionBaseValue; // baseFare + distance*rate + duration*rate
  final double handlingFeesTotal;
  final double waitingFee;
  final double additionalStopsFee;
  final double surchargesTotal;
  final double subtotal; // somme de tout ce qui précède, APRÈS remise client
  final double customerDiscountAmount; // remise appliquée (>= 0, plafonnée au subtotal brut)
  final double customerServiceFee;
  final double taxAmount;
  final double customerTotal;

  const CustomerPricingResult({
    required this.pricingVersion,
    required this.missionBaseValue,
    required this.handlingFeesTotal,
    required this.waitingFee,
    required this.additionalStopsFee,
    required this.surchargesTotal,
    required this.subtotal,
    this.customerDiscountAmount = 0,
    required this.customerServiceFee,
    required this.taxAmount,
    required this.customerTotal,
  });

  factory CustomerPricingResult.unconfigured() {
    return const CustomerPricingResult(
      pricingVersion: 'UNCONFIGURED',
      missionBaseValue: 0,
      handlingFeesTotal: 0,
      waitingFee: 0,
      additionalStopsFee: 0,
      surchargesTotal: 0,
      subtotal: 0,
      customerDiscountAmount: 0,
      customerServiceFee: 0,
      taxAmount: 0,
      customerTotal: 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'pricing_version': pricingVersion,
        'mission_base_value': missionBaseValue,
        'handling_fees_total': handlingFeesTotal,
        'waiting_fee': waitingFee,
        'additional_stops_fee': additionalStopsFee,
        'surcharges_total': surchargesTotal,
        'subtotal': subtotal,
        'customer_discount_amount': customerDiscountAmount,
        'customer_service_fee': customerServiceFee,
        'tax_amount': taxAmount,
        'customer_total': customerTotal,
      };
}

class CustomerPricingEngine {
  /// Calcule un devis client complet à partir d'une configuration de
  /// pricing et des caractéristiques de la mission.
  ///
  /// Si `config.pricingVersion == 'UNCONFIGURED'` (aucune configuration
  /// réelle disponible, ex: backend non connecté), retourne un résultat
  /// neutre plutôt que de simuler un prix réel — le frontend doit alors
  /// afficher un état `not_configured`.
  static CustomerPricingResult calculateQuote({
    required PricingConfig config,
    required CustomerPricingInput input,
  }) {
    if (!config.isActive || config.pricingVersion == 'UNCONFIGURED') {
      return CustomerPricingResult.unconfigured();
    }

    final rule = config.ruleFor(input.vehicleCategory);
    if (rule == null) {
      return CustomerPricingResult.unconfigured();
    }

    // 1. Valeur de base de la mission.
    final rawBase = rule.baseFare +
        (rule.ratePerKm * input.distanceKm) +
        (rule.ratePerMinute * input.estimatedDurationMinutes);
    final missionBaseValue = rawBase < rule.minimumCharge ? rule.minimumCharge : rawBase;

    // 2. Frais de manutention.
    final h = config.handlingFees;
    final handling = input.handling;
    double handlingFeesTotal = 0;
    if (handling.isHeavyItem) handlingFeesTotal += h.heavyItemFee;
    if (handling.isBulkyItem) handlingFeesTotal += h.bulkyItemFee;
    if (handling.needsStairs) handlingFeesTotal += h.stairsFee;
    if (handling.noElevator) handlingFeesTotal += h.noElevatorFee;
    if (handling.needsSecondHandler) handlingFeesTotal += h.secondHandlerFee;
    if (handling.needsSpecialEquipment) handlingFeesTotal += h.specialEquipmentFee;

    // 3. Frais d'attente.
    final waitingFee = config.waitingFee.computeWaitingFee(input.totalWaitingMinutes);

    // 4. Frais d'arrêts supplémentaires.
    final additionalStopsFee =
        config.additionalStopFee.feePerStop * input.additionalStopsCount;

    // 5. Majorations (surcharges) applicables.
    double surchargesTotal = 0;
    final baseForSurcharges = missionBaseValue + handlingFeesTotal;
    for (final surcharge in config.surcharges) {
      if (surcharge.enabled && input.applicableSurchargeIds.contains(surcharge.id)) {
        surchargesTotal += surcharge.computeAmount(baseForSurcharges);
      }
    }

    // 6. Sous-total avant remise, frais de service et taxes.
    final rawSubtotal = missionBaseValue +
        handlingFeesTotal +
        waitingFee +
        additionalStopsFee +
        surchargesTotal;

    // 6bis. Remise client (code promo déjà validé) — plancher à 0, jamais
    // négative, jamais supérieure au subtotal brut (une remise ne peut pas
    // transformer une mission en revenu négatif pour la plateforme).
    final customerDiscountAmount =
        input.customerDiscountAmount <= 0
            ? 0.0
            : (input.customerDiscountAmount > rawSubtotal ? rawSubtotal : input.customerDiscountAmount);
    final subtotal = rawSubtotal - customerDiscountAmount;

    // 7. Frais de service client (revenu plateforme distinct de la
    // commission chauffeur), calculé sur le subtotal APRÈS remise.
    final customerServiceFee = config.customerServiceFee.compute(subtotal);

    // 8. Taxes (appliquées sur subtotal + frais de service, selon la
    // juridiction — simplifié ici, à affiner selon les règles fiscales
    // réelles du Québec/Canada lors de l'intégration serveur).
    final taxableAmount = subtotal + customerServiceFee;
    final taxAmount = taxableAmount * config.taxRate;

    final customerTotal = subtotal + customerServiceFee + taxAmount;

    return CustomerPricingResult(
      pricingVersion: config.pricingVersion,
      missionBaseValue: missionBaseValue,
      handlingFeesTotal: handlingFeesTotal,
      waitingFee: waitingFee,
      additionalStopsFee: additionalStopsFee,
      surchargesTotal: surchargesTotal,
      subtotal: subtotal,
      customerDiscountAmount: customerDiscountAmount,
      customerServiceFee: customerServiceFee,
      taxAmount: taxAmount,
      customerTotal: customerTotal,
    );
  }
}
