import { db, admin } from './admin';
import { failedPrecondition, invalidArgument } from './errors';
import { AgendaInterval, normalizeAgendaInterval, normalizeDriverAgenda, intervalIsAvailable } from './driverAgenda';
import { ServiceZonesConfig, isWithinServiceZones } from './serviceZones';
import { MAX_BOOKING_DAYS_AHEAD } from './bookingHours';
/** PAY-08 : jamais au-delà de la fenêtre d'autorisation Stripe, quelle que soit la config. */
export const MAX_SCHEDULING_ADVANCE_MINUTES = MAX_BOOKING_DAYS_AHEAD * 24 * 60;
export interface SchedulingPolicy {
    enabled: true;
    approved: true;
    duration_confirmation_approved: true;
    version: string;
    max_advance_minutes: number;
}
export async function readSchedulingPolicy(tx?: FirebaseFirestore.Transaction): Promise<SchedulingPolicy | null> {
    const ref = db.doc('system_config/driver_scheduling');
    const snap = tx ? await tx.get(ref) : await ref.get(), p = snap.data();
    if (!p || p.enabled !== true) return null;
    if (p.approved !== true || p.duration_confirmation_approved !== true ||
        typeof p.version !== 'string' || !p.version || !Number.isSafeInteger(p.max_advance_minutes) || p.max_advance_minutes <= 0)
        throw failedPrecondition('La configuration de planification active est incomplète ou non approuvée.');
    return { ...(p as SchedulingPolicy), max_advance_minutes: Math.min(p.max_advance_minutes, MAX_SCHEDULING_ADVANCE_MINUTES) };
}
export interface ReservedSlot extends AgendaInterval {
    pickup_at: string;
    policy_version: string;
}
export function missionRequestedAt(m: Record<string, any>): string | null {
    return m.booking_snapshot?.load?.requested_at ?? m.pricing_snapshot?.pre_assignment?.load?.requested_at ?? m.requested_at ?? null;
}
export function confirmedSlot(raw: unknown, mission: Record<string, any>, policy: SchedulingPolicy, now = Date.now()): ReservedSlot {
    const slot = normalizeAgendaInterval(raw), data = raw as Record<string, unknown>;
    if (data.full_duration_confirmed !== true)
        throw invalidArgument('Confirmez explicitement la durée complète de la mission.');
    if (data.policy_version !== policy.version)
        throw failedPrecondition('Les conditions de planification ont changé.');
    const pickup = normalizeAgendaInterval({ start: data.pickup_at, end: slot.end }).start;
    const requested = missionRequestedAt(mission);
    if (requested && pickup !== new Date(requested).toISOString())
        throw failedPrecondition('L’heure demandée a changé.');
    const start = Date.parse(slot.start), end = Date.parse(slot.end), pickupMs = Date.parse(pickup);
    if (start > pickupMs || pickupMs < now - 60000 || end <= now || pickupMs - now > policy.max_advance_minutes * 60000)
        throw failedPrecondition('Créneau hors des limites autorisées.');
    const route = mission.estimated_duration_minutes ?? mission.pricing_snapshot?.estimated_duration_minutes;
    if (typeof route !== 'number' || !Number.isFinite(route) || route < 0)
        throw failedPrecondition('Durée officielle du trajet manquante.');
    if (end - pickupMs < route * 60000)
        throw invalidArgument('Le créneau doit inclure au moins le trajet officiel et la manutention confirmée.');
    return { ...slot, pickup_at: pickup, policy_version: policy.version };
}
export function overlap(a: AgendaInterval, b: AgendaInterval): boolean {
    return Date.parse(a.start) < Date.parse(b.end) && Date.parse(b.start) < Date.parse(a.end);
}
export const terminalScheduleStatuses = new Set(['completed', 'cancelled', 'payment_failed', 'refunded', 'disputed']);
export function reservationStillActive(m: Record<string, any> | undefined, driverId: string): boolean {
    return !!m && m.driver_id === driverId && !terminalScheduleStatuses.has(m.status);
}
export function locationInDriverZone(driver: Record<string, any>, location: Record<string, any> | undefined, pickup: Record<string, any>, zones: ServiceZonesConfig, now = Date.now()): boolean {
    const valid = (lat: unknown, lng: unknown) => typeof lat === 'number' && Number.isFinite(lat) && Math.abs(lat) <= 90 && typeof lng === 'number' && Number.isFinite(lng) && Math.abs(lng) <= 180;
    if (!zones?.enabled || !Array.isArray(zones.zones) || !zones.zones.length || !pickup || !valid(pickup.lat, pickup.lng) || !isWithinServiceZones(pickup.lat, pickup.lng, zones))
        return false;
    // Dispatch distance only. Never replaces the route used in the official quote.
    const radius = driver.service_radius_km;
    if (typeof radius !== 'number' || !Number.isFinite(radius) || radius <= 0)
        return false;
    const fresh = location?.updated_at?.toMillis?.();
    let lat: number, lng: number;
    if (typeof fresh === 'number' && fresh <= now && now - fresh <= 5 * 60000 && valid(location?.latitude, location?.longitude)) {
        lat = location!.latitude;
        lng = location!.longitude;
    }
    else if (driver.base_location_verified === true && valid(driver.base_lat, driver.base_lng)) {
        lat = driver.base_lat;
        lng = driver.base_lng;
    }
    else
        return false;
    // A declared base zone remains a constraint even when a live location exists.
    if (driver.base_location_verified !== true || !valid(driver.base_lat, driver.base_lng) || driver.verified_base_lat !== driver.base_lat || driver.verified_base_lng !== driver.base_lng)
        return false;
    const distance = (a: number, b: number, c: number, d: number) => {
        const r = Math.PI / 180, x = Math.sin((c - a) * r / 2) ** 2 + Math.cos(a * r) * Math.cos(c * r) * Math.sin((d - b) * r / 2) ** 2;
        return 6371.0088 * 2 * Math.asin(Math.sqrt(Math.min(1, Math.max(0, x))));
    };
    return distance(driver.base_lat, driver.base_lng, pickup.lat, pickup.lng) <= radius && distance(lat, lng, pickup.lat, pickup.lng) <= radius;
}
/** All reads occur before the caller writes. The agenda root is the mutex for
 * concurrent bookings, availability edits, external busy refreshes and moves. */
