// Private pilot administration (2026-10-22): testers by email, on/off switch,
// trial booking terms that never replace approved terms.
import { admin, db } from '../../src/lib/admin';
import { adminPilotSetup } from '../../src/functions/adminPilotSetup';
import { getBookingPolicy } from '../../src/lib/bookingServer';
import { isPilotUser } from '../../src/lib/runtimeFlags';
import { TRIAL_POLICY_VERSION } from '../../src/config/trialBookingPolicy';
import { testBookingPolicy } from '../testUtils/bookingPolicyFixture';

const call = (data: unknown, uid = 'pilot_staff', roles = ['admin']) =>
  ({ data, auth: { uid, token: { roles, role: roles[0] } }, rawRequest: {}, acceptsStreaming: false } as any);
const email = 'testeur.pilote@example.com';
let testerUid: string;

beforeEach(async () => {
  testerUid = (await admin.auth().createUser({ email, password: 'synthetic-password' })).uid;
});
afterEach(async () => {
  if (process.env.GCLOUD_PROJECT !== 'demo-movik-test' || process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8080') throw Error('cleanup isolation');
  await admin.auth().deleteUser(testerUid).catch(() => undefined);
  for (const c of ['system_config', 'audit_logs']) await db.recursiveDelete(db.collection(c));
});

test('admins only', async () => {
  await expect(adminPilotSetup.run(call({ action: 'get' }, 'someone', ['customer'])))
    .rejects.toMatchObject({ code: 'permission-denied' });
});

test('testers are added by the email of an existing account, listed, enabled and removed', async () => {
  await expect(adminPilotSetup.run(call({ action: 'addTester', email: 'personne@example.com' })))
    .rejects.toMatchObject({ code: 'not-found' });
  expect(await adminPilotSetup.run(call({ action: 'addTester', email: ' Testeur.Pilote@example.com ' })))
    .toMatchObject({ success: true, uid: testerUid });
  // Listed but not yet enabled: still closed.
  expect(await isPilotUser(testerUid)).toBe(false);
  await adminPilotSetup.run(call({ action: 'setEnabled', enabled: true }));
  expect(await isPilotUser(testerUid)).toBe(true);
  expect(await adminPilotSetup.run(call({ action: 'get' })))
    .toMatchObject({ enabled: true, testers: [{ uid: testerUid, email }] });

  await adminPilotSetup.run(call({ action: 'removeTester', uid: testerUid }));
  expect(await isPilotUser(testerUid)).toBe(false);
  const audits = await db.collection('audit_logs').where('source_function', '==', 'adminPilotSetup').get();
  expect(audits.docs.map(d => d.data().action).sort())
    .toEqual(['pilot_enabled', 'pilot_tester_added', 'pilot_tester_removed']);
});

test('trial terms are a valid policy that opens confirmation, never over approved terms', async () => {
  expect((await adminPilotSetup.run(call({ action: 'get' }))).terms).toMatchObject({ published: false });
  expect(await adminPilotSetup.run(call({ action: 'publishTrialTerms' })))
    .toMatchObject({ success: true, version: TRIAL_POLICY_VERSION });
  const policy = await getBookingPolicy();
  expect(policy).toMatchObject({ version: TRIAL_POLICY_VERSION, setup_enabled: true });
  expect(policy!.documents.booking.content.fr).toContain("VERSION D'ESSAI");
  expect(policy!.documents.booking.content.fr).toContain('30 $');
  expect((await adminPilotSetup.run(call({ action: 'get' }))).terms)
    .toMatchObject({ published: true, version: TRIAL_POLICY_VERSION, trial: true });

  await db.doc('system_config/booking_policy').set(testBookingPolicy('APPROVED-REAL'));
  await expect(adminPilotSetup.run(call({ action: 'publishTrialTerms' })))
    .rejects.toMatchObject({ code: 'failed-precondition' });
  expect((await getBookingPolicy())!.version).toBe('APPROVED-REAL');
});
