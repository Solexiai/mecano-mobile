// Bookings are limited to 4 days ahead (owner decision 2026-10-22, see
// MAX_BOOKING_ADVANCE_MS). Scheduled test pickups use the next round hour
// one day from now, so they stay valid whenever the suite runs.
const HOUR_MS = 60 * 60 * 1000;
export const TEST_SCHEDULED_PICKUP = new Date(Math.ceil(Date.now() / HOUR_MS) * HOUR_MS + 24 * HOUR_MS).toISOString();
