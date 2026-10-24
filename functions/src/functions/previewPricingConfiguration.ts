// -----------------------------------------------------------------------------
// previewPricingConfiguration — Cloud Function callable (admin+), LECTURE SEULE.
//
// Simulateur de la grille de tarifs admin : calcule, pour quelques courses
// types, le prix client, la part Movi-K et la part chauffeur avec la grille
// ACTIVE et avec le BROUILLON, côte à côte. Rien n'est écrit.
//
// Le calcul suit exactement le devis officiel (calculateDeliveryQuote.ts) :
// calculateCustomerQuote → taxes figées par resolveAndFreezeTaxSnapshot →
// arrondi au cent ; puis la commission standard (calculateDriverCompensation)
// comme à l'acceptation d'un chauffeur sans programme Fondateur ni promotion.
// La remise d'un code promo n'est pas simulée.
// -----------------------------------------------------------------------------

import { HttpsError, onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { requireAdminOrAbove, requireSignedIn } from "../lib/auth";
import { invalidArgument } from "../lib/errors";
import { cardHoldMinor, MissionFeePolicy, missionFeePolicyFrom } from "../lib/missionFees";
import { toMinorUnits } from "../lib/money";
import {
  asPricingVersion,
  PILOT_PRICING_CATEGORIES,
  validatePricingDraft,
} from "../lib/pricingConfigValidation";
import {
  calculateCustomerQuote,
  calculateDriverCompensation,
  HandlingFlagsInput,
} from "../lib/pricingEngine";
import { applyTaxSnapshotToQuote, DEFAULT_JURISDICTION, resolveAndFreezeTaxSnapshot } from "../lib/taxEngine";
import { PricingVersionDoc } from "../lib/types";
import { resolveConfiguredVehicleCategory } from "../lib/vehicleCategory";

export interface PricingPreviewScenario {
  id: string;
  distanceKm: number;
  durationMinutes: number;
  additionalStops?: number;
  handling?: HandlingFlagsInput;
}

export interface PreviewPricingConfigurationRequest {
  config: unknown;
  scenarios: PricingPreviewScenario[];
  vehicleCategory?: string;
}

export interface PricingPreviewAmounts {
  customer_total_minor: number;
  subtotal_minor: number;
  service_fee_minor: number;
  tax_minor: number;
  platform_minor: number;
  driver_minor: number;
  card_hold_minor: number;
}

const HANDLING_KEYS: (keyof HandlingFlagsInput)[] = [
  "needsLoading",
  "needsUnloading",
  "needsStairs",
  "noElevator",
  "needsSecondHandler",
  "needsSpecialEquipment",
];

function parseScenarios(raw: unknown): PricingPreviewScenario[] {
  if (!Array.isArray(raw) || raw.length === 0 || raw.length > 8) {
    throw invalidArgument("Entre 1 et 8 courses types sont attendues.");
  }
  return raw.map((item, index) => {
    const s = (item ?? {}) as Record<string, unknown>;
    const distanceKm = s.distanceKm;
    const durationMinutes = s.durationMinutes;
    const stops = s.additionalStops ?? 0;
    if (typeof distanceKm !== "number" || !Number.isFinite(distanceKm) || distanceKm < 0 || distanceKm > 300) {
      throw invalidArgument(`Course ${index + 1} : distance entre 0 et 300 km.`);
    }
    if (typeof durationMinutes !== "number" || !Number.isFinite(durationMinutes) ||
        durationMinutes < 0 || durationMinutes > 600) {
      throw invalidArgument(`Course ${index + 1} : durée entre 0 et 600 minutes.`);
    }
    if (!Number.isSafeInteger(stops) || (stops as number) < 0 || (stops as number) > 5) {
      throw invalidArgument(`Course ${index + 1} : 0 à 5 arrêts supplémentaires.`);
    }
    const rawHandling = (s.handling ?? {}) as Record<string, unknown>;
    const handling: HandlingFlagsInput = { isHeavyItem: false, isBulkyItem: false };
    for (const key of HANDLING_KEYS) handling[key] = rawHandling[key] === true;
    return {
      id: typeof s.id === "string" && s.id.trim() ? s.id.trim().slice(0, 40) : `course_${index + 1}`,
      distanceKm,
      durationMinutes,
      additionalStops: stops as number,
      handling,
    };
  });
}

async function quoteAmounts(
  config: PricingVersionDoc,
  vehicleCategory: string,
  scenario: PricingPreviewScenario,
  feePolicy: MissionFeePolicy,
  atMillis: number
): Promise<PricingPreviewAmounts | null> {
  const category = resolveConfiguredVehicleCategory(
    config.vehicle_rules.map((r) => r.category),
    vehicleCategory
  );
  if (!category) return null;
  const flat = calculateCustomerQuote(config, {
    vehicleCategory: category,
    distanceKm: scenario.distanceKm,
    estimatedDurationMinutes: scenario.durationMinutes,
    handling: scenario.handling,
    totalWaitingMinutes: 0,
    additionalStopsCount: scenario.additionalStops ?? 0,
    applicableSurchargeIds: [],
  });
  const taxSnapshot = await resolveAndFreezeTaxSnapshot({
    jurisdiction: DEFAULT_JURISDICTION,
    taxableAmountMajor: flat.subtotal + flat.customerServiceFee,
    applyToTransport: true,
    applyToPlatformFees: true,
    atMillis,
  });
  const priced = applyTaxSnapshotToQuote(flat, taxSnapshot);
  const compensation = calculateDriverCompensation({
    pricingResult: priced,
    resolvedCommission: {
      rate: config.commission.standard_commission_rate,
      program: "standard",
      reason: "standard_rate",
    },
    commissionConfig: config.commission,
  });
  const customerTotalMinor = toMinorUnits(priced.customerTotal);
  return {
    customer_total_minor: customerTotalMinor,
    subtotal_minor: toMinorUnits(priced.subtotal),
    service_fee_minor: toMinorUnits(priced.customerServiceFee),
    tax_minor: toMinorUnits(priced.taxAmount),
    platform_minor: toMinorUnits(compensation.platformCommissionAmount + priced.customerServiceFee),
    driver_minor: toMinorUnits(compensation.driverGrossEarnings),
    card_hold_minor: cardHoldMinor(customerTotalMinor, feePolicy),
  };
}

export const previewPricingConfiguration = onCall<PreviewPricingConfigurationRequest>(
  async (request) => {
    const ctx = requireSignedIn(request);
    requireAdminOrAbove(ctx);

    const data = request.data ?? ({} as PreviewPricingConfigurationRequest);
    const scenarios = parseScenarios(data.scenarios);
    const vehicleCategory =
      typeof data.vehicleCategory === "string" && data.vehicleCategory.trim()
        ? data.vehicleCategory.trim()
        : PILOT_PRICING_CATEGORIES[0];

    const validation = validatePricingDraft(data.config);

    const activeSnap = await db.collection("pricing_configs").doc("active").get();
    const rawActiveId = activeSnap.data()?.active_pricing_version;
    const activeId = typeof rawActiveId === "string" && rawActiveId.trim() ? rawActiveId.trim() : null;
    const activeVersionSnap = activeId
      ? await db.collection("pricing_versions").doc(activeId).get()
      : null;
    const active = (activeVersionSnap?.data() as PricingVersionDoc | undefined) ?? null;
    const activeFee = missionFeePolicyFrom(active?.mission_fee_policy, activeId ?? undefined);

    const draftVersion = validation.draft
      ? asPricingVersion(
          validation.draft,
          {
            tax_rate: typeof active?.tax_rate === "number" ? active.tax_rate : 0,
            tip_policy: active?.tip_policy ?? { driver_tip_percentage: 100 },
          },
          "PREVIEW"
        )
      : null;
    const draftFee = draftVersion
      ? missionFeePolicyFrom(draftVersion.mission_fee_policy, "PREVIEW")
      : null;

    const atMillis = admin.firestore.Timestamp.now().toMillis();
    try {
      const rows: Array<{
        id: string;
        current: PricingPreviewAmounts | null;
        draft: PricingPreviewAmounts | null;
      }> = [];
      for (const scenario of scenarios) {
        rows.push({
          id: scenario.id,
          current: active ? await quoteAmounts(active, vehicleCategory, scenario, activeFee, atMillis) : null,
          draft: draftVersion && draftFee
            ? await quoteAmounts(draftVersion, vehicleCategory, scenario, draftFee, atMillis)
            : null,
        });
      }
      return {
        activePricingVersion: activeId,
        vehicleCategory,
        errors: validation.errors,
        rows,
        fee: {
          current: { total_minor: activeFee.total_minor, driver_minor: activeFee.driver_minor,
            platform_minor: activeFee.platform_minor },
          draft: draftFee ? { total_minor: draftFee.total_minor, driver_minor: draftFee.driver_minor,
            platform_minor: draftFee.platform_minor } : null,
        },
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      throw new HttpsError("internal", "Simulation impossible avec cette grille.");
    }
  }
);
