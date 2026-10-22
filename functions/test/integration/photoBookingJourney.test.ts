import { testBookingPolicy, testBookingConsent } from '../testUtils/bookingPolicyFixture';
jest.mock('../../src/lib/pushNotifications',()=>({sendDeliveryOfferPush:jest.fn(async()=>({attempted:0,sent:0}))}));
jest.mock('../../src/lib/openAiPhotoAnalyzer',()=>({analyzeWithOpenAi:jest.fn()}));
jest.mock('firebase-functions/params',()=>({...jest.requireActual('firebase-functions/params'),defineSecret:()=>({value:()=> 'SIMULATED-NOT-A-KEY'})}));
import { admin,db } from '../../src/lib/admin';
import { analyzeWithOpenAi } from '../../src/lib/openAiPhotoAnalyzer';
import { handleAnalyzeBookingPhoto } from '../../src/functions/analyzeBookingPhoto';
import { saveBookingDraft,getBookingVehicleForAcceptance } from '../../src/functions/bookingJourney';
import { calculateDeliveryQuote } from '../../src/functions/calculateDeliveryQuote';
import { createDeliveryRequest } from '../../src/functions/createDeliveryRequest';
import { onMissionCreatedDispatch } from '../../src/functions/dispatchMissionToDrivers';
import { acceptDelivery } from '../../src/functions/acceptDelivery';
import { sendDeliveryOfferPush } from '../../src/lib/pushNotifications';
import { encodeGeohash } from '../../src/lib/geohash';
import { buildPricingConfig } from '../unit/fixtures';
import { seedDefaultRuntimeFlagsEnabled } from '../testUtils/runtimeFlagsFixture';
import { FakePaymentProvider,buildFakePaymentProfile } from '../testUtils/fakePaymentProvider';
import { setPaymentProviderForTesting } from '../../src/payment/paymentProviderFactory';
const customer='photo_journey_customer',driver='photo_journey_driver',vehicle='photo_journey_vehicle',draftId='photo-journey-draft';
const photo='booking_photos/'+customer+'/'+draftId+'/item/0.jpg';
const access={floor:0,stairs:false,elevator:false,help:false};
const capacity={category:'cargo_van',rank:1,version:'PHOTO-JOURNEY-TEST',verified:true,length_cm:250,width_cm:150,height_cm:150,opening_width_cm:150,opening_height_cm:150,payload_kg:500,handlers:2,equipment:[],services:['handling','stairs']};
const stops=[{type:'pickup',address:{line1:'Synthetic pickup',city:'Test',postal_code:'T0T0T0',lat:45.4,lng:-72.7}},{type:'dropoff',address:{line1:'Synthetic delivery',city:'Test',postal_code:'T0T0T0',lat:45.41,lng:-72.71}}];
const contacts={pickup_name:'Synthetic Sender',pickup_phone:'+15145550100',dropoff_name:'Synthetic Recipient',dropoff_phone:'+15145550101',instructions:''};
const call=(data:any,uid=customer)=>({data,auth:{uid,token:{email_verified:true,roles:uid===customer?['customer']:['driver']}},rawRequest:{},acceptsStreaming:false} as any);
function booking(special=false,mode:'immediate'|'scheduled'='immediate'):any{return {draft_id:draftId,intake_mode:'photo_assisted',timing_mode:mode,requested_at:mode==='scheduled'?'2099-01-01T12:00:00Z':null,pickup:access,dropoff:access,handlers:1,equipment:[],items:[{id:'item',category:special?'materials':'sofa',label:special?'Synthetic materials':'Synthetic sofa',quantity:1,length:special?120:null,width:special?40:null,height:special?30:null,weight:null,dimension_unit:'cm',weight_unit:'kg',approximate:special,upright:true,photos:[photo],identification_confirmed:true,special_handling:special,...(special?{handling_notes:'Bundled; ground floor access.'}:{})}]};}
let provider:FakePaymentProvider,storage:jest.SpyInstance,stored:Set<string>;
beforeEach(async()=>{
 jest.clearAllMocks();provider=new FakePaymentProvider();setPaymentProviderForTesting(provider);stored=new Set([photo]);
 storage=jest.spyOn(admin.storage(),'bucket').mockReturnValue({file:(name:string)=>({
  getMetadata:async()=>{if(!stored.has(name))throw Object.assign(Error('missing synthetic image'),{code:404});return [{contentType:'image/jpeg',size:4,generation:'1'}];},
  download:async()=>[Buffer.from([255,216,255,0])]
 })} as any);
 (analyzeWithOpenAi as jest.Mock).mockResolvedValue({category:'sofa',label:'Synthetic sofa',confidence:'high',special_handling:false,reason:'ordinary'});
 await seedDefaultRuntimeFlagsEnabled();
 const pricing=buildPricingConfig({pricing_version:'PHOTO-JOURNEY-TEST'});
 await db.doc('pricing_configs/active').set({active_pricing_version:pricing.pricing_version});
 await db.doc('pricing_versions/PHOTO-JOURNEY-TEST').set(pricing);
 await db.doc('system_config/booking_capacity').set({approved:true,version:'PHOTO-JOURNEY-TEST',capacities:[capacity],heavy_item_kg:100,bulky_item_cm:300,require_booking_details:true,photo_intake:{enabled:true,version:'PHOTO-JOURNEY-TEST',category_vehicle_categories:{sofa:['cargo_van'],materials:['cargo_van']}}});
 await db.doc('system_config/service_zones').set({enabled:true,zones:[{name:'SIMULATED',min_lat:45,max_lat:46,min_lng:-73,max_lng:-72}]});
 await db.doc('system_config/booking_policy').set(testBookingPolicy('PHOTO-JOURNEY-TEST'));
 await db.doc('system_config/photo_analysis').set({enabled:true,provider:'openai',model:'SIMULATED',allowedUserUids:[customer],userDailyLimit:10,globalDailyLimit:20});
 await db.doc('payment_profiles/'+customer).set(buildFakePaymentProfile(customer));
 await db.doc('driver_profiles/'+driver).set({status:'approved',full_name:'Synthetic Driver',online_status:'online',documents_all_valid:true,accepted_vehicle_categories:['cargoVan'],current_geohash:encodeGeohash(45.4,-72.7,6)});
 await db.doc('driver_vehicles/'+vehicle).set({driver_id:driver,is_verified:true,verified_capacity:capacity,capacity_valid_until:admin.firestore.Timestamp.fromMillis(Date.now()+86400000)});
});
afterEach(async()=>{
 storage.mockRestore();setPaymentProviderForTesting(null);
 // Dedicated demo emulator only; never allowed against an existing project.
 if(process.env.GCLOUD_PROJECT!=='demo-movik-test'||process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8080')throw Error('cleanup isolation');
 for(const collection of ['delivery_quotes','delivery_requests','delivery_offers','financial_snapshots','payments','audit_logs','booking_drafts','booking_attempts','booking_photo_grants','photo_analysis_usage','users','driver_locations','driver_profiles','driver_vehicles','payment_profiles','pricing_configs','pricing_versions','system_config','routing_rate_limits'])await db.recursiveDelete(db.collection(collection));
});
async function quoteAndCreate(load:any){
 const result=await calculateDeliveryQuote.run(call({booking:load,stops}));
 const input={quoteId:result.quoteId,booking:load,stops,contacts,consent:testBookingConsent('PHOTO-JOURNEY-TEST'),description:'',itemCategoryKey:'',requiredVehicleCategory:result.vehicleCategory,customerDisplayName:'Synthetic'};
 const created=await createDeliveryRequest.run(call(input));
 expect((await createDeliveryRequest.run(call(input))).missionId).toBe(created.missionId);
 return {result,created};
}
test.each(['immediate','scheduled'] as const)('%s photo -> AI suggestion -> quote -> mission -> offer -> acceptance preserves exact cents',async mode=>{
 const load=booking(false,mode);
 await saveBookingDraft.run(call({ownerUid:customer,draftId,revision:1,draft:{intake_mode:'photo_assisted',items:load.items}}));
 const suggestion=await handleAnalyzeBookingPhoto(call({draftId,itemId:'item',photoPath:photo,locale:'fr',consent:true}));
 expect(suggestion).toMatchObject({suggestion:{category:'sofa'},quoteAuthorized:false,measurementsVerified:false,requiresConfirmation:true});
 const {result,created}=await quoteAndCreate(load);
 const ref=db.doc('delivery_requests/'+created.missionId);const mission=(await ref.get()).data()!;
 const quote=(await db.doc('delivery_quotes/'+result.quoteId).get()).data()!;
 expect(mission.booking_snapshot.load.items[0].photos).toEqual([photo]);
 expect(mission.booking_snapshot.load.items[0].weight_kg).toBeNull();
 expect(mission.customer_total_minor).toBe(quote.customer_total_minor);
 await onMissionCreatedDispatch.run({data:{data:()=>mission},params:{missionId:created.missionId}} as any);
 const offers=await db.collection('delivery_offers').where('mission_id','==',created.missionId).get();
 expect(offers.size).toBe(1);expect(offers.docs[0].data()).toMatchObject({driver_id:driver,status:'pending'});
 expect((await db.doc('users/'+driver+'/notifications/delivery_offer_'+created.missionId).get()).exists).toBe(true);
 expect(sendDeliveryOfferPush).toHaveBeenCalledTimes(1);
 expect((await db.doc('booking_photo_grants/'+customer+'_'+draftId).get()).data()?.mission_id).toBe(created.missionId);
 const chosen=await getBookingVehicleForAcceptance.run(call({missionId:created.missionId},driver));
 expect(chosen.vehicle?.id).toBe(vehicle);
 const accepted=await acceptDelivery.run(call({missionId:created.missionId,vehicleId:vehicle},driver));
 expect(accepted.success).toBe(true);
 const finalMission=(await ref.get()).data()!;
 expect(finalMission.driver_id).toBe(driver);expect(finalMission.assigned_vehicle_id).toBe(vehicle);
 const snapshot=(await db.doc('financial_snapshots/'+accepted.snapshotId).get()).data()!;
 expect(snapshot.customer_total_minor).toBe(quote.customer_total_minor);
 expect(snapshot.pricing_snapshot).toEqual(quote.pricing_snapshot);
 expect(provider.createdPaymentParams).toHaveLength(1);
 expect(provider.createdPaymentParams[0].amountMinor).toBe(quote.customer_total_minor);
 expect(finalMission.booking_snapshot.load.items[0].length_cm).toBeNull();
});
test('special-item details reach the driver snapshot without inventing unknown weight',async()=>{
 const load=booking(true);const {created}=await quoteAndCreate(load);
 const mission=(await db.doc('delivery_requests/'+created.missionId).get()).data()!;
 expect(mission.booking_snapshot.load.items[0]).toMatchObject({handling_notes:'Bundled; ground floor access.',length_cm:120,weight_kg:null});
 await onMissionCreatedDispatch.run({data:{data:()=>mission},params:{missionId:created.missionId}} as any);
 expect((await db.collection('delivery_offers').where('mission_id','==',created.missionId).get()).size).toBe(1);
});
test('changing photo or special details invalidates the locked quote',async()=>{
 const load=booking(true),q=await calculateDeliveryQuote.run(call({booking:load,stops}));
 load.items[0].handling_notes='Different handling';
 await expect(createDeliveryRequest.run(call({quoteId:q.quoteId,booking:load,stops,contacts,consent:testBookingConsent('PHOTO-JOURNEY-TEST')}))).rejects.toMatchObject({code:'failed-precondition'});
 expect((await db.collection('delivery_requests').get()).empty).toBe(true);
});
test('a missing private photo cannot obtain an official photo quote',async()=>{
 stored.clear();
 await expect(calculateDeliveryQuote.run(call({booking:booking(),stops}))).rejects.toMatchObject({code:'failed-precondition'});
 expect((await db.collection('delivery_quotes').get()).empty).toBe(true);
});
test('photo owned by a different customer is rejected before quote',async()=>{
 const load=booking();load.items[0].photos=['booking_photos/other/'+draftId+'/item/0.jpg'];
 await expect(calculateDeliveryQuote.run(call({booking:load,stops}))).rejects.toMatchObject({code:'invalid-argument'});
});
test('non-eligible driver receives no offer; customer demand remains honestly unassigned',async()=>{
 await db.doc('driver_vehicles/'+vehicle).update({is_verified:false});
 const {created}=await quoteAndCreate(booking());const ref=db.doc('delivery_requests/'+created.missionId),mission=(await ref.get()).data()!;
 await onMissionCreatedDispatch.run({data:{data:()=>mission},params:{missionId:created.missionId}} as any);
 expect((await ref.get()).data()?.status).toBe('searching_driver');
 expect((await db.collection('delivery_offers').get()).empty).toBe(true);expect(provider.createdPaymentParams).toHaveLength(0);
});


test('driver sees server-calculated remuneration before acceptance without financial writes', async () => {
 const {created}=await quoteAndCreate(booking());
 const ref=db.doc('delivery_requests/'+created.missionId),mission=(await ref.get()).data()!;
 await onMissionCreatedDispatch.run({data:{data:()=>mission},params:{missionId:created.missionId}} as any);
 const response:any=await getBookingVehicleForAcceptance.run(call({missionId:created.missionId},driver));
 expect(response.offerTerms).toMatchObject({currency:'CAD',pricingVersion:'PHOTO-JOURNEY-TEST'});
 expect(Number.isSafeInteger(response.offerTerms.amountMinor)).toBe(true);
 expect(response.offerTerms.amountMinor).toBeGreaterThan(0);
 expect((await db.collection('financial_snapshots').get()).empty).toBe(true);
 expect(provider.createdPaymentParams).toHaveLength(0);
 const accepted=await acceptDelivery.run(call({missionId:created.missionId,vehicleId:vehicle,
   expectedDriverOfferMinor:response.offerTerms.amountMinor},driver));
 const snapshot=(await db.doc('financial_snapshots/'+accepted.snapshotId).get()).data()!;
 expect(Math.round(snapshot.driver_offer_amount*100)).toBe(response.offerTerms.amountMinor);
});

test('changed remuneration cannot be accepted under the previously displayed amount', async () => {
 const {created}=await quoteAndCreate(booking());
 const mission=(await db.doc('delivery_requests/'+created.missionId).get()).data()!;
 await onMissionCreatedDispatch.run({data:{data:()=>mission},params:{missionId:created.missionId}} as any);
 await expect(acceptDelivery.run(call({missionId:created.missionId,vehicleId:vehicle,
   expectedDriverOfferMinor:1},driver))).rejects.toMatchObject({code:'failed-precondition'});
 expect((await db.doc('delivery_requests/'+created.missionId).get()).data()?.driver_id).toBeNull();
 expect((await db.collection('financial_snapshots').get()).empty).toBe(true);
 expect(provider.createdPaymentParams).toHaveLength(0);
});

test('a declined offer cannot obtain new acceptance terms', async () => {
 const {created}=await quoteAndCreate(booking());
 const mission=(await db.doc('delivery_requests/'+created.missionId).get()).data()!;
 await onMissionCreatedDispatch.run({data:{data:()=>mission},params:{missionId:created.missionId}} as any);
 const offers=await db.collection('delivery_offers').where('mission_id','==',created.missionId).get();
 await offers.docs[0].ref.update({status:'declined'});
 await expect(getBookingVehicleForAcceptance.run(call({missionId:created.missionId},driver)))
   .rejects.toMatchObject({code:'failed-precondition'});
});


test('offer withdrawn after preview cannot be accepted with the old confirmation', async () => {
 const {created}=await quoteAndCreate(booking());
 const mission=(await db.doc('delivery_requests/'+created.missionId).get()).data()!;
 await onMissionCreatedDispatch.run({data:{data:()=>mission},params:{missionId:created.missionId}} as any);
 const response:any=await getBookingVehicleForAcceptance.run(call({missionId:created.missionId},driver));
 const offers=await db.collection('delivery_offers').where('mission_id','==',created.missionId).get();
 await offers.docs[0].ref.update({status:'declined'});
 await expect(acceptDelivery.run(call({missionId:created.missionId,vehicleId:vehicle,
   expectedDriverOfferMinor:response.offerTerms.amountMinor},driver)))
   .rejects.toMatchObject({code:'failed-precondition'});
 expect((await db.doc('delivery_requests/'+created.missionId).get()).data()?.driver_id).toBeNull();
 expect(provider.createdPaymentParams).toHaveLength(0);
});
