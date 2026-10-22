import { normalizeLoad, recommend, bookingHandling } from '../../src/lib/booking';
import { buildPricingConfig } from './fixtures';
import { calculateCustomerQuote } from '../../src/lib/pricingEngine';
import { toMinorUnits } from '../../src/lib/money';
import { buildQuoteIntegrityEnvelope, computeQuoteIntegrityHash, resolveLockedQuote, LockedQuotePricingSnapshot } from '../../src/lib/quoteIntegrity';
function fixture() {
 const access={floor:0,stairs:false,elevator:false,help:false};
 const load=normalizeLoad({draft_id:'integrity-test',intake_mode:'photo_assisted',timing_mode:'immediate',requested_at:null,
 items:[{id:'one',category:'boxes',label:'Synthetic boxes',quantity:1,length:null,width:null,height:null,weight:null,dimension_unit:'cm',weight_unit:'kg',approximate:false,upright:true,
 photos:['booking_photos/fake/integrity-test/one/0.jpg'],identification_confirmed:true,special_handling:false}],pickup:access,dropoff:access,handlers:1,equipment:[]});
 const rules={approved:true,version:'TEST',heavy_item_kg:50,bulky_item_cm:150,capacities:[{category:'cargo_van',rank:1,version:'TEST',verified:true,length_cm:200,width_cm:100,height_cm:100,opening_width_cm:100,opening_height_cm:100,payload_kg:200,handlers:1,equipment:[],services:[]}],photo_intake:{enabled:true,version:'PHOTO-TEST',category_vehicle_categories:{boxes:['cargo_van']}}};
 const booking=recommend(load,rules).snapshot!;
 const config=buildPricingConfig();const handling=bookingHandling(load,rules);
 const breakdown=calculateCustomerQuote(config,{vehicleCategory:'cargoVan',distanceKm:10,estimatedDurationMinutes:20,handling});
 const cents=toMinorUnits(breakdown.customerTotal);
 const snapshot:LockedQuotePricingSnapshot={schema_version:1,currency:'CAD',pricing_version:config.pricing_version,vehicle_category:'cargoVan',distance_km:10,estimated_duration_minutes:20,
 route_provider:'FAKE',route_result:{distance_km:10,estimated_duration_minutes:20},handling,total_waiting_minutes:0,additional_stops_count:0,applicable_surcharge_ids:[],promotion:{code:null,discount_amount:0},tax_snapshot:null,breakdown,customer_total_minor:cents,booking};
 const quote:any={customer_id:'fake',customer_total:breakdown.customerTotal,customer_total_minor:cents,pricing_version:config.pricing_version,quote_breakdown:{...breakdown},pricing_snapshot:snapshot,stops:[],created_at:{toMillis:()=>1000},expires_at:{toMillis:()=>2000}};
 quote.integrity_hash=computeQuoteIntegrityHash(buildQuoteIntegrityEnvelope({quoteId:'fake-quote',customerId:'fake',createdAtMillis:1000,expiresAtMillis:2000,stops:[],pricingSnapshot:snapshot}));
 return {quote,cents,snapshot};
}
test('new photo metadata is locked without changing source cents',()=>{
 const {quote,cents,snapshot}=fixture();const before=JSON.stringify(quote);const result=resolveLockedQuote('fake-quote',quote);
 expect(result.customerTotalMinor).toBe(cents);expect(result.pricingSnapshot?.booking).toEqual(snapshot.booking);expect(JSON.stringify(quote)).toBe(before);
});
test.each(['category','policy','assessment','quantity','photos'])('tampering with photo %s breaks quote integrity',field=>{
 const {quote,snapshot}=fixture();const b=snapshot.booking!;
 if(field==='category')b.category='pickup_truck';if(field==='policy')b.photo_policy_version='OTHER';
 if(field==='assessment')delete b.vehicle_assessment;if(field==='quantity')b.load.items[0].quantity=2;
 if(field==='photos')b.load.items[0].photos=[];
 expect(()=>resolveLockedQuote('fake-quote',quote)).toThrow();
});
