import { db } from '../../src/lib/admin';
import { getDriverAgenda, saveDriverAgenda } from '../../src/functions/driverAgenda';
const uid='agenda-emulator-driver';
const request=(data:unknown, id=uid)=>({data,auth:{uid:id,token:{roles:['driver']}},rawRequest:{},acceptsStreaming:false} as any);
beforeEach(async()=>{
 await db.doc('driver_profiles/'+uid).set({status:'approved'});
 await db.doc('driver_agendas/'+uid).delete();
});
afterEach(async()=>{
 await db.doc('driver_profiles/'+uid).delete();
 await db.doc('driver_agendas/'+uid).delete();
});
test('round trip persists exact instants and a server timestamp',async()=>{
 const empty=await getDriverAgenda.run(request({}));
 expect(empty.configured).toBe(false);expect(empty.revision).toBe(0);
 await saveDriverAgenda.run(request({revision:0,agenda:{windows:[{
   start:'2026-11-01T05:30:00Z',end:'2026-11-01T06:30:00Z'}],blocked:[]}}));
 const result=await getDriverAgenda.run(request({}));
 expect(result.revision).toBe(1);expect(result.agenda.windows).toHaveLength(1);
 expect((await db.doc('driver_agendas/'+uid).get()).data()?.updated_at.toMillis()).toBeGreaterThan(0);
});
test('two simultaneous saves from the same revision: exactly one wins',async()=>{
 const input={revision:0,agenda:{windows:[],blocked:[]}};
 const results=await Promise.allSettled([saveDriverAgenda.run(request(input)),saveDriverAgenda.run(request(input))]);
 expect(results.filter(r=>r.status==='fulfilled')).toHaveLength(1);
 const failure=results.find(r=>r.status==='rejected') as PromiseRejectedResult;
 expect(failure.reason.code).toBe('failed-precondition');
 expect((await getDriverAgenda.run(request({}))).revision).toBe(1);
});
test('driver without profile cannot write another driver agenda',async()=>{
 await expect(saveDriverAgenda.run(request({driver_id:uid,revision:0,agenda:{windows:[],blocked:[]}},'no-profile')))
   .rejects.toMatchObject({code:'permission-denied'});
 expect((await db.doc('driver_agendas/'+uid).get()).exists).toBe(false);
});
