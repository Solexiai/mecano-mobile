import { classifyPhotoIntake, PHOTO_CATEGORIES } from '../../src/lib/photoIntake';
const confirmed = (category: unknown, specialItem = false) =>
  classifyPhotoIntake({category, specialItem, customerConfirmed: true});
test.each(['sofa','armchair','fridge','washer','table','tv','boxes'])('%s needs no mandatory measurements during intake', category => {
  expect(confirmed(category)).toMatchObject({status:'standard',measurementsRequired:false,requiredDetails:[]});
});
test('materials request specifications', () => {
  expect(confirmed('materials')).toMatchObject({status:'special',measurementsRequired:true});
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
test('other is not silently treated as ordinary', () => {
  expect(confirmed('other').status).toBe('confirm_category');
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
