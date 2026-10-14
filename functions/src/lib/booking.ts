/** Booking contract. Capacities and handling thresholds MUST come from approved
 * configuration. Conservative fit: no stacking, no diagonal loading, fixed
 * upright orientation when requested. A refusal can require human review. */
import { invalidArgument } from './errors';

export interface CargoItem {
  id: string; category: string; label: string; quantity: number;
  length_cm: number | null; width_cm: number | null; height_cm: number | null;
  weight_kg: number | null; approximate: boolean; upright: boolean; photos: string[];
}
export interface Access { floor: number; stairs: boolean; elevator: boolean; help: boolean }
export interface BookingLoad {
  schema_version: 1; draft_id: string; items: CargoItem[]; pickup: Access; dropoff: Access;
  handlers: number; equipment: string[]; requested_at: string | null;
}
export interface Capacity {
  category: string; rank: number; version: string; verified: boolean;
  length_cm: number; width_cm: number; height_cm: number;
  opening_width_cm: number; opening_height_cm: number; payload_kg: number;
  handlers: number; equipment: string[]; services: string[];
}
export interface BookingRules {
  approved: boolean; version: string; capacities: Capacity[];
  heavy_item_kg: number; bulky_item_cm: number;
}
export interface BookingSnapshot {
  load: BookingLoad; rules_version: string; category: string; capacity_version: string;
}
export type ReviewReason = 'dimensions_unknown' | 'weight_unknown' | 'approximate_measurements' |
  'capacity_unconfigured' | 'no_verified_fit' | 'requested_time_missing';

function object(v: unknown): Record<string, unknown> {
  if (!v || typeof v !== 'object' || Array.isArray(v)) throw invalidArgument('Description de livraison invalide.');
  return v as Record<string, unknown>;
}
function str(v: unknown, max: number, required = true): string {
  if (typeof v !== 'string' || v.length > max || (required && !v.trim())) throw invalidArgument('Texte absent ou trop long.');
  return v.trim();
}
function num(v: unknown, min: number, max: number, integer = false): number {
  if (typeof v !== 'number' || !Number.isFinite(v) || v < min || v > max || (integer && !Number.isInteger(v))) {
    throw invalidArgument('Mesure ou quantité invalide.');
  }
  return v;
}
function bool(v: unknown): boolean {
  if (typeof v !== 'boolean') throw invalidArgument('Précisez les contraintes et les accès.');
  return v;
}
function access(v: unknown): Access {
  const a = object(v);
  return { floor: num(a.floor, -10, 200, true), stairs: bool(a.stairs), elevator: bool(a.elevator), help: bool(a.help) };
}
export function normalizeLoad(raw: unknown): BookingLoad {
  const v = object(raw);
  const draftId = str(v.draft_id,80);
  if (!/^[a-zA-Z0-9_-]{8,80}$/.test(draftId)) throw invalidArgument('Identifiant du brouillon invalide.');
  if (!Array.isArray(v.items) || !v.items.length || v.items.length > 20) throw invalidArgument('Ajoutez de 1 à 20 objets.');
  const ids = new Set<string>();
  let count = 0;
  const items = v.items.map((value): CargoItem => {
    const i = object(value);
    const id = str(i.id, 80);
    if (ids.has(id) || !/^[a-zA-Z0-9_-]+$/.test(id)) throw invalidArgument('Identifiant objet invalide.');
    ids.add(id);
    const quantity = num(i.quantity, 1, 20, true); count += quantity;
    if (i.dimension_unit !== 'cm' && i.dimension_unit !== 'in') throw invalidArgument('Unité de dimension invalide.');
    if (i.weight_unit !== 'kg' && i.weight_unit !== 'lb') throw invalidArgument('Unité de poids invalide.');
    const dim = (value: unknown) => value == null ? null : Math.round(num(value, 0.01, 10000) * (i.dimension_unit === 'in' ? 2.54 : 1) * 1000) / 1000;
    return { id, category: str(i.category, 60), label: str(i.label, 160), quantity,
      length_cm: dim(i.length), width_cm: dim(i.width), height_cm: dim(i.height),
      weight_kg: i.weight == null ? null : Math.round(num(i.weight, 0.01, 100000) * (i.weight_unit === 'lb' ? 0.45359237 : 1) * 1000) / 1000,
      approximate: bool(i.approximate), upright: bool(i.upright),
      photos: Array.isArray(i.photos) && i.photos.length <= 3 ? i.photos.map(p => str(p, 400)) : [] };
  });
  if (count > 20) throw invalidArgument('Au-delà de 20 pièces, une étude de chargement est nécessaire.');
  const equipment = v.equipment;
  if (!Array.isArray(equipment) || equipment.length > 10) throw invalidArgument('Équipement invalide.');
  const requested = v.requested_at == null ? null : str(v.requested_at, 40);
  if (requested && !Number.isFinite(Date.parse(requested))) throw invalidArgument('Date demandée invalide.');
  return { schema_version: 1, draft_id: draftId, items, pickup: access(v.pickup), dropoff: access(v.dropoff),
    handlers: num(v.handlers, 1, 2, true), equipment: [...new Set(equipment.map(e => str(e, 50)))].sort(), requested_at: requested };
}

