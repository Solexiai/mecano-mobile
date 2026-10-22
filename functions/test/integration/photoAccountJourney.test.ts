import { testBookingPolicy, testBookingConsent } from '../testUtils/bookingPolicyFixture';
jest.mock('../../src/lib/pushNotifications', () => ({ sendDeliveryOfferPush: jest.fn(async () => ({attempted:0,sent:0})) }));
jest.mock('../../src/lib/openAiPhotoAnalyzer', () => ({ analyzeWithOpenAi: jest.fn() }));
jest.mock('firebase-functions/params', () => ({ ...jest.requireActual('firebase-functions/params'), defineSecret: () => ({value: () => 'SIMULATED-NOT-A-KEY'}) }));
import {readFileSync,appendFileSync} from 'fs';
import {randomBytes} from 'crypto';
import {initializeApp,deleteApp,FirebaseApp} from 'firebase/app';
import {getAuth,connectAuthEmulator,signInWithEmailAndPassword,signOut,Auth} from 'firebase/auth';
import {getFirestore,connectFirestoreEmulator,doc,getDoc,collection,query,where,getDocs,terminate,Firestore} from 'firebase/firestore';
import {getStorage,connectStorageEmulator,ref,uploadBytes,getBytes,FirebaseStorage} from 'firebase/storage';
import {admin,db} from '../../src/lib/admin';
import {analyzeWithOpenAi} from '../../src/lib/openAiPhotoAnalyzer';
import {handleAnalyzeBookingPhoto} from '../../src/functions/analyzeBookingPhoto';
import {saveBookingDraft,getBookingVehicleForAcceptance} from '../../src/functions/bookingJourney';
import {calculateDeliveryQuote} from '../../src/functions/calculateDeliveryQuote';
import {createDeliveryRequest} from '../../src/functions/createDeliveryRequest';
import {onMissionCreatedDispatch} from '../../src/functions/dispatchMissionToDrivers';
import {approveDriver} from '../../src/functions/approveDriver';
import {reviewDriverVehicle,vehicleIdentity} from '../../src/functions/reviewDriverVehicle';
import {acceptDelivery} from '../../src/functions/acceptDelivery';
import {declineDeliveryOffer} from '../../src/functions/driverScheduleLifecycle';
import {encodeGeohash} from '../../src/lib/geohash';
import {buildPricingConfig} from '../unit/fixtures';
import {seedDefaultRuntimeFlagsEnabled} from '../testUtils/runtimeFlagsFixture';
import {FakePaymentProvider,buildFakePaymentProfile} from '../testUtils/fakePaymentProvider';
import {setPaymentProviderForTesting} from '../../src/payment/paymentProviderFactory';
import { TEST_SCHEDULED_PICKUP } from '../testUtils/bookingTimeFixture';

