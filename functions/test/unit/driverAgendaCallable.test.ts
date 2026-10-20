jest.mock('../../src/lib/admin', () => {
  const current = { revision: 2, windows: [], blocked: [] };
  const reference=(path:string):any=>({path,get:async()=>({exists:false,data:()=>undefined}),collection:()=>({where:()=>({query:true})})});
  const tx = { get: jest.fn(async (ref: any) => ref.query?{docs:[]}:({
    exists: true, data: () => ref.path.startsWith('driver_profiles/') ? {} : current,
  })), set: jest.fn() };
  return { db: { doc: jest.fn(reference), runTransaction: jest.fn(async f => f(tx)) },
    admin: { firestore: { FieldValue: { serverTimestamp: jest.fn(() => 'SERVER_TIMESTAMP'),delete:jest.fn(()=>null) } } },
    __tx: tx, __current: current };
});
import { saveDriverAgenda } from '../../src/functions/driverAgenda';
const mocked = jest.requireMock('../../src/lib/admin');
const request = (data: unknown, roles = ['driver'], uid = 'driver-test') => ({
  data, auth: { uid, token: { roles } }, rawRequest: {}, acceptsStreaming: false,
} as any);
beforeEach(() => jest.clearAllMocks());
test('rejects unauthenticated writes',async()=>{
 await expect(saveDriverAgenda.run({data:{}} as any)).rejects.toMatchObject({code:'unauthenticated'});
 expect(mocked.__tx.set).not.toHaveBeenCalled();
});
test('rejects customer role',async()=>{
 await expect(saveDriverAgenda.run(request({},['customer']))).rejects.toMatchObject({code:'permission-denied'});
});
test('cannot target another driver; server uses authenticated identity and server time',async()=>{
 const result=await saveDriverAgenda.run(request({driver_id:'victim', revision:2,agenda:{windows:[],blocked:[]}}));
 expect(mocked.__tx.set).toHaveBeenCalledWith(expect.objectContaining({path:'driver_agendas/driver-test'}),expect.objectContaining({
   driver_id:'driver-test',revision:3,updated_at:'SERVER_TIMESTAMP',
 }),{merge:true});
 expect(result.dispatch_connected).toBe(false);
 expect(result.external_sync_connected).toBe(false);
});
test('stale revision refuses overwriting concurrent changes',async()=>{
 await expect(saveDriverAgenda.run(request({revision:1,agenda:{windows:[],blocked:[]}}))).rejects.toMatchObject({code:'failed-precondition'});
 expect(mocked.__tx.set).not.toHaveBeenCalled();
});
test('invalid range never reaches transaction write',async()=>{
 await expect(saveDriverAgenda.run(request({revision:2,agenda:{windows:[{start:'bad',end:'bad'}],blocked:[]}}))).rejects.toMatchObject({code:'invalid-argument'});
 expect(mocked.__tx.set).not.toHaveBeenCalled();
});
test.each([-1,1.5,null,'2'])('invalid revision %s is rejected',async revision=>{
 await expect(saveDriverAgenda.run(request({revision,agenda:{windows:[],blocked:[]}}))).rejects.toMatchObject({code:'invalid-argument'});
});
