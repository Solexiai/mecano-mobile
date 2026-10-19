import { summarizeDriverActivity } from "../../src/lib/driverActivity";
test("approved classification has a real zero when no failure has been confirmed",()=>{
 expect(summarizeDriverActivity([{id:"m",status:"cancelled"}],[]).failed).toBe(0);
});
test("counts only a current administrative finding, with cancellations separate",()=>{
 const result=summarizeDriverActivity([
  {id:"f",driver_id:"d",status:"in_transit",admin_failure_confirmed:true},
  {id:"none",driver_id:"d",status:"in_transit"},
  {id:"revoked",driver_id:"d",status:"in_transit",admin_failure_confirmed:false},
  {id:"cancel",driver_id:"d",status:"cancelled",admin_failure_confirmed:true},
  {id:"done",driver_id:"d",status:"completed",admin_failure_confirmed:true},
  {id:"test",driver_id:"d",status:"in_transit",assignment_mode:"internal_test",admin_failure_confirmed:true},
 ],[]);
 expect(result).toMatchObject({failed:1,cancelled:1,completed:1});
});

test("a refund alone neither proves failure nor erases a confirmed non-delivery",()=>{
 const base={driver_id:"d",status:"refunded"};
 expect(summarizeDriverActivity([
  {...base,id:"unreviewed"},
  {...base,id:"confirmed",admin_failure_confirmed:true},
  {...base,id:"delivered",completed_at:"date",admin_failure_confirmed:true},
 ],[]).failed).toBe(1);
});
