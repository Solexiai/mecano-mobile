// -----------------------------------------------------------------------------
// Tableau de prix public (décision du propriétaire, 13 novembre 2026).
//
// Le visiteur sans compte voit des prix approximatifs avant de commencer une
// demande : une ligne par classe d'objet (léger, moyen, lourd, très lourd),
// une colonne par distance. Les montants viennent de la grille ACTIVE et du
// même calcul que le devis officiel, donc le tableau ne peut pas contredire
// le prix réel. Seul le total client sort d'ici : jamais la commission ni la
// part du chauffeur.
//
// Hypothèses d'une ligne (celles du parcours simple) : un objet, sans
// escaliers, un chauffeur, le client donne un coup de main, chargement et
// déchargement compris.
// -----------------------------------------------------------------------------
import { ITEM_CLASSES, PROPOSED_ITEM_CLASSES } from "./itemClassFees";
import { PHOTO_CATEGORIES } from "./photoIntake";
import { HandlingFlagsInput } from "./pricingEngine";
import { ItemClass, PricingVersionDoc } from "./types";

export const PUBLIC_PRICE_DISTANCES_KM: readonly number[] = [5, 10, 20, 40];

/** Same estimate as the admin "Essayer un prix": 2 minutes per km + 10. */
export function publicPriceDurationMinutes(distanceKm: number): number {
  return Math.round(distanceKm * 2 + 10);
}

/** The simple booking flow: help at both ends, no stairs, one handler. */
export const PUBLIC_PRICE_HANDLING: HandlingFlagsInput = Object.freeze({
  needsLoading: true,
  needsUnloading: true,
  isHeavyItem: false,
  isBulkyItem: false,
  needsStairs: false,
  noElevator: false,
  needsSecondHandler: false,
  needsSpecialEquipment: false,
});

export interface PublicPriceRowPlan {
  item_class: ItemClass;
  /** Item types of this class in the active grid, in catalog order. */
  categories: string[];
}

/** One row per item class that holds at least one item type. "Autre objet"
 * is left out: it says nothing to a visitor. */
export function publicPriceRows(
  config: Pick<PricingVersionDoc, "item_class_fees">
): PublicPriceRowPlan[] {
  const classes: Record<string, ItemClass> = config.item_class_fees?.classes ?? {};
  return ITEM_CLASSES.map((itemClass) => ({
    item_class: itemClass,
    categories: (PHOTO_CATEGORIES as readonly string[]).filter(
      (category) =>
        category !== "other" &&
        (classes[category] ?? PROPOSED_ITEM_CLASSES[category] ?? "medium") === itemClass
    ),
  })).filter((row) => row.categories.length > 0);
}

export interface PublicPriceRow extends PublicPriceRowPlan {
  /** Customer total, taxes included, in cents; one per distance. */
  totals_minor: number[];
}

export interface PublicPriceTable {
  currency: "CAD";
  distances_km: number[];
  rows: PublicPriceRow[];
  /** The lowest amount of the table: "à partir de". */
  from_minor: number;
  taxes_included: true;
}

/** Null when a price is missing or not a positive whole number of cents: the
 * page then shows no table rather than a wrong one. */
export function assemblePublicPriceTable(
  rows: PublicPriceRow[],
  distancesKm: readonly number[] = PUBLIC_PRICE_DISTANCES_KM
): PublicPriceTable | null {
  if (rows.length === 0) return null;
  const all: number[] = [];
  for (const row of rows) {
    if (row.totals_minor.length !== distancesKm.length) return null;
    for (const total of row.totals_minor) {
      if (!Number.isSafeInteger(total) || total <= 0) return null;
      all.push(total);
    }
  }
  return {
    currency: "CAD",
    distances_km: [...distancesKm],
    rows,
    from_minor: Math.min(...all),
    taxes_included: true,
  };
}
