// Prix avec le courriel seulement (2026-11-26) : règles pures.
import {
  guestMayGetPrice,
  guestSeriesAllowed,
  isAnonymousToken,
  leadEmailKey,
  normalizeLeadEmail,
} from '../../src/lib/guestLead';

const DAY = 24 * 3600_000;

test.each([
  ['  Marie@Exemple.COM ', 'marie@exemple.com'],
  ['jean.tremblay+movik@videotron.ca', 'jean.tremblay+movik@videotron.ca'],
  ["o'neil@exemple.ca", "o'neil@exemple.ca"],
  ['marie<script>@exemple.ca', null],
  ['marie@exemple', null],
  ['marie exemple@x.ca', null],
  ['@exemple.ca', null],
  ['marie@@exemple.ca', null],
  ['marie@exemple..ca', null],
  ['marie@127.0.0.1', null],
  ['a@b.c', null],
  [`${'x'.repeat(65)}@exemple.ca`, null],
  [null, null],
  [42, null],
])('normalizeLeadEmail(%p) → %p', (raw, expected) => {
  expect(normalizeLeadEmail(raw)).toBe(expected);
});

test('the address is never the document id as written', () => {
  const key = leadEmailKey(' Marie@Exemple.com ');
  expect(key).toMatch(/^[0-9a-f]{64}$/);
  expect(key).toBe(leadEmailKey('marie@exemple.com'));
  expect(key).not.toContain('marie');
});

test('only a session without email or password is anonymous', () => {
  expect(isAnonymousToken({ firebase: { sign_in_provider: 'anonymous' } })).toBe(true);
  expect(isAnonymousToken({ firebase: { sign_in_provider: 'password' } })).toBe(false);
  expect(isAnonymousToken({})).toBe(false);
  expect(isAnonymousToken(undefined)).toBe(false);
});

test('a guest gets a price only after leaving an email', () => {
  expect(guestMayGetPrice(undefined)).toBe(false);
  expect(guestMayGetPrice({ guest: true })).toBe(false);
  expect(guestMayGetPrice({ guest: true, email: 'pas un courriel' })).toBe(false);
  expect(guestMayGetPrice({ email: 'marie@exemple.com' })).toBe(false);
  expect(guestMayGetPrice({ guest: true, email: 'marie@exemple.com' })).toBe(true);
});

test('one follow-up series per typed address per cooldown, whatever the session', () => {
  const now = 100 * DAY;
  expect(guestSeriesAllowed(undefined, 'a', now, 14 * DAY)).toBe(true);
  // The same session carries on with its own series (day 1, then day 3).
  expect(guestSeriesAllowed({ user_id: 'a', started_at_ms: now - 2 * DAY }, 'a', now, 14 * DAY)).toBe(true);
  // Another session that typed the same address waits.
  expect(guestSeriesAllowed({ user_id: 'a', started_at_ms: now - 2 * DAY }, 'b', now, 14 * DAY)).toBe(false);
  expect(guestSeriesAllowed({ user_id: 'a', started_at_ms: now - 14 * DAY }, 'b', now, 14 * DAY)).toBe(true);
  expect(guestSeriesAllowed({ user_id: 'a' }, 'b', now, 14 * DAY)).toBe(true);
});
