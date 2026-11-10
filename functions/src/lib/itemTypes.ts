// -----------------------------------------------------------------------------
// Item types and the vehicles allowed to carry them (owner decision
// 2026-10-26). Stored in system_config/booking_capacity
// .photo_intake.category_vehicle_categories, edited by the admin
// (functions/adminItemTypes.ts). The price does not depend on the vehicle
// (uniform tariff): this only decides which drivers see a request.
// -----------------------------------------------------------------------------
import { PHOTO_CATEGORIES, PhotoCategory } from './photoIntake';

// 2026-11-09 (Daniel) : le VUS devient un véhicule du pilote. Même prix que
// les autres (le tarif est uniforme, voir quoteBeforeAssignment) ; il ne
// transporte que ce que l'admin lui coche : par défaut colis/boîtes, table,
// chaises, commode — jamais électroménager ni sectionnel (sofa).
export const ITEM_VEHICLES = ['pickup_truck', 'cargo_van', 'cube_truck', 'suv'] as const;
export type ItemVehicle = typeof ITEM_VEHICLES[number];

/** Véhicules « gros volume » : tout type, sauf matériaux pour le fourgon. */
const TRUCKS: ItemVehicle[] = ['pickup_truck', 'cargo_van', 'cube_truck'];

/** Ce qu'un VUS peut prendre par défaut (décision Daniel 2026-11-09). */
export const SUV_DEFAULT_ITEMS: readonly PhotoCategory[] = ['boxes', 'table', 'chairs', 'dresser'];

/** The distribution proposed on 2026-10-26 (updated 2026-11-09 with the
 * SUV): every type for every truck, except construction materials (pickup
 * or cube truck, not a van); the SUV only for SUV_DEFAULT_ITEMS. Only a
 * suggestion shown in the admin screen until the admin saves it. */
export const PROPOSED_ITEM_VEHICLES: Record<PhotoCategory, ItemVehicle[]> = Object.fromEntries(
  PHOTO_CATEGORIES.map((c) => [
    c,
    [
      ...(c === 'materials' ? ['pickup_truck', 'cube_truck'] : TRUCKS),
      ...(SUV_DEFAULT_ITEMS.includes(c) ? ['suv'] : []),
    ],
  ]),
) as Record<PhotoCategory, ItemVehicle[]>;

/** Validates an admin mapping: every catalog type present, only known
 * vehicles, no duplicates. An empty list means the type is not offered. */
export function parseItemVehicles(raw: unknown): Record<PhotoCategory, ItemVehicle[]> | null {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null;
  const value = raw as Record<string, unknown>;
  if (Object.keys(value).some((k) => !(PHOTO_CATEGORIES as readonly string[]).includes(k))) return null;
  const out = {} as Record<PhotoCategory, ItemVehicle[]>;
  for (const category of PHOTO_CATEGORIES) {
    const list = value[category];
    if (!Array.isArray(list) || list.length > ITEM_VEHICLES.length) return null;
    if (list.some((v) => !(ITEM_VEHICLES as readonly unknown[]).includes(v))) return null;
    if (new Set(list).size !== list.length) return null;
    out[category] = ITEM_VEHICLES.filter((v) => list.includes(v));
  }
  return out;
}
