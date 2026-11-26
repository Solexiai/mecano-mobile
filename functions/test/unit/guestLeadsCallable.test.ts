// LOCAL TESTS ONLY: real callables, mocked Firestore. Price with the email
// only (2026-11-26): the guest profile is written by the server, never over
// a real account.
jest.mock('../../src/lib/admin', () => {
  const { Timestamp } = jest.requireActual('firebase-admin/firestore');
  return { admin: { firestore: { Timestamp } }, db: { collection: jest.fn(), runTransaction: jest.fn() } };
});
import { db } from '../../src/lib/admin';
import { handleCompleteGuestAccount, handleRegisterQuoteLead } from '../../src/functions/guestLeads';
import { GUEST_EMAIL_MAX_CHANGES, GUEST_LEADS_PER_IP_PER_DAY } from '../../src/lib/guestLead';

let data: Record<string, any>;
const guest = (uid = 'guest-1', email: unknown = 'Marie@Exemple.com', ip = '198.51.100.7', extra: Record<string, unknown> = {}) => ({
  auth: { uid, token: { firebase: { sign_in_provider: 'anonymous' } } },
  data: { email, locale: 'fr', ...extra },
  rawRequest: { headers: { 'x-forwarded-for': ip } },
}) as any;
const account = (uid = 'guest-1', email = 'marie@exemple.com', extra: Record<string, unknown> = {}) => ({
  auth: { uid, token: { email, firebase: { sign_in_provider: 'password' } } },
  data: { ...extra },
  rawRequest: { headers: { 'x-forwarded-for': '198.51.100.7' } },
}) as any;

beforeEach(() => {
  jest.clearAllMocks();
  data = {};
  (db.collection as jest.Mock).mockImplementation((name: string) => ({ doc: (id: string) => ({ path: `${name}/${id}` }) }));
  (db.runTransaction as jest.Mock).mockImplementation(async (fn) => {
    let wrote = false;
    return fn({
      get: async (r: any) => { if (wrote) throw Error('read after write'); return { data: () => data[r.path] }; },
      set: (r: any, value: any, options?: { merge?: boolean }) => {
        wrote = true;
        data[r.path] = options?.merge ? { ...(data[r.path] ?? {}), ...value } : value;
      },
    });
  });
});

test('the typed email becomes a guest customer profile, in lower case', async () => {
  await expect(handleRegisterQuoteLead(guest('guest-1', ' Marie@Exemple.com ', '198.51.100.7', { locale: 'en' }))).resolves.toEqual({ saved: true });
  expect(data['users/guest-1']).toMatchObject({
    uid: 'guest-1', email: 'marie@exemple.com', roles: ['customer'], guest: true,
    is_disabled: false, email_verified: false, preferred_locale: 'en', guest_email_changes: 1,
  });
  expect(typeof data['users/guest-1'].created_at).toBe('string');
  // The visitor's address is stored hashed, never as written.
  expect(Object.keys(data).some((path) => path.includes('198.51.100.7'))).toBe(false);
});

test('the same email again costs nothing; a corrected one is counted and capped', async () => {
  await handleRegisterQuoteLead(guest());
  const created = data['users/guest-1'].created_at;
  await handleRegisterQuoteLead(guest());
  expect(data['users/guest-1'].guest_email_changes).toBe(1);
  for (let i = 2; i <= GUEST_EMAIL_MAX_CHANGES; i++) await handleRegisterQuoteLead(guest('guest-1', `marie${i}@exemple.com`));
  expect(data['users/guest-1']).toMatchObject({ email: `marie${GUEST_EMAIL_MAX_CHANGES}@exemple.com`, created_at: created });
  await expect(handleRegisterQuoteLead(guest('guest-1', 'encore@exemple.com'))).rejects.toMatchObject({ code: 'resource-exhausted' });
  expect(data['users/guest-1'].email).toBe(`marie${GUEST_EMAIL_MAX_CHANGES}@exemple.com`);
});

test('one address cannot register an endless list of emails in a day', async () => {
  for (let i = 0; i < GUEST_LEADS_PER_IP_PER_DAY; i++) await handleRegisterQuoteLead(guest(`guest-${i}`, `p${i}@exemple.com`));
  await expect(handleRegisterQuoteLead(guest('guest-x', 'trop@exemple.com'))).rejects.toMatchObject({ code: 'resource-exhausted' });
  expect(data['users/guest-x']).toBeUndefined();
  // Another visitor is not affected.
  await expect(handleRegisterQuoteLead(guest('guest-y', 'autre@exemple.com', '203.0.113.5'))).resolves.toEqual({ saved: true });
});

test.each([['pas un courriel'], [''], [null], [42]])('invalid email %p writes nothing', async (email) => {
  await expect(handleRegisterQuoteLead(guest('guest-1', email))).rejects.toMatchObject({ code: 'invalid-argument' });
  expect(data).toEqual({});
});

test('never over a real profile, and a real account has nothing to register', async () => {
  data['users/guest-1'] = { uid: 'guest-1', email: 'vrai@exemple.com', roles: ['customer'] };
  await expect(handleRegisterQuoteLead(guest())).rejects.toMatchObject({ code: 'failed-precondition' });
  expect(data['users/guest-1'].email).toBe('vrai@exemple.com');
  await expect(handleRegisterQuoteLead(account())).resolves.toEqual({ saved: false, reason: 'account' });
  expect(db.runTransaction).toHaveBeenCalledTimes(1);
});

test('signed out, or a driver account: refused', async () => {
  await expect(handleRegisterQuoteLead({ data: { email: 'a@exemple.com' } } as any)).rejects.toMatchObject({ code: 'unauthenticated' });
  const driver = guest();
  driver.auth.token.roles = ['driver'];
  await expect(handleRegisterQuoteLead(driver)).rejects.toMatchObject({ code: 'failed-precondition' });
  expect(data).toEqual({});
});

test('after the password, the guest profile becomes an ordinary customer with the sign-in email', async () => {
  await handleRegisterQuoteLead(guest('guest-1', 'tape@exemple.com'));
  const created = data['users/guest-1'].created_at;
  await expect(handleCompleteGuestAccount(account('guest-1', 'marie@exemple.com', { fullName: '  Marie Tremblay ', email: 'pirate@exemple.com' })))
    .resolves.toEqual({ completed: true });
  expect(data['users/guest-1']).toMatchObject({
    uid: 'guest-1', email: 'marie@exemple.com', roles: ['customer'], guest: false,
    full_name: 'Marie Tremblay', created_at: created, email_verified: false,
  });
});

test('completing needs a real sign-in and never touches an ordinary profile', async () => {
  await expect(handleCompleteGuestAccount(guest())).rejects.toMatchObject({ code: 'failed-precondition' });
  data['users/guest-1'] = { uid: 'guest-1', email: 'vrai@exemple.com', roles: ['customer', 'driver'], full_name: 'Marc' };
  await expect(handleCompleteGuestAccount(account('guest-1', 'autre@exemple.com', { fullName: 'X' }))).resolves.toEqual({ completed: false });
  expect(data['users/guest-1']).toEqual({ uid: 'guest-1', email: 'vrai@exemple.com', roles: ['customer', 'driver'], full_name: 'Marc' });
  // No profile at all (the email step was skipped somehow): an ordinary customer profile is created.
  await expect(handleCompleteGuestAccount(account('guest-2', 'neuf@exemple.com'))).resolves.toEqual({ completed: true });
  expect(data['users/guest-2']).toMatchObject({ uid: 'guest-2', email: 'neuf@exemple.com', roles: ['customer'], guest: false });
});
