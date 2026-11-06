// Blocage du solde à J-4 (2026-11-06) : quand l'attendre, et son échéance.
jest.mock('../../src/lib/admin', () => {
  const { Timestamp } = jest.requireActual('firebase-admin/firestore');
  return { admin: { firestore: { Timestamp } }, db: { collection: jest.fn(), doc: jest.fn(), runTransaction: jest.fn() } };
});
jest.mock('../../src/payment/paymentOrchestration', () => ({ createAndAuthorizeMissionPayment: jest.fn(), refundPayment: jest.fn() }));
jest.mock('../../src/lib/audit', () => ({ writeAuditLogInTransaction: jest.fn() }));
import { buildScheduledHold, holdPickupAtMs, SCHEDULED_HOLD_POLICY, shouldScheduleHold } from '../../src/lib/scheduledPaymentHold';
import { admin } from '../../src/lib/admin';

const now = Date.parse('2026-11-10T12:00:00Z');
const day = 24 * 60 * 60 * 1000;

test('le blocage attend J-4 seulement pour un ramassage à plus de 4 jours', () => {
  expect(shouldScheduleHold(null, now)).toBe(false); // dès que possible : blocage immédiat
  expect(shouldScheduleHold(now + 3 * day, now)).toBe(false);
  expect(shouldScheduleHold(now + 4 * day, now)).toBe(false);
  expect(shouldScheduleHold(now + 4 * day + 60 * 1000, now)).toBe(true);
  expect(shouldScheduleHold(now + 30 * day, now)).toBe(true);
});

test('heure de ramassage : créneau réservé, sinon heure demandée', () => {
  const mission = { booking_snapshot: { load: { requested_at: '2026-11-20T15:00:00Z' } } };
  expect(holdPickupAtMs(mission, null)).toBe(Date.parse('2026-11-20T15:00:00Z'));
  expect(holdPickupAtMs(mission, '2026-11-21T09:00:00Z')).toBe(Date.parse('2026-11-21T09:00:00Z'));
  expect(holdPickupAtMs({}, null)).toBeNull();
});

test('échéance = ramassage − 4 jours', () => {
  const pickup = now + 10 * day;
  const hold = buildScheduledHold(pickup, admin.firestore.Timestamp.fromMillis(now));
  expect(hold.status).toBe('scheduled');
  expect(hold.due_at.toMillis()).toBe(pickup - SCHEDULED_HOLD_POLICY.lead_ms);
  expect(hold.next_attempt_at?.toMillis()).toBe(pickup - 4 * day);
  expect(hold.attempts).toBe(0);
});
