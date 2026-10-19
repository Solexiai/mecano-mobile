import { canConfirmMissionFailure, validateFailureReviewInput } from "../../src/lib/missionFailureReview";
const base={driver_id:"d",status:"in_transit"};
test.each(["assigned","driver_to_pickup","arrived_at_pickup","picked_up","in_transit","arrived_at_dropoff","disputed","refunded"])("eligible administrative review: %s",status=>{
 expect(canConfirmMissionFailure({...base,status})).toBe(true);
});
test.each(["cancelled","completed","delivered","draft","quoted","searching_driver","offered"])("never treats %s as a failed delivery",status=>{
 expect(canConfirmMissionFailure({...base,status})).toBe(false);
});
test.each([{assignment_mode:"internal_test"},{driver_id:null},{completed_at:"date"},{delivered_at:"date"},{proof_of_delivery_url:"proof"}])("rejects contradictory evidence %j",extra=>{
 expect(canConfirmMissionFailure({...base,...extra})).toBe(false);
});
const input={missionId:"m",action:"confirm",reason:"Delivery not performed",expectedStatus:"in_transit",expectedRevision:0,expectedDriverId:"d",deliveryNotCompleted:true};
test("requires an explicit attestation and preserves a bounded reason",()=>{
 expect(validateFailureReviewInput(input).reason).toBe(input.reason);
 expect(()=>validateFailureReviewInput({...input,deliveryNotCompleted:false})).toThrow();
 expect(()=>validateFailureReviewInput({...input,reason:" "})).toThrow();
 expect(()=>validateFailureReviewInput({...input,expectedRevision:-1})).toThrow();
});
