import { MAX_BOOKING_ADVANCE_MS, requestedTimeReason } from '../../src/lib/booking';

const now = Date.parse('2026-10-22T12:00:00Z');
const at = (ms: number) => new Date(now + ms).toISOString();

test('bookings are limited to 4 days ahead (Visa hold placed without the customer)', () => {
  expect(MAX_BOOKING_ADVANCE_MS).toBe(4 * 24 * 60 * 60 * 1000);
  expect(requestedTimeReason(null, now)).toBeNull();
  expect(requestedTimeReason(at(60 * 60 * 1000), now)).toBeNull();
  expect(requestedTimeReason(at(MAX_BOOKING_ADVANCE_MS), now)).toBeNull();
  expect(requestedTimeReason(at(MAX_BOOKING_ADVANCE_MS + 60 * 1000), now)).toBe('requested_time_too_far');
  expect(requestedTimeReason(at(-60 * 1000), now)).toBe('requested_time_past');
  expect(requestedTimeReason('not a date', now)).toBe('requested_time_past');
});

test('2026-11-06 : la fenêtre enregistrée par l’admin (jusqu’à 30 jours) remplace le défaut', () => {
  const day = 24 * 60 * 60 * 1000;
  expect(requestedTimeReason(at(10 * day), now, 30 * day)).toBeNull();
  expect(requestedTimeReason(at(30 * day), now, 30 * day)).toBeNull();
  expect(requestedTimeReason(at(30 * day + 60 * 1000), now, 30 * day)).toBe('requested_time_too_far');
  expect(requestedTimeReason(at(10 * day), now)).toBe('requested_time_too_far');
});
