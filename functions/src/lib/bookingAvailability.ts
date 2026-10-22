import { getBookingPolicy } from './bookingServer';
import { isPilotUser, resolveRuntimeFlag, RuntimeFlagKeys } from './runtimeFlags';

// Public capabilities only. Never changes flags, prepares payments, or exposes
// internal configuration details. Mutating endpoints retain their own guards.
// A pilot account (system_config/pilot_access) sees booking and payment open
// while the public switches stay closed; whether it is a pilot is never exposed.
export async function getPublicBookingConfiguration(uid?: string | null) {
  const [policy, booking, payment, pilot] = await Promise.all([
    getBookingPolicy(),
    resolveRuntimeFlag(RuntimeFlagKeys.ACCEPT_NEW_DELIVERY_REQUESTS),
    resolveRuntimeFlag(RuntimeFlagKeys.PAYMENTS_ENABLED),
    isPilotUser(uid),
  ]);
  return {
    policy,
    availability: {
      booking_enabled: booking.enabled || pilot,
      payment_enabled: payment.enabled || pilot,
      technical_error: booking.reason === 'firestore_error' || payment.reason === 'firestore_error',
    },
  };
}
