import { DEFAULT_BOOKING_HOURS, getSavedBookingHours } from './bookingHours';
import { getBookingPolicy } from './bookingServer';
import { isPilotUser, resolveRuntimeFlag, RuntimeFlagKeys } from './runtimeFlags';

// Public capabilities only. Never changes flags, prepares payments, or exposes
// internal configuration details. Mutating endpoints retain their own guards.
// A pilot account (system_config/pilot_access) sees booking and payment open
// while the public switches stay closed; whether it is a pilot is never exposed.
export async function getPublicBookingConfiguration(uid?: string | null) {
  const [policy, booking, payment, pilot, hours] = await Promise.all([
    getBookingPolicy(),
    resolveRuntimeFlag(RuntimeFlagKeys.ACCEPT_NEW_DELIVERY_REQUESTS),
    resolveRuntimeFlag(RuntimeFlagKeys.PAYMENTS_ENABLED),
    isPilotUser(uid),
    getSavedBookingHours().catch(() => null),
  ]);
  return {
    policy,
    // Hours the app offers (Où et quand ?, 2026-10-26); the launch rules
    // when the admin never saved any.
    booking_hours: hours ?? DEFAULT_BOOKING_HOURS,
    availability: {
      booking_enabled: booking.enabled || pilot,
      payment_enabled: payment.enabled || pilot,
      technical_error: booking.reason === 'firestore_error' || payment.reason === 'firestore_error',
    },
  };
}
