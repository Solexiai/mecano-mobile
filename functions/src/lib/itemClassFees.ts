// -----------------------------------------------------------------------------
// Handling supplement by item class (owner decision 2026-10-26).
// Every item type has a class (léger, moyen, lourd, très lourd); each class an
// amount per item, times the quantity, capped per order. Amounts, classes and
// the driver's share live in the pricing version: versioned, simulated and
// published like every other price. An older version without it: 0 $.
// -----------------------------------------------------------------------------
import { PHOTO_CATEGORIES } from "./photoIntake";
import { ItemClass, ItemClassFeesDoc, PricingVersionDoc } from "./types";

export const ITEM_CLASSES: readonly ItemClass[] = ["light", "medium", "heavy", "very_heavy"];

/** The classes proposed on 2026-10-26 (plan-prix-par-type-objet.md). */
export const PROPOSED_ITEM_CLASSES: Record<string, ItemClass> = {
  sofa: "heavy", armchair: "medium", bed: "heavy", dresser: "medium", desk: "medium",
  chairs: "light", table: "medium", tv_stand: "medium", tv: "light", fridge: "heavy",
  freezer: "heavy", washer: "heavy", stove: "heavy", tires: "medium",
  yard_equipment: "very_heavy", patio: "medium", sport: "light", boxes: "light",
  materials: "very_heavy", other: "medium",
};

/** Zero amounts: publishing this changes no price. */
export function defaultItemClassFees(): ItemClassFeesDoc {
  return { light: 0, medium: 0, heavy: 0, very_heavy: 0, order_cap: 0, driver_keeps_all: true,
    classes: { ...PROPOSED_ITEM_CLASSES } };
}

export const ITEM_CLASS_LIMITS = Object.freeze({ per_item: 200, order_cap: 1000 });

/** Validates the admin's section; pushes readable errors in French. */
export function parseItemClassFees(raw: unknown, errors: string[]): ItemClassFeesDoc {
  const base = defaultItemClassFees();
  if (raw === undefined || raw === null) return base;
  if (typeof raw !== "object" || Array.isArray(raw)) {
    errors.push("Supplément par objet : section invalide.");
    return base;
  }
  const r = raw as Record<string, unknown>;
  const money = (v: unknown, max: number, label: string): number => {
    if (typeof v !== "number" || !Number.isFinite(v) || v < 0 || v > max) {
      errors.push(`Supplément par objet : ${label} entre 0 et ${max} $.`);
      return 0;
    }
    return Math.round(v * 100) / 100;
  };
  const out: ItemClassFeesDoc = {
    light: money(r.light, ITEM_CLASS_LIMITS.per_item, "léger"),
    medium: money(r.medium, ITEM_CLASS_LIMITS.per_item, "moyen"),
    heavy: money(r.heavy, ITEM_CLASS_LIMITS.per_item, "lourd"),
    very_heavy: money(r.very_heavy, ITEM_CLASS_LIMITS.per_item, "très lourd"),
    order_cap: money(r.order_cap ?? 0, ITEM_CLASS_LIMITS.order_cap, "plafond par commande"),
    driver_keeps_all: r.driver_keeps_all !== false,
    classes: { ...PROPOSED_ITEM_CLASSES },
  };
  if (r.classes !== undefined) {
    const classes = r.classes;
    if (!classes || typeof classes !== "object" || Array.isArray(classes)) {
      errors.push("Supplément par objet : classes invalides.");
    } else {
      for (const [category, cls] of Object.entries(classes as Record<string, unknown>)) {
        if (!(PHOTO_CATEGORIES as readonly string[]).includes(category)) {
          errors.push(`Supplément par objet : type inconnu (${category}).`);
        } else if (!(ITEM_CLASSES as readonly unknown[]).includes(cls)) {
          errors.push(`Supplément par objet : classe invalide pour ${category}.`);
        } else {
          out.classes[category] = cls as ItemClass;
        }
      }
    }
  }
  return out;
}

export interface ItemClassFeeLine {
  category: string;
  item_class: ItemClass;
  quantity: number;
  amount: number;
}

export interface ItemClassFee {
  total: number;
  lines: ItemClassFeeLine[];
  capped: boolean;
}

/** The supplement for a load, from the locked items only (never a client
 * amount). Unknown types fall back to the proposal, then to "medium". */
export function itemClassFeeFor(
  config: Pick<PricingVersionDoc, "item_class_fees">,
  items: readonly { category: string; quantity: number }[]
): ItemClassFee {
  const fees = config.item_class_fees;
  if (!fees) return { total: 0, lines: [], capped: false };
  const lines: ItemClassFeeLine[] = [];
  let sum = 0;
  for (const item of items) {
    const itemClass = fees.classes?.[item.category] ?? PROPOSED_ITEM_CLASSES[item.category] ?? "medium";
    const each = fees[itemClass] ?? 0;
    const quantity = Number.isSafeInteger(item.quantity) && item.quantity > 0 ? item.quantity : 1;
    const amount = Math.round(each * quantity * 100) / 100;
    if (amount > 0) lines.push({ category: item.category, item_class: itemClass, quantity, amount });
    sum += amount;
  }
  const cap = fees.order_cap > 0 ? fees.order_cap : Infinity;
  const total = Math.round(Math.min(sum, cap) * 100) / 100;
  return { total, lines, capped: sum > cap };
}
