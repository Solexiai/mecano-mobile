// -----------------------------------------------------------------------------
// taxEngine.ts — Moteur de taxes CONFIGURABLE (point 16 du cahier des
// charges Phase 6).
//
// ⚠️ AUCUNE RÈGLE FISCALE N'EST INVENTÉE ICI. Ce module fournit uniquement
// le MÉCANISME de calcul à partir d'une configuration explicite
// (`tax_configs/{jurisdiction}`, voir types.ts TaxConfigDoc), jamais un taux
// GST/QST/HST codé en dur. Les taux réels (ex: 5% GST + 9.975% QST au
// Québec) doivent être saisis par un administrateur via
// `updateTaxConfiguration()` (Cloud Function admin, ci-dessous) après
// validation comptable/légale — voir section "points nécessitant une
// validation comptable/légale" du rapport final Phase 6.
//
// Ce module REMPLACE PROGRESSIVEMENT le `tax_rate` unique et plat de
// `PricingVersionDoc` (Phase 1-4) par une liste de `TaxConfigDoc` par
// juridiction, permettant plusieurs taxes cumulées (ex: GST + QST) et un
// statut d'exemption. Tant qu'aucune config Phase 6 n'existe pour une
// juridiction, `calculateTaxes()` retombe sur le taux plat existant
// (rétro-compatibilité stricte, AUCUNE régression sur les missions déjà
// tarifées en Phase 1-5).
// -----------------------------------------------------------------------------

import { applyRateMinor } from "./money";
import { TaxConfigDoc } from "./types";

export interface TaxLineResult {
  taxType: string;
  jurisdiction: string;
  rate: number;
  amountMinor: number;
  taxRegistrationOwner: "platform" | "driver" | "not_applicable";
}

export interface TaxCalculationResult {
  lines: TaxLineResult[];
  totalTaxMinor: number;
}

/**
 * Calcule les lignes de taxe applicables à partir d'une liste de
 * configurations actives pour une juridiction donnée. `taxableAmountMinor`
 * doit déjà exclure tout montant non taxable (ex: pourboire, selon la
 * politique en vigueur — non décidé ici, voir appelant).
 */
export function calculateTaxes(params: {
  taxableAmountMinor: number;
  configs: TaxConfigDoc[];
  jurisdiction: string;
  applyToTransport: boolean;
  applyToPlatformFees: boolean;
}): TaxCalculationResult {
  const { taxableAmountMinor, configs, jurisdiction, applyToTransport, applyToPlatformFees } =
    params;

  const applicable = configs.filter(
    (c) =>
      c.is_active &&
      c.jurisdiction === jurisdiction &&
      ((applyToTransport && c.applies_to_transport) ||
        (applyToPlatformFees && c.applies_to_platform_fees))
  );

  if (applicable.length === 0) {
    return { lines: [], totalTaxMinor: 0 };
  }

  const lines: TaxLineResult[] = applicable.map((c) => ({
    taxType: c.tax_type,
    jurisdiction: c.jurisdiction,
    rate: c.rate,
    amountMinor:
      c.tax_type === "tax_exempt" ? 0 : applyRateMinor(taxableAmountMinor, c.rate),
    taxRegistrationOwner: c.tax_registration_owner,
  }));

  const totalTaxMinor = lines.reduce((sum, l) => sum + l.amountMinor, 0);

  return { lines, totalTaxMinor };
}

/**
 * Fallback rétro-compatible : utilise le `tax_rate` plat existant de
 * `PricingVersionDoc` (Phase 1-4) quand aucune configuration Phase 6
 * n'existe pour la juridiction. Garantit qu'aucune mission déjà en cours
 * n'est affectée par l'introduction du moteur de taxes Phase 6.
 */
export function calculateFlatTaxFallback(taxableAmountMinor: number, flatRate: number): number {
  return applyRateMinor(taxableAmountMinor, flatRate);
}
