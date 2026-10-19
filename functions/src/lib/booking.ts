/** Booking contract. Capacities and handling thresholds MUST come from approved
 * configuration. Conservative fit: no stacking, no diagonal loading, fixed
 * upright orientation when requested. A refusal can require human review. */
import { invalidArgument, failedPrecondition } from './errors';
import { classifyPhotoIntake } from './photoIntake';
import { normalizeVehicleCategory } from './vehicleCategory';

export interface CargoItem {
  id: string; category: string; label: string; quantity: number;
  length_cm: number | null; width_cm: number | null; height_cm: number | null;
  weight_kg: number | null; approximate: boolean; upright: boolean; photos: string[];
  identification_confirmed?: boolean; special_handling?: boolean;
  handling_notes?: string;
}
export interface Access {
  floor: number; stairs: boolean; elevator: boolean; help: boolean;
  details_version?: 1; confirmed_fields?: string[];
  onsite_help?: 'yes' | 'no' | 'unknown' | null;
  inside?: boolean; customer_handles_inside?: boolean; notes?: string;
}
export interface BookingLoad {
  schema_version: 1; draft_id: string; items: CargoItem[]; pickup: Access; dropoff: Access;
  handlers: number; equipment: string[]; requested_at: string | null;
  /** Omitted on legacy scheduled snapshots to preserve their integrity contract. */
  timing_mode?: 'immediate' | 'scheduled';
  /** Explicit opt-in; omitted from legacy normalized loads. */
  intake_mode?: 'photo_assisted';
}
export interface Capacity {
  category: string; rank: number; version: string; verified: boolean;
  length_cm: number; width_cm: number; height_cm: number;
  opening_width_cm: number; opening_height_cm: number; payload_kg: number;
  handlers: number; equipment: string[]; services: string[];
}
export interface BookingRules {
  approved: boolean; version: string; capacities: Capacity[];
  /** Legacy fee threshold retained for document compatibility; no longer required. */
  heavy_item_kg?: number; bulky_item_cm: number;
  /** Server-owned rollout and object-to-vehicle policy. No default mapping. */
  photo_intake?: { enabled: boolean; version: string; category_vehicle_categories: Record<string, string[]> };
}
export interface BookingSnapshot {
  load: BookingLoad; rules_version: string; category: string; capacity_version: string;
  vehicle_assessment?: 'driver_photo_review';
  photo_policy_version?: string;
}
export type ReviewReason = 'dimensions_unknown' | 'weight_unknown' | 'approximate_measurements' |
  'capacity_unconfigured' | 'no_verified_fit' | 'requested_time_missing' |
  'photo_policy_unconfigured' | 'photo_category_unconfigured' | 'photo_required' |
  'object_confirmation_required' | 'special_details_required' | 'no_eligible_photo_vehicle';

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
  const result: Access = { floor: num(a.floor, -10, 200, true), stairs: bool(a.stairs), elevator: bool(a.elevator), help: bool(a.help) };
  // Omitted on historical contracts: never rewrite a locked legacy snapshot.
  if (a.details_version === undefined) return result;
  if (a.details_version !== 1) throw invalidArgument('Version des réponses invalide.');
  if (!Array.isArray(a.confirmed_fields) ||
      !['floor','stairs','elevator'].every(k => (a.confirmed_fields as unknown[]).includes(k))) {
    throw invalidArgument('Confirmez le niveau, les marches et l’ascenseur.');
  }
  const onsite = a.onsite_help;
  if ((onsite != null && !['yes','no','unknown'].includes(onsite as string)) ||
      (result.help && onsite == null)) throw invalidArgument('Précisez l’aide disponible sur place.');
  const inside = bool(a.inside);
  const customer = a.customer_handles_inside == null ? undefined : bool(a.customer_handles_inside);
  if (!result.help && inside && customer !== true) {
    throw invalidArgument('Précisez qui assure le déplacement entre l’intérieur et le véhicule.');
  }
  return {...result, details_version: 1, confirmed_fields: ['floor','stairs','elevator'],
    onsite_help: onsite == null ? null : onsite as 'yes' | 'no' | 'unknown',
    inside, ...(customer === undefined ? {} : {customer_handles_inside: customer}),
    ...(a.notes == null ? {} : {notes: str(a.notes,1200,false)})};
}
export function normalizeLoad(raw: unknown): BookingLoad {
  const v = object(raw);
  if (v.intake_mode !== undefined && v.intake_mode !== 'photo_assisted') throw invalidArgument('Mode de description invalide.');
  const photoIntake = v.intake_mode === 'photo_assisted';
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
      ...(photoIntake ? { identification_confirmed: bool(i.identification_confirmed), special_handling: bool(i.special_handling),
        ...(i.handling_notes == null ? {} : { handling_notes: str(i.handling_notes, 1200, false) }) } : {}),
      photos: Array.isArray(i.photos) && i.photos.length <= 3 ? i.photos.map(p => str(p, 400)) : [] };
  });
  if (count > 20) throw invalidArgument('Au-delà de 20 pièces, une étude de chargement est nécessaire.');
  const equipment = v.equipment;
  if (!Array.isArray(equipment) || equipment.length > 10) throw invalidArgument('Équipement invalide.');
  const requested = v.requested_at == null ? null : str(v.requested_at, 40);
  if (requested && !Number.isFinite(Date.parse(requested))) throw invalidArgument('Date demandée invalide.');
  const mode = v.timing_mode;
  if (mode !== undefined && mode !== 'immediate' && mode !== 'scheduled') {
    throw invalidArgument('Choisissez une demande dès maintenant ou programmée.');
  }
  if (mode === 'immediate' && requested !== null) {
    throw invalidArgument('Une demande dès maintenant ne doit pas contenir de date programmée.');
  }
  return { schema_version: 1, draft_id: draftId, items, pickup: access(v.pickup), dropoff: access(v.dropoff),
    handlers: num(v.handlers, 1, 2, true), equipment: [...new Set(equipment.map(e => str(e, 50)))].sort(), requested_at: requested,
    ...(mode === undefined ? {} : { timing_mode: mode }),
    ...(photoIntake ? { intake_mode: 'photo_assisted' as const } : {}) };
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
  return fitsKnownGeometry(load.items, c);
}
function fitsKnownGeometry(items: CargoItem[], c: Capacity): boolean {
  // Shelf packing establishes an actual non-overlapping plan; total volume
  // alone never accepts a load. No stacking assumptions for fragile cargo.
  const boxes = items.flatMap(i => Array.from({ length: i.quantity }, () => i))
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
  if (load.intake_mode === 'photo_assisted') return recommendPhoto(load, rules);
  const reasons: ReviewReason[] = [];
  if (load.items.some(i => i.length_cm === null || i.width_cm === null || i.height_cm === null)) reasons.push('dimensions_unknown');
  if (load.items.some(i => i.weight_kg === null)) reasons.push('weight_unknown');
  if (load.items.some(i => i.approximate)) reasons.push('approximate_measurements');
  if (load.timing_mode !== 'immediate' && !load.requested_at) reasons.push('requested_time_missing');
  if (!rules?.approved || !rules.version || !Array.isArray(rules.capacities) || !rules.capacities.some(validCapacity) ||
    !(rules.bulky_item_cm > 0)) reasons.push('capacity_unconfigured');
  const compatible = reasons.length ? [] : rules.capacities.filter(c => fitsVehicle(load, c)).sort((a,b) => a.rank-b.rank || a.category.localeCompare(b.category));
  if (!reasons.length && !compatible.length) reasons.push('no_verified_fit');
  const selected = compatible[0];
  return { status: selected ? 'ready' as const : 'review_required' as const, reasons,
    compatible_categories: compatible.map(c => c.category),
    snapshot: selected ? { load, rules_version: rules.version, category: selected.category, capacity_version: selected.version } as BookingSnapshot : null };
}
export function bookingHandling(load: BookingLoad, rules: BookingRules) {
  return { needsLoading: load.pickup.help, needsUnloading: load.dropoff.help, isHeavyItem: false,
    isBulkyItem: load.items.some(i => Math.max(i.length_cm ?? 0, i.width_cm ?? 0, i.height_cm ?? 0) >= rules.bulky_item_cm),
    needsStairs: load.pickup.stairs || load.dropoff.stairs,
    noElevator: (load.pickup.stairs && !load.pickup.elevator) || (load.dropoff.stairs && !load.dropoff.elevator),
    needsSecondHandler: load.handlers === 2, needsSpecialEquipment: load.equipment.length > 0 };
}

