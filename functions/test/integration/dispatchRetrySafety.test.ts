jest.mock('../../src/lib/pushNotifications', () => ({
  sendDeliveryOfferPush: jest.fn(async () => ({ attempted: 0, sent: 0 })),
}));
import { db } from '../../src/lib/admin';
import { onMissionCreatedDispatch } from '../../src/functions/dispatchMissionToDrivers';
import { sendDeliveryOfferPush } from '../../src/lib/pushNotifications';

// Dedicated demo Firestore only. No callable payment, real driver or FCM.
const missionId = 'dispatch_retry_synthetic_mission';
const driverId = 'dispatch_retry_synthetic_driver';
const missionRef = db.doc('delivery_requests/' + missionId);
const initial = { status: 'searching_driver', driver_id: null,
  dispatch_zone_geohash: 'f25abc', required_vehicle_category: 'cargo_van' };
const event = () => ({ data: { data: () => initial }, params: { missionId } } as any);
const offers = () => db.collection('delivery_offers').where('mission_id', '==', missionId).get();

beforeEach(async () => {
  jest.clearAllMocks();
  await missionRef.set(initial);
  await db.doc('driver_profiles/' + driverId).set({
    status: 'approved', online_status: 'online', documents_all_valid: true,
    accepted_vehicle_categories: ['cargo_van'], current_geohash: 'f25abc',
  });
});
afterEach(async () => {
  for (const offer of (await offers()).docs) await offer.ref.delete();
  await db.recursiveDelete(db.doc('users/' + driverId));
  await db.doc('driver_profiles/' + driverId).delete();
  await missionRef.delete();
});

test('duplicate event keeps exactly one offer and one push attempt', async () => {
  await onMissionCreatedDispatch.run(event());
  const first = (await offers()).docs[0];
  await onMissionCreatedDispatch.run(event());
  const final = await offers();
  expect(final.size).toBe(1);
  expect(final.docs[0].id).toBe(first.id);
  expect(final.docs[0].data()).toEqual(first.data());
  expect(sendDeliveryOfferPush).toHaveBeenCalledTimes(1);
});

test.each(['assigned', 'cancelled', 'completed', 'payment_failed'])(
  'stale creation event cannot reopen a %s mission', async status => {
    const current = { ...initial, status, driver_id: status === 'assigned' ? 'winner' : null };
    await missionRef.set(current);
    await onMissionCreatedDispatch.run(event());
    expect((await missionRef.get()).data()).toEqual(current);
    expect((await offers()).empty).toBe(true);
    expect(sendDeliveryOfferPush).not.toHaveBeenCalled();
  });

test('simultaneous dispatch events create only one offer', async () => {
  await Promise.all([onMissionCreatedDispatch.run(event()), onMissionCreatedDispatch.run(event())]);
  expect((await offers()).size).toBe(1);
  expect(sendDeliveryOfferPush).toHaveBeenCalledTimes(1);
  expect((await missionRef.get()).data()?.status).toBe('offered');
});

test('replay does not replace a declined offer or its notification', async () => {
  await onMissionCreatedDispatch.run(event());
  const offer = (await offers()).docs[0];
  await offer.ref.update({ status: 'declined' });
  const notificationRef = db.doc('users/' + driverId + '/notifications/delivery_offer_' + missionId);
  await notificationRef.update({ is_read: true });
  const before = (await notificationRef.get()).data();
  await onMissionCreatedDispatch.run(event());
  expect((await offers()).size).toBe(1);
  expect((await offer.ref.get()).data()?.status).toBe('declined');
  expect((await notificationRef.get()).data()).toEqual(before);
});

test('missing mission cannot create orphan offers', async () => {
  await missionRef.delete();
  await expect(onMissionCreatedDispatch.run(event())).resolves.not.toThrow();
  expect((await offers()).empty).toBe(true);
  expect(sendDeliveryOfferPush).not.toHaveBeenCalled();
});
