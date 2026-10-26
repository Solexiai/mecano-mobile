import { normalizeLoad, recommend, fitsVehicle, selectBookingVehicle, Capacity } from '../../src/lib/booking';
const capacity: Capacity = { category:'pickup_truck',rank:1,version:'TEST',verified:true,
 length_cm:200,width_cm:100,height_cm:100,opening_width_cm:100,opening_height_cm:100,payload_kg:200,handlers:2,equipment:['dolly'],services:['handling','stairs'] };
const rules = () => ({approved:true,version:'TEST',capacities:[capacity],heavy_item_kg:50,bulky_item_cm:150,
 photo_intake:{enabled:true,version:'PHOTO-TEST',category_vehicle_categories:{sofa:['pickup_truck'],boxes:['pickup_truck']}}});
const raw = () => ({draft_id:'photo-test-draft',intake_mode:'photo_assisted',timing_mode:'immediate',requested_at:null,
 items:[{id:'one',category:'sofa',label:'Fictitious sofa',quantity:1,length:null as number|null,width:null as number|null,height:null as number|null,weight:null as number|null,
 dimension_unit:'cm',weight_unit:'kg',approximate:false,upright:true,photos:['booking_photos/fake/photo-test-draft/one/0.jpg'],identification_confirmed:true,special_handling:false}],
 pickup:{floor:0,stairs:false,elevator:false,help:false},dropoff:{floor:0,stairs:false,elevator:false,help:false},handlers:1,equipment:[] as string[]});
const result = (input=raw(),config=rules()) => recommend(normalizeLoad(input),config);
test('ordinary photo load receives explicit driver review snapshot, not verified fit',()=>{
 const input=raw();const before=JSON.stringify(input);const r=result(input);
 expect(r.status).toBe('ready');expect(r.snapshot).toMatchObject({category:'pickup_truck',vehicle_assessment:'driver_photo_review',photo_policy_version:'PHOTO-TEST'});
 expect(fitsVehicle(normalizeLoad(input),capacity)).toBe(false);expect(JSON.stringify(input)).toBe(before);
 expect(r.snapshot?.load.items[0].weight_kg).toBeNull();
});
test('normalizer preserves explicit intake and confirmation without inventing measurements',()=>{
 expect(normalizeLoad(raw())).toMatchObject({intake_mode:'photo_assisted',items:[{identification_confirmed:true,special_handling:false,length_cm:null,weight_kg:null}]});
});
test('legacy input retains its exact contract and conservative fit',()=>{
 const input:any=raw();delete input.intake_mode;const r=result(input);
 expect(r.status).toBe('review_required');expect(normalizeLoad(input)).not.toHaveProperty('intake_mode');
 expect(normalizeLoad(input).items[0]).not.toHaveProperty('identification_confirmed');
});
test.each(['invalid',null,1])('invalid explicit intake mode rejected: %s',mode=>expect(()=>normalizeLoad({...raw(),intake_mode:mode})).toThrow());
test('photo policy disabled or absent never enables photo eligibility',()=>{
 const config:any=rules();config.photo_intake.enabled=false;expect(result(raw(),config).reasons).toContain('photo_policy_unconfigured');
 delete config.photo_intake;expect(result(raw(),config).reasons).toContain('photo_policy_unconfigured');
});
test('unapproved capacity config still blocks photo intake',()=>expect(result(raw(),{...rules(),approved:false}).status).toBe('review_required'));
test('unmapped category cannot silently select a vehicle',()=>{const input=raw();input.items[0].category='fridge';expect(result(input).reasons).toContain('photo_category_unconfigured');});
test('photo is required when measurements are unknown',()=>{const input=raw();input.items[0].photos=[];expect(result(input).reasons).toContain('photo_required');});
test('object confirmation is required',()=>{const input=raw();input.items[0].identification_confirmed=false;expect(result(input).reasons).toContain('object_confirmation_required');});
test.each(['materials','other'])('%s without a configured vehicle mapping still cannot select a vehicle',category=>{const input=raw();input.items[0].category=category;expect(result(input).reasons).toContain('photo_category_unconfigured');});
// Owner decision 2026-10-25: a flagged item reaches drivers without measurements.
test('client flagging an unusual object is passed to drivers without required measurements',()=>{const input=raw();input.items[0].special_handling=true;const r=result(input);expect(r.reasons).not.toContain('special_details_required');expect(r.status).toBe('ready');});
test('known overweight never becomes eligible through photo review',()=>{const input=raw();input.items[0].weight=201;expect(result(input).status).toBe('review_required');});
test('known oversize dimension never becomes eligible through photo review',()=>{const input=raw();input.items[0].length=1000;expect(result(input).status).toBe('review_required');});
test('actual services, equipment and handlers remain mandatory',()=>{
 const input=raw();input.equipment=['crane'];expect(result(input).status).toBe('review_required');
 input.equipment=[];input.handlers=2;expect(result(input,{...rules(),capacities:[{...capacity,handlers:1}]}).status).toBe('review_required');
 input.handlers=1;input.pickup.help=true;expect(result(input,{...rules(),capacities:[{...capacity,services:[]}]}).status).toBe('review_required');
});
test('passenger cars cannot enter photo offering through configuration',()=>{const config=rules();config.capacities=[{...capacity,category:'car'}];config.photo_intake.category_vehicle_categories.sofa=['car'];expect(result(raw(),config).status).toBe('review_required');});
test('selected category uses approved mapping and rank, never client preference',()=>{
 const config=rules();config.capacities=[{...capacity,category:'cargo_van',rank:2},capacity];config.photo_intake.category_vehicle_categories.sofa=['cargo_van'];
 expect(result(raw(),config).snapshot?.category).toBe('cargo_van');
});
test('all objects must allow the same selected vehicle category',()=>{
 const input=raw();input.items.push({...input.items[0],id:'two',category:'boxes'});const config=rules();config.photo_intake.category_vehicle_categories.boxes=['cargo_van'];
 expect(result(input,config).status).toBe('review_required');
});

test('photo quote cannot be switched to a client-chosen category',()=>{
 const config=rules();config.capacities.push({...capacity,category:'cargo_van',rank:2});config.photo_intake.category_vehicle_categories.sofa=['pickup_truck','cargo_van'];
 const review=result(raw(),config);const snapshot=review.snapshot!;
 expect(selectBookingVehicle(snapshot,config,review.compatible_categories)).toBe(snapshot);
 expect(selectBookingVehicle(snapshot,config,review.compatible_categories,'pickup_truck')).toEqual(snapshot);
 expect(()=>selectBookingVehicle(snapshot,config,review.compatible_categories,'cargo_van')).toThrow();
});
test('legacy allowed vehicle alternatives retain their existing contract',()=>{
 const input:any=raw();delete input.intake_mode;input.items[0]={...input.items[0],length:20,width:20,height:20,weight:5};
 const config=rules();config.capacities.push({...capacity,category:'cargo_van',rank:2});const review=result(input,config);
 expect(selectBookingVehicle(review.snapshot!,config,review.compatible_categories,'cargo_van').category).toBe('cargo_van');
 expect(()=>selectBookingVehicle(review.snapshot!,config,review.compatible_categories,'car')).toThrow();
});
