import { assertFails, assertSucceeds, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { doc, getDoc, setDoc, deleteDoc, serverTimestamp, Timestamp } from "firebase/firestore";
import { createTestEnv } from "./setup";
let env: RulesTestEnvironment;
beforeAll(async()=>{env=await createTestEnv();});
afterEach(async()=>{await env.clearFirestore();});
afterAll(async()=>{await env.cleanup();});
async function seed(status="completed",assignment="marketplace") {
 await env.withSecurityRulesDisabled(async ctx=>{
  await setDoc(doc(ctx.firestore(),"driver_profiles","d"),{status:"approved"});
  await setDoc(doc(ctx.firestore(),"delivery_requests","m"),{status,driver_id:"d",customer_id:"c",assignment_mode:assignment});
 });
}
test("presence: server timestamp, staff read, owner delete",async()=>{
 await seed();const db=env.authenticatedContext("d",{role:"driver"}).firestore();
 const ref=doc(db,"driver_presence","session");
 await assertSucceeds(setDoc(ref,{driver_id:"d",updated_at:serverTimestamp()}));
 await assertSucceeds(getDoc(doc(env.authenticatedContext("a",{role:"analyst"}).firestore(),"driver_presence","session")));
 await assertFails(getDoc(doc(env.authenticatedContext("c",{role:"customer"}).firestore(),"driver_presence","session")));
 await assertSucceeds(deleteDoc(ref));
});
test("presence: no impersonation, future timestamp, takeover or customer write",async()=>{
 await seed();const db=env.authenticatedContext("d",{role:"driver"}).firestore();
 await assertFails(setDoc(doc(db,"driver_presence","s"),{driver_id:"other",updated_at:serverTimestamp()}));
 await assertFails(setDoc(doc(db,"driver_presence","s"),{driver_id:"d",updated_at:Timestamp.fromMillis(Date.now()+600000)}));
 await assertSucceeds(setDoc(doc(db,"driver_presence","s"),{driver_id:"d",updated_at:serverTimestamp()}));
 await assertFails(setDoc(doc(env.authenticatedContext("x",{role:"driver"}).firestore(),"driver_presence","s"),{driver_id:"x",updated_at:serverTimestamp()}));
 await assertFails(setDoc(doc(env.authenticatedContext("c",{role:"customer"}).firestore(),"driver_presence","c"),{driver_id:"c",updated_at:serverTimestamp()}));
});
function rating(stars=5){return {mission_id:"m",rater_id:"c",rater_role:"customer",stars,created_at:serverTimestamp()};}
test("one canonical review only, immutable, no alternate-id duplicates",async()=>{
 await seed();const db=env.authenticatedContext("c",{role:"customer"}).firestore();
 await assertSucceeds(setDoc(doc(db,"ratings","m_customer"),rating()));
 await assertFails(setDoc(doc(db,"ratings","m_customer"),rating(4)));
 await assertFails(setDoc(doc(db,"ratings","random"),rating()));
});
test.each([0,6,2.5])("rejects invalid stars %s",async stars=>{
 await seed();const db=env.authenticatedContext("c",{role:"customer"}).firestore();
 await assertFails(setDoc(doc(db,"ratings","m_customer"),rating(stars)));
});
test.each(["assigned","cancelled"])("rejects reviews before completed: %s",async status=>{
 await seed(status);const db=env.authenticatedContext("c",{role:"customer"}).firestore();
 await assertFails(setDoc(doc(db,"ratings","m_customer"),rating()));
});
test("rejects another customer and internal tests",async()=>{
 await seed();const db=env.authenticatedContext("x",{role:"customer"}).firestore();
 await assertFails(setDoc(doc(db,"ratings","m_customer"),{...rating(),rater_id:"x"}));
 await seed("completed","internal_test");
 await assertFails(setDoc(doc(env.authenticatedContext("c",{role:"customer"}).firestore(),"ratings","m_customer"),rating()));
});
