// Item types and vehicles (owner decision 2026-10-26): the admin checks which
// vehicles may carry each type; nothing else in booking_capacity changes.
import { db } from '../../src/lib/admin';
import { adminItemTypes } from '../../src/functions/adminItemTypes';
import { PROPOSED_ITEM_VEHICLES } from '../../src/lib/itemTypes';
import { PHOTO_CATEGORIES } from '../../src/lib/photoIntake';

const call = (data: unknown, uid = 'types_staff', roles = ['admin']) =>
  ({ data, auth: { uid, token: { roles, role: roles[0] } }, rawRequest: {}, acceptsStreaming: false } as any);
const ref = db.collection('system_config').doc('booking_capacity');
const capacities = [{ category: 'pickup_truck', rank: 1, version: 'T', verified: true }];

afterEach(async () => {
  if (process.env.GCLOUD_PROJECT !== 'demo-movik-test' || process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8080') throw Error('cleanup isolation');
  for (const c of ['system_config', 'audit_logs']) await db.recursiveDelete(db.collection(c));
});

test('admins only', async () => {
  await expect(adminItemTypes.run(call({ action: 'get' }, 'someone', ['customer'])))
    .rejects.toMatchObject({ code: 'permission-denied' });
});

test('get: saved types as saved (normalized), new types as the proposal', async () => {
  await ref.set({ approved: true, capacities, photo_intake: { enabled: true, version: 'old',
    category_vehicle_categories: { sofa: ['pickupTruck'], materials: ['cube_truck', 'unknown'] } } });
  const result = (await adminItemTypes.run(call({ action: 'get' }))) as any;
  expect(result).toMatchObject({ configured: true, photoIntakeEnabled: true, vehicles: ['pickup_truck', 'cargo_van', 'cube_truck'] });
  const byType = Object.fromEntries(result.types.map((t: any) => [t.category, t]));
  expect(byType.sofa).toEqual({ category: 'sofa', vehicles: ['pickup_truck'], saved: true });
  expect(byType.materials).toEqual({ category: 'materials', vehicles: ['cube_truck'], saved: true });
  expect(byType.bed).toEqual({ category: 'bed', vehicles: ['pickup_truck', 'cargo_van', 'cube_truck'], saved: false });
  expect(result.types).toHaveLength(PHOTO_CATEGORIES.length);
});

test('save replaces only the mapping, keeps the rest, and is audited', async () => {
  await ref.set({ approved: true, capacities, heavy_item_kg: 100, photo_intake: { enabled: true, version: 'old',
    category_vehicle_categories: { sofa: ['pickup_truck'], legacy: ['cargo_van'] } } });
  const mapping = { ...PROPOSED_ITEM_VEHICLES, tires: [] };
  const saved = (await adminItemTypes.run(call({ action: 'save', mapping }))) as any;
  expect(saved.success).toBe(true);
  const after = (await ref.get()).data()!;
  expect(after.capacities).toEqual(capacities);
  expect(after.heavy_item_kg).toBe(100);
  expect(after.photo_intake.enabled).toBe(true);
  expect(after.photo_intake.version).toBe(saved.version);
  expect(after.photo_intake.category_vehicle_categories).toEqual(mapping);
  expect(after.photo_intake.category_vehicle_categories.legacy).toBeUndefined();
  expect(after.photo_intake.category_vehicle_categories.materials).toEqual(['pickup_truck', 'cube_truck']);
  const audits = await db.collection('audit_logs').where('source_function', '==', 'adminItemTypes').get();
  expect(audits.docs.map(d => d.data().metadata.not_offered)).toEqual([['tires']]);
});

test.each([
  null, [], { sofa: ['pickup_truck'] },
  { ...PROPOSED_ITEM_VEHICLES, sofa: ['spaceship'] },
  { ...PROPOSED_ITEM_VEHICLES, sofa: ['pickup_truck', 'pickup_truck'] },
  { ...PROPOSED_ITEM_VEHICLES, piano: ['pickup_truck'] },
])('invalid mapping refused: %p', async (mapping) => {
  await ref.set({ approved: true, capacities, photo_intake: { enabled: true, version: 'old', category_vehicle_categories: {} } });
  await expect(adminItemTypes.run(call({ action: 'save', mapping })))
    .rejects.toMatchObject({ code: 'invalid-argument' });
  expect((await ref.get()).data()!.photo_intake.version).toBe('old');
});

test('no photo booking configuration: refused, nothing created', async () => {
  await expect(adminItemTypes.run(call({ action: 'save', mapping: PROPOSED_ITEM_VEHICLES })))
    .rejects.toMatchObject({ code: 'failed-precondition' });
  expect((await ref.get()).exists).toBe(false);
});
