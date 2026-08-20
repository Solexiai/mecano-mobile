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

import { applyRateMinor, toMajorUnits, toMinorUnits } from "./money";
import { admin, db } from "./admin";
import { TaxConfigDoc, TaxSnapshot } from "./types";
import { CustomerPricingResult } from "./pricingEngine";

/**
 * Juridiction système par défaut, utilisée UNIQUEMENT quand aucune
 * juridiction explicite n'est disponible sur la mission/adresse (aucun
 * champ `jurisdiction`/`province` n'existe encore sur `StopInput` — voir
 * createDeliveryRequest.ts). Ceci n'est PAS un taux fiscal codé en dur :
 * c'est un identifiant de juridiction par défaut, documenté explicitement,
 * qui ne produit AUCUNE taxe tant qu'aucun admin n'a créé de TaxConfigDoc
 * pour cette juridiction via updateTaxConfiguration(). Point nécessitant
 * une décision produit ultérieure (ajout d'un champ jurisdiction explicite
 * sur l'adresse) — signalé dans le rapport final Phase 6.
 */
export const DEFAULT_JURISDICTION = "QC";

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

/**
 * Lit toutes les configurations de taxes ACTIVES pour une juridiction à un
 * instant donné (`atMillis`), en s'appuyant sur les alias mutables
 * `tax_configs/{jurisdiction}_{taxCode}_current` (une requête par tax_code
 * connu) plutôt qu'un scan complet de la collection — voir
 * updateTaxConfiguration.ts pour l'écriture de ces alias.
 *
 * Une configuration est considérée ACTIVE à `atMillis` si :
 *   - `enabled === true` ;
 *   - `effective_from <= atMillis` ;
 *   - `effective_until` est null OU `effective_until > atMillis`.
 *
 * Renvoie un tableau vide si aucune configuration n'existe pour la
 * juridiction (comportement de repli géré par l'appelant via
 * `calculateFlatTaxFallback()` — voir acceptDelivery.ts).
 */
export async function readActiveTaxConfigs(
  jurisdiction: string,
  atMillis: number,
  tx?: FirebaseFirestore.Transaction
): Promise<TaxConfigDoc[]> {
  // Les alias `_current` sont retrouvés en interrogeant la collection par
  // champs indexables `jurisdiction` + `is_alias` (plutôt que de deviner
  // tous les tax_code possibles). Si `tx` est fourni (appel depuis une
  // transaction Firestore existante, ex: acceptDelivery.ts), on utilise
  // `tx.get()` pour que CETTE lecture participe à la même transaction —
  // convention déjà suivie ailleurs dans ce module (ex: driver_promotions
  // dans acceptDelivery.ts).
  const aliasQueryRef = db
    .collection("tax_configs")
    .where("jurisdiction", "==", jurisdiction)
    .where("is_alias", "==", true);
  const aliasQuery = tx ? await tx.get(aliasQueryRef) : await aliasQueryRef.get();

  if (aliasQuery.empty) {
    return [];
  }

  const configIds = aliasQuery.docs.map((d) => d.data().latest_config_id as string);
  const configSnaps = await Promise.all(
    configIds.map((id) => {
      const ref = db.collection("tax_configs").doc(id);
      return tx ? tx.get(ref) : ref.get();
    })
  );

  const configs: TaxConfigDoc[] = [];
  for (const snap of configSnaps) {
    if (!snap.exists) continue;
    const config = snap.data() as TaxConfigDoc;
    if (!config.enabled) continue;
    const fromMillis = config.effective_from.toMillis();
    if (fromMillis > atMillis) continue;
    if (config.effective_until && config.effective_until.toMillis() <= atMillis) continue;
    configs.push(config);
  }

  return configs;
}

/**
 * Résout et FIGE le calcul fiscal d'une mission au moment où elle devient
 * contractuelle (acceptDelivery.ts / createFinancialSnapshot.ts) : lit les
 * configurations actives de la juridiction, calcule les lignes de taxe, et
 * retourne soit un `TaxSnapshot` complet (Phase 6, si au moins une config
 * active existe pour la juridiction), soit `null` (aucune config Phase 6
 * disponible — l'appelant doit alors utiliser `calculateFlatTaxFallback()`
 * avec le `tax_rate` plat legacy de `PricingVersionDoc`, de façon EXPLICITE
 * et non silencieuse — voir logs `used_flat_tax_fallback` dans l'appelant).
 *
 * `taxableAmountMajor` est le montant taxable en DOLLARS (frontière avec le
 * pricingEngine.ts existant, qui produit des `number` en dollars) — converti
 * ici en cents entiers via `toMinorUnits()` UNE SEULE FOIS, à la frontière,
 * conformément au contrat documenté dans money.ts.
 */
export async function resolveAndFreezeTaxSnapshot(params: {
  jurisdiction: string;
  taxableAmountMajor: number;
  applyToTransport: boolean;
  applyToPlatformFees: boolean;
  atMillis: number;
  tx?: FirebaseFirestore.Transaction;
}): Promise<TaxSnapshot | null> {
  const { jurisdiction, taxableAmountMajor, applyToTransport, applyToPlatformFees, atMillis, tx } =
    params;

  const configs = await readActiveTaxConfigs(jurisdiction, atMillis, tx);
  if (configs.length === 0) {
    return null;
  }

  const taxableAmountMinor = toMinorUnits(taxableAmountMajor);
  const result = calculateTaxes({
    taxableAmountMinor,
    configs,
    jurisdiction,
    applyToTransport,
    applyToPlatformFees,
  });

  return {
    tax_jurisdiction: jurisdiction,
    tax_version_ids: configs.map((c) => `${c.jurisdiction}_${c.tax_code}_v${c.version}`),
    tax_rates: result.lines.map((l) => ({ tax_code: l.taxType, rate: l.rate })),
    taxable_base_minor: taxableAmountMinor,
    tax_amounts_minor: result.lines.map((l) => ({
      tax_code: l.taxType,
      amount_minor: l.amountMinor,
    })),
    total_tax_minor: result.totalTaxMinor,
    snapshotted_at: admin.firestore.Timestamp.now(),
  };
}

/** Convertit `total_tax_minor` d'un TaxSnapshot en dollars, pour alimenter
 * le champ legacy `customer_tax` (dollars) de `financial_snapshots` sans
 * dupliquer la logique d'arrondi. */
export function taxSnapshotTotalMajor(snapshot: TaxSnapshot): number {
  return toMajorUnits(snapshot.total_tax_minor);
}

/**
 * Remplace `taxAmount`/`customerTotal` d'un `CustomerPricingResult` déjà
 * calculé (taux plat legacy) par le résultat du moteur Phase 6, SI et
 * SEULEMENT SI un `TaxSnapshot` a pu être résolu (sinon retourne le résultat
 * INCHANGÉ, préservant intégralement le comportement Phase 1-5). Utilisé de
 * façon IDENTIQUE par `calculateDeliveryQuote.ts` (devis) et
 * `acceptDelivery.ts` (acceptation) pour garantir que le montant facturé au
 * client à l'acceptation est EXACTEMENT celui annoncé au devis.
 */
export function applyTaxSnapshotToQuote(
  pricingResult: CustomerPricingResult,
  taxSnapshot: TaxSnapshot | null
): CustomerPricingResult {
  if (!taxSnapshot) {
    return pricingResult;
  }
  const taxAmount = taxSnapshotTotalMajor(taxSnapshot);
  const customerTotal = pricingResult.subtotal + pricingResult.customerServiceFee + taxAmount;
  return { ...pricingResult, taxAmount, customerTotal };
}
