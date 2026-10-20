import { createCipheriv, createDecipheriv, createHash, randomBytes } from 'crypto';
import { defineSecret } from 'firebase-functions/params';
import { failedPrecondition } from './errors';
export type CalendarProvider = 'google' | 'microsoft';
export const CALENDAR_TOKEN_KEY = defineSecret('CALENDAR_TOKEN_ENCRYPTION_KEY');
export const GOOGLE_CALENDAR_SECRET = defineSecret('GOOGLE_CALENDAR_CLIENT_SECRET');
export const MICROSOFT_CALENDAR_SECRET = defineSecret('MICROSOFT_CALENDAR_CLIENT_SECRET');
export const calendarSecrets = [CALENDAR_TOKEN_KEY, GOOGLE_CALENDAR_SECRET, MICROSOFT_CALENDAR_SECRET];
export interface CalendarConfig {
    enabled: boolean;
    privacy_approved: boolean;
    google_client_id: string;
    microsoft_client_id: string;
    callback_url: string;
    return_url: string;
}
export interface Tokens {
    access_token: string;
    refresh_token: string;
    expires_at: number;
    scope: string;
}
export function provider(v: unknown): CalendarProvider {
    if (v !== 'google' && v !== 'microsoft')
        throw failedPrecondition('Fournisseur de calendrier invalide.');
    return v;
}
export function seal(value: unknown, aad: string, key = CALENDAR_TOKEN_KEY.value()): string {
    const k = Buffer.from(key, 'base64');
    if (k.length !== 32)
        throw failedPrecondition('Chiffrement des calendriers non configuré.');
    const iv = randomBytes(12), cipher = createCipheriv('aes-256-gcm', k, iv);
    cipher.setAAD(Buffer.from(aad));
    const encrypted = Buffer.concat([cipher.update(JSON.stringify(value), 'utf8'), cipher.final()]);
    return ['v1', iv.toString('base64'), cipher.getAuthTag().toString('base64'), encrypted.toString('base64')].join('.');
}
export function unseal<T>(value: string, aad: string, key = CALENDAR_TOKEN_KEY.value()): T {
    const [version, iv, tag, data] = value.split('.');
    if (version !== 'v1')
        throw failedPrecondition('Version de chiffrement non prise en charge.');
    const decipher = createDecipheriv('aes-256-gcm', Buffer.from(key, 'base64'), Buffer.from(iv, 'base64'));
    decipher.setAAD(Buffer.from(aad));
    decipher.setAuthTag(Buffer.from(tag, 'base64'));
    return JSON.parse(Buffer.concat([decipher.update(Buffer.from(data, 'base64')), decipher.final()]).toString('utf8')) as T;
}
export function hash(v: string): string { return createHash('sha256').update(v).digest('hex'); }
export function scopes(p: CalendarProvider, write: boolean): string[] {
    return p === 'google' ? ['https://www.googleapis.com/auth/calendar.events.freebusy', 'https://www.googleapis.com/auth/calendar.calendarlist.readonly', ...(write ? ['https://www.googleapis.com/auth/calendar.app.created'] : [])]
        : ['offline_access', write ? 'Calendars.ReadWrite' : 'Calendars.ReadBasic'];
}
export function validateConfig(c: CalendarConfig, project: string): void {
    const callback = new URL(c.callback_url), ret = new URL(c.return_url);
    if (!c.enabled || !c.privacy_approved || callback.protocol !== 'https:' ||
        callback.hostname !== 'us-central1-' + project + '.cloudfunctions.net' || callback.pathname !== '/calendarOAuthCallback' ||
        callback.search || callback.hash || callback.username || callback.password ||
        ret.origin !== 'https://www.movi-k.com' || ret.search || ret.hash || ret.username || ret.password)
        throw failedPrecondition('Connexion de calendrier non approuvée ou redirection invalide.');
}
export function authUrl(p: CalendarProvider, c: CalendarConfig, state: string, verifier: string, write: boolean): string {
    const clientId = p === 'google' ? c.google_client_id : c.microsoft_client_id;
    if (typeof clientId !== 'string' || !clientId.trim())
        throw failedPrecondition('Ce fournisseur de calendrier n’est pas configuré.');
    const u = new URL(p === 'google' ? 'https://accounts.google.com/o/oauth2/v2/auth' : 'https://login.microsoftonline.com/common/oauth2/v2.0/authorize');
    u.search = new URLSearchParams({ client_id: p === 'google' ? c.google_client_id : c.microsoft_client_id, redirect_uri: c.callback_url,
        response_type: 'code', scope: scopes(p, write).join(' '), state, code_challenge: createHash('sha256').update(verifier).digest('base64url'), code_challenge_method: 'S256',
        ...(p === 'google' ? { access_type: 'offline', prompt: 'consent' } : { prompt: 'select_account' }) }).toString();
    return u.toString();
}
export class CalendarApiError extends Error {
    constructor(public readonly status: number, public readonly reconnect = false) { super('calendar_provider_request_failed'); }
}
async function json(url: string, init: RequestInit = {}): Promise<any> {
    const response = await fetch(url, { ...init, redirect: 'error', signal: AbortSignal.timeout(20000) });
    if (!response.ok)
        throw new CalendarApiError(response.status, response.status === 401 || response.status === 403);
    if (response.status === 204)
        return {};
    const text = await response.text();
    return text ? JSON.parse(text) : {};
}
export async function exchange(p: CalendarProvider, c: CalendarConfig, code: string, verifier: string, refresh?: string): Promise<Tokens> {
    const data = await json(p === 'google' ? 'https://oauth2.googleapis.com/token' : 'https://login.microsoftonline.com/common/oauth2/v2.0/token', {
        method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ client_id: p === 'google' ? c.google_client_id : c.microsoft_client_id,
            client_secret: p === 'google' ? GOOGLE_CALENDAR_SECRET.value() : MICROSOFT_CALENDAR_SECRET.value(),
            ...(refresh ? { grant_type: 'refresh_token', refresh_token: refresh } : { grant_type: 'authorization_code', code, code_verifier: verifier, redirect_uri: c.callback_url }) }).toString()
    });
    if (typeof data.access_token !== 'string' || !(data.refresh_token || refresh) || !Number.isFinite(data.expires_in) || data.expires_in <= 0)
        throw new CalendarApiError(401, true);
    return { access_token: data.access_token, refresh_token: data.refresh_token ?? refresh, expires_at: Date.now() + data.expires_in * 1000, scope: data.scope ?? '' };
}
function base(p: CalendarProvider) { return p === 'google' ? 'https://www.googleapis.com/calendar/v3' : 'https://graph.microsoft.com/v1.0'; }
export async function api(p: CalendarProvider, token: string, path: string, method = 'GET', body?: unknown): Promise<any> {
    if (!path.startsWith('/') || path.startsWith('//'))
        throw new Error('Invalid calendar API path');
    return json(base(p) + path, { method, headers: { Authorization: 'Bearer ' + token, 'Content-Type': 'application/json', ...(p === 'microsoft' ? { Prefer: 'outlook.timezone="UTC"' } : {}) }, ...(body !== undefined ? { body: JSON.stringify(body) } : {}) });
}
export async function calendars(p: CalendarProvider, t: string): Promise<{
    id: string;
    name: string;
}[]> {
    const result: {
        id: string;
        name: string;
    }[] = [];
    let path = p === 'google' ? '/users/me/calendarList?maxResults=250' : '/me/calendars?$select=id,name&$top=100';
    for (let page = 0; page < 10; page++) {
        const d = await api(p, t, path);
        for (const c of p === 'google' ? d.items ?? [] : d.value ?? [])
            result.push({ id: c.id, name: p === 'google' ? c.summary : c.name });
        if (p === 'google' && d.nextPageToken)
            path = '/users/me/calendarList?maxResults=250&pageToken=' + encodeURIComponent(d.nextPageToken);
        else if (p === 'microsoft' && d['@odata.nextLink'])
            path = graphPath(d['@odata.nextLink']);
        else
            return result;
    }
    throw new CalendarApiError(413);
}
export function graphPath(url: string): string {
    const u = new URL(url);
    if (u.origin !== 'https://graph.microsoft.com' || !u.pathname.startsWith('/v1.0/'))
        throw new CalendarApiError(400);
    return u.pathname.slice(5) + u.search;
}
function utc(v: string) { return /(?:Z|[+-]\d\d:\d\d)$/.test(v) ? v : v + 'Z'; }
export async function busy(p: CalendarProvider, t: string, ids: string[], from: string, to: string): Promise<{
    start: string;
    end: string;
}[]> {
    if (ids.length === 0 || ids.length > 20)
        throw failedPrecondition('Sélectionnez de 1 à 20 calendriers personnels.');
    if (p === 'google') {
        const d = await api(p, t, '/freeBusy', 'POST', { timeMin: from, timeMax: to, items: ids.map(id => ({ id })) });
        return ids.flatMap(id => { const c = d.calendars?.[id]; if (!c || c.errors?.length)
            throw new CalendarApiError(403, true); return c.busy ?? []; });
    }
    const result: {
        start: string;
        end: string;
    }[] = [];
    for (const id of ids) {
        let path = '/me/calendars/' + encodeURIComponent(id) + '/calendarView?' + new URLSearchParams({ startDateTime: from, endDateTime: to, '$select': 'id,start,end,showAs,isCancelled', '$top': '250' });
        for (let page = 0; page < 20; page++) {
            const d = await api(p, t, path);
            for (const e of d.value ?? [])
                if (!e.isCancelled && e.showAs !== 'free')
                    result.push({ start: utc(e.start.dateTime), end: utc(e.end.dateTime) });
            if (!d['@odata.nextLink'])
                break;
            if (page === 19)
                throw new CalendarApiError(413);
            path = graphPath(d['@odata.nextLink']);
        }
    }
    return result;
}
export async function revoke(p: CalendarProvider, tokens: Tokens): Promise<boolean> {
    if (p === 'microsoft')
        return false; // No token-revocation API for this delegated grant. Local credentials are erased.
    await json('https://oauth2.googleapis.com/revoke', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: new URLSearchParams({ token: tokens.refresh_token }).toString() });
    return true;
}
export function eventKey(missionId: string): string { return 'movik' + hash(missionId).slice(0, 48); }
export async function writeEvent(p: CalendarProvider, t: string, calendarId: string, missionId: string, slot: {
    start: string;
    end: string;
} | null, externalId?: string): Promise<string | null> {
    const path = p === 'google' ? '/calendars/' + encodeURIComponent(calendarId) + '/events' : '/me/calendars/' + encodeURIComponent(calendarId) + '/events';
    const key = eventKey(missionId);
    let id = externalId ?? (p === 'google' ? key : undefined);
    const propertyId = 'String {31636d01-2317-41af-8dd5-6f66f24fce7f} Name MovikMission';
    if (p === 'microsoft' && !id) {
        const filter = "singleValueExtendedProperties/Any(ep: ep/id eq '" + propertyId + "' and ep/value eq '" + key + "')";
        const found = await api(p, t, path + '?' + new URLSearchParams({ '$filter': filter, '$select': 'id', '$top': '2' }));
        if ((found.value ?? []).length > 1)
            throw new CalendarApiError(409);
        id = found.value?.[0]?.id;
    }
    if (!slot) {
        if (!id)
            return null;
        try {
            await api(p, t, path + '/' + encodeURIComponent(id), 'DELETE');
        }
        catch (e) {
            if (!(e instanceof CalendarApiError) || ![404, 410].includes(e.status))
                throw e;
        }
        return null;
    }
    const body = p === 'google' ? { summary: 'Mission Movi-K', start: { dateTime: slot.start }, end: { dateTime: slot.end }, description: 'Consultez les détails sécurisés dans votre espace Movi-K.' }
        : { subject: 'Mission Movi-K', start: { dateTime: slot.start, timeZone: 'UTC' }, end: { dateTime: slot.end, timeZone: 'UTC' }, showAs: 'busy', body: { contentType: 'text', content: 'Consultez les détails sécurisés dans votre espace Movi-K.' } };
    if (id) {
        try {
            await api(p, t, path + '/' + encodeURIComponent(id), 'PATCH', body);
            return id;
        }
        catch (e) {
            if (!(e instanceof CalendarApiError) || ![404, 410].includes(e.status))
                throw e;
        }
    }
    if (p === 'google') {
        // Deleted IDs can remain as tombstones. Deterministic successor IDs also
        // recover a lost POST response without creating another event.
        const suffix = id?.startsWith(key + 'a') ? Number(id.slice(key.length + 1)) : 0;
        const initial = Number.isSafeInteger(suffix) && suffix >= 0 ? suffix : 0;
        for (let attempt = initial; attempt < initial + 5; attempt++) {
            const candidate = attempt === 0 ? key : key + 'a' + attempt;
            try {
                await api(p, t, path, 'POST', { ...body, id: candidate });
                return candidate;
            }
            catch (e) {
                if (!(e instanceof CalendarApiError) || e.status !== 409)
                    throw e;
                try {
                    await api(p, t, path + '/' + candidate, 'PATCH', body);
                    return candidate;
                }
                catch (patchError) {
                    if (!(patchError instanceof CalendarApiError) || ![404, 410].includes(patchError.status))
                        throw patchError;
                }
            }
        }
        throw new CalendarApiError(409);
    }
    const d = await api(p, t, path, 'POST', { ...body, transactionId: key, singleValueExtendedProperties: [{ id: propertyId, value: key }] });
    if (typeof d.id !== 'string')
        throw new CalendarApiError(502);
    return d.id;
}
