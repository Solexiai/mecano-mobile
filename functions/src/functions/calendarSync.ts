import { onSchedule } from 'firebase-functions/v2/scheduler';
import { onCall } from 'firebase-functions/v2/https';
import { randomBytes } from 'crypto';
import { db, admin } from '../lib/admin';
import { requireSignedIn, requireAnyRole } from '../lib/auth';
import { PlatformRoles } from '../lib/types';
import { calendarSecrets, CalendarProvider, writeEvent, CalendarApiError, eventKey } from '../lib/calendarProviders';
import { withConnection, ensureWriteCalendar, refreshBusy } from '../lib/calendarConnections';
import { readSchedulingPolicy } from '../lib/driverScheduling';
import { invalidArgument } from '../lib/errors';
export async function syncMissionCalendar(missionId: string): Promise<void> {
    const ref = db.doc('calendar_sync_jobs/' + missionId), lease = randomBytes(16).toString('hex');
    const job = await db.runTransaction(async (tx) => {
        const d = (await tx.get(ref)).data();
        if (!d || (d.lease_until?.toMillis() ?? 0) > Date.now() || (d.next_attempt_at?.toMillis() ?? 0) > Date.now())
            return null;
        tx.update(ref, { lease, lease_until: admin.firestore.Timestamp.fromMillis(Date.now() + 600000) });
        return d;
    });
    if (!job)
        return;
    try {
        const m = (await db.doc('delivery_requests/' + missionId).get()).data();
        if (m?.assignment_mode === 'internal_test') {
            await db.runTransaction(async (tx) => { const current = (await tx.get(ref)).data(); if (current?.lease === lease)
                tx.update(ref, { state: 'suppressed_test', lease: admin.firestore.FieldValue.delete(), lease_until: admin.firestore.FieldValue.delete() }); });
            return;
        }
        if (m?.scheduling && m.driver_id && m.status === 'assigned' && m.assignment_mode !== 'internal_test' && !['authorized', 'captured'].includes(m.payment_status)) {
            await db.runTransaction(async (tx) => {
                const current = (await tx.get(ref)).data();
                if (current?.lease === lease)
                    tx.update(ref, { state: 'pending', next_attempt_at: admin.firestore.Timestamp.fromMillis(Date.now() + 60000), lease: admin.firestore.FieldValue.delete(), lease_until: admin.firestore.FieldValue.delete() });
            });
            return;
        }
        const active = !!m?.scheduling && m.driver_id === job.driver_id && !['cancelled', 'payment_failed', 'refunded', 'disputed'].includes(m.status);
        const slot = active ? { start: m!.scheduling.start, end: m!.scheduling.end } : null;
        const connections = await db.collection('driver_calendar_connections/' + job.driver_id + '/providers').get();
        let writes = 0;
        for (const d of connections.docs) {
            const p = d.id as CalendarProvider;
            if (!d.data().write_allowed)
                continue;
            await withConnection(job.driver_id, p, async (c, t) => {
                if (c.state !== 'ready')
                    throw new CalendarApiError(401, true);
                const calendarId = await ensureWriteCalendar(job.driver_id, p, c, t);
                if (!calendarId)
                    return;
                writes++;
                const mapRef = ref.collection('events').doc(p + '_' + c.generation), mapping = (await mapRef.get()).data();
                const externalId = await writeEvent(p, t.access_token, calendarId, missionId, slot, mapping?.event_id);
                await mapRef.set({ provider: p, connection_generation: c.generation, calendar_id: calendarId, event_id: externalId,
                    source_generation: job.generation, synced_at: admin.firestore.Timestamp.now() });
            });
        }
        await db.runTransaction(async (tx) => {
            const current = (await tx.get(ref)).data();
            if (current?.lease !== lease)
                return;
            const unchanged = current.generation === job.generation;
            tx.update(ref, { state: unchanged ? (writes > 0 ? 'synced' : 'not_connected') : 'pending', attempts: 0, lease: admin.firestore.FieldValue.delete(),
                lease_until: admin.firestore.FieldValue.delete(), last_synced_at: admin.firestore.Timestamp.now(),
                next_attempt_at: admin.firestore.Timestamp.fromMillis(Date.now() + (unchanged ? 15 * 60000 : 0)) });
        });
    }
    catch (e) {
        await db.runTransaction(async (tx) => {
            const current = (await tx.get(ref)).data();
            if (current?.lease !== lease)
                return;
            const attempts = (current.attempts ?? 0) + 1;
            tx.update(ref, { state: attempts >= 6 ? 'attention_required' : 'retry', attempts,
                error_code: e instanceof CalendarApiError && e.reconnect ? 'reconnect_required' : 'sync_failed',
                next_attempt_at: admin.firestore.Timestamp.fromMillis(Date.now() + Math.min(3600000, 60000 * 2 ** attempts)),
                lease: admin.firestore.FieldValue.delete(), lease_until: admin.firestore.FieldValue.delete() });
        });
    }
}
export const maintainDriverCalendars = onSchedule({ schedule: 'every 1 minutes', secrets: calendarSecrets, timeoutSeconds: 540 }, async () => {
    const deadline = Date.now() + 420000;
    const jobs = await db.collection('calendar_sync_jobs').where('state', 'in', ['pending', 'retry', 'synced', 'not_connected']).where('next_attempt_at', '<=', admin.firestore.Timestamp.now()).limit(20).get();
    for (const job of jobs.docs) {
        if (Date.now() > deadline)
            break;
        await syncMissionCalendar(job.id);
    }
    // Persisted cursor prevents the same first accounts from monopolising polling.
    const cursorRef = db.doc('calendar_worker_state/provider_poll'), cursor = (await cursorRef.get()).data()?.cursor;
    const query = db.collectionGroup('providers').where('state', '==', 'ready').orderBy(admin.firestore.FieldPath.documentId()).limit(20);
    const providers = await (typeof cursor === 'string' ? query.startAfter(db.doc(cursor)) : query).get();
    const policy = await readSchedulingPolicy(), seen = new Set<string>();
    const from = new Date().toISOString(), to = new Date(Date.now() + Math.min(policy?.max_advance_minutes ?? 1440, 90 * 1440) * 60000).toISOString();
    let processed = 0;
    for (const d of providers.docs) {
        if (Date.now() > deadline)
            break;
        if (d.ref.path.startsWith('driver_calendar_connections/')) {
            const uid = d.ref.parent.parent!.id;
            if (!seen.has(uid))
                try {
                    seen.add(uid);
                    await refreshBusy(uid, from, to);
                }
                catch { /* Explicit persisted error; no sensitive logs. */ }
        }
        await cursorRef.set({ cursor: d.ref.path });
        processed++;
    }
    if (processed === providers.size && providers.size < 20)
        await cursorRef.set({ cursor: null });
    for (const name of ['calendar_oauth_states', 'calendar_oauth_claims']) {
        const expired = await db.collection(name).where('expires_at', '<', admin.firestore.Timestamp.now()).limit(100).get();
        if (!expired.empty) {
            const batch = db.batch();
            expired.docs.forEach(d => batch.delete(d.ref));
            await batch.commit();
        }
    }
});
export const retryDriverCalendarSync = onCall(async (request) => {
    const ctx = requireSignedIn(request);
    requireAnyRole(ctx, [PlatformRoles.DRIVER]);
    const jobs = await db.collection('calendar_sync_jobs').where('driver_id', '==', ctx.uid).where('state', 'in', ['retry', 'attention_required']).limit(100).get();
    const batch = db.batch();
    jobs.docs.forEach(d => batch.update(d.ref, { state: 'pending', attempts: 0, next_attempt_at: admin.firestore.Timestamp.now() }));
    await batch.commit();
    return { queued: jobs.size };
});
export function calendarIcs(missions: {
    id: string;
    start: string;
    end: string;
    cancelled: boolean;
}[], stamp = new Date()): string {
    const dt = (s: string) => new Date(s).toISOString().replace(/[-:]/g, '').replace(/\.\d{3}Z$/, 'Z');
    const lines = ['BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//Movi-K//Driver agenda//FR', 'CALSCALE:GREGORIAN', 'METHOD:PUBLISH'];
    for (const m of missions)
        lines.push('BEGIN:VEVENT', 'UID:' + eventKey(m.id) + '@movi-k.com', 'DTSTAMP:' + dt(stamp.toISOString()), 'DTSTART:' + dt(m.start), 'DTEND:' + dt(m.end), 'SUMMARY:Mission Movi-K', 'STATUS:' + (m.cancelled ? 'CANCELLED' : 'CONFIRMED'), 'END:VEVENT');
    lines.push('END:VCALENDAR');
    return lines.join('\r\n') + '\r\n';
}
export const exportDriverCalendar = onCall(async (request) => {
    const ctx = requireSignedIn(request);
    requireAnyRole(ctx, [PlatformRoles.DRIVER]);
    const from = Date.parse(request.data?.from), to = Date.parse(request.data?.to);
    if (!Number.isFinite(from) || !Number.isFinite(to) || to <= from || to - from > 366 * 86400000)
        throw invalidArgument('Période d’export invalide.');
    const docs = await db.collection('delivery_requests').where('driver_id', '==', ctx.uid).get();
    const missions = docs.docs.filter(d => d.data().assignment_mode !== 'internal_test' && (['authorized', 'captured'].includes(d.data().payment_status) || ['cancelled', 'payment_failed', 'refunded', 'disputed'].includes(d.data().status)) && d.data().scheduling && Date.parse(d.data().scheduling.end) > from && Date.parse(d.data().scheduling.start) < to)
        .map(d => ({ id: d.id, start: d.data().scheduling.start, end: d.data().scheduling.end, cancelled: ['cancelled', 'payment_failed', 'refunded', 'disputed'].includes(d.data().status) }));
    return { filename: 'movik-agenda.ics', content: calendarIcs(missions), mode: 'manual_export', automatic_sync: false };
});
