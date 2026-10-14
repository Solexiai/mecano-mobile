import { startBookingCardSetup, getBookingCardStatus } from '../../src/functions/bookingCardSetup';
import { setPaymentProviderForTesting } from '../../src/payment/paymentProviderFactory';
import { FakePaymentProvider } from '../testUtils/fakePaymentProvider';
import type { CallableRequest } from 'firebase-functions/v2/https';
import { admin, db } from '../../src/lib/admin';
import { normalizeLoad } from '../../src/lib/booking';
import { findCompatibleVehicle } from '../../src/lib/bookingServer';
import { createDeliveryRequest } from '../../src/functions/createDeliveryRequest';
import { saveBookingDraft, getBookingDraft, requestBookingReview, cleanupExpiredBookingData } from '../../src/functions/bookingJourney';
import { buildQuoteIntegrityEnvelope, computeQuoteIntegrityHash } from '../../src/lib/quoteIntegrity';
import { seedLockedQuote } from '../testUtils/officialQuoteFixture';
import { buildPricingConfig } from '../unit/fixtures';
import { seedDefaultRuntimeFlagsEnabled } from '../testUtils/runtimeFlagsFixture';
import { buildFakePaymentProfile } from '../testUtils/fakePaymentProvider';
const previousPublicUrl=process.env.APP_PUBLIC_BASE_URL;
const uid='booking_customer_test'; const id='booking_quote_test';
const request=(data: unknown, user=uid, verified=true)=>({data,auth:{uid:user,token:{email:'test@example.invalid',email_verified:verified,roles:['customer']}},rawRequest:{},acceptsStreaming:false} as unknown as CallableRequest<any>);
const access={floor:0,stairs:false,elevator:false,help:true};
const load={draft_id:'review-test',items:[{id:'box',category:'boxes',label:'Test box',quantity:1,length:50,width:50,height:50,weight:10,dimension_unit:'cm',weight_unit:'kg',upright:true,approximate:false,photos:[]}],pickup:access,dropoff:access,handlers:1,equipment:[],requested_at:'2099-01-01T12:00:00Z'};
const capacity={category:'cargo_van',rank:1,version:'TEST-ONLY',verified:true,length_cm:200,width_cm:120,height_cm:120,opening_width_cm:100,opening_height_cm:100,payload_kg:200,handlers:2,equipment:[],services:['handling','stairs']};
const snapshot={load:normalizeLoad(load),rules_version:'TEST-ONLY',category:'cargo_van',capacity_version:'TEST-ONLY'};
const stops=[{type:'pickup',address:{line1:'Test pickup',city:'Test city',postal_code:'T0T0T0',lat:45.5,lng:-73.6}},{type:'dropoff',address:{line1:'Test dropoff',city:'Test city',postal_code:'T0T0T0',lat:45.6,lng:-73.7}}];
const contacts={pickup_name:'Test pickup',pickup_phone:'+15145550100',dropoff_name:'Test recipient',dropoff_phone:'+15145550101',instructions:''};
const input={quoteId:id,booking:load,contacts,consent:{terms_version:'TEST-ONLY',accepted:true,marketing:false},requiredVehicleCategory:'cargo_van',stops,itemCategoryKey:'forged',description:'forged',customerDisplayName:'Test'};
beforeEach(async()=>{
 process.env.APP_PUBLIC_BASE_URL='https://booking-test.example.invalid';
 await seedDefaultRuntimeFlagsEnabled();
 await db.doc('system_config/booking_policy').set({approved:true,version:'TEST-ONLY',terms_url:'https://example.invalid/terms',privacy_url:'https://example.invalid/privacy',cancellation_text:{fr:'TEST ONLY'},payment_text:{fr:'TEST ONLY'},setup_enabled:true});
 await db.doc('system_config/booking_capacity').set({approved:true,version:'TEST-ONLY',capacities:[capacity],heavy_item_kg:50,bulky_item_cm:150,require_booking_details:true});
 await db.doc('system_config/service_zones').set({enabled:true,zones:[{name:'TEST ONLY',min_lat:45,max_lat:46,min_lng:-74,max_lng:-73}]});
 await db.doc(`payment_profiles/${uid}`).set(buildFakePaymentProfile(uid));
 const pricing=buildPricingConfig(); await db.doc(`pricing_versions/${pricing.pricing_version}`).set(pricing);
 await seedLockedQuote({quoteId:id,customerId:uid,pricingConfig:pricing,stops,vehicleCategory:'cargoVan',distanceKm:10,estimatedDurationMinutes:20});
 const quote=(await db.doc(`delivery_quotes/${id}`).get()).data()!;
 quote.pricing_snapshot.booking=snapshot;
 quote.integrity_hash=computeQuoteIntegrityHash(buildQuoteIntegrityEnvelope({quoteId:id,customerId:uid,createdAtMillis:quote.created_at.toMillis(),expiresAtMillis:quote.expires_at.toMillis(),stops,pricingSnapshot:quote.pricing_snapshot}));
 await db.doc(`delivery_quotes/${id}`).set(quote);
});
afterEach(async()=>{
 setPaymentProviderForTesting(null);
 if(previousPublicUrl===undefined)delete process.env.APP_PUBLIC_BASE_URL;else process.env.APP_PUBLIC_BASE_URL=previousPublicUrl;
 for(const path of ['system_config/booking_policy','system_config/booking_capacity','system_config/service_zones',`payment_profiles/${uid}`,`booking_payment_setups/${id}`,`booking_drafts/${uid}`,`booking_attempts/${uid}_review-test`,`delivery_quotes/${id}`,'driver_vehicles/booking_vehicle']) await db.doc(path).delete();
 const missions=await db.collection('delivery_requests').where('customer_id','==',uid).get();for(const m of missions.docs)await db.recursiveDelete(m.ref);
 await db.doc(`users/${uid}`).delete();
 const reviews=await db.collection('booking_reviews').where('customer_id','==',uid).get();for(const r of reviews.docs)await r.ref.delete();
});
test('concurrent confirmation creates one mission, preserves cents, cargo and private consent',async()=>{
 const results=await Promise.all([createDeliveryRequest.run(request(input)),createDeliveryRequest.run(request(input))]);
 expect(results[0].missionId).toBe(results[1].missionId);
 const mission=(await db.doc(`delivery_requests/${results[0].missionId}`).get()).data()!;
 const quote=(await db.doc(`delivery_quotes/${id}`).get()).data()!;
 expect(mission.customer_total_minor).toBe(quote.customer_total_minor);expect(mission.description).toBe('1 × Test box');expect(mission.contacts).toBeUndefined();
 const privateData=(await db.doc(`delivery_requests/${results[0].missionId}/private/booking`).get()).data()!;
 expect(privateData.consent.accepted_at.toMillis()).toBeGreaterThan(0);expect(privateData.contacts.pickup_phone).toBe(contacts.pickup_phone);
 expect((await createDeliveryRequest.run(request(input))).missionId).toBe(results[0].missionId);
});
test('changed load, unverified email and stale consent cannot confirm',async()=>{
 await expect(createDeliveryRequest.run(request({...input,booking:{...load,handlers:2}}))).rejects.toMatchObject({code:'failed-precondition'});
 await expect(createDeliveryRequest.run(request(input,uid,false))).rejects.toMatchObject({code:'failed-precondition'});
 await expect(createDeliveryRequest.run(request({...input,consent:{...input.consent,terms_version:'OLD'}}))).rejects.toMatchObject({code:'failed-precondition'});
});
test('draft owner binding and stale revision guard',async()=>{
 const draft={ownerUid:uid,draftId:'test-draft',revision:2,draft:{items:[],test:'latest'}};
 await saveBookingDraft.run(request(draft));await saveBookingDraft.run(request({...draft,revision:1,draft:{items:[],test:'stale'}}));
 expect((await getBookingDraft.run(request({}))).draft).toEqual({items:[],test:'latest'});
 await expect(saveBookingDraft.run(request(draft,'other-account'))).rejects.toMatchObject({code:'permission-denied'});
 expect((await getBookingDraft.run(request({},'other-account'))).draft).toBeNull();
});
test('real vehicle unknown, unverified, expired or undersized is rejected',async()=>{
 expect(await findCompatibleVehicle('driver_test',snapshot)).toBeNull();
 const ref=db.doc('driver_vehicles/booking_vehicle');
 await ref.set({driver_id:'driver_test',is_verified:true,verified_capacity:{...capacity,payload_kg:1},capacity_valid_until:admin.firestore.Timestamp.fromMillis(Date.now()+86400000)});
 expect(await findCompatibleVehicle('driver_test',snapshot)).toBeNull();
 await ref.update({verified_capacity:capacity});expect((await findCompatibleVehicle('driver_test',snapshot))?.vehicle_id).toBe(ref.id);
 await ref.update({capacity_valid_until:admin.firestore.Timestamp.fromMillis(1)});expect(await findCompatibleVehicle('driver_test',snapshot)).toBeNull();
});
test('unknown dimensions open a private review and never a mission',async()=>{
 const result=await requestBookingReview.run(request({draftId:'review-test',load:{...load,items:[{...load.items[0],length:null}]},stops}));
 expect(result.status).toBe('verification_required');
 const missions=await db.collection('delivery_requests').where('customer_id','==',uid).get();expect(missions.empty).toBe(true);
});