export function validCapacity(c: Capacity): boolean {
  return !!c && c.verified === true && typeof c.version === 'string' && !!c.version && typeof c.category === 'string' && !!c.category &&
    [c.length_cm, c.width_cm, c.height_cm, c.opening_width_cm, c.opening_height_cm, c.payload_kg, c.handlers].every(n => typeof n === 'number' && Number.isFinite(n) && n > 0) &&
    Number.isInteger(c.handlers) && Number.isFinite(c.rank) && Array.isArray(c.equipment) && Array.isArray(c.services);
}

export function fitsVehicle(load: BookingLoad, c: Capacity): boolean {
  if (!validCapacity(c) || load.handlers > c.handlers || load.equipment.some(e => !c.equipment.includes(e))) return false;
  if ((load.pickup.help || load.dropoff.help) && !c.services.includes('handling')) return false;
  if ((load.pickup.stairs || load.dropoff.stairs) && !c.services.includes('stairs')) return false;
  if (load.items.some(i => i.approximate || i.length_cm === null || i.width_cm === null || i.height_cm === null || i.weight_kg === null)) return false;
  if (load.items.reduce((s, i) => s + i.weight_kg! * i.quantity, 0) > c.payload_kg) return false;
  // Shelf packing establishes an actual non-overlapping plan; total volume
  // alone never accepts a load. No stacking assumptions for fragile cargo.
  const boxes = load.items.flatMap(i => Array.from({ length: i.quantity }, () => i))
    .sort((a, b) => b.length_cm! * b.width_cm! - a.length_cm! * a.width_cm!);
  const shelves: { length: number; usedWidth: number }[] = [];
  let usedLength = 0;
  for (const box of boxes) {
    const [l, w, h] = [box.length_cm!, box.width_cm!, box.height_cm!];
    const orientations = box.upright ? [[l,w,h], [w,l,h]] : [[l,w,h],[w,l,h],[l,h,w],[h,l,w],[w,h,l],[h,w,l]];
    const options = orientations.filter(([x,y,z]) => x <= c.length_cm && y <= c.width_cm && z <= c.height_cm && y <= c.opening_width_cm && z <= c.opening_height_cm);
    let placed = false;
    for (const shelf of shelves) {
      const fit = options.find(([x,y]) => x <= shelf.length && shelf.usedWidth + y <= c.width_cm);
      if (fit) { shelf.usedWidth += fit[1]; placed = true; break; }
    }
    if (!placed) {
      const fit = options.filter(([x]) => usedLength + x <= c.length_cm).sort((a,b) => a[0]-b[0] || a[1]-b[1])[0];
      if (!fit) return false;
      shelves.push({ length: fit[0], usedWidth: fit[1] }); usedLength += fit[0];
    }
  }
  return true;
}
export function recommend(load: BookingLoad, rules: BookingRules) {
  const reasons: ReviewReason[] = [];
  if (load.items.some(i => i.length_cm === null || i.width_cm === null || i.height_cm === null)) reasons.push('dimensions_unknown');
  if (load.items.some(i => i.weight_kg === null)) reasons.push('weight_unknown');
  if (load.items.some(i => i.approximate)) reasons.push('approximate_measurements');
  if (!load.requested_at) reasons.push('requested_time_missing');
  if (!rules?.approved || !rules.version || !Array.isArray(rules.capacities) || !rules.capacities.some(validCapacity) ||
    !(rules.heavy_item_kg > 0) || !(rules.bulky_item_cm > 0)) reasons.push('capacity_unconfigured');
  const compatible = reasons.length ? [] : rules.capacities.filter(c => fitsVehicle(load, c)).sort((a,b) => a.rank-b.rank || a.category.localeCompare(b.category));
  if (!reasons.length && !compatible.length) reasons.push('no_verified_fit');
  const selected = compatible[0];
  return { status: selected ? 'ready' as const : 'review_required' as const, reasons,
    compatible_categories: compatible.map(c => c.category),
    snapshot: selected ? { load, rules_version: rules.version, category: selected.category, capacity_version: selected.version } as BookingSnapshot : null };
}
export function bookingHandling(load: BookingLoad, rules: BookingRules) {
  return { needsLoading: load.pickup.help, needsUnloading: load.dropoff.help, isHeavyItem: load.items.some(i => (i.weight_kg ?? 0) >= rules.heavy_item_kg),
    isBulkyItem: load.items.some(i => Math.max(i.length_cm ?? 0, i.width_cm ?? 0, i.height_cm ?? 0) >= rules.bulky_item_cm),
    needsStairs: load.pickup.stairs || load.dropoff.stairs,
    noElevator: (load.pickup.stairs && !load.pickup.elevator) || (load.dropoff.stairs && !load.dropoff.elevator),
    needsSecondHandler: load.handlers === 2, needsSpecialEquipment: load.equipment.length > 0 };
}
