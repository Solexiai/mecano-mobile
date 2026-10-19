import { summarizeDriverActivity } from "../../src/lib/driverActivity";
const missions = [
  {id:"a", status:"completed", customer_id:"c"},
  {id:"b", status:"cancelled", customer_id:"c"},
  {id:"c", status:"disputed", customer_id:"c"},
  {id:"t", status:"completed", customer_id:"c", assignment_mode:"internal_test"},
];
const vote = {id:"a_customer", mission_id:"a", rater_role:"customer", rater_id:"c", stars:5};
test("counts outcomes separately without inventing failed missions", () => {
  expect(summarizeDriverActivity(missions, [])).toMatchObject({completed:1,cancelled:1,disputed:1,failed:null,rating:null,ratingCount:0});
});
test("canonical review wins over legacy duplicates, one vote per mission", () => {
  const legacy={...vote,id:"legacy",stars:1};
  for(const ratings of [[legacy,vote],[vote,legacy]]) expect(summarizeDriverActivity(missions,ratings)).toMatchObject({rating:5,ratingCount:1});
});
test.each([
  {...vote,rater_id:"other"}, {...vote,stars:2.5}, {...vote,stars:0},
  {...vote,stars:6}, {...vote,rater_role:"driver"}, {...vote,mission_id:"t"},
  {...vote,mission_id:"b"}, {...vote,mission_id:"missing"},
])("ignores untrusted or ineligible review %j", bad => {
  expect(summarizeDriverActivity(missions,[bad]).ratingCount).toBe(0);
});
test("averages real customer stars, bounded comments", () => {
  const result=summarizeDriverActivity([...missions,{id:"d",status:"completed",customer_id:"d"}],
    [vote,{id:"d_customer",mission_id:"d",rater_role:"customer",rater_id:"d",stars:2,comment:"x".repeat(2100)}]);
  expect(result.rating).toBe(3.5); expect(result.reviews[1].comment.length).toBe(2000);
});
