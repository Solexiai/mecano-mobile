jest.mock('../../src/lib/admin', () => ({ db: { collection: jest.fn(), doc: jest.fn() } }));
jest.mock('../../src/lib/serviceZones', () => ({ getServiceZonesConfig: jest.fn(async () => ({enabled:true,zones:[{}]})), isWithinServiceZones: jest.fn(() => true) }));
jest.mock('../../src/lib/bookingPhotoValidation', () => ({ validateBookingPhotos: jest.fn(async () => {}) }));
import { db } from '../../src/lib/admin';
import { findCompatibleVehicle, requireCompatibleVehicle, reviewBooking } from '../../src/lib/bookingServer';
import { normalizeLoad, recommend, eligibleForBookingSnapshot, BookingSnapshot, Capacity } from '../../src/lib/booking';
const capacity: Capacity = {category:'pickup_truck',rank:1,version:'TEST',verified:true,length_cm:200,width_cm:100,height_cm:100,opening_width_cm:100,opening_height_cm:100,payload_kg:200,handlers:1,equipment:[],services:[]};
const raw=()=>({draft_id:'photo-test-draft',intake_mode:'photo_assisted',timing_mode:'immediate',requested_at:null,
 items:[{id:'one',category:'sofa',label:'Fictitious sofa',quantity:1,length:null,width:null,height:null,weight:null,dimension_unit:'cm',weight_unit:'kg',approximate:false,upright:true,
 photos:['booking_photos/fake/photo-test-draft/one/0.jpg'],identification_confirmed:true,special_handling:false}],
 pickup:{floor:0,stairs:false,elevator:false,help:false},dropoff:{floor:0,stairs:false,elevator:false,help:false},handlers:1,equipment:[]});
const rules={approved:true,version:'TEST',capacities:[capacity],heavy_item_kg:50,bulky_item_cm:150,photo_intake:{enabled:true,version:'PHOTO-TEST',category_vehicle_categories:{sofa:['pickup_truck']}}};
const snapshot=()=>recommend(normalizeLoad(raw()),rules).snapshot!;
const vehicle=()=>({driver_id:'driver-test',is_verified:true,verified_capacity:capacity,capacity_valid_until:{toMillis:()=>Date.now()+60000}});
const docs=(v=vehicle(),id='vehicle-test')=>({docs:[{id,data:()=>v}]});
let query:any;
beforeEach(()=>{jest.clearAllMocks();query={where:jest.fn().mockReturnThis(),limit:jest.fn().mockReturnThis(),get:jest.fn(async()=>docs())};(db.collection as jest.Mock).mockReturnValue(query);(db.doc as jest.Mock).mockReturnValue({get:jest.fn(async()=>({data:()=>rules}))});});
test('real shared repository lookup filters driver and reads verified vehicle',async()=>{
 expect(await findCompatibleVehicle('driver-test',snapshot())).toEqual({vehicle_id:'vehicle-test',capacity_version:'TEST'});
 expect(query.where).toHaveBeenCalledWith('driver_id','==','driver-test');expect(query.limit).toHaveBeenCalledWith(20);
});
test('assignment transaction reads vehicle inside transaction, not outside',async()=>{
 const tx={get:jest.fn(async()=>docs())};
 expect(await requireCompatibleVehicle('driver-test',snapshot(),tx as any,'vehicle-test')).toEqual({assigned_vehicle_id:'vehicle-test',assigned_capacity_version:'TEST'});
 expect(tx.get).toHaveBeenCalledWith(query);expect(query.get).not.toHaveBeenCalled();
});
test.each(['expired','unverified','wrong-category','overweight','wrong-selected-id'])('lookup refuses %s',async reason=>{
 const v=vehicle();if(reason==='expired')v.capacity_valid_until={toMillis:()=>1};if(reason==='unverified')v.is_verified=false;
 if(reason==='wrong-category')v.verified_capacity={...capacity,category:'car'};
 const s=snapshot();if(reason==='overweight')s.load.items[0].weight_kg=201;
 query.get.mockResolvedValue(docs(v));expect(await findCompatibleVehicle('driver-test',s,undefined,reason==='wrong-selected-id'?'other':undefined)).toBeNull();
});
test('assignment refusal remains a failed-precondition error',async()=>{
 const tx={get:jest.fn(async()=>({docs:[]}))};await expect(requireCompatibleVehicle('driver-test',snapshot(),tx as any)).rejects.toMatchObject({code:'failed-precondition'});
});
test('photo snapshot without policy provenance does not downgrade legacy safety',()=>{
 const s=snapshot();delete s.photo_policy_version;expect(eligibleForBookingSnapshot(s,capacity)).toBe(false);
 const s2=snapshot();delete s2.vehicle_assessment;expect(eligibleForBookingSnapshot(s2,capacity)).toBe(false);
});
test('legacy fully measured snapshot still uses verified geometric fit',()=>{
 const input:any=raw();delete input.intake_mode;input.items[0]={...input.items[0],length:20,width:20,height:20,weight:5};
 const s:BookingSnapshot={load:normalizeLoad(input),rules_version:'TEST',category:'pickup_truck',capacity_version:'TEST'};
 expect(eligibleForBookingSnapshot(s,capacity)).toBe(true);s.load.items[0].weight_kg=null;expect(eligibleForBookingSnapshot(s,capacity)).toBe(false);
});
const stops=[{address:{line1:'Synthetic',city:'Test',postal_code:'T0T0T0',lat:45,lng:-73}},{address:{line1:'Synthetic',city:'Test',postal_code:'T0T0T0',lat:45.1,lng:-73.1}}];
test('server review binds photo paths to authenticated customer',async()=>{
 await expect(reviewBooking(raw(),stops,'other')).rejects.toMatchObject({code:'invalid-argument'});
 const result=await reviewBooking(raw(),stops,'fake');expect(result.review.snapshot?.vehicle_assessment).toBe('driver_photo_review');
});
test('normalized request preserves snapshot load for confirmation equality',()=>{
 const input=raw();const s=snapshot();expect(JSON.stringify(normalizeLoad(input))).toBe(JSON.stringify(s.load));
 input.items[0].quantity=2;expect(JSON.stringify(normalizeLoad(input))).not.toBe(JSON.stringify(s.load));
});
