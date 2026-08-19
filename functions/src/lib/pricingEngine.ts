// -----------------------------------------------------------------------------
// CustomerPricingEngine (port serveur) — DOIT rester rigoureusement équivalent
// à `lib/finance/models/pricing_config.dart` + `lib/finance/engines/customer_pricing_engine.dart`.
//
// Ce moteur est la version AUTORITATIVE : c'est CE calcul, exécuté ici avec
// la pricing_version active côté serveur, qui produit le devis officiel et
// alimente le FinancialSnapshot — jamais un montant envoyé par le client.
// -----------------------------------------------------------------------------

import {
  CommissionConfigDoc,
  PricingVersionDoc,
} from "./types";

export interface HandlingFlagsInput {
  isHeavyItem?: boolean;
  isBulkyItem?: boolean;
  needsStairs?: boolean;
  noElevator?: boolean;
  needsSecondHandler?: boolean;
  needsSpecialEquipment?: boolean;
}

export interface CustomerPricingInput {
  vehicleCategory: string;
  distanceKm: number;
  estimatedDurationMinutes: number;
  handling?: HandlingFlagsInput;
  totalWaitingMinutes?: number;
  additionalStopsCount?: number;
  applicableSurchargeIds?: string[];
  // Remise client (code promo déjà VALIDÉ en amont — jamais un montant
  // arbitraire venant du client) — voir `customer_discount` dans
  // FinancialSnapshot et l'équivalent Dart (customer_pricing_engine.dart).
  customerDiscountAmount?: number;
}

export interface CustomerPricingResult {
  pricingVersion: string;
  missionBaseValue: number;
  handlingFeesTotal: number;
  waitingFee: number;
  additionalStopsFee: number;
  surchargesTotal: number;
  subtotal: number; // APRÈS remise client
  customerDiscountAmount: number;
  customerServiceFee: number;
  taxAmount: number;
  customerTotal: number;
}

export function calculateCustomerQuote(
  config: PricingVersionDoc,
  input: CustomerPricingInput
): CustomerPricingResult {
  const rule = config.vehicle_rules.find((r) => r.category === input.vehicleCategory);
  if (!rule) {
    throw new Error(`Aucune règle de tarification pour la catégorie ${input.vehicleCategory}`);
  }

  // 1. Valeur de base.
  const rawBase =
    rule.base_fare +
    rule.rate_per_km * input.distanceKm +
    rule.rate_per_minute * input.estimatedDurationMinutes;
  const missionBaseValue = rawBase < rule.minimum_charge ? rule.minimum_charge : rawBase;

  // 2. Frais de manutention.
  const h = config.handling_fees;
  const flags = input.handling ?? {};
  let handlingFeesTotal = 0;
  if (flags.isHeavyItem) handlingFeesTotal += h.heavy_item_fee;
  if (flags.isBulkyItem) handlingFeesTotal += h.bulky_item_fee;
  if (flags.needsStairs) handlingFeesTotal += h.stairs_fee;
  if (flags.noElevator) handlingFeesTotal += h.no_elevator_fee;
  if (flags.needsSecondHandler) handlingFeesTotal += h.second_handler_fee;
  if (flags.needsSpecialEquipment) handlingFeesTotal += h.special_equipment_fee;

  // 3. Frais d'attente.
  const totalWaitingMinutes = input.totalWaitingMinutes ?? 0;
  const extraWaiting = totalWaitingMinutes - config.waiting_fee.free_waiting_minutes;
  const waitingFee =
    extraWaiting > 0 ? extraWaiting * config.waiting_fee.waiting_rate_per_minute : 0;

  // 4. Arrêts supplémentaires.
  const additionalStopsFee =
    config.additional_stop_fee.fee_per_stop * (input.additionalStopsCount ?? 0);

  // 5. Majorations.
  const baseForSurcharges = missionBaseValue + handlingFeesTotal;
  let surchargesTotal = 0;
  const applicableIds = input.applicableSurchargeIds ?? [];
  for (const surcharge of config.surcharges) {
    if (surcharge.enabled && applicableIds.includes(surcharge.id)) {
      surchargesTotal +=
        surcharge.mode === "percentage" ? baseForSurcharges * surcharge.value : surcharge.value;
    }
  }

  // 6. Sous-total brut (avant remise).
  const rawSubtotal =
    missionBaseValue + handlingFeesTotal + waitingFee + additionalStopsFee + surchargesTotal;

  // 6bis. Remise client — plancher 0, plafonnée au subtotal brut (jamais de
  // revenu négatif pour la plateforme via une remise).
  const rawDiscount = input.customerDiscountAmount ?? 0;
  const customerDiscountAmount =
    rawDiscount <= 0 ? 0 : rawDiscount > rawSubtotal ? rawSubtotal : rawDiscount;
  const subtotal = rawSubtotal - customerDiscountAmount;

  // 7. Frais de service client (calculé sur le subtotal APRÈS remise).
  const rawServiceFee = subtotal * config.customer_service_fee.service_fee_rate;
  const customerServiceFee =
    rawServiceFee < config.customer_service_fee.minimum_service_fee
      ? config.customer_service_fee.minimum_service_fee
      : rawServiceFee;

  // 8. Taxes.
  const taxableAmount = subtotal + customerServiceFee;
  const taxAmount = taxableAmount * config.tax_rate;

  const customerTotal = subtotal + customerServiceFee + taxAmount;

  return {
    pricingVersion: config.pricing_version,
    missionBaseValue,
    handlingFeesTotal,
    waitingFee,
    additionalStopsFee,
    surchargesTotal,
    subtotal,
    customerDiscountAmount,
    customerServiceFee,
    taxAmount,
    customerTotal,
  };
}

