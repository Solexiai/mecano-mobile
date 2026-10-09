
describe("P1-M-01 supplementary collection permissions", () => {
  beforeEach(async()=>{
    await testEnv.withSecurityRulesDisabled(async(ctx)=>{
      await setDoc(doc(ctx.firestore(),"delivery_requests/supp_A"),{customer_id:"supp_client_A",driver_id:"supp_driver",status:"in_transit"});
      await setDoc(doc(ctx.firestore(),"delivery_requests/supp_B"),{customer_id:"supp_client_B",driver_id:"supp_driver",status:"in_transit"});
      for(const [id,delivery] of [["A1","supp_A"],["B1","supp_B"]])
        await setDoc(doc(ctx.firestore(),"driver_locations/supp_driver/history/"+id),{delivery_id:delivery,latitude:45,longitude:-72});
    });
  });
  it("P1-M-01 admin roles and stranger collection queries",async()=>{
    for(const role of ["analyst","admin","super_admin"]){
      const c=testEnv.authenticatedContext("supp_"+role,{role});
      const s=await assertSucceeds(getDocs(collection(c.firestore(),"driver_locations/supp_driver/history")));
      expect(s.size).toBe(2);
    }
    const otherDriver=testEnv.authenticatedContext("supp_other_driver",{role:"driver"});
    await assertFails(getDocs(collection(otherDriver.firestore(),"driver_locations/supp_driver/history")));
    await assertFails(getDocs(collection(testEnv.unauthenticatedContext().firestore(),"driver_locations/supp_driver/history")));
  });
  it("P1-M-01 listener scoped own allowed other denied unfiltered denied",async()=>{
    const c=testEnv.authenticatedContext("supp_client_A",{role:"customer"});
    const base=collection(c.firestore(),"driver_locations/supp_driver/history");
    const {onSnapshot}=require("firebase/firestore");
    async function first(q){
      let unsub;
      try{return await new Promise((resolve,reject)=>{unsub=onSnapshot(q,{includeMetadataChanges:true},snap=>{if(!snap.metadata.fromCache)resolve(snap);},reject);});}
      finally{if(unsub)unsub();}
    }
    const own=await first(query(base,where("delivery_id","==","supp_A")));
    expect(own.docs.map(d=>d.id)).toEqual(["A1"]);
    await expect(first(query(base,where("delivery_id","==","supp_B")))).rejects.toMatchObject({code:"permission-denied"});
    await expect(first(base)).rejects.toMatchObject({code:"permission-denied"});
  });
});

