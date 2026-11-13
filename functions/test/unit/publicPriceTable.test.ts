// Tableau de prix public (13 novembre 2026) : lignes par classe d'objet et
// garde-fous d'assemblage. Le calcul lui-même est celui du devis officiel.

import {
  assemblePublicPriceTable,
  PUBLIC_PRICE_DISTANCES_KM,
  PUBLIC_PRICE_HANDLING,
  publicPriceDurationMinutes,
  publicPriceRows,
} from '../../src/lib/publicPriceTable';
import { defaultItemClassFees } from '../../src/lib/itemClassFees';

describe('publicPriceRows', () => {
  test('one row per item class, in order, without "other"', () => {
    const rows = publicPriceRows({ item_class_fees: defaultItemClassFees() });
    expect(rows.map((r) => r.item_class)).toEqual(['light', 'medium', 'heavy', 'very_heavy']);
    expect(rows[0].categories).toEqual(['chairs', 'tv', 'sport', 'boxes']);
    expect(rows[2].categories).toEqual(['sofa', 'bed', 'fridge', 'freezer', 'washer', 'stove']);
    expect(rows.flatMap((r) => r.categories)).not.toContain('other');
  });

  test('follows the classes of the active grid and drops an empty class', () => {
    const fees = defaultItemClassFees();
    fees.classes['yard_equipment'] = 'heavy';
    fees.classes['materials'] = 'heavy';
    const rows = publicPriceRows({ item_class_fees: fees });
    expect(rows.map((r) => r.item_class)).toEqual(['light', 'medium', 'heavy']);
    expect(rows[2].categories).toContain('materials');
  });

  test('an older grid without item classes uses the proposal', () => {
    const rows = publicPriceRows({});
    expect(rows.map((r) => r.item_class)).toEqual(['light', 'medium', 'heavy', 'very_heavy']);
  });
});

describe('assumptions', () => {
  test('the simple flow: help at both ends, no stairs, one handler', () => {
    expect(PUBLIC_PRICE_HANDLING).toMatchObject({
      needsLoading: true, needsUnloading: true, needsStairs: false, needsSecondHandler: false,
    });
    expect(PUBLIC_PRICE_DISTANCES_KM).toEqual([5, 10, 20, 40]);
    expect(publicPriceDurationMinutes(20)).toBe(50);
  });
});

describe('assemblePublicPriceTable', () => {
  const row = (totals: number[]) => ({ item_class: 'light' as const, categories: ['boxes'], totals_minor: totals });

  test('keeps the rows and finds the lowest price', () => {
    const table = assemblePublicPriceTable([
      row([5200, 6100, 8000, 12000]),
      { item_class: 'heavy', categories: ['sofa'], totals_minor: [6700, 7600, 9500, 13500] },
    ]);
    expect(table).not.toBeNull();
    expect(table!.from_minor).toBe(5200);
    expect(table!.distances_km).toEqual([5, 10, 20, 40]);
    expect(table!.taxes_included).toBe(true);
    expect(Object.keys(table!)).toEqual(['currency', 'distances_km', 'rows', 'from_minor', 'taxes_included']);
  });

  test('no table rather than a wrong one', () => {
    expect(assemblePublicPriceTable([])).toBeNull();
    expect(assemblePublicPriceTable([row([5200, 6100, 8000])])).toBeNull();
    expect(assemblePublicPriceTable([row([5200, 0, 8000, 12000])])).toBeNull();
    expect(assemblePublicPriceTable([row([5200, 61.5, 8000, 12000])])).toBeNull();
  });
});
