// 2026-11-06 : version minimale de l'app Android (app_config/app_versions),
// réglée depuis le Centre de commande, lue par l'app au démarrage.
import { RulesTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc } from 'firebase/firestore';
import { createTestEnv } from './setup';
import { db } from '../../src/lib/admin';
import { updateAppVersionPolicy } from '../../src/functions/updateAppVersionPolicy';
import { APP_CONFIG_COLLECTION, APP_VERSIONS_DOC_ID } from '../../src/lib/appVersionPolicy';

const call = (data: unknown, uid = 'ver_staff', roles = ['admin']) =>
  ({ data, auth: { uid, token: { roles, role: roles[0] } }, rawRequest: {}, acceptsStreaming: false } as any);

const path = `${APP_CONFIG_COLLECTION}/${APP_VERSIONS_DOC_ID}`;

afterEach(async () => {
  if (process.env.GCLOUD_PROJECT !== 'demo-movik-test' || process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8080') throw Error('cleanup isolation');
  for (const c of [APP_CONFIG_COLLECTION, 'audit_logs']) await db.recursiveDelete(db.collection(c));
});

test('admins only (get et save)', async () => {
  for (const role of ['customer', 'driver', 'analyst']) {
    await expect(updateAppVersionPolicy.run(call({ action: 'get' }, 'x', [role]))).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(updateAppVersionPolicy.run(call({ action: 'save', android_min_build: 10 }, 'x', [role]))).rejects.toMatchObject({
      code: 'permission-denied',
    });
  }
  await expect(updateAppVersionPolicy.run({ data: { action: 'get' }, rawRequest: {}, acceptsStreaming: false } as any)).rejects.toMatchObject({
    code: 'unauthenticated',
  });
});

test('get sans document : aucun minimum', async () => {
  const r = (await updateAppVersionPolicy.run(call({ action: 'get' }))) as any;
  expect(r).toMatchObject({ success: true, android_min_build: 0, note: '' });
});

test('save : minimum en vigueur, note gardée, audit old/new', async () => {
  const first = (await updateAppVersionPolicy.run(call({ action: 'save', android_min_build: 10, note: ' dépôt 25 $ ' }))) as any;
  expect(first).toMatchObject({ success: true, android_min_build: 10, note: 'dépôt 25 $', previous_android_min_build: 0 });
  const second = (await updateAppVersionPolicy.run(call({ action: 'save', android_min_build: 11 }))) as any;
  expect(second).toMatchObject({ android_min_build: 11, note: '', previous_android_min_build: 10 });
  const snap = await db.doc(path).get();
  expect(snap.data()).toMatchObject({ android_min_build: 11, note: '', updated_by_user_id: 'ver_staff' });
  const r = (await updateAppVersionPolicy.run(call({ action: 'get' }))) as any;
  expect(r).toMatchObject({ android_min_build: 11, note: '' });
  const audits = await db.collection('audit_logs').where('source_function', '==', 'updateAppVersionPolicy').get();
  expect(audits.size).toBe(2);
  const metas = audits.docs.map((d) => d.data().metadata).sort((a, b) => a.newValues.android_min_build - b.newValues.android_min_build);
  expect(metas[0]).toMatchObject({ oldValues: { android_min_build: 0 }, newValues: { android_min_build: 10 }, wasBootstrapped: true });
  expect(metas[1]).toMatchObject({ oldValues: { android_min_build: 10 }, newValues: { android_min_build: 11 }, wasBootstrapped: false });
});

test.each([
  { android_min_build: -1 },
  { android_min_build: 100_001 },
  { android_min_build: 9.5 },
  { android_min_build: '10' },
  { android_min_build: 10, note: 'x'.repeat(201) },
  {},
])('save invalide refusé, rien d’écrit : %p', async (payload) => {
  await expect(updateAppVersionPolicy.run(call({ action: 'save', ...payload }))).rejects.toMatchObject({ code: 'invalid-argument' });
  expect((await db.doc(path).get()).exists).toBe(false);
});

test('règles : lecture publique (même sans connexion), écriture directe refusée même pour un admin', async () => {
  let testEnv: RulesTestEnvironment | null = null;
  try {
    testEnv = await createTestEnv();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), path), { android_min_build: 10, note: '' });
    });
    await assertSucceeds(getDoc(doc(testEnv.unauthenticatedContext().firestore(), path)));
    const customer = testEnv.authenticatedContext('ver_rules_customer', { role: 'customer' });
    await assertSucceeds(getDoc(doc(customer.firestore(), path)));
    const adminCtx = testEnv.authenticatedContext('ver_rules_admin', { role: 'admin' });
    await assertFails(setDoc(doc(adminCtx.firestore(), path), { android_min_build: 99 }));
    await assertFails(setDoc(doc(testEnv.unauthenticatedContext().firestore(), path), { android_min_build: 99 }));
  } finally {
    if (testEnv) await testEnv.cleanup();
  }
});
