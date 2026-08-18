/// Pricing configuration models — Movi-K CUSTOMER PRICING ENGINE inputs.
///
/// IMPORTANT: None of these values are ever hardcoded in UI or business
/// logic. They are loaded from Firestore (`pricing_configs` / `pricing_versions`
/// collections, see FIRESTORE_ARCHITECTURE.md) and passed into
/// [CustomerPricingEngine]. A [PricingConfig] is always tied to an immutable
/// [pricingVersion] string (e.g. `MOVIK-PRICING-001`) — see section 42 of the
/// Movi-K financial architecture spec. Once a mission's quote/snapshot is
/// created, the *version string* is frozen on the mission; the underlying
/// config values referenced by that version must never be mutated in place.
library;

import '../../models/enums.dart';
import '../../backend/models/firestore_date.dart';

/// Per-vehicle-category pricing rule (section 17: `vehicle_pricing_rules`).
class VehiclePricingRule {
  final VehicleCategory category;
  final double baseFare; // `base_fare`
  final double ratePerKm; // used in `distance_fee = billable_km * rate_per_km`
  final double ratePerMinute; // used in `time_fee = billable_minutes * rate_per_minute`
  final double minimumCharge;
  final double? maxPayloadKg;
  final double? surchargeFixedAmount; // optional category-level surcharge

  const VehiclePricingRule({
    required this.category,
    required this.baseFare,
    required this.ratePerKm,
    required this.ratePerMinute,
    required this.minimumCharge,
    this.maxPayloadKg,
    this.surchargeFixedAmount,
  });

  Map<String, dynamic> toJson() => {
        'category': category.name,
        'base_fare': baseFare,
        'rate_per_km': ratePerKm,
        'rate_per_minute': ratePerMinute,
        'minimum_charge': minimumCharge,
        'max_payload_kg': maxPayloadKg,
        'surcharge_fixed_amount': surchargeFixedAmount,
      };

  factory VehiclePricingRule.fromJson(Map<String, dynamic> json) => VehiclePricingRule(
        category: VehicleCategory.values.firstWhere((c) => c.name == json['category'], orElse: () => VehicleCategory.other),
        baseFare: (json['base_fare'] as num?)?.toDouble() ?? 0,
        ratePerKm: (json['rate_per_km'] as num?)?.toDouble() ?? 0,
        ratePerMinute: (json['rate_per_minute'] as num?)?.toDouble() ?? 0,
        minimumCharge: (json['minimum_charge'] as num?)?.toDouble() ?? 0,
        maxPayloadKg: (json['max_payload_kg'] as num?)?.toDouble(),
        surchargeFixedAmount: (json['surcharge_fixed_amount'] as num?)?.toDouble(),
      );
}

/// Configurable handling fees (section 18: `handling_fee`).
class HandlingFeeConfig {
  final double loadingFee;
  final double unloadingFee;
  final double heavyItemFee;
  final double bulkyItemFee;
  final double stairsFee;
  final double noElevatorFee;
  final double secondHandlerFee;
  final double specialEquipmentFee;

  const HandlingFeeConfig({
    this.loadingFee = 0,
    this.unloadingFee = 0,
    this.heavyItemFee = 0,
    this.bulkyItemFee = 0,
    this.stairsFee = 0,
    this.noElevatorFee = 0,
    this.secondHandlerFee = 0,
    this.specialEquipmentFee = 0,
  });

  Map<String, dynamic> toJson() => {
        'loading_fee': loadingFee,
        'unloading_fee': unloadingFee,
        'heavy_item_fee': heavyItemFee,
        'bulky_item_fee': bulkyItemFee,
        'stairs_fee': stairsFee,
        'no_elevator_fee': noElevatorFee,
        'second_handler_fee': secondHandlerFee,
        'special_equipment_fee': specialEquipmentFee,
      };

