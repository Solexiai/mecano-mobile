import { classifyPhotoIntake, PHOTO_CATEGORIES } from '../../src/lib/photoIntake';
const confirmed = (category: unknown, specialItem = false) =>
  classifyPhotoIntake({category, specialItem, customerConfirmed: true});
test.each(['sofa','armchair','fridge','washer','table','tv','boxes'])('%s needs no mandatory measurements during intake', category => {
  expect(confirmed(category)).toMatchObject({status:'standard',measurementsRequired:false,requiredDetails:[]});
});
// Owner decision 2026-10-25: no measurements are ever required from the
// customer; special items stay flagged for the driver.
test('materials are flagged special without required measurements', () => {
  expect(confirmed('materials')).toMatchObject({status:'special',measurementsRequired:false,requiredDetails:[]});
});
test('a piano can use existing other category with explicit special classification', () => {
  expect(confirmed('other',true).status).toBe('special');
});
test('an exceptional sofa remains special', () => {
  expect(confirmed('sofa',true).status).toBe('special');
});
test.each(['piano','cat_furniture','',null,123,{}])('unsupported category is not silently accepted: %p', category => {
  expect(confirmed(category)).toMatchObject({category:null,status:'confirm_category'});
});
test('a confirmed "other" item is accepted; the driver judges it from the photo', () => {
  expect(confirmed('other').status).toBe('standard');
});
test('AI result requires customer confirmation', () => {
  expect(classifyPhotoIntake({category:'sofa',specialItem:false,customerConfirmed:false}).status).toBe('confirm_object');
});
test.each(PHOTO_CATEGORIES)('intake never authorizes quote or asserts verified fit: %s', category => {
  const input={category,customerConfirmed:true,specialItem:false};
  const before=JSON.stringify(input);const result=classifyPhotoIntake(input);
  expect(result.quoteAuthorized).toBe(false);expect(result.vehicleFitVerified).toBe(false);
  expect(result).not.toHaveProperty('price');expect(result).not.toHaveProperty('weight_kg');
  expect(JSON.stringify(input)).toBe(before);
});
