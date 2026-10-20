import { randomBytes } from 'crypto';
import { db, admin } from './admin';
import { failedPrecondition } from './errors';
import { CalendarProvider, CalendarConfig, Tokens, validateConfig, seal, unseal, exchange, CalendarApiError, busy, api, calendars } from './calendarProviders';
import { normalizeAgendaInterval } from './driverAgenda';
export interface Connection {
    provider: CalendarProvider;
    generation: string;
    encrypted_tokens: string;
    write_allowed: boolean;
    selected_ids: string[];
    write_calendar_id?: string;
    state: string;
    lease?: string;
    lease_until?: FirebaseFirestore.Timestamp;
}
export async function calendarConfig(): Promise<CalendarConfig> {
    const c = (await db.doc('system_config/calendar_oauth').get()).data() as CalendarConfig;
    if (!c)
        throw failedPrecondition('Calendriers externes non configurés.');
    validateConfig(c, process.env.GCLOUD_PROJECT ?? '');
    return c;
}
export const connectionRef = (uid: string, p: CalendarProvider) => db.doc('driver_calendar_connections/' + uid + '/providers/' + p);
export async function withConnection<T>(uid: string, p: CalendarProvider, fn: (c: Connection, t: Tokens) => Promise<T>): Promise<T> {
    const ref = connectionRef(uid, p), lease = randomBytes(24).toString('hex');
    let c: Connection | undefined;
    await db.runTransaction(async (tx) => {
        const d = (await tx.get(ref)).data() as Connection | undefined;
        if (!d || d.state === 'reconnect_required')
            throw failedPrecondition('Reconnectez votre calendrier.');
        if ((d.lease_until?.toMillis() ?? 0) > Date.now())
            throw failedPrecondition('Une synchronisation est déjà en cours. Réessayez.');
        c = d;
        tx.update(ref, { lease, lease_until: admin.firestore.Timestamp.fromMillis(Date.now() + 600000) });
    });
    const connection = c!;
    try {
        let t = unseal<Tokens>(connection.encrypted_tokens, uid + '/' + p);
        if (t.expires_at < Date.now() + 60000) {
            try {
                t = await exchange(p, await calendarConfig(), '', '', t.refresh_token);
            }
            catch (e) {
                if (e instanceof CalendarApiError && e.status === 400)
                    throw new CalendarApiError(401, true);
                throw e;
            }
            await db.runTransaction(async (tx) => {
                const current = (await tx.get(ref)).data();
                if (current?.lease !== lease || current?.generation !== connection.generation)
                    throw failedPrecondition('Connexion modifiée.');
                tx.update(ref, { encrypted_tokens: seal(t, uid + '/' + p) });
            });
        }
        return await fn(connection, t);
    }
    catch (e) {
        if (e instanceof CalendarApiError && e.reconnect)
            await db.runTransaction(async (tx) => {
                const current = (await tx.get(ref)).data();
                if (current?.generation === connection.generation)
                    tx.update(ref, { state: 'reconnect_required' });
            });
        throw e;
    }
    finally {
        await db.runTransaction(async (tx) => {
            const current = (await tx.get(ref)).data();
            if (current?.lease === lease)
                tx.update(ref, { lease: admin.firestore.FieldValue.delete(), lease_until: admin.firestore.FieldValue.delete() });
        });
    }
}
export async function ensureWriteCalendar(uid: string, p: CalendarProvider, c: Connection, t: Tokens): Promise<string | null> {
    if (!c.write_allowed)
        return null;
    if (c.write_calendar_id)
        return c.write_calendar_id;
    // Stable private name allows recovery if creation succeeded but its response was lost.
    const name = 'Movi-K ' + c.generation.slice(0, 10);
    const existing = (await calendars(p, t.access_token)).find(x => x.name === name);
    const created = existing ?? await api(p, t.access_token, p === 'google' ? '/calendars' : '/me/calendars', 'POST', p === 'google' ? { summary: name } : { name });
    const calendarId = created.id;
    if (typeof calendarId !== 'string')
        throw new CalendarApiError(502);
    await db.runTransaction(async (tx) => {
        const ref = connectionRef(uid, p), current = (await tx.get(ref)).data();
        if (current?.generation !== c.generation)
            throw failedPrecondition('Connexion modifiée.');
        tx.update(ref, { write_calendar_id: calendarId });
    });
    return calendarId;
}
export async function refreshBusy(uid: string, from: string, to: string): Promise<void> {
    const interval = normalizeAgendaInterval({ start: from, end: to });
    if (Date.parse(interval.end) - Date.parse(interval.start) > 93 * 86400000)
        throw failedPrecondition('Période de synchronisation trop grande.');
    const root = db.doc('driver_agendas/' + uid), ref = db.doc('driver_calendar_busy/' + uid);
    const connections = await db.collection('driver_calendar_connections/' + uid + '/providers').get();
    const versions = connections.docs.map(d => [d.id, d.data().generation, JSON.stringify(d.data().selected_ids)]);
    const intervals: {
        start: string;
        end: string;
    }[] = [];
    try {
        for (const d of connections.docs) {
            const p = d.id as CalendarProvider;
            const slots = await withConnection(uid, p, async (c, t) => {
                if (c.state !== 'ready' || !c.selected_ids.length)
                    throw failedPrecondition('Choisissez les calendriers à prendre en compte.');
                return busy(p, t.access_token, c.selected_ids.filter(id => id !== c.write_calendar_id), interval.start, interval.end);
            });
            intervals.push(...slots.map(normalizeAgendaInterval));
        }
        await db.runTransaction(async (tx) => {
            const current = await tx.get(db.collection('driver_calendar_connections/' + uid + '/providers'));
            const a = await tx.get(root);
            if (JSON.stringify(current.docs.map(d => [d.id, d.data().generation, JSON.stringify(d.data().selected_ids)])) !== JSON.stringify(versions))
                throw failedPrecondition('Connexion modifiée pendant la synchronisation.');
            tx.set(ref, { required: connections.size > 0, status: 'ready', busy: intervals, from: interval.start, to: interval.end, checked_at: admin.firestore.Timestamp.now() });
            if (a.exists)
                tx.set(root, { lock_version: admin.firestore.FieldValue.increment(1) }, { merge: true });
        });
    }
    catch (e) {
        await db.runTransaction(async (tx) => {
            const a = await tx.get(root);
            const latest = await tx.get(db.collection('driver_calendar_connections/' + uid + '/providers'));
            if (JSON.stringify(latest.docs.map(d => [d.id, d.data().generation, JSON.stringify(d.data().selected_ids)])) !== JSON.stringify(versions))
                return;
            tx.set(ref, { required: latest.size > 0, status: e instanceof CalendarApiError && e.reconnect ? 'reconnect_required' : 'error', checked_at: admin.firestore.Timestamp.now() }, { merge: true });
            if (a.exists)
                tx.set(root, { lock_version: admin.firestore.FieldValue.increment(1) }, { merge: true });
        });
        throw e;
    }
}
