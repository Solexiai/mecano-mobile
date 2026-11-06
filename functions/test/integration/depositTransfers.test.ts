// ---------------------------------------------------------------------------
// Dépôt de réservation (2026-11-06) — virements au chauffeur financés par le
// dépôt (payment/depositTransferOrchestration.ts) :
//   1. solde capturé trop petit pour la part du chauffeur → complément ;
//   2. dépôt gardé → 20 $ chauffeur / 5 $ Movi-K, registre et snapshot.
// Documents seedés directement : la mécanique de capture est testée ailleurs.
// ---------------------------------------------------------------------------
import { admin, db } from '../../src/lib/admin';
import { FakePaymentProvider } from '../testUtils/fakePaymentProvider';
import { setPaymentProviderForTesting } from '../../src/payment/paymentProviderFactory';
import {
  DEPOSIT_KEPT_SPLIT, depositKeptSnapshotId, depositTransferId, settleDepositDriverShortfall, settleKeptDeposit,
} from '../../src/payment/depositTransferOrchestration';
import { computeMissionFinancialBalance } from '../../src/lib/missionFinancialBalance';

const customer = 'dt_customer', driver = 'dt_driver', account = 'acct_dt_driver';
let provider: FakePaymentProvider;
const now = () => admin.firestore.Timestamp.now();

async function seedMission(missionId: string, extra: Record<string, unknown>, balance?: Record<string, unknown>) {
  const depositId = `deposit_quote_${missionId}`;
  await db.doc(`payments/${depositId}`).set({
    payment_id: depositId, mission_id: missionId, customer_id: customer, driver_id: '', purpose: 'deposit',
    status: 'captured', currency: 'CAD', amount_authorized_minor: 0, amount_captured_minor: 2500, amount_refunded_minor: 0,
    application_fee_minor: 0, provider: 'stripe', provider_customer_id: 'cus_dt', provider_payment_method_id: 'pm_dt',
    provider_payment_intent_id: 'pi_dt_deposit', provider_charge_id: 'ch_dt_deposit', connected_account_id: null,
    idempotency_key: 'k', stripe_environment: 'test', created_at: now(), updated_at: now(), captured_at: now(),
  });
  if (balance) {
    await db.doc(`payments/balance_${missionId}`).set({
      payment_id: `balance_${missionId}`, mission_id: missionId, customer_id: customer, driver_id: driver,
      status: 'captured', currency: 'CAD', amount_authorized_minor: 3400, amount_captured_minor: 3400, amount_refunded_minor: 0,
      application_fee_minor: 0, provider: 'stripe', provider_customer_id: 'cus_dt', provider_payment_method_id: 'pm_dt',
      provider_payment_intent_id: 'pi_dt_balance', provider_charge_id: 'ch_dt_balance', connected_account_id: account,
      idempotency_key: 'k2', stripe_environment: 'test', created_at: now(), updated_at: now(), captured_at: now(),
      ...balance,
    });
  }
  await db.doc(`delivery_requests/${missionId}`).set({
    customer_id: customer, driver_id: driver, status: 'completed', customer_total_minor: 5900,
    active_payment_id: balance ? `balance_${missionId}` : null,
    deposit: { policy_version: 'MOVIK-DEPOSIT-20261106-001', amount_minor: 2500, currency: 'CAD', payment_id: depositId,
      status: 'captured', captured_at: now(), updated_at: now() },
    ...extra,
  });
  return depositId;
}

beforeEach(async () => {
  provider = new FakePaymentProvider(); setPaymentProviderForTesting(provider);
  await db.doc(`driver_profiles/${driver}`).set({ status: 'approved', full_name: 'DT Driver',
    stripe_connected_account_id: account, stripe_connected_account_environment: 'test', stripe_charges_enabled: true, stripe_payouts_enabled: true });
});
afterEach(async () => {
  setPaymentProviderForTesting(null);
  for (const col of ['delivery_requests', 'payments', 'deposit_transfers']) {
    const rows = await db.collection(col).where('customer_id', '==', customer).get();
    for (const r of rows.docs) await r.ref.delete();
  }
  for (const col of ['transaction_ledger', 'financial_snapshots']) {
    const rows = await db.collection(col).where('mission_id', 'in', ['m_short', 'm_kept', 'm_noshort']).get();
    for (const r of rows.docs) await r.ref.delete();
  }
  await db.doc(`driver_profiles/${driver}`).delete();
});