// -----------------------------------------------------------------------------
// CommissionResolver (port serveur) — DOIT rester équivalent à
// `lib/finance/engines/commission_resolver.dart`.
// -----------------------------------------------------------------------------

export interface FoundingProgramForResolver {
  promotionalCommissionRate: number;
  preferredCommissionRate: number;
}

export interface FoundingQualificationForResolver {
  status: string; // FoundingDriverStatuses
  promotionalPeriodEndsAtMillis: number;
}

export interface DriverPromotionForResolver {
  promotionalCommissionRate: number;
  startsAtMillis: number;
  endsAtMillis: number;
  isActive: boolean;
}

export interface ResolvedCommission {
  rate: number;
  program: "founding_preferred" | "promotional" | "standard";
  reason: string;
}

export function resolveCommission(params: {
  nowMillis: number;
  foundingQualification?: FoundingQualificationForResolver | null;
  foundingProgram?: FoundingProgramForResolver | null;
  activePromotion?: DriverPromotionForResolver | null;
  standardRate: number;
}): ResolvedCommission {
  const { nowMillis, foundingQualification, foundingProgram, activePromotion, standardRate } =
    params;

  // 1. Founding Driver (priorité la plus haute).
  if (foundingQualification && foundingQualification.status === "qualified" && foundingProgram) {
    const withinPromo = nowMillis < foundingQualification.promotionalPeriodEndsAtMillis;
    return {
      rate: withinPromo
        ? foundingProgram.promotionalCommissionRate
        : foundingProgram.preferredCommissionRate,
      program: "founding_preferred",
      reason: withinPromo
        ? "founding_driver_promotional_period"
        : "founding_driver_preferred_rate",
    };
  }

  // 2. Promotion active spécifique au chauffeur.
  if (
    activePromotion &&
    activePromotion.isActive &&
    nowMillis >= activePromotion.startsAtMillis &&
    nowMillis < activePromotion.endsAtMillis
  ) {
    return {
      rate: activePromotion.promotionalCommissionRate,
      program: "promotional",
      reason: "active_driver_promotion",
    };
  }

  // 3. Taux standard.
  return { rate: standardRate, program: "standard", reason: "standard_rate" };
}