export async function prepareReservation(tx: FirebaseFirestore.Transaction, driverId: string, missionId: string, slot: ReservedSlot, now = Date.now()) {
    const root = db.doc('driver_agendas/' + driverId);
    const agendaDoc = await tx.get(root);
    if (!agendaDoc.exists)
        throw failedPrecondition('Déclarez vos disponibilités avant d’accepter.');
    const agenda = normalizeDriverAgenda(agendaDoc.data());
    const before = agenda.recurrence?.pause_before_minutes ?? 0, after = agenda.recurrence?.pause_after_minutes ?? 0;
    const occupied = { start: new Date(Date.parse(slot.start) - before * 60000).toISOString(), end: new Date(Date.parse(slot.end) + after * 60000).toISOString() };
    if (!intervalIsAvailable(agenda, occupied))
        throw failedPrecondition('Ce créneau ne correspond plus à vos disponibilités.');
    const reservations = await tx.get(root.collection('reservations').where('active', '==', true));
    for (const doc of reservations.docs) {
        if (doc.id === missionId)
            continue;
        const r = doc.data();
        if (overlap(occupied, r as AgendaInterval)) {
            const m = await tx.get(db.doc('delivery_requests/' + doc.id));
            if (reservationStillActive(m.data(), driverId))
                throw failedPrecondition('Une autre mission occupe déjà ce créneau.');
        }
    }
    // Legacy active missions may predate reservation records. Never infer their end.
    const live = (await tx.get(db.doc('driver_locations/' + driverId))).data();
    if (typeof live?.active_delivery_id === 'string' && live.active_delivery_id !== missionId) {
        const active = (await tx.get(db.doc('delivery_requests/' + live.active_delivery_id))).data();
        if (reservationStillActive(active, driverId) && (!active?.scheduling || overlap(occupied, active.scheduling)))
            throw failedPrecondition('Votre mission active doit être terminée ou son créneau clarifié avant cette réservation.');
    }
    const external = await tx.get(db.doc('driver_calendar_busy/' + driverId));
    const e = external.data();
    if (e?.required === true) {
        if (e.status !== 'ready' || !Array.isArray(e.busy) || !Number.isFinite(Date.parse(e.from)) || !Number.isFinite(Date.parse(e.to)) || !e.checked_at?.toMillis || e.checked_at.toMillis() > now || now - e.checked_at.toMillis() > 60000 ||
            Date.parse(e.from) > Date.parse(occupied.start) || Date.parse(e.to) < Date.parse(occupied.end)) {
            throw failedPrecondition('Actualisez vos calendriers connectés avant d’accepter.');
        }
        if ((e.busy ?? []).some((b: AgendaInterval) => overlap(occupied, b)))
            throw failedPrecondition('Un calendrier connecté bloque ce créneau.');
    }
    return {
        write() {
            tx.set(root, { lock_version: admin.firestore.FieldValue.increment(1) }, { merge: true });
            tx.set(root.collection('reservations').doc(missionId), { ...slot, ...occupied,
                mission_start: slot.start, mission_end: slot.end, driver_id: driverId, active: true, updated_at: admin.firestore.FieldValue.serverTimestamp() });
            tx.set(db.doc('calendar_sync_jobs/' + missionId), { mission_id: missionId, driver_id: driverId,
                state: 'pending', generation: admin.firestore.FieldValue.increment(1), attempts: 0, next_attempt_at: admin.firestore.Timestamp.now() }, { merge: true });
        },
        occupied,
    };
}

/** A rollback must not let the legacy flow ignore already reserved future work. */
export async function assertNoScheduledCommitments(tx:FirebaseFirestore.Transaction,uid:string):Promise<void>{
 const root=db.doc('driver_agendas/'+uid);
 const agenda=await tx.get(root);if(!agenda.exists)return;
 const reservations=await tx.get(root.collection('reservations').where('active','==',true));
 for(const r of reservations.docs){
  if(Date.parse(r.data().end)<=Date.now())continue;
  const mission=(await tx.get(db.doc('delivery_requests/'+r.id))).data();
  if(reservationStillActive(mission,uid))throw failedPrecondition('Des missions programmées existent déjà. La planification doit être rétablie avant une nouvelle attribution.');
 }
}
