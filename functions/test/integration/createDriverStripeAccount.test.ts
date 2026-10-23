// Driver payouts setup (Stripe Connect Express), 2026-10-23:
// - only an APPROVED driver can start it (the screen hid the button, the
//   server did not check);
// - Stripe onboarding links expire and work once: every call on an
//   unfinished account returns a NEW link, so a driver can resume;
// - a finished account (charges + payouts enabled) gets no link.
import { admin, db } from '../../src/lib/admin';
import { createDriverStripeAccount } from '../../src/functions/createDriverStripeAccount';
import { setPaymentProviderForTesting } from '../../src/payment/paymentProviderFactory';
import { FakePaymentProvider } from '../testUtils/fakePaymentProvider';

const email = 'chauffeur.connect@example.com';
let uid: string;
let provider: FakePaymentProvider;
const call = (roles = ['driver']) =>
  ({ data: {}, auth: { uid, token: { roles, role: roles[0] } }, rawRequest: {}, acceptsStreaming: false } as any);
const profile = () => db.doc(`driver_profiles/${uid}`);

beforeEach(async () => {
  provider = new FakePaymentProvider();
  setPaymentProviderForTesting(provider);
  uid = (await admin.auth().createUser({ email, password: 'synthetic-password' })).uid;
});
afterEach(async () => {
  setPaymentProviderForTesting(null);
  if (process.env.GCLOUD_PROJECT !== 'demo-movik-test' || process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8080') throw Error('cleanup isolation');
  await admin.auth().deleteUser(uid).catch(() => undefined);
  await db.recursiveDelete(db.collection('driver_profiles'));
});

test('only drivers, and only once Movi-K approved the file', async () => {
  await expect(createDriverStripeAccount.run(call(['customer']))).rejects.toMatchObject({ code: 'permission-denied' });
  await expect(createDriverStripeAccount.run(call())).rejects.toMatchObject({ code: 'failed-precondition' });
  await profile().set({ status: 'pending_review' });
  await expect(createDriverStripeAccount.run(call())).rejects.toMatchObject({ code: 'failed-precondition' });
  expect(provider.onboardingLinkCount).toBe(0);
});

test('an approved driver gets an account and a new link each time until the setup is finished', async () => {
  await profile().set({ status: 'approved' });
  const first = await createDriverStripeAccount.run(call());
  expect(first).toMatchObject({ success: true, alreadyExisted: false, active: false, connectedAccountId: `fake_acct_${uid}` });
  expect(first.onboardingUrl).toMatch(/^https:\/\/connect\.stripe\.com\//);

  const second = await createDriverStripeAccount.run(call());
  expect(second).toMatchObject({ success: true, alreadyExisted: true, active: false, connectedAccountId: `fake_acct_${uid}` });
  expect(second.onboardingUrl).not.toBe(first.onboardingUrl);
  expect((await profile().get()).data()).toMatchObject({ stripe_connected_account_id: `fake_acct_${uid}`, stripe_onboarding_url: second.onboardingUrl });

  // Finished at Stripe (synced by the account.updated webhook): no link.
  await profile().set({ stripe_charges_enabled: true, stripe_payouts_enabled: true }, { merge: true });
  const done = await createDriverStripeAccount.run(call());
  expect(done).toMatchObject({ success: true, active: true, onboardingUrl: null });
  expect(provider.onboardingLinkCount).toBe(2);
});
