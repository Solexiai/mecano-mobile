// Owner decision 2026-10-19: compute the official price BEFORE assigning a driver.
// This context is NOT a booking/capacity certificate. Historical snapshots are unchanged.
import { HttpsError } from 'firebase-functions/v2/https';
import { BookingLoad, normalizeLoad } from './booking';
import { validateBookingPhotos } from './bookingPhotoValidation';
import { invalidArgument } from './errors';
import { classifyPhotoIntake } from './photoIntake';
import { getServiceZonesConfig, isWithinServiceZones } from './serviceZones';
import { PricingVersionDoc } from './types';
import { normalizeVehicleCategory } from './vehicleCategory';

export interface PreAssignmentQuote {
  version: 1;
  load: BookingLoad;
  vehicle_assignment: 'pending';
  tariff_categories: string[];
  /** Calculation basis only: never displayed as a recommended or verified vehicle. */
  tariff_rule_category: string;
}
const PILOT_CATEGORIES = ['pickup_truck', 'cargo_van', 'cube_truck'];
function refuse(reason: string): never {
  throw new HttpsError('failed-precondition', 'Les informations tarifaires de la demande doivent être précisées.', { quote_reason: reason });
}

/** Security/input validation only. No booking_capacity, driver, reservation or payment read. */
export async function validatePriceBeforeAssignment(raw: unknown, stops: unknown, uid: string): Promise<BookingLoad> {
  const load = normalizeLoad(raw);
  for (const item of load.items) {
    if (item.photos.some(p => !p.startsWith(`booking_photos/${uid}/${load.draft_id}/`) || p.includes('..'))) throw invalidArgument('Photo inaccessible.');
    if (load.intake_mode === 'photo_assisted') {
      if (!item.photos.length) refuse('photo_required');
      if (item.identification_confirmed !== true) refuse('object_confirmation_required');
      const classification = classifyPhotoIntake({ category: item.category, customerConfirmed: true, specialItem: item.special_handling !== false });
      if (classification.status === 'confirm_category') refuse('object_category_required');
      if (classification.status === 'special' &&
        (![item.length_cm,item.width_cm,item.height_cm].every(n => n !== null && Number.isFinite(n) && n > 0) || !item.handling_notes?.trim())) refuse('special_details_required');
    }
  }
  await validateBookingPhotos(load, uid);
  if (!Array.isArray(stops) || stops.length !== 2) throw invalidArgument('Une adresse de ramassage et une adresse de livraison sont requises.');
  for (const stop of stops) {
    const a = stop?.address;
    if (!a || !Number.isFinite(a.lat) || !Number.isFinite(a.lng) || Math.abs(a.lat) > 90 || Math.abs(a.lng) > 180 ||
      typeof a.line1 !== 'string' || !a.line1.trim() || a.line1.length > 300 ||
      typeof a.city !== 'string' || !a.city.trim() || typeof a.postal_code !== 'string' || !a.postal_code.trim()) throw invalidArgument('Sélectionnez deux adresses complètes.');
  }
  const zones = await getServiceZonesConfig({ fallbackToLaunchZone: true });
  if (!zones.enabled || !zones.zones.length) refuse('service_area_unconfigured');
  if (stops.some(s => !isWithinServiceZones(s.address.lat, s.address.lng, zones))) refuse('outside_service_area');
  if (load.timing_mode !== 'immediate' && !load.requested_at) refuse('requested_time_missing');
  if (load.requested_at && Date.parse(load.requested_at) <= Date.now()) refuse('requested_time_past');
  return load;
}

/** Use existing rates only. A uniform tariff has no dependency on vehicle availability.
 * If the active tariff stops being uniform, fail explicitly rather than guess a price.
 */
export function preparePriceBeforeAssignment(load: BookingLoad, config: PricingVersionDoc) {
  const rules = PILOT_CATEGORIES.map(category => {
    const matches = config.vehicle_rules.filter(r => normalizeVehicleCategory(r.category) === category);
    if (matches.length !== 1) refuse('pricing_category_required');
    return matches[0];
  });
  const fields = ['base_fare','rate_per_km','rate_per_minute','minimum_charge'] as const;
  if (rules.some(rule => fields.some(key => !Number.isFinite(rule[key]) || rule[key] < 0 || rule[key] !== rules[0][key]))) refuse('pricing_category_required');
  // A zero fee needs no physical threshold. Never silently remove a nonzero fee.
  if (config.handling_fees.bulky_item_fee !== 0) refuse('pricing_handling_required');
  const context: PreAssignmentQuote = {
    version: 1, load, vehicle_assignment: 'pending', tariff_categories: [...PILOT_CATEGORIES], tariff_rule_category: rules[0].category,
  };
  return { context, vehicleCategory: rules[0].category, handling: {
    needsLoading: load.pickup.help, needsUnloading: load.dropoff.help,
    isHeavyItem: false, isBulkyItem: false,
    needsStairs: load.pickup.stairs || load.dropoff.stairs,
    noElevator: (load.pickup.stairs && !load.pickup.elevator) || (load.dropoff.stairs && !load.dropoff.elevator),
    needsSecondHandler: load.handlers === 2, needsSpecialEquipment: load.equipment.length > 0,
  } };
}
