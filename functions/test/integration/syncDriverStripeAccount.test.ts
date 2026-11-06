// « Vérifier l'état chez Stripe » (2026-11-06): copies the connected
// account's state onto the profile so the app can show "under review"
// right after the driver finished the Stripe form, without waiting for
// the next account.updated event. Admin may sync any driver.
import { admin, db } from '../../src/lib/admin';
import { syncDriverStripeAccount } from '../../src/functions/syncDriverStripeAccount';
import { setPaymentProviderForTesting } from '../../src/payment/paymentProviderFactory';
import { FakePaymentProvider } from '../testUtils/fakePaymentProvider';

const email = 'chauffeur.sync@example.com';
let uid: string;
let provider: FakePaymentProvider;
const call = (data: Record<string, unknown> = {}, roles = ['driver'], who = uid) =>
  ({ data, auth: { uid: who, token: { roles, role: roles[0] } }, rawRequest: {}, acceptsStreaming: false } as any);
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
  await db.recursiveDelete(db.collection('audit_logs'));
});

test('no account in the active environment => failed-precondition, nothing written', async () => {
  await profile().set({ status: 'approved' });
  await expect(syncDriverStripeAccount.run(call())).rejects.toMatchObject({ code: 'failed-precondition' });
  expect((await profile().get()).data()).not.toHaveProperty('stripe_details_submitted');
});

test('driver syncs own account: details submitted, nothing due => written once, audited, not payout-ready', async () => {
  await profile().set({
    status: 'approved',
    stripe_connected_account_id: 'acct_sync_1',
    stripe_connected_account_environment: provider.environment,
    stripe_charges_enabled: false,
    stripe_payouts_enabled: false,
  });
  const r = await syncDriverStripeAccount.run(call());
  expect(r).toMatchObject({ success: true, updated: true, details_submitted: true, requirements_currently_due: 0, payout_ready: false });
  const data = (await profile().get()).data()!;
  expect(data.stripe_details_submitted).toBe(true);
  expect(data.stripe_requirements_currently_due).toBe(0);
  expect(data.stripe_account_synced_at).toBeTruthy();

  // Same state again => nothing written, no second audit line.
  const again = await syncDriverStripeAccount.run(call());
  expect(again.updated).toBe(false);
  const audits = await db.collection('audit_logs').where('target_id', '==', uid).get();
  expect(audits.size).toBe(1);
});

test('once Stripe enabled charges and payouts the driver is payout-ready', async () => {
  await profile().set({
    status: 'approved',
    stripe_connected_account_id: 'acct_sync_2',
    stripe_connected_account_environment: provider.environment,
  });
  provider.driverAccountStatus = { chargesEnabled: true, payoutsEnabled: true, detailsSubmitted: true, currentlyDue: 0, disabledReason: null };
  const r = await syncDriverStripeAccount.run(call());
  expect(r).toMatchObject({ payout_ready: true, charges_enabled: true, payouts_enabled: true });
});

test('admin may sync another driver; a customer may not', async () => {
  await profile().set({
    status: 'approved',
    stripe_connected_account_id: 'acct_sync_3',
    stripe_connected_account_environment: provider.environment,
  });
  await expect(syncDriverStripeAccount.run(call({ driverId: uid }, ['customer'], 'someone_else'))).rejects.toMatchObject({ code: 'permission-denied' });
  const r = await syncDriverStripeAccount.run(call({ driverId: uid }, ['admin'], 'admin_user'));
  expect(r.success).toBe(true);
  const audit = (await db.collection('audit_logs').where('target_id', '==', uid).get()).docs[0].data();
  expect(audit.actor_user_id).toBe('admin_user');
});
