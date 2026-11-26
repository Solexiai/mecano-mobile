// LOCAL TESTS ONLY: real callable, mocked provider and Firestore. Public
// photo recognition of the estimate page (2026-11-26).
jest.mock('../../src/lib/admin', () => {
  const { Timestamp } = jest.requireActual('firebase-admin/firestore');
  return { admin: { firestore: { Timestamp } }, db: { doc: jest.fn(), collection: jest.fn(), runTransaction: jest.fn() } };
});
jest.mock('../../src/lib/openAiPhotoAnalyzer', () => ({ analyzeWithOpenAi: jest.fn() }));
jest.mock('firebase-functions/params', () => ({
  ...jest.requireActual('firebase-functions/params'),
  defineSecret: () => ({ value: () => 'FAKE-KEY' }),
}));
import { db } from '../../src/lib/admin';
import { analyzeWithOpenAi } from '../../src/lib/openAiPhotoAnalyzer';
import { clearEstimateCachesForTesting } from '../../src/functions/estimateDeliveryPrice';
import { handleEstimateItemFromPhoto } from '../../src/functions/estimateItemFromPhoto';
import { defaultItemClassFees } from '../../src/lib/itemClassFees';
import { PUBLIC_PHOTO_LIMITS } from '../../src/lib/publicPhotoEstimate';
import { buildPricingConfig } from './fixtures';

const image = Buffer.concat([Buffer.from([255, 216, 255]), Buffer.alloc(32)]).toString('base64');
let data: Record<string, any>;
let tx: any;
const request = (ip = '198.51.100.9', overrides: Record<string, unknown> = {}) => ({
  data: { imageBase64: image, locale: 'fr', consent: true, ...overrides },
  rawRequest: { headers: { 'x-forwarded-for': ip } },
}) as any;

beforeEach(() => {
  jest.clearAllMocks();
  clearEstimateCachesForTesting();
  const config = buildPricingConfig();
  config.item_class_fees = defaultItemClassFees();
  data = {
    'system_config/photo_analysis': { enabled: true, provider: 'openai', model: 'TEST-MODEL', globalDailyLimit: 5 },
    'pricing_configs/active': { active_pricing_version: config.pricing_version },
    [`pricing_versions/${config.pricing_version}`]: config,
  };
  const ref = (path: string) => ({ path, get: async () => ({ exists: data[path] !== undefined, data: () => data[path] }) });
  (db.doc as jest.Mock).mockImplementation(ref);
  (db.collection as jest.Mock).mockImplementation((name: string) => ({ doc: (id: string) => ref(`${name}/${id}`) }));
  let wrote = false;
  tx = {
    get: jest.fn(async (r: any) => { if (wrote) throw Error('read after write'); return { data: () => data[r.path] }; }),
    set: jest.fn((r: any, value: any) => { wrote = true; data[r.path] = value; }),
  };
  (db.runTransaction as jest.Mock).mockImplementation(async (fn) => { wrote = false; return fn(tx); });
  (analyzeWithOpenAi as jest.Mock).mockResolvedValue({
    category: 'sofa', label: 'Divan sectionnel', confidence: 'high', special_handling: false, reason: 'ordinary',
  });
});

test('a photo gives the item and its weight; only usage counters are written', async () => {
  await expect(handleEstimateItemFromPhoto(request())).resolves.toEqual({
    label: 'Divan sectionnel', category: 'sofa', weight: 'heavy',
  });
  expect(analyzeWithOpenAi).toHaveBeenCalledTimes(1);
  expect((analyzeWithOpenAi as jest.Mock).mock.calls[0][0]).toMatchObject({ locale: 'fr', model: 'TEST-MODEL', apiKey: 'FAKE-KEY' });
  expect(tx.set.mock.calls.every(([r]: any) => r.path.startsWith('photo_analysis_usage/'))).toBe(true);
  // The address is stored hashed, never as written.
  expect(Object.keys(data).some((path) => path.includes('198.51.100.9'))).toBe(false);
  const global = Object.entries(data).find(([path]) => path.startsWith('photo_analysis_usage/global_'));
  expect(global![1]).toMatchObject({ count: 1 });
});

test('an unsure answer gives no weight', async () => {
  (analyzeWithOpenAi as jest.Mock).mockResolvedValue({
    category: 'other', label: 'Objet', confidence: 'low', special_handling: false, reason: 'uncertain',
  });
  await expect(handleEstimateItemFromPhoto(request())).resolves.toEqual({ label: 'Objet', category: 'other', weight: null });
});

test.each([
  ['no consent', { consent: false }],
  ['not an image', { imageBase64: Buffer.from('not a jpeg at all').toString('base64') }],
  ['unknown language', { locale: 'de' }],
])('%s never reaches the provider or the counters', async (_name, overrides) => {
  await expect(handleEstimateItemFromPhoto(request('198.51.100.9', overrides))).rejects.toMatchObject({ code: 'invalid-argument' });
  expect(analyzeWithOpenAi).not.toHaveBeenCalled();
  expect(db.runTransaction).not.toHaveBeenCalled();
});

test.each(['disabled', 'public use closed', 'missing'])('%s: closed, the provider is not called', async (reason) => {
  if (reason === 'disabled') data['system_config/photo_analysis'].enabled = false;
  if (reason === 'public use closed') data['system_config/photo_analysis'].publicEstimateEnabled = false;
  if (reason === 'missing') delete data['system_config/photo_analysis'];
  await expect(handleEstimateItemFromPhoto(request())).rejects.toMatchObject({ code: 'failed-precondition' });
  expect(analyzeWithOpenAi).not.toHaveBeenCalled();
});

test('three photos per address, then resource-exhausted; another address still passes', async () => {
  for (let i = 0; i < PUBLIC_PHOTO_LIMITS.perIpWindow; i++) {
    await expect(handleEstimateItemFromPhoto(request())).resolves.toMatchObject({ weight: 'heavy' });
  }
  await expect(handleEstimateItemFromPhoto(request())).rejects.toMatchObject({ code: 'resource-exhausted' });
  await expect(handleEstimateItemFromPhoto(request('203.0.113.7'))).resolves.toMatchObject({ weight: 'heavy' });
  expect(analyzeWithOpenAi).toHaveBeenCalledTimes(PUBLIC_PHOTO_LIMITS.perIpWindow + 1);
});

test('the global daily limit of photo analysis is shared', async () => {
  data['system_config/photo_analysis'].globalDailyLimit = 2;
  await handleEstimateItemFromPhoto(request('203.0.113.1'));
  await handleEstimateItemFromPhoto(request('203.0.113.2'));
  await expect(handleEstimateItemFromPhoto(request('203.0.113.3'))).rejects.toMatchObject({ code: 'resource-exhausted' });
  expect(analyzeWithOpenAi).toHaveBeenCalledTimes(2);
});

test('a provider failure consumes the attempt and leaks nothing', async () => {
  (analyzeWithOpenAi as jest.Mock).mockRejectedValueOnce(Error('RAW SECRET ERROR'));
  await expect(handleEstimateItemFromPhoto(request())).rejects.toMatchObject({
    code: 'unavailable', message: 'Photo analysis unavailable.',
  });
  const global = Object.entries(data).find(([path]) => path.startsWith('photo_analysis_usage/global_'));
  expect(global![1]).toMatchObject({ count: 1 });
});
