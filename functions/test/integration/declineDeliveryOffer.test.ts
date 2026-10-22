import { admin,db } from '../../src/lib/admin';
import { declineDeliveryOffer } from '../../src/functions/declineDeliveryOffer';
const request=(uid='decline_driver',roles=['driver'])=>({auth:{uid,token:{roles}},data:{missionId:'decline_mission'},rawRequest:{},acceptsStreaming:false} as any);
beforeEach(async()=>{
 await db.doc('driver_profiles/decline_driver').set({status:'approved',documents_all_valid:true,online_status:'online'});
 await db.doc('delivery_requests/decline_mission').set({status:'offered',driver_id:null,customer_total_minor:12345});
 for(const [id,driver]of [['decline_offer','decline_driver'],['decline_other','other_driver']])await db.doc('delivery_offers/'+id).set({mission_id:'decline_mission',driver_id:driver,status:'pending',expires_at:admin.firestore.Timestamp.fromMillis(Date.now()+60000)});
});
afterEach(async()=>{for(const p of ['driver_profiles/decline_driver','delivery_requests/decline_mission','delivery_offers/decline_offer','delivery_offers/decline_other'])await db.doc(p).delete();});
test('decline is idempotent, preserves other offers and every mission field',async()=>{
 const before=(await db.doc('delivery_requests/decline_mission').get()).data();
 expect(await declineDeliveryOffer.run(request())).toEqual({declined:true});
 const first=(await db.doc('delivery_offers/decline_offer').get()).data();
 expect(first?.status).toBe('declined');expect(first?.declined_at.toMillis()).toBeGreaterThan(0);
 expect(await declineDeliveryOffer.run(request())).toEqual({declined:true});
 expect((await db.doc('delivery_offers/decline_offer').get()).data()).toEqual(first);
 expect((await db.doc('delivery_offers/decline_other').get()).data()?.status).toBe('pending');
 expect((await db.doc('delivery_requests/decline_mission').get()).data()).toEqual(before);
});
test.each(['customer','unapproved','foreign','expired','assigned'])('%s cannot decline an active offer',async scenario=>{
 let r=request();
 if(scenario==='customer')r=request('decline_driver',['customer']);
 if(scenario==='unapproved')await db.doc('driver_profiles/decline_driver').update({status:'suspended'});
 if(scenario==='foreign')r=request('stranger');
 if(scenario==='expired')await db.doc('delivery_offers/decline_offer').update({expires_at:admin.firestore.Timestamp.fromMillis(1)});
 if(scenario==='assigned')await db.doc('delivery_requests/decline_mission').update({status:'assigned',driver_id:'other_driver'});
 await expect(declineDeliveryOffer.run(r)).rejects.toBeDefined();
 expect((await db.doc('delivery_offers/decline_offer').get()).data()?.status).toBe('pending');
});
test('concurrent decline calls have one stable result',async()=>{
 const results=await Promise.all([declineDeliveryOffer.run(request()),declineDeliveryOffer.run(request())]);
 expect(results).toEqual([{declined:true},{declined:true}]);
 expect((await db.doc('delivery_offers/decline_other').get()).data()?.status).toBe('pending');
});
