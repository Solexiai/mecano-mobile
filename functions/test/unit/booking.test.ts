import { bookingHandling, Capacity, fitsVehicle, normalizeLoad, recommend } from '../../src/lib/booking';
import { verifyCardSetup } from '../../src/lib/bookingPayment';
// SYNTHETIC TEST DATA ONLY. These dimensions are never production defaults.
const capacity: Capacity = { category:'cargo_van', rank:1, version:'TEST-ONLY', verified:true,
  length_cm:200,width_cm:100,height_cm:100,opening_width_cm:90,opening_height_cm:90,payload_kg:200,handlers:2,equipment:['dolly'],services:['handling','stairs'] };
const access = {floor:0,stairs:false,elevator:false,help:true};
function input(overrides: Record<string,unknown> = {}) { return { draft_id:'test-booking-draft', items:[{id:'one',category:'other',label:'Test box',quantity:1,length:80,width:60,height:50,weight:20,dimension_unit:'cm',weight_unit:'kg',approximate:false,upright:true,...overrides}], pickup:access,dropoff:access,handlers:1,equipment:[],requested_at:'2099-01-01T10:00:00Z' }; }
const rules = { approved:true,version:'TEST-ONLY',capacities:[capacity],heavy_item_kg:50,bulky_item_cm:150 };
test('converts inches and pounds on the server',()=>{const item=normalizeLoad(input({length:10,width:10,height:10,weight:10,dimension_unit:'in',weight_unit:'lb'})).items[0];expect(item.length_cm).toBe(25.4);expect(item.weight_kg).toBeCloseTo(4.536,3);});
test.each([{length:null},{weight:null},{approximate:true}])('unknown/approximate measurements never give a reservable recommendation: %s',item=>{expect(recommend(normalizeLoad(input(item)),rules).status).toBe('review_required');});
test('no unapproved or invented vehicle capacities',()=>{expect(recommend(normalizeLoad(input()),{...rules,approved:false}).reasons).toContain('capacity_unconfigured');expect(fitsVehicle(normalizeLoad(input()),{...capacity,verified:false})).toBe(false);});
test.each([{length:201},{weight:201},{height:91},{width:91,length:91}])('rejects excess size, weight and opening: %s',item=>expect(fitsVehicle(normalizeLoad(input(item)),capacity)).toBe(false));
test('volume may fit while multiple boxes cannot share the floor',()=>{expect(fitsVehicle(normalizeLoad(input({length:110,width:60,height:20,quantity:2})),capacity)).toBe(false);});
test('accepts a verified non-overlapping plan without stacking',()=>{expect(fitsVehicle(normalizeLoad(input({quantity:2})),capacity)).toBe(true);});
test('total payload includes quantities',()=>{expect(fitsVehicle(normalizeLoad(input({weight:110,quantity:2})),capacity)).toBe(false);});
test('upright restriction cannot be rotated away',()=>{const l=normalizeLoad(input({height:120,width:40,length:40}));expect(fitsVehicle(l,capacity)).toBe(false);l.items[0].upright=false;expect(fitsVehicle(l,capacity)).toBe(true);});
test('two handlers and equipment are real capability requirements',()=>{const l=normalizeLoad({...input(),handlers:2,equipment:['dolly']});expect(fitsVehicle(l,{...capacity,handlers:1})).toBe(false);expect(fitsVehicle(l,{...capacity,equipment:[]})).toBe(false);expect(bookingHandling(l,rules).needsSecondHandler).toBe(true);});
test('invalid units, duplicate IDs, negative and unbounded values rejected',()=>{for(const o of [{length:-2},{quantity:21},{dimension_unit:'meters'},{weight:NaN}])expect(()=>normalizeLoad(input(o))).toThrow();const i=input();i.items.push(i.items[0]);expect(()=>normalizeLoad(i)).toThrow();});
test('sort recommendation by configured rank, never browser preference',()=>{const result=recommend(normalizeLoad(input()),{...rules,capacities:[{...capacity,rank:2,category:'box_truck'},capacity]});expect(result.snapshot?.category).toBe('cargo_van');});
const session={id:'cs_test',url:null,complete:true,customerId:'cus_test',paymentMethodId:'pm_test',livemode:false,quoteId:'quote',userId:'customer'};
const expected={customerId:'cus_test',quoteId:'quote',userId:'customer',environment:'test'};
test('incomplete bank authentication never means ready',()=>{expect(verifyCardSetup({...session,complete:false},expected)).toBeNull();});
test.each([{customerId:'other'},{quoteId:'other'},{userId:'other'},{livemode:true}])('rejects checkout ownership/environment mismatch: %s',change=>{expect(()=>verifyCardSetup({...session,...change},expected)).toThrow();});
test('verified completed setup returns only opaque payment method',()=>expect(verifyCardSetup(session,expected)).toBe('pm_test'));

test('configured loading/unloading fees are applied without changing existing rates',()=>{
 const { buildPricingConfig } = require('./fixtures');
 const { calculateCustomerQuote } = require('../../src/lib/pricingEngine');
 const config=buildPricingConfig();config.handling_fees.loading_fee=7;config.handling_fees.unloading_fee=9;
 const base={vehicleCategory:'cargoVan',distanceKm:10,estimatedDurationMinutes:20};
 expect(calculateCustomerQuote(config,{...base,handling:{needsLoading:true,needsUnloading:true}}).handlingFeesTotal).toBe(16);
 expect(calculateCustomerQuote(config,base).handlingFeesTotal).toBe(0);
});