test('petite livraison : la part manquante du chauffeur est virée depuis la charge du dépôt, une seule fois', async () => {
  await seedMission('m_short', {}, { deposit_applied_minor: 2500, deposit_driver_shortfall_minor: 900 });
  expect(await settleDepositDriverShortfall('m_short')).toBe('transferred');
  expect(await settleDepositDriverShortfall('m_short')).toBe('already_done');
  expect(provider.createdTransferParams).toHaveLength(1);
  expect(provider.createdTransferParams[0]).toMatchObject({
    connectedAccountId: account, amountMinor: 900, sourceChargeId: 'ch_dt_deposit', transferGroup: 'mission_m_short' });
  const transfer = (await db.doc(`deposit_transfers/${depositTransferId('m_short', 'driver_shortfall')}`).get()).data()!;
  expect(transfer).toMatchObject({ status: 'succeeded', kind: 'driver_shortfall', amount_minor: 900, driver_id: driver });
  const mission = (await db.doc('delivery_requests/m_short').get()).data()!;
  expect(mission.deposit.driver_shortfall_transfer).toMatchObject({ amount_minor: 900 });
  // Le bilan de mission compte ce virement comme payé au chauffeur.
  const balance = await computeMissionFinancialBalance('m_short');
  expect(balance.driver_paid_minor).toBe(3400 + 900);
});

test('solde suffisant : aucun virement', async () => {
  await seedMission('m_noshort', {}, { deposit_applied_minor: 2500, deposit_driver_shortfall_minor: 0 });
  expect(await settleDepositDriverShortfall('m_noshort')).toBe('not_applicable');
  expect(provider.createdTransferParams).toHaveLength(0);
});

test('dépôt gardé : 20 $ au chauffeur, 5 $ à Movi-K, registre et snapshot « frais »', async () => {
  const depositId = await seedMission('m_kept', { status: 'cancelled', cancellation_reason: 'customer_request' });
  await db.doc('delivery_requests/m_kept').update({ 'deposit.status': 'kept' });
  expect(await settleKeptDeposit('m_kept')).toBe('transferred');
  expect(await settleKeptDeposit('m_kept')).toBe('already_done');
  expect(provider.createdTransferParams).toHaveLength(1);
  expect(provider.createdTransferParams[0]).toMatchObject({ connectedAccountId: account, amountMinor: DEPOSIT_KEPT_SPLIT.driver_minor, sourceChargeId: 'ch_dt_deposit' });
  const snapshot = (await db.doc(`financial_snapshots/${depositKeptSnapshotId('m_kept')}`).get()).data()!;
  expect(snapshot).toMatchObject({ snapshot_kind: 'mission_fee', fee_kind: 'deposit_kept', driver_id: driver, customer_total_minor: 2500,
    driver_net_mission_earnings: 20, platform_commission_amount: 5, status: 'confirmed', payment_id: depositId });
  const ledger = await db.collection('transaction_ledger').where('mission_id', '==', 'm_kept').get();
  const byType = Object.fromEntries(ledger.docs.map(d => [d.data().type, d.data().amount_minor]));
  expect(byType).toEqual({ driver_earning: 2000, platform_commission: 500 });
  const balance = await computeMissionFinancialBalance('m_kept');
  expect(balance.driver_paid_minor).toBe(2000);
});

test('virement refusé : noté, aucune écriture au registre, relance possible', async () => {
  await seedMission('m_kept', { status: 'cancelled' });
  await db.doc('delivery_requests/m_kept').update({ 'deposit.status': 'kept' });
  setPaymentProviderForTesting(new FakePaymentProvider({ forceTransferFailure: true }));
  expect(await settleKeptDeposit('m_kept')).toBe('failed');
  expect((await db.doc(`deposit_transfers/${depositTransferId('m_kept', 'deposit_kept')}`).get()).data()).toMatchObject({ status: 'failed', attempts: 1 });
  expect((await db.collection('transaction_ledger').where('mission_id', '==', 'm_kept').get()).empty).toBe(true);
  setPaymentProviderForTesting(provider);
  expect(await settleKeptDeposit('m_kept')).toBe('transferred');
  expect((await db.doc(`deposit_transfers/${depositTransferId('m_kept', 'deposit_kept')}`).get()).data()).toMatchObject({ status: 'succeeded', attempts: 2 });
});
