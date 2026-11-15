// -----------------------------------------------------------------------------
// Tableau de prix public.
//
// Le visiteur sans compte voit un tableau de prix avant de commencer une
// demande : une ligne par classe d'objet (léger, moyen, lourd, très lourd),
// une colonne par distance.
//
// DEPUIS LE 15 NOVEMBRE 2026 (décision du propriétaire) : les montants
// affichés sont ceux de SA FICHE (OWNER_PUBLIC_PRICES_DOLLARS), et non plus un
// calcul à partir de la grille active. La grille de tarifs n'a PAS été changée
// en même temps : le devis officiel peut donc différer du tableau. Pour
// changer un montant affiché, modifier la fiche ci-dessous ; publier une
// nouvelle grille ne change plus ce tableau.
//
// Les exemples d'objets de chaque ligne viennent toujours de la grille active
// (classe de chaque type d'objet). Seul le total client sort d'ici : jamais
// la commission ni la part du chauffeur.
// -----------------------------------------------------------------------------
import { ITEM_CLASSES, PROPOSED_ITEM_CLASSES } from "./itemClassFees";
import { PHOTO_CATEGORIES } from "./photoIntake";
import { ItemClass, PricingVersionDoc } from "./types";

export const PUBLIC_PRICE_DISTANCES_KM: readonly number[] = [5, 10, 20, 40];

/**
 * Fiche du propriétaire (15 novembre 2026), en dollars, taxes comprises, une
 * valeur par distance de PUBLIC_PRICE_DISTANCES_KM. « Très lourd » = « lourd »
 * + 5 $ (son choix le même jour).
 */
export const OWNER_PUBLIC_PRICES_DOLLARS: Readonly<Record<ItemClass, readonly number[]>> = {
  light: [39, 49, 69, 109],
  medium: [49, 59, 79, 119],
  heavy: [69, 79, 100, 142],
  very_heavy: [74, 84, 105, 147],
};

/** The owner's displayed prices for one item class, in cents. */
export function ownerPublicTotalsMinor(itemClass: ItemClass): number[] {
  return OWNER_PUBLIC_PRICES_DOLLARS[itemClass].map((dollars) => Math.round(dollars * 100));
}

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
