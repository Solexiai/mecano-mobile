import { parseBookingPolicy } from './bookingContract';
import { db } from './admin';
import { validateBookingPhotos } from './bookingPhotoValidation';
import { bookingHoursReason, getSavedBookingHours } from './bookingHours';
import { BookingLoad, BookingRules, BookingSnapshot, Capacity, eligibleForBookingSnapshot, isDriverJudgement, normalizeLoad, recommend, requestedTimeReason } from './booking';
import { failedPrecondition, invalidArgument } from './errors';
import { getServiceZonesConfig, isWithinServiceZones } from './serviceZones';
import { normalizeVehicleCategory } from './vehicleCategory';

export async function getBookingRules(): Promise<BookingRules> {
  return (await db.doc('system_config/booking_capacity').get()).data() as BookingRules;
}
export async function reviewBooking(raw: unknown, stops: unknown, uid: string) {
  const load = normalizeLoad(raw);
  if (load.items.some(i => i.photos.some(p => !p.startsWith(`booking_photos/${uid}/${load.draft_id}/`) || p.includes('..')))) throw invalidArgument('Photo inaccessible.');
  await validateBookingPhotos(load, uid);
  const rules = await getBookingRules();
  const review = recommend(load, rules);
  if (!Array.isArray(stops) || stops.length !== 2) throw invalidArgument('Une adresse de ramassage et une adresse de livraison sont requises.');
  for (const stop of stops) {
    const a = stop?.address;
    if (!a || !Number.isFinite(a.lat) || !Number.isFinite(a.lng) || Math.abs(a.lat)>90 || Math.abs(a.lng)>180 ||
      typeof a.line1 !== 'string' || !a.line1.trim() || a.line1.length>300 || typeof a.city !== 'string' || !a.city.trim() ||
      typeof a.postal_code !== 'string' || !a.postal_code.trim()) throw invalidArgument('Sélectionnez deux adresses complètes, avec ville et code postal.');
  }
  const zones = await getServiceZonesConfig({ fallbackToLaunchZone: true });
  const zoneReason = !zones.enabled || !zones.zones.length ? 'service_area_unconfigured' :
    stops.some(s => !isWithinServiceZones(s.address.lat,s.address.lng,zones)) ? 'outside_service_area' : null;
  const savedHours = await getSavedBookingHours();
  const timeReason = requestedTimeReason(load.requested_at) ??
    (savedHours ? bookingHoursReason(load.requested_at, savedHours) : null);
  const reasons = [...review.reasons, ...(zoneReason ? [zoneReason] : []), ...(timeReason ? [timeReason] : [])];
  return { review: { ...review, status: reasons.length ? 'review_required' : 'ready', reasons, snapshot: reasons.length ? null : review.snapshot }, rules };
}

export { BookingPolicy } from './bookingContract';
export async function getBookingPolicy() {
  return parseBookingPolicy((await db.doc('system_config/booking_policy').get()).data());
}

/** Reads vehicle documents INSIDE assignment transactions. Verified capacity is
 * writable only by administrators, never by the driver claiming dimensions. */
export async function findCompatibleVehicle(driverId: string, snapshot: BookingSnapshot,
  tx?: FirebaseFirestore.Transaction, selectedId?: string): Promise<{ vehicle_id: string; capacity_version: string } | null> {
  const q = db.collection('driver_vehicles').where('driver_id','==',driverId).limit(20);
  const vehicles = tx ? await tx.get(q) : await q.get();
  if (isDriverJudgement(snapshot)) {
    // No measured capacity: any vehicle of the driver in an eligible pilot
    // category. The driver confirms the fit (acceptDelivery: fitConfirmed).
    const eligible = snapshot.eligible_categories.map(normalizeVehicleCategory);
    for (const doc of vehicles.docs) {
      if (selectedId && doc.id !== selectedId) continue;
      const category = doc.data().category;
      if (typeof category === 'string' && eligible.includes(normalizeVehicleCategory(category))) {
        return { vehicle_id: doc.id, capacity_version: 'driver_judgement' };
      }
    }
    return null;
  }
  for (const doc of vehicles.docs) {
    if (selectedId && doc.id !== selectedId) continue;
    const v = doc.data(); const capacity = v.verified_capacity as Capacity;
    if (v.is_verified !== true || !capacity || normalizeVehicleCategory(capacity.category) !== normalizeVehicleCategory(snapshot.category)) continue;
    if (!v.capacity_valid_until || typeof v.capacity_valid_until.toMillis !== 'function' || v.capacity_valid_until.toMillis() <= Date.now()) continue;
    if (eligibleForBookingSnapshot(snapshot, capacity)) return { vehicle_id: doc.id, capacity_version: capacity.version };
  }
  return null;
}
export async function requireCompatibleVehicle(driverId: string, snapshot: BookingSnapshot | undefined,
  tx: FirebaseFirestore.Transaction, selectedId?: string) {
  if (!snapshot) return {};
  const match = await findCompatibleVehicle(driverId, snapshot, tx, selectedId);
  if (!match) throw failedPrecondition('Aucun véhicule réel vérifié ne convient au chargement et aux services demandés.');
  return { assigned_vehicle_id: match.vehicle_id, assigned_capacity_version: match.capacity_version };
}
export interface BookingContacts { pickup_name: string; pickup_phone: string; dropoff_name: string; dropoff_phone: string; instructions: string }
export function normalizeContacts(value: unknown): BookingContacts {
  const v = value as BookingContacts;
  if (!v || [v.pickup_name,v.dropoff_name].some(s => typeof s !== 'string' || !s.trim() || s.length>120) ||
    [v.pickup_phone,v.dropoff_phone].some(s => typeof s !== 'string' || !/^\+?[0-9 ()-]{8,25}$/.test(s) || s.replace(/\D/g,'').length<8) ||
    typeof v.instructions !== 'string' || v.instructions.length>1200) throw invalidArgument('Précisez les noms et téléphones des deux contacts.');
  return { pickup_name: v.pickup_name.trim(), pickup_phone: v.pickup_phone.trim(), dropoff_name: v.dropoff_name.trim(), dropoff_phone: v.dropoff_phone.trim(), instructions: v.instructions.trim() };
}
// Keep imported contract reachable for generated declarations.
export type { BookingLoad };
