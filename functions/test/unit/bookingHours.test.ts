// Booking hours set by the admin (Où et quand ?, 2026-10-26).
import { bookingHoursReason, DEFAULT_BOOKING_HOURS, MAX_BOOKING_DAYS_AHEAD, parseBookingHours } from '../../src/lib/bookingHours';

// Monday 2026-11-02 in Québec (UTC-5 after the time change).
const now = Date.parse('2026-11-02T13:00:00Z'); // 8:00 local
const local = (day: number, hour: number, minute = 0) =>
  new Date(Date.UTC(2026, 10, day, hour + 5, minute)).toISOString();

test('the launch defaults', () => {
  expect(DEFAULT_BOOKING_HOURS).toEqual({ slot_hours: [9, 11, 13, 15, 17, 19], lead_minutes: 60, days_ahead: 4, open_weekdays: [1, 2, 3, 4, 5, 6, 7] });
});
test('an offered hour, an open day, with enough notice', () => {
  expect(bookingHoursReason(local(2, 11), DEFAULT_BOOKING_HOURS, now)).toBeNull();
  expect(bookingHoursReason(null, DEFAULT_BOOKING_HOURS, now)).toBeNull();
});
test('too soon, too far, closed hour, closed day', () => {
  expect(bookingHoursReason(local(2, 9), { ...DEFAULT_BOOKING_HOURS, lead_minutes: 120 }, now)).toBe('requested_time_past');
  expect(bookingHoursReason(local(9, 11), DEFAULT_BOOKING_HOURS, now)).toBe('requested_time_too_far');
  expect(bookingHoursReason(local(2, 10), DEFAULT_BOOKING_HOURS, now)).toBe('requested_time_closed');
  expect(bookingHoursReason(local(2, 11, 30), DEFAULT_BOOKING_HOURS, now)).toBe('requested_time_closed');
  // Tuesday 2026-11-03, closed on Tuesdays.
  expect(bookingHoursReason(local(3, 11), { ...DEFAULT_BOOKING_HOURS, open_weekdays: [1, 3, 4, 5, 6] }, now)).toBe('requested_time_closed');
});
test('admin values are validated', () => {
  const ok: string[] = [];
  expect(parseBookingHours({ slot_hours: [17, 9, 9], lead_minutes: 30, days_ahead: 5, open_weekdays: [6, 7] }, ok))
    .toEqual({ slot_hours: [9, 17], lead_minutes: 30, days_ahead: 5, open_weekdays: [6, 7] });
  expect(ok).toEqual([]);
  // PAY-08 (2026-10-27) : jamais au-delà de 5 jours (fenêtre d'autorisation Stripe).
  expect(MAX_BOOKING_DAYS_AHEAD).toBe(5);
  const tooFar: string[] = [];
  parseBookingHours({ ...DEFAULT_BOOKING_HOURS, days_ahead: 7 }, tooFar);
  expect(tooFar.length).toBeGreaterThan(0);
  for (const bad of [null, { ...DEFAULT_BOOKING_HOURS, slot_hours: [] }, { ...DEFAULT_BOOKING_HOURS, slot_hours: [23] },
    { ...DEFAULT_BOOKING_HOURS, lead_minutes: -1 }, { ...DEFAULT_BOOKING_HOURS, days_ahead: 30 }, { ...DEFAULT_BOOKING_HOURS, open_weekdays: [0] }]) {
    const e: string[] = [];
    parseBookingHours(bad, e);
    expect(e.length).toBeGreaterThan(0);
  }
});
