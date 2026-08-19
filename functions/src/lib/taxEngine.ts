// -----------------------------------------------------------------------------
// taxEngine.ts — Moteur de taxes CONFIGURABLE (point 16 du cahier des
// charges Phase 6).
//
// ⚠️ AUCUNE règle fiscale n'est inventée ici. Ce module fournit uniquement
// l'ARCHITECTURE permettant de configurer des taxes par juridiction/type
// (GST/QST/HST/other/exempt) via la collection admin `tax_configs`. Les
// TAUX RÉELS et l'applicabilité définitive (transport vs frais Movi-K,
// statut de fournisseur/marketplace vis-à-vis de Revenu Québec/ARC) doivent
// être validés par un professionnel comptable/juridique avant mise en
// production — voir docs/PAYMENT_ARCHITECTURE.md §9 et le rapport final
// Phase 6 (section "points nécessitant validation comptable/juridique").
//
// Par défaut, en l'absence de toute configuration explicite dans
// `tax_configs`, le moteur applique le comportement historique (taux unique
// `pricing_versions.tax_rate`, déjà utilisé par `calculateCustomerQuote()`
// depuis les phases précédentes) — AUCUNE régression introduite sur le
// calcul déjà validé. Le nouveau comportement multi-juridictions n'est
// utilisé que si des `tax_configs` actifs existent pour la juridiction
// donnée.
// -----------------------------------------------------------------------------

import { TaxConfigDoc, TaxType } from "./types";
import { applyRateMinor } from "./money";

export interface TaxBreakdownLineMinor {
  taxType: TaxType;
  jurisdiction: string;
  rate: number;
  taxableAmountMinor: number;
  taxAmountMinor: number;
  taxRegistrationOwner: "platform" | "driver" | "not_applicable";
}

export interface TaxCalculationResultMinor {
  totalTaxMinor: number;
  breakdown: TaxBreakdownLineMinor[];
}

/**
 * Calcule les taxes applicables à un montant taxable (transport) et à un
 * montant de frais plateforme, séparément, à partir des `tax_configs`
 * actifs d'une juridiction. Aucune configuration active -> retourne un
 * résultat à zéro (l'appelant doit alors utiliser le taux legacy du
 * pricing_version, jamais suppose un taux implicite ici).
 */
export function calculateTaxesMinor(params: {
  transportTaxableAmountMinor: number;
  platformFeesTaxableAmountMinor: number;
  activeTaxConfigs: TaxConfigDoc[];
}): TaxCalculationResultMinor {
  const { transportTaxableAmountMinor, platformFeesTaxableAmountMinor, activeTaxConfigs } = params;

  const breakdown: TaxBreakdownLineMinor[] = [];
  let totalTaxMinor = 0;

  for (const config of activeTaxConfigs) {
    if (!config.is_active || config.tax_type === "tax_exempt") continue;

    let taxableForThisConfig = 0;
    if (config.applies_to_transport) taxableForThisConfig += transportTaxableAmountMinor;
    if (config.applies_to_platform_fees) taxableForThisConfig += platformFeesTaxableAmountMinor;
    if (taxableForThisConfig <= 0) continue;

    const taxAmountMinor = applyRateMinor(taxableForThisConfig, config.rate);
    totalTaxMinor += taxAmountMinor;

    breakdown.push({
      taxType: config.tax_type,
      jurisdiction: config.jurisdiction,
      rate: config.rate,
      taxableAmountMinor: taxableForThisConfig,
      taxAmountMinor,
      taxRegistrationOwner: config.tax_registration_owner,
    });
  }

  return { totalTaxMinor, breakdown };
}

/** true si au moins une config active existe pour la juridiction donnée. */
export function hasActiveTaxConfig(configs: TaxConfigDoc[]): boolean {
  return configs.some((c) => c.is_active);
}