/** Eligibility to inspect a photo offer is NOT a verified vehicle fit. */
export function eligibleForPhotoReview(load: BookingLoad, c: Capacity): boolean {
  if (load.intake_mode !== 'photo_assisted' || !validCapacity(c) ||
    !['pickup_truck', 'cargo_van', 'cube_truck'].includes(normalizeVehicleCategory(c.category))) return false;
  if (!load.items.length || load.items.some(i => !isCompletePhotoItem(i))) return false;
  if (load.handlers > c.handlers || load.equipment.some(e => !c.equipment.includes(e))) return false;
  if ((load.pickup.help || load.dropoff.help) && !c.services.includes('handling')) return false;
  if ((load.pickup.stairs || load.dropoff.stairs) && !c.services.includes('stairs')) return false;
  // Known values remain constraints. Null does not become a fabricated estimate.
  if (load.items.reduce((sum, i) => sum + (i.weight_kg ?? 0) * i.quantity, 0) > c.payload_kg) return false;
  for (const item of load.items) {
    const [l,w,h] = [item.length_cm,item.width_cm,item.height_cm];
    const orientations = item.upright ? [[l,w,h],[w,l,h]] : [[l,w,h],[w,l,h],[l,h,w],[h,l,w],[w,h,l],[h,w,l]];
    const within = (value: number | null, limit: number) => value === null ||
      (Number.isFinite(value) && value > 0 && value <= limit);
    if (!orientations.some(([x,y,z]) => within(x,c.length_cm) && within(y,c.width_cm) &&
      within(z,c.height_cm) && within(y,c.opening_width_cm) && within(z,c.opening_height_cm))) return false;
    if (item.weight_kg !== null && (!Number.isFinite(item.weight_kg) || item.weight_kg <= 0)) return false;
  }
  const measured = load.items.filter(i => i.length_cm !== null && i.width_cm !== null && i.height_cm !== null);
  return fitsKnownGeometry(measured, c);
}
function isCompletePhotoItem(item: CargoItem): boolean {
  if (!item.photos.length || item.identification_confirmed !== true) return false;
  const assessment = classifyPhotoIntake({ category: item.category,
    customerConfirmed: true, specialItem: item.special_handling !== false });
  if (assessment.status === 'standard') return true;
  // Customer-provided dimensions constrain eligibility; they are never AI measurements.
  // A special item also needs explicit handling details for the driver's decision.
  return assessment.status === 'special' &&
    [item.length_cm, item.width_cm, item.height_cm].every(n => n !== null && Number.isFinite(n) && n > 0) &&
    typeof item.handling_notes === 'string' && item.handling_notes.trim().length > 0;
}
function recommendPhoto(load: BookingLoad, rules: BookingRules) {
  const reasons: ReviewReason[] = [];
  const policy = rules?.photo_intake;
  if (!policy || policy.enabled !== true || typeof policy.version !== 'string' || !policy.version.trim() ||
    !policy.category_vehicle_categories || typeof policy.category_vehicle_categories !== 'object') reasons.push('photo_policy_unconfigured');
  if (!rules?.approved || !rules.version || !Array.isArray(rules.capacities) || !rules.capacities.some(validCapacity) ||
    !(rules.bulky_item_cm > 0)) reasons.push('capacity_unconfigured');
  if (load.timing_mode !== 'immediate' && !load.requested_at) reasons.push('requested_time_missing');
  for (const item of load.items) {
    if (item.identification_confirmed !== true) reasons.push('object_confirmation_required');
    if (!item.photos.length) reasons.push('photo_required');
    if (item.identification_confirmed === true && item.photos.length && !isCompletePhotoItem(item)) reasons.push('special_details_required');
    const mapped = policy?.category_vehicle_categories?.[item.category];
    if (!Array.isArray(mapped) || !mapped.length || mapped.some(x => typeof x !== 'string' ||
      !['pickup_truck','cargo_van','cube_truck'].includes(normalizeVehicleCategory(x)))) reasons.push('photo_category_unconfigured');
  }
  const compatible = reasons.length ? [] : rules.capacities.filter(c => eligibleForPhotoReview(load,c) &&
    load.items.every(i => policy!.category_vehicle_categories[i.category].some(x => normalizeVehicleCategory(x) === normalizeVehicleCategory(c.category))))
    .sort((a,b) => a.rank-b.rank || a.category.localeCompare(b.category));
  if (!reasons.length && !compatible.length) reasons.push('no_eligible_photo_vehicle');
  const selected = compatible[0];
  return { status: selected ? 'ready' as const : 'review_required' as const, reasons: [...new Set(reasons)],
    compatible_categories: compatible.map(c => c.category),
    snapshot: selected ? { load, rules_version: rules.version, category: selected.category, capacity_version: selected.version,
      vehicle_assessment: 'driver_photo_review', photo_policy_version: policy!.version } as BookingSnapshot : null };
}
/** Shared by dispatch and assignment; legacy snapshots retain strict measured fit. */
export function eligibleForBookingSnapshot(snapshot: BookingSnapshot, capacity: Capacity): boolean {
  if (normalizeVehicleCategory(snapshot.category) !== normalizeVehicleCategory(capacity.category)) return false;
  if (snapshot.vehicle_assessment === undefined) return snapshot.load.intake_mode === undefined && fitsVehicle(snapshot.load,capacity);
  if (snapshot.vehicle_assessment !== 'driver_photo_review' || typeof snapshot.photo_policy_version !== 'string' || !snapshot.photo_policy_version.trim()) return false;
  return eligibleForPhotoReview(snapshot.load,capacity);
}

/** Keep the quote category selected by the server for photo-assisted loads. */
export function selectBookingVehicle(snapshot: BookingSnapshot, rules: BookingRules,
  compatibleCategories: string[], requestedCategory?: string): BookingSnapshot {
  if (!requestedCategory) return snapshot;
  if (snapshot.vehicle_assessment === 'driver_photo_review') {
    if (requestedCategory !== snapshot.category) throw failedPrecondition('Le véhicule est sélectionné par Movi-K pour cette demande.');
    return snapshot;
  }
  const alternative = rules.capacities.find(c => c.category === requestedCategory && compatibleCategories.includes(c.category));
  if (!alternative) throw failedPrecondition('Cette catégorie ne convient pas au chargement.');
  return {...snapshot,category:alternative.category,capacity_version:alternative.version};
}
