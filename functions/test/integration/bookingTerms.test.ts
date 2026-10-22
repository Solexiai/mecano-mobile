import { getBookingReceipt } from '../../src/functions/bookingReceipt';
import { testBookingPolicy, testBookingConsent } from '../testUtils/bookingPolicyFixture';
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
import { TEST_SCHEDULED_PICKUP } from '../testUtils/bookingTimeFixture';
const previousPublicUrl=process.env.APP_PUBLIC_BASE_URL;
const uid='booking_customer_test'; const id='booking_quote_test';
const request=(data: unknown, user=uid, verified=true)=>({data,auth:{uid:user,token:{email:'test@example.invalid',email_verified:verified,roles:['customer']}},rawRequest:{},acceptsStreaming:false} as unknown as CallableRequest<any>);
const access={floor:0,stairs:false,elevator:false,help:true};
const load={draft_id:'review-test',items:[{id:'box',category:'boxes',label:'Test box',quantity:1,length:50,width:50,height:50,weight:10,dimension_unit:'cm',weight_unit:'kg',upright:true,approximate:false,photos:[]}],pickup:access,dropoff:access,handlers:1,equipment:[],requested_at:TEST_SCHEDULED_PICKUP};
const capacity={category:'cargo_van',rank:1,version:'TEST-ONLY',verified:true,length_cm:200,width_cm:120,height_cm:120,opening_width_cm:100,opening_height_cm:100,payload_kg:200,handlers:2,equipment:[],services:['handling','stairs']};
const snapshot={load:normalizeLoad(load),rules_version:'TEST-ONLY',category:'cargo_van',capacity_version:'TEST-ONLY'};
const stops=[{type:'pickup',address:{line1:'Test pickup',city:'Test city',postal_code:'T0T0T0',lat:45.5,lng:-73.6}},{type:'dropoff',address:{line1:'Test dropoff',city:'Test city',postal_code:'T0T0T0',lat:45.6,lng:-73.7}}];
const contacts={pickup_name:'Test pickup',pickup_phone:'+15145550100',dropoff_name:'Test recipient',dropoff_phone:'+15145550101',instructions:''};
const input={quoteId:id,booking:load,contacts,consent:testBookingConsent('TEST-ONLY'),requiredVehicleCategory:'cargo_van',stops,itemCategoryKey:'forged',description:'forged',customerDisplayName:'Test'};
beforeEach(async()=>{
 process.env.APP_PUBLIC_BASE_URL='https://booking-test.example.invalid';
 await seedDefaultRuntimeFlagsEnabled();
 await db.doc('system_config/booking_policy').set(testBookingPolicy('TEST-ONLY'));
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

test.each([false,undefined])('server rejects accepted=%s with complete current documents', async accepted=>{
 await expect(createDeliveryRequest.run(request({...input,consent:{...testBookingConsent(),accepted}}))).rejects.toMatchObject({code:'failed-precondition'});
 expect((await db.doc(`delivery_quotes/${id}`).get()).data()?.is_consumed).toBe(false);
});
test.each(['contract_hash','booking_terms_version','general_terms_version','privacy_presented_version','terms_version'])('server rejects stale %s',async field=>{
 await expect(createDeliveryRequest.run(request({...input,consent:{...testBookingConsent(),[field]:'OLD'}}))).rejects.toMatchObject({code:'failed-precondition'});
});
test('same version with changed text invalidates earlier acceptance', async()=>{
 await db.doc('system_config/booking_policy').update({'documents.terms.content.fr':'SIMULATION CHANGED WITHOUT VERSION BUMP'});
 await expect(createDeliveryRequest.run(request(input))).rejects.toMatchObject({code:'failed-precondition'});
});
test('receipt stores original terms, server date, privacy presentation and separate optional marketing', async()=>{
 const {missionId}=await createDeliveryRequest.run(request(input));
 const stored=(await db.doc(`delivery_requests/${missionId}/private/booking`).get()).data()!;
 expect(stored.consent.accepted_by).toBe(uid);
 expect(stored.consent.accepted_at.toMillis()).toBeGreaterThan(0);
 expect(stored.consent.privacy_presented_version).toBe('TEST-ONLY-privacy');
 expect(stored.consent.privacy_accepted).toBeUndefined();
 expect(stored.consent.marketing).toBeUndefined();
 expect(stored.marketing_preference.opt_in).toBe(false);
 await db.doc('system_config/booking_policy').set(testBookingPolicy('NEW-VERSION'));
 const r=await getBookingReceipt.run(request({missionId}));
 expect(r.contract).toEqual(testBookingPolicy());
 expect(r.acceptance.acceptedAtMillis).toBe(stored.consent.accepted_at.toMillis());
 expect(r.customerTotalMinor).toBe((await db.doc(`delivery_quotes/${id}`).get()).data()?.customer_total_minor);
 expect(r.driverAssigned).toBe(false);
 expect(r.paymentStatus).toBe('pending');
 await expect(getBookingReceipt.run(request({missionId},'other-owner'))).rejects.toMatchObject({code:'permission-denied'});
});
test('expired quote cannot consume contract acceptance',async()=>{
 await db.doc(`delivery_quotes/${id}`).update({expires_at:admin.firestore.Timestamp.fromMillis(1)});
 await expect(createDeliveryRequest.run(request(input))).rejects.toMatchObject({code:'failed-precondition'});
 expect((await db.collection('delivery_requests').where('customer_id','==',uid).get()).empty).toBe(true);
});
test('incomplete current document keeps booking and card setup closed',async()=>{
 await db.doc('system_config/booking_policy').update({'documents.booking.content.fr':''});
 await expect(createDeliveryRequest.run(request(input))).rejects.toMatchObject({code:'failed-precondition'});
 await expect(startBookingCardSetup.run(request({quoteId:id,consent:testBookingConsent()}))).rejects.toMatchObject({code:'failed-precondition'});
});
test('legacy reservation never displays current terms as original terms',async()=>{
 const {missionId}=await createDeliveryRequest.run(request(input));
 await db.doc(`delivery_requests/${missionId}/private/booking`).set({consent:{terms_version:'LEGACY',accepted_at:admin.firestore.Timestamp.now(),payment_text:{fr:'OLD STORED TEXT'}}});
 const r=await getBookingReceipt.run(request({missionId}));
 expect(r.contract).toBeNull();expect(r.legacyTerms?.payment_text.fr).toBe('OLD STORED TEXT');
});
