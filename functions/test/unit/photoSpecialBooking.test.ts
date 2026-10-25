import { normalizeLoad, recommend, eligibleForBookingSnapshot, BookingRules, Capacity } from '../../src/lib/booking';
const access={floor:0,stairs:false,elevator:false,help:false};
const capacity:Capacity={category:'pickup_truck',rank:1,version:'SIMULATED',verified:true,length_cm:250,width_cm:150,height_cm:150,opening_width_cm:150,opening_height_cm:150,payload_kg:500,handlers:2,equipment:[],services:['handling','stairs']};
const rules:BookingRules={approved:true,version:'SIMULATED',capacities:[capacity],heavy_item_kg:100,bulky_item_cm:300,photo_intake:{enabled:true,version:'SIMULATED',category_vehicle_categories:{materials:['pickup_truck'],other:['pickup_truck'],sofa:['pickup_truck']}}};
function request():any {return {draft_id:'photo-special-test',intake_mode:'photo_assisted',timing_mode:'immediate',requested_at:null,pickup:access,dropoff:access,handlers:1,equipment:[],items:[{id:'object',category:'materials',label:'Synthetic timber bundle',quantity:1,length:120,width:40,height:30,weight:null,dimension_unit:'cm',weight_unit:'kg',upright:true,approximate:true,photos:['booking_photos/test/photo-special-test/object/0.jpg'],identification_confirmed:true,special_handling:true,handling_notes:'Bundled, accessible at ground level.'}]};}
test('special photo with customer dimensions and handling details can receive a server recommendation',()=>{
 const load=normalizeLoad(request());const result=recommend(load,rules);
 expect(result.status).toBe('ready');expect(result.snapshot?.vehicle_assessment).toBe('driver_photo_review');
 expect(eligibleForBookingSnapshot(result.snapshot!,capacity)).toBe(true);
 expect(result.snapshot?.load.items[0].weight_kg).toBeNull();
});
test('special details survive normalization and therefore quote integrity',()=>{
 const raw=request();raw.items[0].handling_notes='  Keep bundle tied.  ';
 expect((normalizeLoad(raw).items[0] as any).handling_notes).toBe('Keep bundle tied.');
 const before=JSON.stringify(normalizeLoad(raw));raw.items[0].handling_notes='Different constraints';
 expect(JSON.stringify(normalizeLoad(raw))).not.toBe(before);
});
// Owner decision 2026-10-25: details are optional, the driver judges.
test.each(['length','width','height','handling_notes'])('missing special %s no longer blocks',field=>{
 const raw=request();raw.items[0][field]=null;
 const result=recommend(normalizeLoad(raw),rules);
 expect(result.reasons).not.toContain('special_details_required');
 expect(result.status).toBe('ready');
});
test('the AI size range reaches the driver as an advisory estimate',()=>{
 const raw=request();Object.assign(raw.items[0],{photo_size_hint:{basis:'typical_object',confidence:'low',length_cm:{min:60,max:70},width_cm:{min:60,max:70},height_cm:{min:85,max:95},photo_path:'x',category:'materials',label:'y'}});
 expect(normalizeLoad(raw).items[0].size_estimate).toEqual({basis:'typical_object',confidence:'low',length_cm:{min:60,max:70},width_cm:{min:60,max:70},height_cm:{min:85,max:95}});
 raw.items[0].photo_size_hint={basis:'typical_object',confidence:'high'};
 expect(normalizeLoad(raw).items[0]).not.toHaveProperty('size_estimate');
});
test('special notes are bounded',()=>{
 const raw=request();raw.items[0].handling_notes='x'.repeat(1201);
 expect(()=>normalizeLoad(raw)).toThrow();
});
test('special known oversized geometry is not waived by photo review',()=>{
 const raw=request();raw.items[0].length=1000;
 expect(recommend(normalizeLoad(raw),rules).status).toBe('review_required');
});
test('ordinary object remains eligible with no invented weight, dimensions or notes',()=>{
 const raw=request();Object.assign(raw.items[0],{category:'sofa',special_handling:false,length:null,width:null,height:null,weight:null});delete raw.items[0].handling_notes;
 const load=normalizeLoad(raw);expect(recommend(load,rules).status).toBe('ready');
 expect(load.items[0].weight_kg).toBeNull();expect(load.items[0].length_cm).toBeNull();
});
test('legacy normalized load does not gain photo fields',()=>{
 const raw=request();delete raw.intake_mode;
 expect(normalizeLoad(raw).items[0]).not.toHaveProperty('handling_notes');
});