test('a recalculated quote for the same draft cannot create a second mission',async()=>{
 const first=await createDeliveryRequest.run(request(input));
 const q=(await db.doc(`delivery_quotes/${id}`).get()).data()!;const nextId='booking_quote_retry';
 q.id=nextId;q.is_consumed=false;q.mission_id=null;q.status='active';delete q.consumed_at;
 q.integrity_hash=computeQuoteIntegrityHash(buildQuoteIntegrityEnvelope({quoteId:nextId,customerId:uid,createdAtMillis:q.created_at.toMillis(),expiresAtMillis:q.expires_at.toMillis(),stops,pricingSnapshot:q.pricing_snapshot}));
 await db.doc(`delivery_quotes/${nextId}`).set(q);
 try {expect((await createDeliveryRequest.run(request({...input,quoteId:nextId}))).missionId).toBe(first.missionId);}
 finally{await db.doc(`delivery_quotes/${nextId}`).delete();}
});

test('hosted setup retry reuses its session; interrupted authentication never marks a card ready',async()=>{
 const provider=new FakePaymentProvider();setPaymentProviderForTesting(provider);
 const profile=(await db.doc(`payment_profiles/${uid}`).get()).data()!;
 await db.doc(`payment_profiles/${uid}`).update({default_payment_method_id:null,stripe_environment:'test'});
 const pending={id:'cs_test_booking',url:'https://checkout.stripe.com/test',complete:false,customerId:profile.provider_customer_id,paymentMethodId:null,livemode:false,quoteId:id,userId:uid};
 const create=jest.spyOn(provider,'createCardSetup').mockResolvedValue(pending);
 const retrieve=jest.spyOn(provider,'getCardSetup').mockResolvedValue(pending);
 const params={quoteId:id,termsVersion:'TEST-ONLY',accepted:true,locale:'fr'};
 expect((await startBookingCardSetup.run(request(params))).ready).toBe(false);
 await startBookingCardSetup.run(request(params));expect(create).toHaveBeenCalledTimes(1);
 expect((await getBookingCardStatus.run(request({quoteId:id}))).ready).toBe(false);
 retrieve.mockResolvedValue({...pending,complete:true,paymentMethodId:'pm_test_booking'});
 expect((await getBookingCardStatus.run(request({quoteId:id}))).ready).toBe(true);
 expect((await getBookingCardStatus.run(request({quoteId:id}))).ready).toBe(true);
 expect((await db.doc(`payment_profiles/${uid}`).get()).data()?.default_payment_method_id).toBe('pm_test_booking');
 await expect(getBookingCardStatus.run(request({quoteId:id},'other-account'))).rejects.toMatchObject({code:'permission-denied'});
});