  factory HandlingFeeConfig.fromJson(Map<String, dynamic> json) => HandlingFeeConfig(
        loadingFee: (json['loading_fee'] as num?)?.toDouble() ?? 0,
        unloadingFee: (json['unloading_fee'] as num?)?.toDouble() ?? 0,
        heavyItemFee: (json['heavy_item_fee'] as num?)?.toDouble() ?? 0,
        bulkyItemFee: (json['bulky_item_fee'] as num?)?.toDouble() ?? 0,
        stairsFee: (json['stairs_fee'] as num?)?.toDouble() ?? 0,
        noElevatorFee: (json['no_elevator_fee'] as num?)?.toDouble() ?? 0,
        secondHandlerFee: (json['second_handler_fee'] as num?)?.toDouble() ?? 0,
        specialEquipmentFee: (json['special_equipment_fee'] as num?)?.toDouble() ?? 0,
      );
}

/// Waiting time policy (section 19: free minutes then `waiting_rate`).
class WaitingFeeConfig {
  final int freeWaitingMinutes;
  final double waitingRatePerMinute;

  const WaitingFeeConfig({this.freeWaitingMinutes = 10, this.waitingRatePerMinute = 0.5});

  double computeWaitingFee(int totalWaitingMinutes) {
    final extra = totalWaitingMinutes - freeWaitingMinutes;
    if (extra <= 0) return 0;
    return extra * waitingRatePerMinute;
  }

  Map<String, dynamic> toJson() => {'free_waiting_minutes': freeWaitingMinutes, 'waiting_rate_per_minute': waitingRatePerMinute};

  factory WaitingFeeConfig.fromJson(Map<String, dynamic> json) => WaitingFeeConfig(
        freeWaitingMinutes: (json['free_waiting_minutes'] as num?)?.toInt() ?? 10,
        waitingRatePerMinute: (json['waiting_rate_per_minute'] as num?)?.toDouble() ?? 0.5,
      );
}

/// Section 20: multi-destination additional stop fee.
class AdditionalStopFeeConfig {
  final double feePerStop;
  const AdditionalStopFeeConfig({this.feePerStop = 0});

  Map<String, dynamic> toJson() => {'fee_per_stop': feePerStop};
  factory AdditionalStopFeeConfig.fromJson(Map<String, dynamic> json) =>
      AdditionalStopFeeConfig(feePerStop: (json['fee_per_stop'] as num?)?.toDouble() ?? 0);
}

/// Section 21: configurable surcharges (fixed or percentage).
class SurchargeRule {
  final String id; // e.g. 'high_demand', 'urgency', 'evening', 'night', 'weekend', 'holiday', 'long_distance', 'remote_zone'
  final SurchargeMode mode;
  final double value; // fixed dollar amount OR percentage (0.10 = 10%)
  final bool enabled;

  const SurchargeRule({required this.id, required this.mode, required this.value, this.enabled = true});

  /// Computes surcharge dollar amount given the base amount it applies to
  /// (relevant only for percentage-mode surcharges).
  double computeAmount(double baseAmount) {
    if (!enabled) return 0;
    return mode == SurchargeMode.percentage ? baseAmount * value : value;
  }

  Map<String, dynamic> toJson() => {'id': id, 'mode': mode.name, 'value': value, 'enabled': enabled};

  factory SurchargeRule.fromJson(Map<String, dynamic> json) => SurchargeRule(
        id: json['id'] as String,
        mode: SurchargeMode.values.firstWhere((m) => m.name == json['mode'], orElse: () => SurchargeMode.fixedAmount),
        value: (json['value'] as num?)?.toDouble() ?? 0,
        enabled: json['enabled'] as bool? ?? true,
      );
}

/// Section 22: customer service fee (distinct from driver commission).
class CustomerServiceFeeConfig {
  final double serviceFeeRate; // percentage of subtotal, e.g. 0.05
  final double minimumServiceFee;

  const CustomerServiceFeeConfig({this.serviceFeeRate = 0, this.minimumServiceFee = 0});

  double compute(double subtotal) {
    final raw = subtotal * serviceFeeRate;
    return raw < minimumServiceFee ? minimumServiceFee : raw;
  }

