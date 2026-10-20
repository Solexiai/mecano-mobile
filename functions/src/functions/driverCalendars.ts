import { onCall, onRequest } from 'firebase-functions/v2/https';
import { randomBytes } from 'crypto';
import { db, admin } from '../lib/admin';
import { requireSignedIn, requireAnyRole } from '../lib/auth';
import { PlatformRoles } from '../lib/types';
import { failedPrecondition, permissionDenied, invalidArgument } from '../lib/errors';
import { calendarSecrets, provider, authUrl, hash, seal, unseal, exchange, Tokens, calendars, revoke, scopes } from '../lib/calendarProviders';
import { calendarConfig, connectionRef, withConnection, ensureWriteCalendar, refreshBusy } from '../lib/calendarConnections';
import { readSchedulingPolicy, missionRequestedAt } from '../lib/driverScheduling';
import { resolveLockedQuote } from '../lib/quoteIntegrity';
import { readDriverOfferCompensation } from '../lib/driverOfferCompensation';
import { toMinorUnits } from '../lib/money';
import { normalizeAgendaInterval } from '../lib/driverAgenda';
function driver(request: Parameters<typeof requireSignedIn>[0]): string {
    const ctx = requireSignedIn(request);
    requireAnyRole(ctx, [PlatformRoles.DRIVER]);
    return ctx.uid;
}
const options = { secrets: calendarSecrets, timeoutSeconds: 120 };
export const getDriverCalendars = onCall(async (request) => {
    const uid = driver(request), docs = await db.collection('driver_calendar_connections/' + uid + '/providers').get();
    const busy = (await db.doc('driver_calendar_busy/' + uid).get()).data();
    let available = false;
    try {
        await calendarConfig();
        available = true;
    }
    catch { /* Honest configured state; no tokens read. */ }
    const jobs = await db.collection('calendar_sync_jobs').where('driver_id', '==', uid).get();
    const states = jobs.docs.map(d => d.data().state);
    const eventStatus = states.some(s => ['retry', 'attention_required'].includes(s)) ? 'error' : states.some(s => s === 'pending') ? 'pending' : states.some(s => s === 'synced') ? 'synced' : 'not_connected';
    return { available, event_sync_status: eventStatus, connections: docs.docs.map(d => ({ provider: d.id, state: d.data().state, write_allowed: d.data().write_allowed,
            selected_count: d.data().selected_ids?.length ?? 0 })), busy_status: busy?.status ?? 'not_connected', checked_at: busy?.checked_at?.toDate().toISOString() ?? null };
});
export const startDriverCalendarConnection = onCall(options, async (request) => {
    const uid = driver(request), p = provider(request.data?.provider), write = request.data?.write_allowed === true;
    if (request.data?.consent !== true)
        throw invalidArgument('Votre autorisation explicite est requise.');
    const c = await calendarConfig(), state = randomBytes(32).toString('base64url'), verifier = randomBytes(48).toString('base64url');
    const ref = db.doc('calendar_oauth_states/' + hash(state));
    await ref.set({ uid, provider: p, write_allowed: write, encrypted_verifier: seal(verifier, ref.id), status: 'pending',
        expires_at: admin.firestore.Timestamp.fromMillis(Date.now() + 600000), consent_at: admin.firestore.Timestamp.now() });
    return { url: authUrl(p, c, state, verifier, write) };
});
/** Callback creates a one-time claim, not an authenticated app session.
 * Finishing requires BOTH this claim and the Firebase identity that started OAuth. */