test('expired photo cleanup is isolated by account and retries a temporary Storage failure',async()=>{
 const expired=admin.firestore.Timestamp.fromMillis(1);
 const ref=db.doc(`booking_drafts/${uid}`);
 const otherGrant=db.doc('booking_photo_grants/other_cleanup-test');
 await ref.set({owner_uid:uid,draft_id:'cleanup-test',expires_at:expired});
 await otherGrant.set({customer_id:'other',mission_id:'other_mission'});
 const remove=jest.fn().mockRejectedValueOnce(new Error('temporary Storage error')).mockResolvedValue(undefined);
 const bucket=jest.spyOn(admin.storage(),'bucket').mockReturnValue({getFiles:jest.fn().mockResolvedValue([[{delete:remove}]])} as any);
 try {
  await expect(cleanupExpiredBookingData()).rejects.toThrow('temporary Storage error');
  expect((await ref.get()).exists).toBe(true);
  expect((await otherGrant.get()).data()?.mission_id).toBe('other_mission');
  await cleanupExpiredBookingData();
  expect((await ref.get()).exists).toBe(false);
  expect(remove).toHaveBeenCalledTimes(2);
 } finally {
  bucket.mockRestore();await otherGrant.delete();await db.doc(`booking_photo_grants/${uid}_cleanup-test`).delete();
 }
});