  Map<String, dynamic> toJson() => {'service_fee_rate': serviceFeeRate, 'minimum_service_fee': minimumServiceFee};

  factory CustomerServiceFeeConfig.fromJson(Map<String, dynamic> json) => CustomerServiceFeeConfig(
        serviceFeeRate: (json['service_fee_rate'] as num?)?.toDouble() ?? 0,
        minimumServiceFee: (json['minimum_service_fee'] as num?)?.toDouble() ?? 0,
      );
}

/// Sections 23-26: Movi-K variable commission with protected min/max bounds.
/// This is the STANDARD commission — see CommissionResolver for the full
/// hierarchy (Founding Driver preferred > promotional > standard).
class CommissionConfig {
  final double standardCommissionRate; // e.g. 0.10, 0.12, 0.15
  final double minimumPlatformCommission; // dollar floor
  final double maximumEffectiveCommissionRate; // protects small missions from a disproportionate floor

  const CommissionConfig({
    required this.standardCommissionRate,
    required this.minimumPlatformCommission,
    required this.maximumEffectiveCommissionRate,
  });

  Map<String, dynamic> toJson() => {
        'standard_commission_rate': standardCommissionRate,
        'minimum_platform_commission': minimumPlatformCommission,
        'maximum_effective_commission_rate': maximumEffectiveCommissionRate,
      };

  factory CommissionConfig.fromJson(Map<String, dynamic> json) => CommissionConfig(
        standardCommissionRate: (json['standard_commission_rate'] as num?)?.toDouble() ?? 0.15,
        minimumPlatformCommission: (json['minimum_platform_commission'] as num?)?.toDouble() ?? 0,
        maximumEffectiveCommissionRate: (json['maximum_effective_commission_rate'] as num?)?.toDouble() ?? 0.30,
      );
}

/// Section 27-28: tip policy. Protected — see FoundingDriverEngine/TipEngine
/// docs. `driverTipPercentage` defaults to 100 and any deviation requires
/// super_admin + is versioned + logged (enforced server-side, not here).
class TipPolicyConfig {
  final double driverTipPercentage; // 100.0 == 100%

  const TipPolicyConfig({this.driverTipPercentage = 100.0});

  Map<String, dynamic> toJson() => {'driver_tip_percentage': driverTipPercentage};

  factory TipPolicyConfig.fromJson(Map<String, dynamic> json) => TipPolicyConfig(
        driverTipPercentage: (json['driver_tip_percentage'] as num?)?.toDouble() ?? 100.0,
      );
}

/// Section 48: quote validity window.
class QuoteConfig {
  final int quoteValidityMinutes;
  const QuoteConfig({this.quoteValidityMinutes = 15});

  Map<String, dynamic> toJson() => {'quote_validity_minutes': quoteValidityMinutes};
  factory QuoteConfig.fromJson(Map<String, dynamic> json) =>
      QuoteConfig(quoteValidityMinutes: (json['quote_validity_minutes'] as num?)?.toInt() ?? 15);
}

/// Aggregate root: one versioned pricing configuration document.
/// Firestore path (proposed): `pricing_versions/{pricingVersion}`
/// See section 42 — never overwrite an existing version; create a new one.
class PricingConfig {
  final String pricingVersion; // e.g. 'MOVIK-PRICING-001'
  final bool isActive;
  final DateTime effectiveFrom;
  final List<VehiclePricingRule> vehicleRules;
  final HandlingFeeConfig handlingFees;
  final WaitingFeeConfig waitingFee;
  final AdditionalStopFeeConfig additionalStopFee;
  final List<SurchargeRule> surcharges;
  final CustomerServiceFeeConfig customerServiceFee;
  final CommissionConfig commission;
  final TipPolicyConfig tipPolicy;
  final QuoteConfig quoteConfig;
  final double taxRate; // combined tax rate applied to customer_total (e.g. 0.14975 QC)