export const calendarOAuthCallback = onRequest(options, async (req, res) => {
    res.set({ 'Cache-Control': 'no-store', 'Referrer-Policy': 'no-referrer', 'Content-Security-Policy': "default-src 'none'; style-src 'unsafe-inline'; frame-ancestors 'none'" });
    try {
        const state = typeof req.query.state === 'string' ? req.query.state : '', code = typeof req.query.code === 'string' ? req.query.code : '';
        if (!state || state.length > 200 || !code || code.length > 4096)
            throw new Error('invalid_callback');
        const ref = db.doc('calendar_oauth_states/' + hash(state));
        const s = await db.runTransaction(async (tx) => {
            const d = (await tx.get(ref)).data();
            if (!d || d.status !== 'pending' || d.expires_at.toMillis() <= Date.now())
                throw new Error('expired_state');
            tx.update(ref, { status: 'exchanging' });
            return d;
        });
        const config = await calendarConfig(), p = provider(s.provider);
        const tokens = await exchange(p, config, code, unseal<string>(s.encrypted_verifier, ref.id));
        const granted = new Set(tokens.scope.split(' '));
        const required = scopes(p, s.write_allowed).filter(x => x !== 'offline_access');
        if (!required.every(x => granted.has(x)))
            throw new Error('missing_scope');
        const claim = randomBytes(32).toString('base64url');
        await db.doc('calendar_oauth_claims/' + hash(claim)).set({ uid: s.uid, provider: p, write_allowed: s.write_allowed,
            encrypted_tokens: seal(tokens, s.uid + '/' + p), expires_at: admin.firestore.Timestamp.fromMillis(Date.now() + 600000) });
        await ref.delete();
        res.status(200).type('html').send('<!doctype html><html lang="fr"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Connexion Movi-K</title><body><h1>Autorisation reçue</h1><p>Retournez dans « Mes calendriers connectés » sur Movi-K et collez ce code pour confirmer la connexion au même compte chauffeur.</p><p style="overflow-wrap:anywhere"><code>' + claim + '</code></p><p>Ce code expire dans 10 minutes. Fermez cette page après confirmation.</p></body></html>');
    }
    catch {
        res.status(400).type('text').send('La connexion n’a pas abouti. Revenez à Movi-K et recommencez. Aucun calendrier n’est confirmé.');
    }
});
export const finishDriverCalendarConnection = onCall(options, async (request) => {
    const uid = driver(request), claim = request.data?.claim;
    if (typeof claim !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(claim))
        throw invalidArgument('Code de connexion invalide.');
    const ref = db.doc('calendar_oauth_claims/' + hash(claim));
    await db.runTransaction(async (tx) => {
        const s = (await tx.get(ref)).data();
        if (!s || s.uid !== uid || s.expires_at.toMillis() <= Date.now())
            throw permissionDenied('Code expiré ou destiné à un autre compte.');
        const p = provider(s.provider), connection = connectionRef(uid, p), existing = (await tx.get(connection)).data();
        if ((existing?.lease_until?.toMillis() ?? 0) > Date.now())
            throw failedPrecondition('Synchronisation en cours. Réessayez.');
        const root = db.doc('driver_agendas/' + uid);
        const agenda = await tx.get(root);
        tx.set(connection, { provider: p, encrypted_tokens: s.encrypted_tokens, generation: randomBytes(16).toString('hex'),
            state: 'selection_required', write_allowed: s.write_allowed, selected_ids: [],
            consent_at: admin.firestore.Timestamp.now() });
        tx.set(db.doc('driver_calendar_busy/' + uid), { required: true, status: 'selection_required', busy: [] });
        tx.set(root, { ...(!agenda.exists ? { windows: [], blocked: [], revision: 0 } : {}), lock_version: admin.firestore.FieldValue.increment(1) }, { merge: true });
        tx.delete(ref);
    });
    return { success: true };
});
export const listDriverCalendars = onCall(options, async (request) => {
    const uid = driver(request), p = provider(request.data?.provider);
    return withConnection(uid, p, async (c, t) => ({ calendars: (await calendars(p, t.access_token)).filter(x => x.id !== c.write_calendar_id) }));
});
export const selectDriverCalendars = onCall(options, async (request) => {
    const uid = driver(request), p = provider(request.data?.provider), ids = request.data?.calendar_ids;
    if (!Array.isArray(ids) || ids.length < 1 || ids.length > 20 || !ids.every(x => typeof x === 'string') || new Set(ids).size !== ids.length)
        throw invalidArgument('Choix des calendriers invalide.');
    await withConnection(uid, p, async (c, t) => {
        const owned = await ensureWriteCalendar(uid, p, c, t);
        const all = await calendars(p, t.access_token);
        if (ids.some(id => id === owned || !all.some(x => x.id === id)))
            throw invalidArgument('Calendrier inaccessible ou réservé aux missions Movi-K.');
        await db.runTransaction(async (tx) => {
            const ref = connectionRef(uid, p), current = (await tx.get(ref)).data(), root = db.doc('driver_agendas/' + uid);
            await tx.get(root);
            if (current?.generation !== c.generation)
                throw failedPrecondition('Connexion modifiée.');
            tx.update(ref, { selected_ids: ids, state: 'ready' });
            tx.set(db.doc('driver_calendar_busy/' + uid), { required: true, status: 'refresh_required', busy: [] });
            tx.set(root, { lock_version: admin.firestore.FieldValue.increment(1) }, { merge: true });
        });
    });
    return { success: true };
});
export const disconnectDriverCalendar = onCall(options, async (request) => {
    const uid = driver(request), p = provider(request.data?.provider), ref = connectionRef(uid, p);
    let revoked = false, revocationFailed = false;
    const saved = await db.runTransaction(async (tx) => {
        const data = (await tx.get(ref)).data();
        if ((data?.lease_until?.toMillis() ?? 0) > Date.now())
            throw failedPrecondition('Synchronisation en cours. Réessayez.');
        const all = await tx.get(db.collection('driver_calendar_connections/' + uid + '/providers')), root = db.doc('driver_agendas/' + uid);
        const agenda = await tx.get(root);
        tx.delete(ref);
        tx.set(db.doc('driver_calendar_busy/' + uid), { required: all.docs.some(d => d.id !== p), status: all.docs.some(d => d.id !== p) ? 'refresh_required' : 'not_connected', busy: [] });
        if (agenda.exists)
            tx.set(root, { lock_version: admin.firestore.FieldValue.increment(1) }, { merge: true });
        return data;
    });
    if (saved)
        try {
            revoked = await revoke(p, unseal<Tokens>(saved.encrypted_tokens, uid + '/' + p));
        }
        catch {
            revocationFailed = true;
        }
    return { success: true, provider_revoked: revoked, manual_revocation_required: p === 'microsoft' || revocationFailed };
});
export const refreshDriverCalendars = onCall(options, async (request) => {
    const uid = driver(request), slot = normalizeAgendaInterval(request.data);
    const agenda = (await db.doc('driver_agendas/' + uid).get()).data();
    await refreshBusy(uid, new Date(Date.parse(slot.start) - (agenda?.recurrence?.pause_before_minutes ?? 0) * 60000).toISOString(), new Date(Date.parse(slot.end) + (agenda?.recurrence?.pause_after_minutes ?? 0) * 60000).toISOString());
    return { success: true };
});
export const prepareDriverMissionAcceptance = onCall(async (request) => {
    const uid = driver(request), missionId = request.data?.missionId;
    if (typeof missionId !== 'string' || !missionId || missionId.includes('/'))
        throw invalidArgument('Mission invalide.');
    const policy = await readSchedulingPolicy();
    const offers = await db.collection('delivery_offers').where('mission_id', '==', missionId).where('driver_id', '==', uid).get();
    if (!offers.docs.some(d => d.data().status === 'pending' && d.data().expires_at?.toMillis() > Date.now()))
        throw permissionDenied('Offre indisponible.');
    const m = (await db.doc('delivery_requests/' + missionId).get()).data();
    if (!m || m.driver_id || !['searching_driver', 'offered'].includes(m.status))
        throw failedPrecondition('Mission indisponible.');
    const driverOfferMinor = await db.runTransaction(async (tx) => {
        const current = (await tx.get(db.doc('delivery_requests/' + missionId))).data();
        const liveOffers = await tx.get(db.collection('delivery_offers').where('mission_id', '==', missionId).where('driver_id', '==', uid));
        if (!current || current.driver_id || !['searching_driver', 'offered'].includes(current.status) || !liveOffers.docs.some(d => d.data().status === 'pending' && d.data().expires_at?.toMillis() > Date.now()))
            throw permissionDenied('Offre indisponible.');
        if (current.assignment_mode === 'internal_test' && current.internal_test_authorized === true)
            return 0;
        const q = (await tx.get(db.doc('delivery_quotes/' + current.active_quote_id))).data();
        if (!q || q.customer_id !== current.customer_id || q.mission_id !== missionId || q.is_consumed !== true)
            throw failedPrecondition('Devis officiel indisponible.');
        const locked = resolveLockedQuote(current.active_quote_id, q);
        if (locked.customerTotalMinor !== toMinorUnits(current.customer_total))
            throw failedPrecondition('Montant officiel incohérent.');
        const { compensation } = await readDriverOfferCompensation(tx, uid, locked);
        return toMinorUnits(compensation.driverOfferAmount);
    });
    if (!policy)
        return { enabled: false, driver_offer_minor: driverOfferMinor };
    const connected = (await db.doc('driver_calendar_busy/' + uid).get()).data()?.required === true;
    return { enabled: true, calendars_connected: connected, driver_offer_minor: driverOfferMinor, policy_version: policy.version, requested_at: missionRequestedAt(m),
        route_minutes: m.estimated_duration_minutes, max_advance_minutes: policy.max_advance_minutes };
});
