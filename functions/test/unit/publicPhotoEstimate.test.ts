// « Pas certain ? Ajoutez une photo » (2026-11-26) : demande, réglages,
// plafonds par adresse IP et poids de l'objet reconnu.
import {
  estimateWeightForCategory,
  MAX_PUBLIC_PHOTO_BYTES,
  nextPublicPhotoUsage,
  parsePublicPhotoRequest,
  PUBLIC_PHOTO_LIMITS,
  publicPhotoConfig,
} from '../../src/lib/publicPhotoEstimate';
import { defaultItemClassFees } from '../../src/lib/itemClassFees';

const jpeg = (size = 16) => Buffer.concat([Buffer.from([255, 216, 255]), Buffer.alloc(size)]).toString('base64');

describe('parsePublicPhotoRequest', () => {
  test('a JPEG in base64, a known language and the consent', () => {
    const parsed = parsePublicPhotoRequest({ imageBase64: jpeg(), locale: 'fr', consent: true });
    expect(parsed.locale).toBe('fr');
    expect([...parsed.bytes.subarray(0, 3)]).toEqual([255, 216, 255]);
  });

  test.each([
    ['no consent', { imageBase64: jpeg(), locale: 'fr' }],
    ['unknown language', { imageBase64: jpeg(), locale: 'de', consent: true }],
    ['not base64', { imageBase64: '<script>alert(1)</script>', locale: 'fr', consent: true }],
    ['a data URL', { imageBase64: `data:image/jpeg;base64,${jpeg()}`, locale: 'fr', consent: true }],
    ['not a JPEG', { imageBase64: Buffer.from('GIF89a-fictitious').toString('base64'), locale: 'fr', consent: true }],
    ['too large', { imageBase64: jpeg(MAX_PUBLIC_PHOTO_BYTES), locale: 'fr', consent: true }],
    ['empty', { imageBase64: '', locale: 'fr', consent: true }],
    ['nothing', null],
  ])('refused: %s', (_name, value) => {
    expect(() => parsePublicPhotoRequest(value)).toThrow(expect.objectContaining({ code: 'invalid-argument' }));
  });
});

describe('publicPhotoConfig', () => {
  const base = { enabled: true, provider: 'openai', model: 'TEST-MODEL', globalDailyLimit: 50 };

  test('the settings of the delivery request, without an account list', () => {
    expect(publicPhotoConfig(base)).toEqual({ model: 'TEST-MODEL', globalDailyLimit: 50 });
  });

  test.each([
    ['missing', undefined],
    ['disabled', { ...base, enabled: false }],
    ['public use closed', { ...base, publicEstimateEnabled: false }],
    ['another provider', { ...base, provider: 'other' }],
    ['bad model', { ...base, model: 'a b' }],
    ['no global limit', { ...base, globalDailyLimit: 0 }],
  ])('closed: %s', (_name, raw) => {
    expect(() => publicPhotoConfig(raw as any)).toThrow(expect.objectContaining({ code: 'failed-precondition' }));
  });
});

describe('nextPublicPhotoUsage', () => {
  const day = '2026-11-26';
  const now = Date.UTC(2026, 10, 26, 15, 0, 0);

  test('first photo of an address', () => {
    expect(nextPublicPhotoUsage(undefined, day, now)).toEqual({ day, count: 1, windowStartMs: now, windowCount: 1 });
  });

  test('three photos per ten minutes', () => {
    let usage = nextPublicPhotoUsage(undefined, day, now);
    for (let i = 1; i < PUBLIC_PHOTO_LIMITS.perIpWindow; i++) usage = nextPublicPhotoUsage(usage!, day, now + i * 1000);
    expect(usage).toMatchObject({ count: 3, windowCount: 3 });
    expect(nextPublicPhotoUsage(usage!, day, now + 60000)).toBeNull();
    // A new window opens ten minutes after the first photo.
    expect(nextPublicPhotoUsage(usage!, day, now + PUBLIC_PHOTO_LIMITS.windowMs)).toMatchObject({ count: 4, windowCount: 1 });
  });

  test('six photos per day, then a new day starts over', () => {
    const full = { day, count: PUBLIC_PHOTO_LIMITS.perIpPerDay, windowStartMs: 0, windowCount: 1 };
    expect(nextPublicPhotoUsage(full, day, now)).toBeNull();
    expect(nextPublicPhotoUsage(full, '2026-11-27', now)).toMatchObject({ day: '2026-11-27', count: 1 });
  });

  test('an unreadable counter counts as reached', () => {
    expect(nextPublicPhotoUsage({ day, count: 'x' }, day, now)).toBeNull();
    expect(nextPublicPhotoUsage({ day, count: 1, windowCount: -1 }, day, now)).toBeNull();
  });
});

describe('estimateWeightForCategory', () => {
  const config = { item_class_fees: defaultItemClassFees() };

  test('the class of the item in the active grid', () => {
    expect(estimateWeightForCategory(config, 'boxes')).toBe('light');
    expect(estimateWeightForCategory(config, 'table')).toBe('medium');
    expect(estimateWeightForCategory(config, 'sofa')).toBe('heavy');
  });

  test('very heavy is estimated as heavy', () => {
    expect(estimateWeightForCategory(config, 'materials')).toBe('heavy');
  });

  test('the grid decides, not the proposal', () => {
    const fees = defaultItemClassFees();
    fees.classes['sofa'] = 'medium';
    expect(estimateWeightForCategory({ item_class_fees: fees }, 'sofa')).toBe('medium');
    expect(estimateWeightForCategory({}, 'sofa')).toBe('heavy');
  });

  test('"other" gives no weight: the visitor chooses', () => {
    expect(estimateWeightForCategory(config, 'other')).toBeNull();
  });
});
