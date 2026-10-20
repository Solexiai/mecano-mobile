import { seal, unseal, authUrl, validateConfig, scopes, graphPath, busy, writeEvent, eventKey, CalendarApiError, revoke } from '../../src/lib/calendarProviders';
import { calendarIcs } from '../../src/functions/calendarSync';
const key = Buffer.alloc(32, 7).toString('base64');
const c = { enabled: true, privacy_approved: true, google_client_id: 'test-google', microsoft_client_id: 'test-ms',
    callback_url: 'https://us-central1-demo-movik-agenda.cloudfunctions.net/calendarOAuthCallback', return_url: 'https://www.movi-k.com/fr/provider/dashboard' };
const mock = jest.fn();
const original = global.fetch;
beforeEach(() => { mock.mockReset(); global.fetch = mock; });
afterAll(() => { global.fetch = original; });
const response = (body: unknown, status = 200) => ({ ok: status >= 200 && status < 300, status, text: async () => JSON.stringify(body) });
test('tokens encrypted with authenticated owner binding', () => {
    const encrypted = seal({ refresh_token: 'synthetic-private' }, 'driver/google', key);
    expect(encrypted).not.toContain('synthetic-private');
    expect(unseal(encrypted, 'driver/google', key)).toEqual({ refresh_token: 'synthetic-private' });
    expect(() => unseal(encrypted, 'another/google', key)).toThrow();
});
test('tampering is rejected', () => { const value = seal('test', 'owner', key); const bits = value.split('.'); bits[3] = Buffer.from('tampered').toString('base64'); expect(() => unseal(bits.join('.'), 'owner', key)).toThrow(); });
test.each(['google', 'microsoft'] as const)('%s authorization has state and PKCE S256', p => {
    const url = new URL(authUrl(p, c, 'one-time-state', 'secret-verifier', false));
    expect(url.searchParams.get('state')).toBe('one-time-state');
    expect(url.searchParams.get('code_challenge_method')).toBe('S256');
    expect(url.toString()).not.toContain('secret-verifier');
    expect(url.searchParams.get('scope')).not.toContain('ReadWrite');
});
test('Google write scope is confined to app-created calendars', () => expect(scopes('google', true)).toContain('https://www.googleapis.com/auth/calendar.app.created'));
test.each([{ return_url: 'https://evil.example/' }, { callback_url: 'https://evil.example/calendarOAuthCallback' }, { enabled: false }, { privacy_approved: false }])('invalid or unapproved OAuth configuration is rejected %j', changes => expect(() => validateConfig({ ...c, ...changes }, 'demo-movik-agenda')).toThrow());
test('approved exact callback passes', () => expect(() => validateConfig(c, 'demo-movik-agenda')).not.toThrow());
test('Graph next link rejects credential exfiltration origins', () => expect(() => graphPath('https://evil.example/v1.0/me/events')).toThrow());
test('Graph next link preserves validated endpoint', () => expect(graphPath('https://graph.microsoft.com/v1.0/me/events?$skiptoken=123')).toBe('/me/events?$skiptoken=123'));
test('Google free/busy reads intervals only', async () => {
    mock.mockResolvedValue(response({ calendars: { private: { busy: [{ start: '2026-10-20T13:00:00Z', end: '2026-10-20T14:00:00Z' }] } } }));
    expect(await busy('google', 'synthetic-token', ['private'], '2026-10-20T00:00:00Z', '2026-10-21T00:00:00Z')).toHaveLength(1);
    expect(mock.mock.calls[0][0]).toContain('/freeBusy');
    expect(mock.mock.calls[0][1].body).not.toContain('summary');
});
test('Google calendar access errors are not treated as free', async () => { mock.mockResolvedValue(response({ calendars: { private: { errors: [{ reason: 'notFound' }] } } })); await expect(busy('google', 'test', ['private'], '2026-10-20T00:00:00Z', '2026-10-21T00:00:00Z')).rejects.toBeInstanceOf(CalendarApiError); });
test('Outlook requests minimal fields and ignores free/cancelled events', async () => {
    mock.mockResolvedValue(response({ value: [{ start: { dateTime: '2026-10-20T13:00:00' }, end: { dateTime: '2026-10-20T14:00:00' }, showAs: 'busy' },
            { showAs: 'free' }, { isCancelled: true }] }));
    const result = await busy('microsoft', 'test', ['private'], '2026-10-20T00:00:00Z', '2026-10-21T00:00:00Z');
    expect(result).toEqual([{ start: '2026-10-20T13:00:00Z', end: '2026-10-20T14:00:00Z' }]);
    const url = decodeURIComponent(mock.mock.calls[0][0]);
    expect(url).toContain('id,start,end,showAs,isCancelled');
    expect(url).not.toMatch(/subject|attendees|body/);
});
test('Outlook revoked permissions fail explicitly', async () => { mock.mockResolvedValue(response({}, 401)); await expect(busy('microsoft', 'test', ['private'], '2026-10-20T00:00:00Z', '2026-10-21T00:00:00Z')).rejects.toMatchObject({ reconnect: true }); });
test('Google event retry reuses deterministic id', async () => {
    mock.mockResolvedValueOnce(response({}, 404)).mockResolvedValueOnce(response({}));
    const slot = { start: '2026-10-20T13:00:00Z', end: '2026-10-20T14:00:00Z' };
    expect(await writeEvent('google', 'test', 'owned', 'mission', slot)).toBe(eventKey('mission'));
    expect(JSON.parse(mock.mock.calls[1][1].body).id).toBe(eventKey('mission'));
});
test('Google duplicate creation reconciles existing event', async () => {
    mock.mockResolvedValueOnce(response({}, 404)).mockResolvedValueOnce(response({}, 409)).mockResolvedValueOnce(response({}));
    await expect(writeEvent('google', 'test', 'owned', 'mission', { start: '2026-10-20T13:00:00Z', end: '2026-10-20T14:00:00Z' })).resolves.toBe(eventKey('mission'));
});
test('external cancellation is idempotent on missing event', async () => { mock.mockResolvedValue(response({}, 404)); await expect(writeEvent('google', 'test', 'owned', 'mission', null)).resolves.toBeNull(); });
test('Microsoft local disconnect never claims remote revocation', async () => { expect(await revoke('microsoft', { access_token: 'test', refresh_token: 'test', expires_at: 0, scope: '' })).toBe(false); expect(mock).not.toHaveBeenCalled(); });
test('iCalendar export has stable UID, UTC and cancellation; no client details', () => {
    const data = calendarIcs([{ id: 'test', start: '2026-11-01T05:30:00Z', end: '2026-11-01T06:30:00Z', cancelled: true }], new Date('2026-10-20T00:00:00Z'));
    expect(data).toContain('DTSTART:20261101T053000Z\r\n');
    expect(data).toContain('STATUS:CANCELLED');
    expect(data).not.toMatch(/ATTENDEE|LOCATION|customer/);
});
test('Outlook lost creation response recovers by persistent mission property', async () => {
    mock.mockResolvedValueOnce(response({ value: [{ id: 'already-created' }] })).mockResolvedValueOnce(response({}));
    expect(await writeEvent('microsoft', 'test', 'owned', 'mission', { start: '2026-10-20T13:00:00Z', end: '2026-10-20T14:00:00Z' })).toBe('already-created');
    expect(mock.mock.calls.map(c => c[1].method)).toEqual(['GET', 'PATCH']);
});
test('Outlook new event uses both provider idempotency and persistent key', async () => {
    mock.mockResolvedValueOnce(response({ value: [] })).mockResolvedValueOnce(response({ id: 'created' }));
    await writeEvent('microsoft', 'test', 'owned', 'mission', { start: '2026-10-20T13:00:00Z', end: '2026-10-20T14:00:00Z' });
    const body = JSON.parse(mock.mock.calls[1][1].body);
    expect(body.transactionId).toBe(eventKey('mission'));
    expect(body.singleValueExtendedProperties[0].value).toBe(eventKey('mission'));
});
test('Outlook cancellation recovers event id after lost response', async () => {
    mock.mockResolvedValueOnce(response({ value: [{ id: 'found' }] })).mockResolvedValueOnce(response({}, 204));
    await expect(writeEvent('microsoft', 'test', 'owned', 'mission', null)).resolves.toBeNull();
    expect(mock.mock.calls[1][1].method).toBe('DELETE');
});
test('Google deleted tombstone uses deterministic replacement and recovers lost creation', async () => {
    const slot = { start: '2026-10-20T13:00:00Z', end: '2026-10-20T14:00:00Z' };
    const key = eventKey('deleted-mission');
    mock.mockResolvedValueOnce(response({}, 410)).mockResolvedValueOnce(response({}, 409)).mockResolvedValueOnce(response({}, 410)).mockResolvedValueOnce(response({}));
    expect(await writeEvent('google', 'test', 'owned', 'deleted-mission', slot, key)).toBe(key + 'a1');
    mock.mockReset();
    mock.mockResolvedValueOnce(response({}, 410)).mockResolvedValueOnce(response({}, 409)).mockResolvedValueOnce(response({}, 410)).mockResolvedValueOnce(response({}, 409)).mockResolvedValueOnce(response({}));
    expect(await writeEvent('google', 'test', 'owned', 'deleted-mission', slot, key)).toBe(key + 'a1');
});
