// -----------------------------------------------------------------------------
// pricingConfigValidation.ts — garde-fous de la grille de tarifs admin
// (updatePricingConfiguration, previewPricingConfiguration).
//
// Une faute de frappe dans la grille (« 150 % » au lieu de « 15 % », un prix
// négatif, un chauffeur payé 0 $) ne doit jamais devenir le tarif actif. Ce
// module vérifie chaque champ contre des bornes explicites et rejoue le
// moteur officiel (pricingEngine.ts) pour s'assurer que le chauffeur reçoit
// toujours un montant positif.
//
// Les taxes (`tax_rate`) et la politique de pourboire (`tip_policy`) ne sont
// JAMAIS acceptées du brouillon : elles sont recopiées telles quelles depuis
// la version active (décision du propriétaire : ne pas toucher aux taxes).
// -----------------------------------------------------------------------------

import { parseItemClassFees } from "./itemClassFees";
import { missionFeeAmountsError } from "./missionFees";
import { calculateCustomerQuote, calculateDriverCompensation } from "./pricingEngine";
import {
  AdditionalStopFeeConfigDoc,
  CommissionConfigDoc,
  CustomerServiceFeeConfigDoc,
  HandlingFeeConfigDoc,
  ItemClassFeesDoc,
  MissionFeePolicyDoc,
  PricingVersionDoc,
  QuoteConfigDoc,
  SurchargeRuleDoc,
  VehiclePricingRuleDoc,
  WaitingFeeConfigDoc,
} from "./types";
import { normalizeVehicleCategory } from "./vehicleCategory";

/** Categories priced together by the "price before driver" booking flow. */
export const PILOT_PRICING_CATEGORIES = ["pickup_truck", "cargo_van", "cube_truck"] as const;

/** Bounds accepted by the grid (dollars unless stated). */
export const PRICING_LIMITS = Object.freeze({
  base_fare: 500,
  rate_per_km: 20,
  rate_per_minute: 10,
  minimum_charge: 500,
  handling_fee: 200,
  waiting_free_minutes: 240,
  waiting_rate_per_minute: 10,
  fee_per_stop: 200,
  surcharge_fixed: 200,
  surcharge_percentage: 1,
  service_fee_rate: 0.3,
  minimum_service_fee: 50,
  commission_rate: 0.4,
  minimum_platform_commission: 100,
  quote_validity_min: 5,
  quote_validity_max: 120,
});

const HANDLING_KEYS: (keyof HandlingFeeConfigDoc)[] = [
  "loading_fee",
  "unloading_fee",
  "heavy_item_fee",
  "bulky_item_fee",
  "stairs_fee",
  "no_elevator_fee",
  "second_handler_fee",
  "special_equipment_fee",
];

/** Editable part of a pricing version (what the admin grid sends). */
export interface PricingDraft {
  vehicle_rules: VehiclePricingRuleDoc[];
  handling_fees: HandlingFeeConfigDoc;
  waiting_fee: WaitingFeeConfigDoc;
  additional_stop_fee: AdditionalStopFeeConfigDoc;
  surcharges: SurchargeRuleDoc[];
  customer_service_fee: CustomerServiceFeeConfigDoc;
  commission: CommissionConfigDoc;
  quote_config: QuoteConfigDoc;
  mission_fee_policy: MissionFeePolicyDoc;
  item_class_fees: ItemClassFeesDoc;
}

export interface PricingDraftValidation {
  errors: string[];
  draft: PricingDraft | null;
}

function isNum(v: unknown): v is number {
  return typeof v === "number" && Number.isFinite(v);
}

function obj(v: unknown): Record<string, unknown> | null {
  return v && typeof v === "object" && !Array.isArray(v) ? (v as Record<string, unknown>) : null;
}

/**
 * Validates a draft and returns a normalized copy (only known fields, so no
 * stray key can reach a published version). `errors` is empty when valid.
 */
