import { bookingHandling, fitsVehicle, normalizeLoad, recommend, BookingRules, Capacity } from '../../src/lib/booking';
import { calculateCustomerQuote } from '../../src/lib/pricingEngine';
import { buildPricingConfig } from './fixtures';
const capacity: Capacity = { category:'cargo_van',rank:1,version:'TEST-ONLY',verified:true,length_cm:200,width_cm:100,height_cm:100,opening_width_cm:90,opening_height_cm:90,payload_kg:200,handlers:2,equipment:[],services:['handling'] };
const access={floor:0,stairs:false,elevator:false,help:false};
function load(weight:number|null=60){return normalizeLoad({draft_id:'heavy-removal-test',timing_mode:'immediate',items:[{id:'one',category:'other',label:'Test object',quantity:1,length:80,width:60,height:50,weight,dimension_unit:'cm',weight_unit:'kg',approximate:false,upright:true}],pickup:access,dropoff:access,handlers:1,equipment:[]});}
const rules:BookingRules={approved:true,version:'TEST-ONLY',capacities:[capacity],heavy_item_kg:50,bulky_item_cm:150};
test.each([null,20,60,200])('new booking never requests heavy surcharge for weight %s',weight=>{expect(bookingHandling(load(weight),rules).isHeavyItem).toBe(false);});
test('obsolete heavy fee threshold is not a capacity prerequisite',()=>{const {heavy_item_kg:unused,...remaining}=rules;void unused;expect(recommend(load(),remaining as BookingRules).status).toBe('ready');});
test('removing fee retains actual payload protection',()=>{expect(fitsVehicle(load(201),capacity)).toBe(false);expect(recommend(load(201),rules).snapshot).toBeNull();});
test('legacy pricing engine retains historical heavy fees',()=>{const config=buildPricingConfig();config.handling_fees.heavy_item_fee=10;expect(calculateCustomerQuote(config,{vehicleCategory:'cargoVan',distanceKm:10,estimatedDurationMinutes:20,handling:{isHeavyItem:true}}).handlingFeesTotal).toBe(10);});
