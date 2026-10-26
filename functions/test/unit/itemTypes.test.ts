import { allowedVehicles, driverJudgementSnapshot } from '../../src/lib/quoteBeforeAssignment';
import { normalizeLoad, recommend, BookingRules, Capacity } from '../../src/lib/booking';
import { parseItemVehicles, PROPOSED_ITEM_VEHICLES } from '../../src/lib/itemTypes';
import { PHOTO_CATEGORIES } from '../../src/lib/photoIntake';

// Same order as the client (lib/services/booking/item_types.dart).
test('the catalog of item types (2026-10-26)', () => {
  expect([...PHOTO_CATEGORIES]).toEqual(['sofa','armchair','bed','dresser','desk','chairs','table','tv_stand','tv',
    'fridge','freezer','washer','stove','tires','yard_equipment','patio','sport','boxes','materials','other']);
});
test('proposal: every vehicle, except no van for construction materials', () => {
  for (const c of PHOTO_CATEGORIES) {
    expect(PROPOSED_ITEM_VEHICLES[c]).toEqual(c === 'materials' ? ['pickup_truck','cube_truck'] : ['pickup_truck','cargo_van','cube_truck']);
  }
  expect(parseItemVehicles(PROPOSED_ITEM_VEHICLES)).toEqual(PROPOSED_ITEM_VEHICLES);
});
test('admin mapping is normalized to the vehicle order and may leave a type off', () => {
  expect(parseItemVehicles({ ...PROPOSED_ITEM_VEHICLES, bed: ['cube_truck','pickup_truck'], tires: [] })!.bed).toEqual(['pickup_truck','cube_truck']);
  expect(parseItemVehicles({ ...PROPOSED_ITEM_VEHICLES, tires: [] })!.tires).toEqual([]);
});
test.each([null, [], {}, { ...PROPOSED_ITEM_VEHICLES, bed: 'pickup_truck' }, { ...PROPOSED_ITEM_VEHICLES, extra: [] }])(
  'invalid mapping %p', raw => expect(parseItemVehicles(raw)).toBeNull());

const capacity: Capacity = { category:'pickup_truck', rank:1, version:'SIMULATED', verified:true, length_cm:250, width_cm:150, height_cm:150,
  opening_width_cm:150, opening_height_cm:150, payload_kg:500, handlers:2, equipment:[], services:['handling','stairs'] };
const access = { floor:0, stairs:false, elevator:false, help:false };
const load = (category: string) => normalizeLoad({ draft_id:'item-types-test', intake_mode:'photo_assisted', timing_mode:'immediate',
  requested_at:null, pickup:access, dropoff:access, handlers:1, equipment:[], items:[{ id:'a', category, label:'Fictif', quantity:4,
  length:null, width:null, height:null, weight:null, dimension_unit:'cm', weight_unit:'kg', approximate:false, upright:true,
  photos:['booking_photos/test/item-types-test/a/0.jpg'], identification_confirmed:true, special_handling:false }] });
const rules = (mapping: Record<string, string[]>): BookingRules => ({ approved:true, version:'SIMULATED', capacities:[capacity],
  heavy_item_kg:100, bulky_item_cm:300, photo_intake:{ enabled:true, version:'SIMULATED', category_vehicle_categories:mapping } });

test.each(['bed','tires','freezer','yard_equipment','sport'])('a confirmed %s photo with its vehicle mapped is ready', category => {
  expect(recommend(load(category), rules({ ...PROPOSED_ITEM_VEHICLES })).status).toBe('ready');
});
test('a type left off by the admin is not offered', () => {
  const result = recommend(load('tires'), rules({ ...PROPOSED_ITEM_VEHICLES, tires: [] }));
  expect(result.status).not.toBe('ready');
  expect(result.reasons).toContain('photo_category_unconfigured');
});

// The live price-first booking honors the admin grid (2026-10-26).
const two = (a: string, b: string) => normalizeLoad({ draft_id:'item-types-test', intake_mode:'photo_assisted', timing_mode:'immediate',
  requested_at:null, pickup:access, dropoff:access, handlers:1, equipment:[], items:[a, b].map((category, i) => ({ id:`i${i}`, category,
  label:'Fictif', quantity:1, length:null, width:null, height:null, weight:null, dimension_unit:'cm', weight_unit:'kg', approximate:false,
  upright:true, photos:[`booking_photos/test/item-types-test/i${i}/0.jpg`], identification_confirmed:true, special_handling:false })) });
test('only vehicles allowed for every item of the load', () => {
  expect(allowedVehicles(two('sofa', 'materials'), { ...PROPOSED_ITEM_VEHICLES })).toEqual(['pickup_truck', 'cube_truck']);
  expect(allowedVehicles(two('sofa', 'bed'), { ...PROPOSED_ITEM_VEHICLES })).toEqual(['pickup_truck', 'cargo_van', 'cube_truck']);
  expect(allowedVehicles(two('sofa', 'bed'), { sofa: ['cargoVan'] })).toEqual(['cargo_van']);
});
test('a type never saved keeps every vehicle, as before', () => {
  expect(allowedVehicles(two('sofa', 'tires'), {})).toEqual(['pickup_truck', 'cargo_van', 'cube_truck']);
});
test('a type left off, or no common vehicle, is refused before any price', () => {
  expect(() => allowedVehicles(two('sofa', 'tires'), { ...PROPOSED_ITEM_VEHICLES, tires: [] }))
    .toThrow(expect.objectContaining({ details: { quote_reason: 'photo_category_unconfigured' } }));
  expect(() => allowedVehicles(two('sofa', 'bed'), { sofa: ['cargo_van'], bed: ['cube_truck'] }))
    .toThrow(expect.objectContaining({ details: { quote_reason: 'no_eligible_photo_vehicle' } }));
});
test('the mission offers only to drivers with an allowed vehicle', () => {
  const pre = { version: 1 as const, load: two('sofa', 'materials'), vehicle_assignment: 'pending' as const,
    tariff_categories: ['pickup_truck', 'cargo_van', 'cube_truck'], tariff_rule_category: 'pickup_truck' };
  expect(driverJudgementSnapshot(pre).eligible_categories).toEqual(['pickup_truck', 'cargo_van', 'cube_truck']);
  expect(driverJudgementSnapshot({ ...pre, vehicle_categories: ['pickup_truck', 'cube_truck'] }).eligible_categories)
    .toEqual(['pickup_truck', 'cube_truck']);
});