export function validatePricingDraft(raw: unknown): PricingDraftValidation {
  const errors: string[] = [];
  const input = obj(raw);
  if (!input) return { errors: ["Grille de tarifs absente."], draft: null };

  const range = (value: unknown, min: number, max: number, label: string): number => {
    if (!isNum(value) || value < min || value > max) {
      errors.push(`${label} : valeur attendue entre ${min} et ${max}.`);
      return 0;
    }
    return value;
  };
  const integerRange = (value: unknown, min: number, max: number, label: string): number => {
    if (!Number.isSafeInteger(value) || (value as number) < min || (value as number) > max) {
      errors.push(`${label} : nombre entier attendu entre ${min} et ${max}.`);
      return 0;
    }
    return value as number;
  };

  // ---- Véhicules ------------------------------------------------------------
  const rawRules = Array.isArray(input.vehicle_rules) ? input.vehicle_rules : [];
  if (rawRules.length === 0 || rawRules.length > 20) {
    errors.push("Il faut entre 1 et 20 règles de véhicule.");
  }
  const seen = new Set<string>();
  const vehicleRules: VehiclePricingRuleDoc[] = [];
  rawRules.slice(0, 20).forEach((ruleRaw, index) => {
    const rule = obj(ruleRaw);
    const categoryRaw = rule?.category;
    const category = typeof categoryRaw === "string" ? categoryRaw.trim() : "";
    const label = category || `Véhicule ${index + 1}`;
    if (!category) {
      errors.push(`Véhicule ${index + 1} : catégorie manquante.`);
    } else if (seen.has(normalizeVehicleCategory(category))) {
      errors.push(`${label} : catégorie en double.`);
    } else {
      seen.add(normalizeVehicleCategory(category));
    }
    const minimum = range(rule?.minimum_charge, 0, PRICING_LIMITS.minimum_charge, `${label}, prix minimum`);
    if (isNum(rule?.minimum_charge) && (rule!.minimum_charge as number) <= 0) {
      errors.push(`${label}, prix minimum : doit être supérieur à 0 $.`);
    }
    const normalized: VehiclePricingRuleDoc = {
      category,
      base_fare: range(rule?.base_fare, 0, PRICING_LIMITS.base_fare, `${label}, prix de base`),
      rate_per_km: range(rule?.rate_per_km, 0, PRICING_LIMITS.rate_per_km, `${label}, $ par km`),
      rate_per_minute: range(
        rule?.rate_per_minute, 0, PRICING_LIMITS.rate_per_minute, `${label}, $ par minute`
      ),
      minimum_charge: minimum,
    };
    // Optional historical fields are carried over unchanged when present.
    if (isNum(rule?.max_payload_kg) || rule?.max_payload_kg === null) {
      normalized.max_payload_kg = rule!.max_payload_kg as number | null;
    }
    if (isNum(rule?.surcharge_fixed_amount) || rule?.surcharge_fixed_amount === null) {
      normalized.surcharge_fixed_amount = rule!.surcharge_fixed_amount as number | null;
    }
    vehicleRules.push(normalized);
  });

  // The booking flow prices the three pilot categories with ONE tariff
  // (quoteBeforeAssignment.preparePriceBeforeAssignment): they must all exist
  // with identical values, or every booking would be refused.
  const pilotRules = PILOT_PRICING_CATEGORIES.map((category) =>
    vehicleRules.filter((r) => normalizeVehicleCategory(r.category) === category)
  );
  if (pilotRules.some((matches) => matches.length !== 1)) {
    errors.push("Les véhicules du pilote (pick-up, fourgon, camion cube) doivent tous avoir un tarif.");
  } else {
    const first = pilotRules[0][0];
    const fields = ["base_fare", "rate_per_km", "rate_per_minute", "minimum_charge"] as const;
    if (pilotRules.some(([r]) => fields.some((f) => r[f] !== first[f]))) {
      errors.push("Les véhicules du pilote (pick-up, fourgon, camion cube) doivent avoir le même tarif.");
    }
  }

  // ---- Manutention ----------------------------------------------------------
  const rawHandling = obj(input.handling_fees);
  if (!rawHandling) errors.push("Frais de manutention absents.");
  const handling = {} as HandlingFeeConfigDoc;
  for (const key of HANDLING_KEYS) {
    handling[key] = range(rawHandling?.[key], 0, PRICING_LIMITS.handling_fee, `Manutention (${key})`);
  }
  // The booking flow refuses any nonzero bulky fee (no threshold defined yet).
  if (handling.bulky_item_fee !== 0) {
    errors.push("Objet encombrant : doit rester à 0 $ (le parcours de réservation ne l'applique pas encore).");
  }

  // ---- Attente, arrêts, majorations ------------------------------------------
  const rawWaiting = obj(input.waiting_fee);
  const waiting: WaitingFeeConfigDoc = {
    free_waiting_minutes: integerRange(
      rawWaiting?.free_waiting_minutes, 0, PRICING_LIMITS.waiting_free_minutes, "Attente gratuite (minutes)"
    ),
    waiting_rate_per_minute: range(
      rawWaiting?.waiting_rate_per_minute, 0, PRICING_LIMITS.waiting_rate_per_minute, "Attente ($ par minute)"
    ),
  };
  const rawStop = obj(input.additional_stop_fee);
  const stop: AdditionalStopFeeConfigDoc = {
    fee_per_stop: range(rawStop?.fee_per_stop, 0, PRICING_LIMITS.fee_per_stop, "Arrêt supplémentaire"),
  };

  const rawSurcharges = Array.isArray(input.surcharges) ? input.surcharges : [];
  if (!Array.isArray(input.surcharges)) errors.push("Majorations absentes.");
  if (rawSurcharges.length > 20) errors.push("Au plus 20 majorations.");
  const surchargeIds = new Set<string>();
  const surcharges: SurchargeRuleDoc[] = [];
  rawSurcharges.slice(0, 20).forEach((surchargeRaw, index) => {
    const s = obj(surchargeRaw);
    const idRaw = s?.id;
    const id = typeof idRaw === "string" ? idRaw.trim() : "";
    const label = id || `Majoration ${index + 1}`;
    if (!/^[a-z0-9_]{2,40}$/.test(id)) errors.push(`${label} : identifiant invalide.`);
    else if (surchargeIds.has(id)) errors.push(`${label} : identifiant en double.`);
    surchargeIds.add(id);
    const modeRaw = s?.mode;
    const mode: SurchargeRuleDoc["mode"] | null =
      modeRaw === "percentage" ? "percentage" : modeRaw === "fixed_amount" ? "fixed_amount" : null;
    if (!mode) errors.push(`${label} : type invalide.`);
    const value = mode === "percentage"
      ? range(s?.value, 0, PRICING_LIMITS.surcharge_percentage, `${label} (pourcentage, 0 à 1)`)
      : range(s?.value, 0, PRICING_LIMITS.surcharge_fixed, `${label} (montant)`);
    if (typeof s?.enabled !== "boolean") errors.push(`${label} : activation invalide.`);
    surcharges.push({ id, mode: mode ?? "fixed_amount", value, enabled: s?.enabled === true });
  });

  // ---- Part Movi-K ----------------------------------------------------------
  const rawService = obj(input.customer_service_fee);
  const service: CustomerServiceFeeConfigDoc = {
    service_fee_rate: range(
      rawService?.service_fee_rate, 0, PRICING_LIMITS.service_fee_rate, "Frais de service client (taux)"
    ),
    minimum_service_fee: range(
      rawService?.minimum_service_fee, 0, PRICING_LIMITS.minimum_service_fee, "Frais de service client (minimum)"
    ),
  };
  const rawCommission = obj(input.commission);
  const commission: CommissionConfigDoc = {
    standard_commission_rate: range(
      rawCommission?.standard_commission_rate, 0, PRICING_LIMITS.commission_rate, "Commission sur le chauffeur (taux)"
    ),
    minimum_platform_commission: range(
      rawCommission?.minimum_platform_commission,
      0,
      PRICING_LIMITS.minimum_platform_commission,
      "Commission minimum"
    ),
    maximum_effective_commission_rate: range(
      rawCommission?.maximum_effective_commission_rate, 0, 1, "Commission maximum (taux)"
    ),
  };
  if (commission.maximum_effective_commission_rate < commission.standard_commission_rate) {
    errors.push("Commission maximum : doit être au moins égale au taux de commission.");
  }

  const rawQuote = obj(input.quote_config);
  const quote: QuoteConfigDoc = {
    quote_validity_minutes: integerRange(
      rawQuote?.quote_validity_minutes,
      PRICING_LIMITS.quote_validity_min,
      PRICING_LIMITS.quote_validity_max,
      "Validité du prix (minutes)"
    ),
  };

  // ---- Frais d'annulation / déplacement --------------------------------------
  const rawFee = obj(input.mission_fee_policy);
  const feeError = missionFeeAmountsError(rawFee);
  if (feeError) errors.push(feeError);
  const fee: MissionFeePolicyDoc = {
    total_minor: (rawFee?.total_minor as number) ?? 0,
    driver_minor: (rawFee?.driver_minor as number) ?? 0,
    platform_minor: (rawFee?.platform_minor as number) ?? 0,
  };

  // ---- Supplément par objet (2026-10-26) ------------------------------------
  // Absent from an older grid: 0 $ everywhere, nothing changes.
  const itemClassFees = parseItemClassFees(input.item_class_fees, errors);

  const draft: PricingDraft = {
    item_class_fees: itemClassFees,
    vehicle_rules: vehicleRules,
    handling_fees: handling,
    waiting_fee: waiting,
    additional_stop_fee: stop,
    surcharges,
    customer_service_fee: service,
    commission,
    quote_config: quote,
    mission_fee_policy: fee,
  };

  // ---- Le chauffeur reçoit toujours un montant positif ----------------------
  if (errors.length === 0) {
    const probe = asPricingVersion(draft, { tax_rate: 0, tip_policy: { driver_tip_percentage: 100 } }, "PROBE");
    for (const rule of vehicleRules) {
      const quoteResult = calculateCustomerQuote(probe, {
        vehicleCategory: rule.category,
        distanceKm: 0,
        estimatedDurationMinutes: 0,
      });
      const compensation = calculateDriverCompensation({
        pricingResult: quoteResult,
        resolvedCommission: { rate: commission.standard_commission_rate, program: "standard", reason: "probe" },
        commissionConfig: commission,
      });
      if (!(compensation.driverGrossEarnings > 0)) {
        errors.push(
          `${rule.category} : au prix minimum, le chauffeur recevrait 0 $. Baissez la commission ou montez le prix minimum.`
        );
      }
    }
  }

  return { errors, draft: errors.length === 0 ? draft : null };
}

/** Full pricing version built from a validated draft. */
export function asPricingVersion(
  draft: PricingDraft,
  locked: Pick<PricingVersionDoc, "tax_rate" | "tip_policy">,
  pricingVersion: string
): PricingVersionDoc {
  return {
    pricing_version: pricingVersion,
    is_active: true,
    effective_from: null as unknown as PricingVersionDoc["effective_from"],
    vehicle_rules: draft.vehicle_rules,
    handling_fees: draft.handling_fees,
    waiting_fee: draft.waiting_fee,
    additional_stop_fee: draft.additional_stop_fee,
    surcharges: draft.surcharges,
    customer_service_fee: draft.customer_service_fee,
    commission: draft.commission,
    tip_policy: locked.tip_policy,
    quote_config: draft.quote_config,
    tax_rate: locked.tax_rate,
    mission_fee_policy: { ...draft.mission_fee_policy, version: pricingVersion },
    item_class_fees: draft.item_class_fees,
  };
}
