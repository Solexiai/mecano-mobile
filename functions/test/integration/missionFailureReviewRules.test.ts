import {assertFails,assertSucceeds,RulesTestEnvironment} from "@firebase/rules-unit-testing";
import {doc,setDoc,getDoc} from "firebase/firestore";
import {createTestEnv} from "./setup";
let env:RulesTestEnvironment;
beforeAll(async()=>{env=await createTestEnv();});
afterEach(async()=>{await env.clearFirestore();});
afterAll(async()=>{await env.cleanup();});
test.each(["analyst","admin","super_admin"])("staff %s can read but cannot directly forge a finding",async role=>{
 await env.withSecurityRulesDisabled(async ctx=>{await setDoc(doc(ctx.firestore(),"mission_outcome_reviews","m"),{confirmed:true});});
 const ref=doc(env.authenticatedContext("staff",{role}).firestore(),"mission_outcome_reviews","m");
 await assertSucceeds(getDoc(ref));await assertFails(setDoc(ref,{confirmed:false}));
});
test.each(["driver","customer"])("non-staff %s cannot read or create findings",async role=>{
 const ref=doc(env.authenticatedContext("u",{role}).firestore(),"mission_outcome_reviews","m");
 await assertFails(getDoc(ref));await assertFails(setDoc(ref,{confirmed:true}));
});