export function capEffectiveRate(params: {
  resolvedRate: number;
  missionBaseValue: number;
  minimumPlatformCommission: number;
  maximumEffectiveCommissionRate: number;
}): number {
  const { resolvedRate, missionBaseValue, minimumPlatformCommission, maximumEffectiveCommissionRate } =
    params;
  if (missionBaseValue <= 0) return resolvedRate;
  const rawCommission = missionBaseValue * resolvedRate;
  const appliedCommission =
    rawCommission < minimumPlatformCommission ? minimumPlatformCommission : rawCommission;
  const effectiveRate = appliedCommission / missionBaseValue;
  return effectiveRate > maximumEffectiveCommissionRate
    ? maximumEffectiveCommissionRate
    : effectiveRate;
}

// -----------------------------------------------------------------------------
// DriverCompensationEngine (port serveur) — équivalent à
// `lib/finance/engines/driver_compensation_engine.dart`.
// -----------------------------------------------------------------------------

export interface ManualDriverAdjustment {
  amount: number;
  reason: string;
}

export interface DriverCompensationResult {
  driverGrossEarnings: number;
  driverOfferAmount: number;
  tipAmount: number;
  manualAdjustmentsTotal: number;
  driverNetMissionEarnings: number;
  platformCommissionAmount: number;
  effectiveCommissionRate: number;
}

export function calculateDriverCompensation(params: {
  pricingResult: CustomerPricingResult;
  resolvedCommission: ResolvedCommission;
  commissionConfig: CommissionConfigDoc;
  tipAmount?: number;
  manualAdjustments?: ManualDriverAdjustment[];
}): DriverCompensationResult {
  const {
    pricingResult,
    resolvedCommission,
    commissionConfig,
    tipAmount = 0,
    manualAdjustments = [],
  } = params;

  const commissionBase = pricingResult.subtotal;

  const effectiveRate = capEffectiveRate({
    resolvedRate: resolvedCommission.rate,
    missionBaseValue: commissionBase,
    minimumPlatformCommission: commissionConfig.minimum_platform_commission,
    maximumEffectiveCommissionRate: commissionConfig.maximum_effective_commission_rate,
  });

  const rawCommission = commissionBase * effectiveRate;
  const platformCommissionAmount =
    rawCommission < commissionConfig.minimum_platform_commission
      ? commissionBase <= 0
        ? 0
        : commissionConfig.minimum_platform_commission
      : rawCommission;

  const driverGrossEarnings = commissionBase - platformCommissionAmount;
  const driverOfferAmount = driverGrossEarnings;

  const manualAdjustmentsTotal = manualAdjustments.reduce((sum, a) => sum + a.amount, 0);

  const driverNetMissionEarnings = driverOfferAmount + tipAmount + manualAdjustmentsTotal;

  return {
    driverGrossEarnings,
    driverOfferAmount,
    tipAmount,
    manualAdjustmentsTotal,
    driverNetMissionEarnings,
    platformCommissionAmount,
    effectiveCommissionRate: effectiveRate,
  };
}

// -----------------------------------------------------------------------------
// PlatformRevenueEngine (port serveur) — équivalent à
// `lib/finance/engines/platform_revenue_engine.dart`.
// -----------------------------------------------------------------------------

export interface PlatformVariableCosts {
  paymentProcessingCost?: number;
  insuranceCost?: number;
}

export interface PlatformRevenueResult {
  platformCommissionAmount: number;
  customerServiceFeeAmount: number;
  platformGrossRevenue: number;
  variableCostsTotal: number;
  contributionMargin: number;
}

export function calculatePlatformRevenue(params: {
  pricingResult: CustomerPricingResult;
  platformCommissionAmount: number;
  variableCosts?: PlatformVariableCosts;
}): PlatformRevenueResult {
  const { pricingResult, platformCommissionAmount, variableCosts = {} } = params;
  const variableCostsTotal =
    (variableCosts.paymentProcessingCost ?? 0) + (variableCosts.insuranceCost ?? 0);
  const platformGrossRevenue = platformCommissionAmount + pricingResult.customerServiceFee;
  const contributionMargin = platformGrossRevenue - variableCostsTotal;
  return {
    platformCommissionAmount,
    customerServiceFeeAmount: pricingResult.customerServiceFee,
    platformGrossRevenue,
    variableCostsTotal,
    contributionMargin,
  };
}
