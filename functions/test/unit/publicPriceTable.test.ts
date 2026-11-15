// Tableau de prix public : lignes par classe d'objet, fiche de prix du
// propriétaire (15 novembre 2026) et garde-fous d'assemblage.

import {
  assemblePublicPriceTable,
  OWNER_PUBLIC_PRICES_DOLLARS,
  ownerPublicTotalsMinor,
  PUBLIC_PRICE_DISTANCES_KM,
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

describe('owner price sheet (2026-11-15)', () => {
  test('the displayed prices are the owner sheet, in cents', () => {
    expect(PUBLIC_PRICE_DISTANCES_KM).toEqual([5, 10, 20, 40]);
    expect(ownerPublicTotalsMinor('light')).toEqual([3900, 4900, 6900, 10900]);
    expect(ownerPublicTotalsMinor('medium')).toEqual([4900, 5900, 7900, 11900]);
    expect(ownerPublicTotalsMinor('heavy')).toEqual([6900, 7900, 10000, 14200]);
    expect(ownerPublicTotalsMinor('very_heavy')).toEqual([7400, 8400, 10500, 14700]);
  });

  test('every class has one price per distance, rising with distance and weight', () => {
    const classes = ['light', 'medium', 'heavy', 'very_heavy'] as const;
    for (const itemClass of classes) {
      const totals = OWNER_PUBLIC_PRICES_DOLLARS[itemClass];
      expect(totals).toHaveLength(PUBLIC_PRICE_DISTANCES_KM.length);
      for (let i = 1; i < totals.length; i++) expect(totals[i]).toBeGreaterThan(totals[i - 1]);
    }
    for (let c = 1; c < classes.length; c++) {
      OWNER_PUBLIC_PRICES_DOLLARS[classes[c]].forEach((total, i) => {
        expect(total).toBeGreaterThan(OWNER_PUBLIC_PRICES_DOLLARS[classes[c - 1]][i]);
      });
    }
  });

  test('the sheet assembles into the public table, from 39 $', () => {
    const rows = publicPriceRows({ item_class_fees: defaultItemClassFees() }).map((plan) => ({
      ...plan,
      totals_minor: ownerPublicTotalsMinor(plan.item_class),
    }));
    const table = assemblePublicPriceTable(rows);
    expect(table!.rows.map((r) => r.item_class)).toEqual(['light', 'medium', 'heavy', 'very_heavy']);
    expect(table!.from_minor).toBe(3900);
    expect(table!.rows[3].totals_minor).toEqual([7400, 8400, 10500, 14700]);
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
