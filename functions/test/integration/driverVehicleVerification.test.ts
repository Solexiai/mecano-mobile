import { admin, db } from '../../src/lib/admin';
import { reviewDriverVehicle, vehicleIdentity } from '../../src/functions/reviewDriverVehicle';
import { approveDriver } from '../../src/functions/approveDriver';
import { initializeTestEnvironment, RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, updateDoc } from 'firebase/firestore';
import { readFileSync } from 'fs';
import { resolve } from 'path';

const driver = 'synthetic-vehicle-driver', vehicle = 'synthetic-vehicle';
const types = ['drivers_licence','vehicle_registration','insurance','identity'];
const capacity = {length_cm:250,width_cm:150,height_cm:150,opening_width_cm:140,opening_height_cm:140,payload_kg:500,handlers:2,equipment:['straps'],services:['handling']};
const ref = () => db.doc('driver_vehicles/' + vehicle);
let rules: RulesTestEnvironment;
let identity: Record<string, unknown>;
const request = (data: unknown, uid = 'synthetic-admin', roles = ['admin']) => ({data,auth:{uid,token:{roles}},rawRequest:{}} as any);
async function review(overrides: Record<string, unknown> = {}, uid?: string, roles?: string[]) {
  return reviewDriverVehicle.run(request({driverId:driver,vehicleId:vehicle,action:'approve',capacity,
    validUntil:new Date(Date.now()+86400000).toISOString(),verificationNote:'SYNTHETIC TEST MEASUREMENTS',
    expectedIdentity:identity,...overrides},uid,roles));
}
beforeAll(async () => {
  if(process.env.GCLOUD_PROJECT !== 'demo-movik-test' || process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8080') throw Error('Isolated emulator required');
  rules = await initializeTestEnvironment({projectId:'demo-movik-test',firestore:{host:'127.0.0.1',port:8080,rules:readFileSync(resolve(__dirname,'../../../firestore.rules'),'utf8')}});
});
beforeEach(async () => {
  await db.doc('driver_profiles/'+driver).set({status:'pending_review',documents_all_valid:false});
  const v = {driver_id:driver,category:'cargo_van',make_model:'SYNTHETIC VAN',year:2025,plate:'TEST-ONLY',max_payload_kg:500,is_verified:false};
  identity=vehicleIdentity(v); await ref().set(v);
  for(const type of types) await db.doc('driver_documents/'+type).set({driver_id:driver,type,status:'uploaded',uploaded_at:admin.firestore.Timestamp.now(),expires_at:admin.firestore.Timestamp.fromMillis(Date.now()+604800000)});
});
afterEach(async () => {
  for(const name of ['driver_profiles','driver_vehicles','driver_documents','audit_logs']) await db.recursiveDelete(db.collection(name));
});
afterAll(async () => {await rules.cleanup();});
async function approve() {await approveDriver.run(request({driverId:driver}));}
test.each(['pickup_truck','cargo_van','cube_truck'])('%s: document approval then capacity verification is persisted and audited', async category => {
  await ref().update({category}); identity.category=category;
  await approve(); await review();
  const v=(await ref().get()).data()!;
  expect(v.is_verified).toBe(true);
  expect(v.verified_capacity).toMatchObject({...capacity,category,verified:true});
  expect(v.verified_capacity.version).toEqual(expect.any(String));
  expect(v.verified_identity).toEqual(identity);
  expect(v.capacity_valid_until.toMillis()).toBeGreaterThan(Date.now());
  const audit=await db.collection('audit_logs').where('action','==','driver_vehicle_verified').get();
  expect(audit.size).toBe(1); expect(audit.docs[0].data().target_id).toBe(vehicle);
});
test.each(['customer','driver'])('%s cannot verify its own vehicle', async role => {
  await approve(); await expect(review({},driver,[role])).rejects.toMatchObject({code:'permission-denied'});
  expect((await ref().get()).data()?.is_verified).toBe(false);
});
test('unapproved profile cannot be verified', async () => {
  await expect(review()).rejects.toMatchObject({code:'failed-precondition'});
});
test.each(['car','suv','trailer'])('%s is not a pilot vehicle', async category => {
  await approve(); await ref().update({category}); identity.category=category;
  await expect(review()).rejects.toMatchObject({code:'failed-precondition'});
});
test('rejects another owner and a stale administrative form', async () => {
  await approve();
  await expect(review({driverId:'other-driver'})).rejects.toMatchObject({code:'not-found'});
  await ref().update({plate:'CHANGED'});
  await expect(review()).rejects.toMatchObject({code:'failed-precondition'});
  expect((await ref().get()).data()?.is_verified).toBe(false);
});
test.each([
  {payload_kg:0},{length_cm:-1},{opening_width_cm:151},{handlers:3},{equipment:['invented']},
])('rejects invalid capacity %j without verification', async invalid => {
  await approve(); await expect(review({capacity:{...capacity,...invalid}})).rejects.toMatchObject({code:'invalid-argument'});
  expect((await ref().get()).data()?.is_verified).toBe(false);
});
test('validity cannot exceed approved insurance or accept a missing document', async () => {
  await approve();
  await db.doc('driver_documents/insurance').update({expires_at:admin.firestore.Timestamp.fromMillis(Date.now()+1000)});
  await expect(review()).rejects.toMatchObject({code:'failed-precondition'});
  await db.doc('driver_documents/insurance').delete();
  await expect(review()).rejects.toMatchObject({code:'failed-precondition'});
});
test('revocation removes eligibility even when the profile is suspended', async () => {
  await approve(); await review();
  await db.doc('driver_profiles/'+driver).update({status:'suspended'});
  await review({action:'revoke'});
  const v=(await ref().get()).data()!;
  expect(v.is_verified).toBe(false); expect(v.verified_capacity).toBeUndefined(); expect(v.capacity_valid_until).toBeUndefined();
});
test('driver cannot self-verify or change verified vehicle identity through client rules', async () => {
  const client=rules.authenticatedContext(driver,{roles:['driver']}).firestore();
  await expect(updateDoc(doc(client,'driver_vehicles/'+vehicle),{is_verified:true,verified_capacity:capacity})).rejects.toMatchObject({code:'permission-denied'});
  await approve(); await review();
  await expect(updateDoc(doc(client,'driver_vehicles/'+vehicle),{plate:'OTHER-VEHICLE'})).rejects.toMatchObject({code:'permission-denied'});
  await expect(updateDoc(doc(client,'driver_vehicles/'+vehicle),{capacity_review_note:'forged'})).rejects.toMatchObject({code:'permission-denied'});
  expect((await ref().get()).data()?.plate).toBe('TEST-ONLY');
});