  const PricingConfig({
    required this.pricingVersion,
    required this.isActive,
    required this.effectiveFrom,
    required this.vehicleRules,
    required this.handlingFees,
    required this.waitingFee,
    required this.additionalStopFee,
    required this.surcharges,
    required this.customerServiceFee,
    required this.commission,
    required this.tipPolicy,
    required this.quoteConfig,
    this.taxRate = 0,
  });

  /// Retourne la règle tarifaire pour la catégorie de véhicule donnée, ou
  /// `null` si aucune règle n'est configurée (ex: PricingConfig.unconfigured()).
  VehiclePricingRule? ruleFor(VehicleCategory category) {
    if (vehicleRules.isEmpty) return null;
    for (final r in vehicleRules) {
      if (r.category == category) return r;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'pricing_version': pricingVersion,
        'is_active': isActive,
        'effective_from': effectiveFrom.toIso8601String(),
        'vehicle_rules': vehicleRules.map((r) => r.toJson()).toList(),
        'handling_fees': handlingFees.toJson(),
        'waiting_fee': waitingFee.toJson(),
        'additional_stop_fee': additionalStopFee.toJson(),
        'surcharges': surcharges.map((s) => s.toJson()).toList(),
        'customer_service_fee': customerServiceFee.toJson(),
        'commission': commission.toJson(),
        'tip_policy': tipPolicy.toJson(),
        'quote_config': quoteConfig.toJson(),
        'tax_rate': taxRate,
      };

  factory PricingConfig.fromJson(Map<String, dynamic> json) => PricingConfig(
        pricingVersion: json['pricing_version'] as String,
        isActive: json['is_active'] as bool? ?? false,
        effectiveFrom: parseFirestoreDate(json['effective_from']) ?? DateTime.now(),
        vehicleRules: (json['vehicle_rules'] as List? ?? []).map((r) => VehiclePricingRule.fromJson(Map<String, dynamic>.from(r))).toList(),
        handlingFees: HandlingFeeConfig.fromJson(Map<String, dynamic>.from(json['handling_fees'] ?? {})),
        waitingFee: WaitingFeeConfig.fromJson(Map<String, dynamic>.from(json['waiting_fee'] ?? {})),
        additionalStopFee: AdditionalStopFeeConfig.fromJson(Map<String, dynamic>.from(json['additional_stop_fee'] ?? {})),
        surcharges: (json['surcharges'] as List? ?? []).map((s) => SurchargeRule.fromJson(Map<String, dynamic>.from(s))).toList(),
        customerServiceFee: CustomerServiceFeeConfig.fromJson(Map<String, dynamic>.from(json['customer_service_fee'] ?? {})),
        commission: CommissionConfig.fromJson(Map<String, dynamic>.from(json['commission'] ?? {})),
        tipPolicy: TipPolicyConfig.fromJson(Map<String, dynamic>.from(json['tip_policy'] ?? {})),
        quoteConfig: QuoteConfig.fromJson(Map<String, dynamic>.from(json['quote_config'] ?? {})),
        taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 0,
      );

  /// A safe, explicit "not configured" default used ONLY so the app never
  /// crashes before a real PricingConfig has been fetched from Firestore.
  /// This must never be used to actually price a real mission in production;
  /// callers should check `DriverRepository`/`PricingRepository` connection
  /// state and show `not_configured` UI instead (see AGENT_HANDOFF.md).
  factory PricingConfig.unconfigured() => PricingConfig(
        pricingVersion: 'UNCONFIGURED',
        isActive: false,
        effectiveFrom: DateTime.fromMillisecondsSinceEpoch(0),
        vehicleRules: const [],
        handlingFees: const HandlingFeeConfig(),
        waitingFee: const WaitingFeeConfig(),
        additionalStopFee: const AdditionalStopFeeConfig(),
        surcharges: const [],
        customerServiceFee: const CustomerServiceFeeConfig(),
        commission: const CommissionConfig(standardCommissionRate: 0, minimumPlatformCommission: 0, maximumEffectiveCommissionRate: 0),
        tipPolicy: const TipPolicyConfig(),
        quoteConfig: const QuoteConfig(),
      );
}