const project='demo-movik-test',customer='account_journey_customer',driver='account_journey_driver',stranger='account_journey_stranger';
const vehicle='account_journey_vehicle',draftId='account-journey-draft';
const photo='booking_photos/'+customer+'/'+draftId+'/item/0.jpg';
const access={floor:0,stairs:false,elevator:false,help:false};
const capacity={category:'cargo_van',rank:1,version:'ACCOUNT-JOURNEY-TEST',verified:true,length_cm:250,width_cm:150,height_cm:150,opening_width_cm:150,opening_height_cm:150,payload_kg:500,handlers:2,equipment:[],services:['handling','stairs']};
const stops=[{type:'pickup',address:{line1:'Synthetic pickup',city:'Test',postal_code:'T0T0T0',lat:45.4,lng:-72.7}},{type:'dropoff',address:{line1:'Synthetic delivery',city:'Test',postal_code:'T0T0T0',lat:45.41,lng:-72.71}}];
const contacts={pickup_name:'Synthetic Sender',pickup_phone:'+15145550100',dropoff_name:'Synthetic Recipient',dropoff_phone:'+15145550101',instructions:''};
type Actor={app:FirebaseApp,auth:Auth,firestore:Firestore,storage:FirebaseStorage};
const actors:Actor[]=[];
let client:Actor,courier:Actor,foreign:Actor,reviewer:Actor,provider:FakePaymentProvider,bytes:Uint8Array;
function evidence(step:string,details:Record<string,unknown>={}){
 if(process.env.MOVIK_JOURNEY_LOG)appendFileSync(process.env.MOVIK_JOURNEY_LOG,JSON.stringify({test:expect.getState().currentTestName,step,...details})+'\n');
}
async function login(uid:string,role:'customer'|'driver'|'admin'):Promise<Actor>{
 const password=randomBytes(24).toString('base64url'),email=uid+'@example.invalid';
 await admin.auth().createUser({uid,email,password,emailVerified:true});
 await admin.auth().setCustomUserClaims(uid,{roles:[role]});
 const app=initializeApp({projectId:project,apiKey:'demo-key',appId:'1:123:web:accounts-test',storageBucket:project+'.appspot.com'},uid);
 const auth=getAuth(app);connectAuthEmulator(auth,'http://127.0.0.1:9099',{disableWarnings:true});
 const firestore=getFirestore(app);connectFirestoreEmulator(firestore,'127.0.0.1',8080);
 const storage=getStorage(app);connectStorageEmulator(storage,'127.0.0.1',9199);
 storage.maxOperationRetryTime=1000;storage.maxUploadRetryTime=1000;
 const actor={app,auth,firestore,storage};actors.push(actor);
 const signed=await signInWithEmailAndPassword(auth,email,password);
 const decoded=await admin.auth().verifyIdToken(await signed.user.getIdToken());
 expect(decoded.uid).toBe(uid);expect(decoded.roles).toEqual([role]);
 if(role!=='admin')expect(decoded.roles).not.toContain('admin');expect(decoded.roles).not.toContain('super_admin');
 evidence('password-login-and-token-verified',{actor:role,uid,project});
 return actor;
}
async function request(actor:Actor,data:unknown):Promise<any>{
 const user=actor.auth.currentUser;if(!user)throw Error('No signed-in test account');
 const decoded=await admin.auth().verifyIdToken(await user.getIdToken());
 return {data,auth:{uid:decoded.uid,token:decoded},rawRequest:{},acceptsStreaming:false};
}
function load(mode:'immediate'|'scheduled'){
 return {draft_id:draftId,intake_mode:'photo_assisted',timing_mode:mode,requested_at:mode==='scheduled'?TEST_SCHEDULED_PICKUP:null,pickup:access,dropoff:access,handlers:1,equipment:[],items:[{id:'item',category:'sofa',label:'Synthetic sofa',quantity:1,length:null,width:null,height:null,weight:null,dimension_unit:'cm',weight_unit:'kg',approximate:false,upright:true,photos:[photo],identification_confirmed:true,special_handling:false}]};
}
beforeEach(async()=>{
 if(process.env.GCLOUD_PROJECT!==project||process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8080'||process.env.FIREBASE_AUTH_EMULATOR_HOST!=='127.0.0.1:9099'||process.env.FIREBASE_STORAGE_EMULATOR_HOST!=='127.0.0.1:9199')throw Error('Account test isolation required');
 // A local JPEG may be supplied; otherwise a tiny synthetic 1x1 JPEG is used
 // (CI). Never a real customer photo.
 bytes=process.env.MOVIK_TEST_JPEG ? new Uint8Array(readFileSync(process.env.MOVIK_TEST_JPEG)) :
  new Uint8Array(Buffer.from('/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA=','base64'));
 expect([...bytes.slice(0,3)]).toEqual([255,216,255]);
 jest.clearAllMocks();provider=new FakePaymentProvider();setPaymentProviderForTesting(provider);
 (analyzeWithOpenAi as jest.Mock).mockResolvedValue({category:'sofa',label:'Synthetic sofa',confidence:'high',special_handling:false,reason:'ordinary'});
 client=await login(customer,'customer');courier=await login(driver,'driver');foreign=await login(stranger,'customer');reviewer=await login('account_journey_reviewer','admin');
 await seedDefaultRuntimeFlagsEnabled();
 const pricing=buildPricingConfig({pricing_version:'ACCOUNT-JOURNEY-TEST'});
 await db.doc('pricing_configs/active').set({active_pricing_version:pricing.pricing_version});
 await db.doc('pricing_versions/'+pricing.pricing_version).set(pricing);
 await db.doc('system_config/booking_capacity').set({approved:true,version:'ACCOUNT-JOURNEY-TEST',capacities:[capacity],heavy_item_kg:100,bulky_item_cm:300,require_booking_details:true,photo_intake:{enabled:true,version:'ACCOUNT-JOURNEY-TEST',category_vehicle_categories:{sofa:['cargo_van']}}});
 await db.doc('system_config/service_zones').set({enabled:true,zones:[{name:'SIMULATED',min_lat:45,max_lat:46,min_lng:-73,max_lng:-72}]});
 await db.doc('system_config/booking_policy').set(testBookingPolicy('ACCOUNT-JOURNEY-TEST'));
 await db.doc('system_config/photo_analysis').set({enabled:true,provider:'openai',model:'SIMULATED',allowedUserUids:[customer],userDailyLimit:10,globalDailyLimit:20});
 await db.doc('payment_profiles/'+customer).set(buildFakePaymentProfile(customer));
 await db.doc('driver_profiles/'+driver).set({status:'pending_review',full_name:'Synthetic Driver',online_status:'online',documents_all_valid:false,accepted_vehicle_categories:['cargoVan'],current_geohash:encodeGeohash(45.4,-72.7,6)});
 await db.doc('driver_vehicles/'+vehicle).set({driver_id:driver,category:'cargo_van',make_model:'SYNTHETIC VEHICLE',year:2025,plate:'TEST-ONLY',max_payload_kg:500,is_verified:false});
 for(const type of ['drivers_licence','vehicle_registration','insurance','identity']) await db.doc('driver_documents/'+type).set({driver_id:driver,type,status:'uploaded',uploaded_at:admin.firestore.Timestamp.now(),expires_at:admin.firestore.Timestamp.fromMillis(Date.now()+604800000)});
 await approveDriver.run(await request(reviewer,{driverId:driver}));
 await verifyVehicle('cargo_van');
});
afterEach(async()=>{
 for(const actor of actors.splice(0)){await signOut(actor.auth);await terminate(actor.firestore);await deleteApp(actor.app);}
 setPaymentProviderForTesting(null);
 if(process.env.GCLOUD_PROJECT!==project||process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8080')throw Error('cleanup isolation');
 await admin.storage().bucket().deleteFiles({prefix:'booking_photos/'+customer+'/'});
 await admin.auth().deleteUsers([customer,driver,stranger,'account_journey_reviewer']);
 for(const c of ['delivery_quotes','delivery_requests','delivery_offers','financial_snapshots','payments','audit_logs','booking_drafts','booking_attempts','booking_photo_grants','photo_analysis_usage','users','driver_locations','driver_profiles','driver_documents','driver_vehicles','payment_profiles','pricing_configs','pricing_versions','system_config','routing_rate_limits'])await db.recursiveDelete(db.collection(c));
});
async function verifyVehicle(category:string){
 const v=(await db.doc('driver_vehicles/'+vehicle).get()).data()!;
 await reviewDriverVehicle.run(await request(reviewer,{driverId:driver,vehicleId:vehicle,action:'approve',expectedIdentity:vehicleIdentity(v),capacity:{...capacity,category},validUntil:new Date(Date.now()+86400000).toISOString(),verificationNote:'SYNTHETIC measured capacities, no real vehicle'}));
 evidence('administrative-vehicle-verification',{vehicleId:vehicle,category});
}
async function prepare(mode:'immediate'|'scheduled'='immediate'){
 const booking=load(mode);
 await saveBookingDraft.run(await request(client,{ownerUid:customer,draftId,revision:1,draft:{intake_mode:'photo_assisted',items:booking.items}}));
 await uploadBytes(ref(client.storage,photo),bytes,{contentType:'image/jpeg'});
 expect(new Uint8Array(await getBytes(ref(client.storage,photo)))).toEqual(bytes);
 await expect(getBytes(ref(foreign.storage,photo))).rejects.toMatchObject({code:'storage/unauthorized'});
 await expect(getBytes(ref(courier.storage,photo))).rejects.toMatchObject({code:'storage/unauthorized'});
 evidence('private-upload-owner-only-before-mission',{byteCount:bytes.length});
 const suggestion=await handleAnalyzeBookingPhoto(await request(client,{draftId,itemId:'item',photoPath:photo,locale:'fr',consent:true}));
 expect(suggestion).toMatchObject({suggestion:{category:'sofa'},requiresConfirmation:true,quoteAuthorized:false});
 const quote=await calculateDeliveryQuote.run(await request(client,{booking,stops}));
 const input={quoteId:quote.quoteId,booking,stops,contacts,consent:testBookingConsent('ACCOUNT-JOURNEY-TEST'),description:'',itemCategoryKey:'',requiredVehicleCategory:quote.vehicleCategory,customerDisplayName:'Synthetic'};
 const created=await createDeliveryRequest.run(await request(client,input));
 expect((await createDeliveryRequest.run(await request(client,input))).missionId).toBe(created.missionId);
 const mref=db.doc('delivery_requests/'+created.missionId),mission=(await mref.get()).data()!;
 await onMissionCreatedDispatch.run({data:{data:()=>mission},params:{missionId:created.missionId}} as any);
 return {booking,quote,created,mref};
}
test.each([
 ['immediate','cargo_van'],['scheduled','cargo_van'],
 ['immediate','pickup_truck'],['scheduled','pickup_truck'],
 ['immediate','cube_truck'],['scheduled','cube_truck'],
] as const)('%s / %s: real emulator accounts and private photo reach eligible driver and exact-price assignment',async(mode,category)=>{
 // Synthetic per-category configuration: no claim about real vehicle capacity or public pricing.
 const selectedCapacity={...capacity,category};
 await db.doc('system_config/booking_capacity').update({capacities:[selectedCapacity],'photo_intake.category_vehicle_categories.sofa':[category]});
 await db.doc('driver_vehicles/'+vehicle).update({category});
 await verifyVehicle(category);
 await db.doc('driver_profiles/'+driver).update({accepted_vehicle_categories:[category]});
 const syntheticPricing=buildPricingConfig();
 await db.doc('pricing_versions/ACCOUNT-JOURNEY-TEST').update({vehicle_rules:[{...syntheticPricing.vehicle_rules[0],category}]});
 const {quote,created,mref}=await prepare(mode);
 expect(quote.vehicleCategory).toBe(category);
 const offers=await getDocs(query(collection(courier.firestore,'delivery_offers'),where('driver_id','==',driver),where('status','==','pending')));
 expect(offers.size).toBe(1);expect(offers.docs[0].data().mission_id).toBe(created.missionId);
 expect((await getDoc(doc(courier.firestore,'users/'+driver+'/notifications/delivery_offer_'+created.missionId))).exists()).toBe(true);
 expect(new Uint8Array(await getBytes(ref(courier.storage,photo)))).toEqual(bytes);
 await expect(getBytes(ref(foreign.storage,photo))).rejects.toMatchObject({code:'storage/unauthorized'});
 await expect(getDoc(doc(foreign.firestore,'delivery_requests/'+created.missionId))).rejects.toMatchObject({code:'permission-denied'});
 evidence('driver-offer-notification-photo-authorized',{missionId:created.missionId,vehicleCategory:quote.vehicleCategory});
 const selected=await getBookingVehicleForAcceptance.run(await request(courier,{missionId:created.missionId}));
 expect(selected.vehicle?.id).toBe(vehicle);
 const accepted=await acceptDelivery.run(await request(courier,{missionId:created.missionId,vehicleId:vehicle}));
 expect(accepted.success).toBe(true);
 const visible=(await getDoc(doc(client.firestore,'delivery_requests/'+created.missionId))).data()!;
 expect(visible.driver_id).toBe(driver);expect(visible.assigned_vehicle_id).toBe(vehicle);
 const official=(await db.doc('delivery_quotes/'+quote.quoteId).get()).data()!;
 const snapshot=(await db.doc('financial_snapshots/'+accepted.snapshotId).get()).data()!;
 expect(visible.customer_total_minor).toBe(official.customer_total_minor);
 expect(snapshot.customer_total_minor).toBe(official.customer_total_minor);
 expect(provider.createdPaymentParams).toHaveLength(1);
 expect(provider.createdPaymentParams[0].amountMinor).toBe(official.customer_total_minor);
 expect((await mref.get()).data()?.booking_snapshot.load.items[0].weight_kg).toBeNull();
 evidence('assignment-visible-to-client',{missionId:created.missionId,vehicleId:vehicle,amountMinor:official.customer_total_minor,provider:'FAKE',externalPayment:false});
});
test('driver test account can decline its offer without cancelling or paying the customer request',async()=>{
 const {created,mref}=await prepare(),before=(await mref.get()).data();
 expect(await declineDeliveryOffer.run(await request(courier,{missionId:created.missionId}))).toEqual({declined:true});
 const pending=await getDocs(query(collection(courier.firestore,'delivery_offers'),where('driver_id','==',driver),where('status','==','pending')));
 expect(pending.empty).toBe(true);expect((await mref.get()).data()).toEqual(before);expect(provider.createdPaymentParams).toHaveLength(0);
 evidence('decline-recorded-without-mission-or-money-change');
});
test('unverified fictitious vehicle cannot receive an offer or be selected for acceptance',async()=>{
 await db.doc('driver_vehicles/'+vehicle).update({is_verified:false});
 const {created,mref}=await prepare();
 const offers=await getDocs(query(collection(courier.firestore,'delivery_offers'),where('driver_id','==',driver)));
 expect(offers.empty).toBe(true);expect((await mref.get()).data()?.status).toBe('searching_driver');
 await expect(getBookingVehicleForAcceptance.run(await request(courier,{missionId:created.missionId}))).rejects.toMatchObject({code:'failed-precondition'});
 expect(provider.createdPaymentParams).toHaveLength(0);
 evidence('unverified-vehicle-refused');
});
