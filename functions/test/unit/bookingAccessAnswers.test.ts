import { normalizeLoad, bookingHandling } from '../../src/lib/booking';
const legacy={floor:0,stairs:false,elevator:false,help:true};
const access=(extra={})=>({...legacy,details_version:1,confirmed_fields:['floor','stairs','elevator'],inside:false,onsite_help:'unknown',...extra});
const raw=(pickup:unknown=access(),dropoff:unknown=access())=>({
 draft_id:'test-access-draft',items:[{id:'test-box',category:'sofa',label:'Test',quantity:1,length:10,width:10,height:10,weight:1,dimension_unit:'cm',weight_unit:'kg',approximate:false,upright:false}],
 pickup,dropoff,handlers:1,equipment:[],requested_at:'2099-01-01T12:00:00Z'});
test('retains separate on-site assistance and interior answers in quote snapshot',()=>{
 const load=normalizeLoad(raw(access({onsite_help:'yes',inside:true,notes:'  Test door  '})));
 expect(load.pickup).toMatchObject({help:true,onsite_help:'yes',inside:true,notes:'Test door'});
});
test.each([null,undefined])('missing Movi-K choice is rejected: %s',help=>expect(()=>normalizeLoad(raw(access({help})))).toThrow());
test.each([{onsite_help:null},{onsite_help:'maybe'},{inside:null},{confirmed_fields:[]},{floor:null},{stairs:null},{elevator:null},{details_version:2}])('reject incomplete new answers %j',extra=>expect(()=>normalizeLoad(raw(access(extra)))).toThrow());
test('contradiction requires clarification, never adds paid help',()=>{
 expect(()=>normalizeLoad(raw(access({help:false,inside:true})))).toThrow();
 const load=normalizeLoad(raw(access({help:false,inside:true,customer_handles_inside:true}),access({help:true,onsite_help:'no'})));
 expect(load.pickup.help).toBe(false);expect(load.dropoff.help).toBe(true);
});
test('legacy normalization and snapshots retain exact shape',()=>expect(normalizeLoad(raw(legacy,legacy)).pickup).toEqual(legacy));
test.each(['yes','no','unknown'])('on-site answer %s does not change charged options or crew',onsite_help=>{
 const load=normalizeLoad(raw(access({onsite_help}),access({help:false})));
 const handling=bookingHandling(load,{approved:true,version:'TEST',capacities:[],bulky_item_cm:150});
 expect(handling.needsLoading).toBe(true);expect(handling.needsUnloading).toBe(false);expect(handling.needsSecondHandler).toBe(false);
});
test('stairs and elevator coexist',()=>expect(normalizeLoad(raw(access({stairs:true,elevator:true}))).pickup).toMatchObject({stairs:true,elevator:true}));
