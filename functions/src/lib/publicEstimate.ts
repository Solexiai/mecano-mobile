// -----------------------------------------------------------------------------
// Estimation publique par codes postaux (décision du propriétaire,
// 26 novembre 2026).
//
// Le visiteur sans compte entre deux codes postaux et un poids (léger, moyen,
// lourd) et voit une FOURCHETTE de prix. Les deux bornes sortent du même
// calcul que le devis officiel, avec la grille ACTIVE :
//   - borne basse : un objet, sans escaliers, le client aide à porter ;
//   - borne haute : escaliers sans ascenseur et deuxième porteur.
// Ce n'est ni un devis ni une réservation : rien n'est écrit, et seul le
// total client sort d'ici (jamais la commission ni la part du chauffeur).
// -----------------------------------------------------------------------------
import { PROPOSED_ITEM_CLASSES } from "./itemClassFees";
import { PHOTO_CATEGORIES } from "./photoIntake";
import { HandlingFlagsInput } from "./pricingEngine";
import { ItemClass, PricingVersionDoc } from "./types";

export type EstimateWeight = "light" | "medium" | "heavy";
export const ESTIMATE_WEIGHTS: readonly EstimateWeight[] = ["light", "medium", "heavy"];

export function parseEstimateWeight(raw: unknown): EstimateWeight | null {
  return (ESTIMATE_WEIGHTS as readonly unknown[]).includes(raw) ? (raw as EstimateWeight) : null;
}

// Lettres admises par Postes Canada (jamais D, F, I, O, Q, U ; W et Z jamais
// en première position).
const POSTAL = /^([ABCEGHJ-NPRSTVXY]\d[ABCEGHJ-NPRSTV-Z])(\d[ABCEGHJ-NPRSTV-Z]\d)?$/;

/**
 * « j2g3v5 », « J2G 3V5 » ou « J2G-3V5 » → « J2G 3V5 ». Les trois premiers
 * caractères seuls (« J2G ») sont acceptés : le visiteur ne connaît pas
 * toujours le code complet du vendeur. Null si ce n'est pas un code postal
 * canadien.
 */
export function normalizePostalCode(raw: unknown): string | null {
  if (typeof raw !== "string" || raw.length > 12) return null;
  const match = POSTAL.exec(raw.toUpperCase().replace(/[\s-]/g, ""));
  if (!match) return null;
  return match[2] ? `${match[1]} ${match[2]}` : match[1];
}

/** Le parcours de réservation : aide aux deux bouts, toujours. */
export const ESTIMATE_LOW_HANDLING: HandlingFlagsInput = Object.freeze({
  needsLoading: true,
  needsUnloading: true,
  isHeavyItem: false,
  isBulkyItem: false,
  needsStairs: false,
  noElevator: false,
  needsSecondHandler: false,
  needsSpecialEquipment: false,
});

export const ESTIMATE_HIGH_HANDLING: HandlingFlagsInput = Object.freeze({
  ...ESTIMATE_LOW_HANDLING,
  needsStairs: true,
  noElevator: true,
  needsSecondHandler: true,
});

/**
 * Un type d'objet de la classe demandée dans la grille active, pour que le
 * supplément par objet soit celui du devis officiel. Null si la grille n'a
 * aucun type dans cette classe.
 */
export function estimateItemCategory(
  config: Pick<PricingVersionDoc, "item_class_fees">,
  weight: EstimateWeight
): string | null {
  const classes: Record<string, ItemClass> = config.item_class_fees?.classes ?? {};
  return (
    (PHOTO_CATEGORIES as readonly string[]).find(
      (category) =>
        category !== "other" &&
        (classes[category] ?? PROPOSED_ITEM_CLASSES[category] ?? "medium") === weight
    ) ?? null
  );
}

export interface PublicEstimate {
  currency: "CAD";
  /** Dollars entiers, taxes comprises : borne basse arrondie vers le bas. */
  low_dollars: number;
  /** Dollars entiers, taxes comprises : borne haute arrondie vers le haut. */
  high_dollars: number;
  /** Distance routière arrondie au kilomètre. */
  distance_km: number;
  taxes_included: true;
}

/** Null si un montant n'est pas un nombre entier de cents strictement positif. */
export function assemblePublicEstimate(
  lowMinor: number,
  highMinor: number,
  distanceKm: number
): PublicEstimate | null {
  if (!Number.isSafeInteger(lowMinor) || !Number.isSafeInteger(highMinor) || lowMinor <= 0 ||
      !Number.isFinite(distanceKm) || distanceKm <= 0) return null;
  const low = Math.floor(lowMinor / 100);
  const high = Math.ceil(Math.max(lowMinor, highMinor) / 100);
  if (low < 1) return null;
  return {
    currency: "CAD",
    low_dollars: low,
    high_dollars: Math.max(low, high),
    distance_km: Math.max(1, Math.round(distanceKm)),
    taxes_included: true,
  };
}
