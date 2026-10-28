// Où et quand ? (2026-10-26): zones and hours saved by the admin.
import { db } from '../../src/lib/admin';
import { adminServiceSettings } from '../../src/functions/adminServiceSettings';
import { getServiceZonesConfig } from '../../src/lib/serviceZones';
import { getSavedBookingHours } from '../../src/lib/bookingHours';

const call = (data: unknown, uid = 'svc_staff', roles = ['admin']) =>
  ({ data, auth: { uid, token: { roles, role: roles[0] } }, rawRequest: {}, acceptsStreaming: false } as any);

afterEach(async () => {
  if (process.env.GCLOUD_PROJECT !== 'demo-movik-test' || process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8080') throw Error('cleanup isolation');
  for (const c of ['system_config', 'audit_logs']) await db.recursiveDelete(db.collection(c));
});

test('admins only', async () => {
  await expect(adminServiceSettings.run(call({ action: 'get' }, 'x', ['customer']))).rejects.toMatchObject({ code: 'permission-denied' });
});

test('get: launch defaults, not saved', async () => {
  const r = (await adminServiceSettings.run(call({ action: 'get' }))) as any;
  expect(r.zones).toMatchObject({ saved: false, enabled: true, list: [{ name: 'Granby', radius_km: 40 }] });
  expect(r.hours).toMatchObject({ saved: false, slot_hours: [9, 11, 13, 15, 17, 19], days_ahead: 4 });
});

test('save zones and hours: in force for prices and bookings, audited', async () => {
  const zones = [{ name: 'Granby', center_lat: 45.39856, center_lng: -72.72225, radius_km: 50 },
    { name: 'Bromont', center_lat: 45.3167, center_lng: -72.65, radius_km: 15 }];
  const hours = { slot_hours: [8, 10, 12], lead_minutes: 120, days_ahead: 5, open_weekdays: [1, 2, 3, 4, 5] };
  await adminServiceSettings.run(call({ action: 'save', zones, hours }));
  const config = await getServiceZonesConfig({ fallbackToLaunchZone: true });
  expect(config.enabled).toBe(true);
  expect(config.zones).toHaveLength(2);
  expect(await getSavedBookingHours()).toEqual(hours);
  const r = (await adminServiceSettings.run(call({ action: 'get' }))) as any;
  expect(r.zones.saved).toBe(true);
  expect(r.hours).toMatchObject({ saved: true, ...hours });
  const audits = await db.collection('audit_logs').where('source_function', '==', 'adminServiceSettings').get();
  expect(audits.size).toBe(1);
});

test.each([
  { zones: [] },
  { zones: [{ name: '', center_lat: 45, center_lng: -72, radius_km: 10 }] },
  { zones: [{ name: 'X', center_lat: 95, center_lng: -72, radius_km: 10 }] },
  { zones: [{ name: 'X', center_lat: 45, center_lng: -72, radius_km: 0 }] },
  { hours: { slot_hours: [], lead_minutes: 60, days_ahead: 4, open_weekdays: [1] } },
  // PAY-08 (2026-10-27) : fenêtre de réservation plafonnée à 5 jours.
  { hours: { slot_hours: [9, 11], lead_minutes: 60, days_ahead: 6, open_weekdays: [1] } },
  {},
])('invalid save refused, nothing written: %p', async (payload) => {
  await expect(adminServiceSettings.run(call({ action: 'save', ...payload }))).rejects.toMatchObject({ code: 'invalid-argument' });
  expect((await db.doc('system_config/service_zones').get()).exists).toBe(false);
  expect((await db.doc('system_config/booking_hours').get()).exists).toBe(false);
});
