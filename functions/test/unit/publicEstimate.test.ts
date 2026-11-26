// Estimation publique par codes postaux (2026-11-26) : codes postaux, poids,
// hypothèses des deux bornes et arrondi de la fourchette.

import {
  assemblePublicEstimate,
  ESTIMATE_HIGH_HANDLING,
  ESTIMATE_LOW_HANDLING,
  estimateItemCategory,
  normalizePostalCode,
  parseEstimateWeight,
} from '../../src/lib/publicEstimate';
import { defaultItemClassFees } from '../../src/lib/itemClassFees';

describe('normalizePostalCode', () => {
  test('accepts the usual spellings of a Canadian postal code', () => {
    expect(normalizePostalCode('J2G 3V5')).toBe('J2G 3V5');
    expect(normalizePostalCode('j2g3v5')).toBe('J2G 3V5');
    expect(normalizePostalCode(' j2g-3v5 ')).toBe('J2G 3V5');
  });

  test('accepts the first three characters alone', () => {
    expect(normalizePostalCode('j2l')).toBe('J2L');
  });

  test('refuses anything else', () => {
    for (const raw of ['', 'Granby', '12345', 'J2G 3V', 'D2G 3V5', 'J2G 3O5', 'J2G 3V5 9', null, 42, 'J'.repeat(40)]) {
      expect(normalizePostalCode(raw)).toBeNull();
    }
  });
});

describe('parseEstimateWeight', () => {
  test('light, medium and heavy only', () => {
    expect(parseEstimateWeight('light')).toBe('light');
    expect(parseEstimateWeight('medium')).toBe('medium');
    expect(parseEstimateWeight('heavy')).toBe('heavy');
    expect(parseEstimateWeight('very_heavy')).toBeNull();
    expect(parseEstimateWeight(undefined)).toBeNull();
  });
});

describe('handling of the two bounds', () => {
  test('low: help at both ends, no stairs, one handler', () => {
    expect(ESTIMATE_LOW_HANDLING).toMatchObject({
      needsLoading: true, needsUnloading: true, needsStairs: false, noElevator: false, needsSecondHandler: false,
    });
  });

  test('high: stairs without elevator and a second handler', () => {
    expect(ESTIMATE_HIGH_HANDLING).toMatchObject({
      needsLoading: true, needsUnloading: true, needsStairs: true, noElevator: true, needsSecondHandler: true,
      isHeavyItem: false, needsSpecialEquipment: false,
    });
  });
});

describe('estimateItemCategory', () => {
  test('an item type of the class, from the active grid', () => {
    const config = { item_class_fees: defaultItemClassFees() };
    expect(estimateItemCategory(config, 'light')).toBe('chairs');
    expect(estimateItemCategory(config, 'medium')).toBe('armchair');
    expect(estimateItemCategory(config, 'heavy')).toBe('sofa');
  });

  test('an older grid without classes uses the proposal', () => {
    expect(estimateItemCategory({}, 'heavy')).toBe('sofa');
  });

  test('null when the grid has no item type in the class', () => {
    const fees = defaultItemClassFees();
    for (const category of Object.keys(fees.classes)) fees.classes[category] = 'medium';
    expect(estimateItemCategory({ item_class_fees: fees }, 'heavy')).toBeNull();
  });
});

describe('assemblePublicEstimate', () => {
  test('whole dollars: low rounded down, high rounded up, distance to the kilometre', () => {
    expect(assemblePublicEstimate(7550, 10050, 12.4)).toEqual({
      currency: 'CAD', low_dollars: 75, high_dollars: 101, distance_km: 12, taxes_included: true,
    });
  });

  test('the high bound is never under the low bound', () => {
    expect(assemblePublicEstimate(7500, 7000, 3)).toMatchObject({ low_dollars: 75, high_dollars: 75 });
  });

  test('null rather than a wrong amount', () => {
    expect(assemblePublicEstimate(0, 5000, 10)).toBeNull();
    expect(assemblePublicEstimate(75.5, 5000, 10)).toBeNull();
    expect(assemblePublicEstimate(50, 5000, 10)).toBeNull();
    expect(assemblePublicEstimate(7500, 9000, 0)).toBeNull();
  });
});
