import { db, admin } from '../../src/lib/admin';
import { startDriverCalendarConnection, calendarOAuthCallback, finishDriverCalendarConnection, getDriverCalendars, disconnectDriverCalendar } from '../../src/functions/driverCalendars';
import { seal, hash, scopes } from '../../src/lib/calendarProviders';
import { refreshBusy, connectionRef, withConnection } from '../../src/lib/calendarConnections';
import { syncMissionCalendar } from '../../src/functions/calendarSync';
const uid = 'calendar_test_driver', original = global.fetch, mock = jest.fn();
const req = (data: unknown, who = uid) => ({ data, auth: { uid: who, token: { roles: ['driver'] } }, rawRequest: {}, acceptsStreaming: false } as any);
function response(body: unknown, status = 200) { return { ok: status >= 200 && status < 300, status, text: async () => JSON.stringify(body) }; }
async function connect(p: 'google' | 'microsoft' = 'google') {
    await connectionRef(uid, p).set({ provider: p, generation: 'testgeneration', state: 'ready', selected_ids: ['personal'], write_allowed: true, write_calendar_id: 'owned',
        encrypted_tokens: seal({ access_token: 'test-access', refresh_token: 'test-refresh', expires_at: Date.now() + 3600000, scope: scopes(p, true).join(' ') }, uid + '/' + p) });
}
beforeAll(() => { process.env.CALENDAR_TOKEN_ENCRYPTION_KEY = Buffer.alloc(32, 9).toString('base64'); process.env.GOOGLE_CALENDAR_CLIENT_SECRET = 'synthetic-test-only'; process.env.MICROSOFT_CALENDAR_CLIENT_SECRET = 'synthetic-test-only'; });
beforeEach(async () => {
    mock.mockReset();
    mock.mockImplementation(() => { throw new Error('Unexpected external request in controlled test'); });
    global.fetch = mock;
    for (const name of ['calendar_oauth_states', 'calendar_oauth_claims']) {
        const docs = await db.collection(name).get();
        for (const d of docs.docs)
            await d.ref.delete();
    }
    for (const path of ['driver_calendar_connections/' + uid, 'driver_calendar_busy/' + uid, 'driver_agendas/' + uid, 'calendar_sync_jobs/calendar_test_mission', 'delivery_requests/calendar_test_mission'])
        await db.recursiveDelete(db.doc(path));
    await db.doc('driver_agendas/' + uid).set({ revision: 0, windows: [], blocked: [] });
    await db.doc('system_config/calendar_oauth').set({ enabled: true, privacy_approved: true, google_client_id: 'test', microsoft_client_id: 'test',
        callback_url: 'https://us-central1-demo-movik-agenda.cloudfunctions.net/calendarOAuthCallback', return_url: 'https://www.movi-k.com/fr/provider/dashboard' });
});
afterEach(async () => {
    global.fetch = original;
    for (const path of ['driver_calendar_connections/' + uid, 'driver_calendar_busy/' + uid, 'driver_agendas/' + uid, 'calendar_sync_jobs/calendar_test_mission', 'delivery_requests/calendar_test_mission', 'system_config/calendar_oauth'])
        await db.recursiveDelete(db.doc(path));
});
test('OAuth start requires explicit consent', async () => { await expect(startDriverCalendarConnection.run(req({ provider: 'google' }))).rejects.toMatchObject({ code: 'invalid-argument' }); expect(mock).not.toHaveBeenCalled(); });
test('OAuth code flow binds one-time claim to original Firebase identity', async () => {
    const started = await startDriverCalendarConnection.run(req({ provider: 'google', consent: true, write_allowed: false }));
    const state = new URL(started.url).searchParams.get('state')!;
    mock.mockResolvedValueOnce(response({ access_token: 'test-access', refresh_token: 'test-refresh', expires_in: 3600, scope: scopes('google', false).join(' ') }));
    let html = '';
    const res: any = { set: jest.fn(), status: jest.fn(), type: jest.fn(), send: jest.fn((body: string) => { html = body; }) };
    res.status.mockReturnValue(res);
    res.type.mockReturnValue(res);
    await calendarOAuthCallback({ query: { state, code: 'synthetic-code' } } as any, res);
    expect(res.status).toHaveBeenCalledWith(200);
    const claim = html.match(/<code>([^<]+)<\/code>/)![1];
    await expect(finishDriverCalendarConnection.run(req({ claim }, 'another_driver'))).rejects.toMatchObject({ code: 'permission-denied' });
    await finishDriverCalendarConnection.run(req({ claim }));
    expect((await connectionRef(uid, 'google').get()).data()!.state).toBe('selection_required');
    await expect(finishDriverCalendarConnection.run(req({ claim }))).rejects.toMatchObject({ code: 'permission-denied' });
    expect(JSON.stringify(await getDriverCalendars.run(req({})))).not.toContain('test-access');
});
test('expired OAuth state never exchanges code', async () => {
    const state = 'expired-test-state';
    await db.doc('calendar_oauth_states/' + hash(state)).set({ uid, status: 'pending', expires_at: admin.firestore.Timestamp.fromMillis(0) });
    const res: any = { set: jest.fn(), status: jest.fn(), type: jest.fn(), send: jest.fn() };
    res.status.mockReturnValue(res);
    res.type.mockReturnValue(res);
    await calendarOAuthCallback({ query: { state, code: 'test' } } as any, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(mock).not.toHaveBeenCalled();
});
test('busy sync stores only occupied intervals and is fresh for server checks', async () => {
    await connect();
    mock.mockResolvedValue(response({ calendars: { personal: { busy: [{ start: '2026-10-20T13:00:00Z', end: '2026-10-20T14:00:00Z' }] } } }));
    await refreshBusy(uid, '2026-10-20T00:00:00Z', '2026-10-21T00:00:00Z');
    const b = (await db.doc('driver_calendar_busy/' + uid).get()).data()!;
    expect(b.status).toBe('ready');
    expect(b.busy).toHaveLength(1);
    expect(JSON.stringify(b)).not.toMatch(/test-access|subject|attendees/);
});
test('provider error leaves explicit blocked sync status', async () => {
    await connect();
    mock.mockResolvedValue(response({}, 401));
    await expect(refreshBusy(uid, '2026-10-20T00:00:00Z', '2026-10-21T00:00:00Z')).rejects.toBeDefined();
    expect((await connectionRef(uid, 'google').get()).data()!.state).toBe('reconnect_required');
    expect((await db.doc('driver_calendar_busy/' + uid).get()).data()!.status).toBe('reconnect_required');
});
test('refresh token rotation is encrypted and saved before release', async () => {
    await connect();
    await connectionRef(uid, 'google').update({ encrypted_tokens: seal({ access_token: 'old', refresh_token: 'old-refresh', expires_at: 0, scope: '' }, uid + '/google') });
    mock.mockResolvedValue(response({ access_token: 'new-access', refresh_token: 'new-refresh', expires_in: 3600 }));
    await withConnection(uid, 'google', async (_c, t) => { expect(t.refresh_token).toBe('new-refresh'); });
    const saved = (await connectionRef(uid, 'google').get()).data()!;
    expect(saved.encrypted_tokens).not.toContain('new-refresh');
    expect(saved.lease).toBeUndefined();
});
test('Microsoft disconnect erases tokens and explicitly asks for account-side revocation', async () => {
    await connect('microsoft');
    const result = await disconnectDriverCalendar.run(req({ provider: 'microsoft' }));
    expect(result.manual_revocation_required).toBe(true);
    expect((await connectionRef(uid, 'microsoft').get()).exists).toBe(false);
    expect((await db.doc('driver_calendar_busy/' + uid).get()).data()!.required).toBe(false);
});
test('external failure never removes internal mission and remains retryable', async () => {
    await connect();
    await db.doc('delivery_requests/calendar_test_mission').set({ driver_id: uid, status: 'assigned', payment_status: 'authorized', scheduling: { start: '2026-10-20T13:00:00Z', end: '2026-10-20T14:00:00Z' } });
    await db.doc('calendar_sync_jobs/calendar_test_mission').set({ driver_id: uid, generation: 1, state: 'pending', attempts: 0, next_attempt_at: admin.firestore.Timestamp.fromMillis(0) });
    mock.mockRejectedValue(new Error('network unavailable'));
    await syncMissionCalendar('calendar_test_mission');
    expect((await db.doc('delivery_requests/calendar_test_mission').get()).data()!.status).toBe('assigned');
    expect((await db.doc('calendar_sync_jobs/calendar_test_mission').get()).data()!.state).toBe('retry');
});
test('event id persists and replay updates the same external event', async () => {
    await connect();
    await db.doc('delivery_requests/calendar_test_mission').set({ driver_id: uid, status: 'assigned', payment_status: 'authorized', scheduling: { start: '2026-10-20T13:00:00Z', end: '2026-10-20T14:00:00Z' } });
    const job = db.doc('calendar_sync_jobs/calendar_test_mission');
    await job.set({ driver_id: uid, generation: 1, state: 'pending', attempts: 0, next_attempt_at: admin.firestore.Timestamp.fromMillis(0) });
    mock.mockResolvedValue(response({}));
    await syncMissionCalendar('calendar_test_mission');
    const first = (await job.collection('events').doc('google_testgeneration').get()).data()!;
    await job.update({ state: 'pending', next_attempt_at: admin.firestore.Timestamp.fromMillis(0) });
    await syncMissionCalendar('calendar_test_mission');
    expect((await job.collection('events').doc('google_testgeneration').get()).data()!.event_id).toBe(first.event_id);
    expect(mock.mock.calls.every(c => c[1].method === 'PATCH')).toBe(true);
});
test('a mission without an external connection is never called synced', async () => {
    await db.doc('delivery_requests/calendar_test_mission').set({ driver_id: uid, status: 'assigned', payment_status: 'authorized', scheduling: { start: '2026-10-20T13:00:00Z', end: '2026-10-20T14:00:00Z' } });
    await db.doc('calendar_sync_jobs/calendar_test_mission').set({ driver_id: uid, generation: 1, state: 'pending', attempts: 0, next_attempt_at: admin.firestore.Timestamp.fromMillis(0) });
    await syncMissionCalendar('calendar_test_mission');
    expect((await db.doc('calendar_sync_jobs/calendar_test_mission').get()).data()!.state).toBe('not_connected');
    expect(mock).not.toHaveBeenCalled();
});
test('payment still pending never creates a confirmed external event', async () => {
    await connect();
    await db.doc('delivery_requests/calendar_test_mission').set({ driver_id: uid, status: 'assigned', payment_status: 'pending', scheduling: { start: '2026-10-20T13:00:00Z', end: '2026-10-20T14:00:00Z' } });
    await db.doc('calendar_sync_jobs/calendar_test_mission').set({ driver_id: uid, generation: 1, state: 'pending', attempts: 0, next_attempt_at: admin.firestore.Timestamp.fromMillis(0) });
    await syncMissionCalendar('calendar_test_mission');
    expect(mock).not.toHaveBeenCalled();
    expect((await db.doc('calendar_sync_jobs/calendar_test_mission').get()).data()!.state).toBe('pending');
});
test('cancellation deletes the mapped external event idempotently', async () => {
    await connect();
    await db.doc('delivery_requests/calendar_test_mission').set({ driver_id: uid, status: 'cancelled', scheduling: { start: '2026-10-20T13:00:00Z', end: '2026-10-20T14:00:00Z' } });
    const job = db.doc('calendar_sync_jobs/calendar_test_mission');
    await job.set({ driver_id: uid, generation: 2, state: 'pending', attempts: 0, next_attempt_at: admin.firestore.Timestamp.fromMillis(0) });
    await job.collection('events').doc('google_testgeneration').set({ event_id: 'known-event' });
    mock.mockResolvedValue(response({}, 404));
    await syncMissionCalendar('calendar_test_mission');
    expect(mock.mock.calls[0][0]).toContain('/known-event');
    expect(mock.mock.calls[0][1].method).toBe('DELETE');
    expect((await job.get()).data()!.state).toBe('synced');
});
