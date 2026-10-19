const store = new Map<string, Record<string, unknown>>();
let nextId=0;
let failAudit=false;
jest.mock("firebase-functions/v2/https",()=>({...jest.requireActual("firebase-functions/v2/https"),onCall:(handler:unknown)=>handler}));
jest.mock("../../src/lib/admin",()=>({
 admin:{firestore:{FieldValue:{serverTimestamp:()=>"SERVER_TIME"}}},
 db:{
  collection:(name:string)=>({doc:(id?:string)=>({path:name+"/"+(id??"audit-"+(++nextId)),id:id??"audit-"+nextId})}),
  runTransaction:async(fn:any)=>{
   const writes:Array<[string,Record<string,unknown>]>=[];
   const result=await fn({
    get:async(ref:any)=>({exists:store.has(ref.path),data:()=>store.get(ref.path)}),
    set:(ref:any,data:any)=>{if(failAudit && ref.path.startsWith('audit_logs/'))throw Error('audit unavailable');writes.push([ref.path,data]);},
   });
   for(const [path,data]of writes)store.set(path,data);
   return result;
  },
 },
}));
import {reviewMissionFailure} from "../../src/functions/reviewMissionFailure";
const input={missionId:"m",action:"confirm",reason:"Client absent, delivery not performed",expectedStatus:"in_transit",expectedRevision:0,expectedDriverId:"d",deliveryNotCompleted:true};
function invoke(data:Record<string,unknown>=input,role:string|null="admin"){
 return (reviewMissionFailure as any)({data,auth:role?{uid:"staff",token:{role,roles:[role]}}:undefined});
}
beforeEach(()=>{
 store.clear();nextId=0;failAudit=false;
 store.set("delivery_requests/m",{driver_id:"d",status:"in_transit"});
 store.set("payments/p",{amount:12345,status:"authorized"});
});
test.each(["admin","super_admin"])("authorized %s records finding and audit atomically without changing mission/payment",async role=>{
 await invoke(input,role);
 expect(store.get("mission_outcome_reviews/m")).toMatchObject({confirmed:true,revision:1,reviewed_at:"SERVER_TIME",reviewed_by:"staff",responsibility:"not_determined"});
 expect(store.get("delivery_requests/m")).toEqual({driver_id:"d",status:"in_transit"});
 expect(store.get("payments/p")).toEqual({amount:12345,status:"authorized"});
 expect([...store.keys()].filter(k=>k.startsWith("audit_logs/"))).toHaveLength(1);
 expect(store.size).toBe(4);
});
test.each(["analyst","driver","customer",null])("rejects %s without any write",async role=>{
 await expect(invoke(input,role)).rejects.toBeDefined();expect(store.size).toBe(2);
});
test("stale status or revision is rejected without duplicate audit",async()=>{
 await expect(invoke({...input,expectedStatus:"assigned"})).rejects.toMatchObject({code:"aborted"});
 await invoke();
 await expect(invoke()).rejects.toMatchObject({code:"aborted"});
 await expect(invoke({...input,expectedRevision:1})).rejects.toMatchObject({code:"already-exists"});
 expect(store.size).toBe(4);
});
test("revocation preserves its history and does not alter the mission",async()=>{
 await invoke();
 await invoke({...input,action:"revoke",expectedRevision:1,reason:"Correction after evidence review"});
 expect(store.get("mission_outcome_reviews/m")).toMatchObject({confirmed:false,revision:2});
 expect([...store.keys()].filter(k=>k.startsWith("audit_logs/"))).toHaveLength(2);
 expect(store.get("delivery_requests/m")?.status).toBe("in_transit");
});
test("cancelled delivery is not classified as failure",async()=>{
 store.set("delivery_requests/m",{driver_id:"d",status:"cancelled"});
 await expect(invoke({...input,expectedStatus:"cancelled"})).rejects.toMatchObject({code:"failed-precondition"});
 expect(store.size).toBe(2);
});
test("explicit attestation is mandatory",async()=>{
 await expect(invoke({...input,deliveryNotCompleted:false})).rejects.toMatchObject({code:"invalid-argument"});expect(store.size).toBe(2);
});

test("driver reassignment invalidates an open administrative confirmation",async()=>{
 store.set("delivery_requests/m",{driver_id:"another",status:"in_transit"});
 await expect(invoke()).rejects.toMatchObject({code:"aborted"});
 expect(store.size).toBe(2);
});
test("a failed audit write prevents the finding from being committed",async()=>{
 failAudit=true;
 await expect(invoke()).rejects.toThrow("audit unavailable");
 expect(store.has("mission_outcome_reviews/m")).toBe(false);
 expect(store.size).toBe(2);
});
