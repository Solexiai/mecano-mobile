import { getBookingPolicy } from './bookingServer';
import { resolveRuntimeFlag, RuntimeFlagKeys } from './runtimeFlags';

// Public capabilities only. Never changes flags, prepares payments, or exposes
// internal configuration details. Mutating endpoints retain their own guards.
export async function getPublicBookingConfiguration() {
  const [policy, booking, payment] = await Promise.all([
    getBookingPolicy(),
    resolveRuntimeFlag(RuntimeFlagKeys.ACCEPT_NEW_DELIVERY_REQUESTS),
    resolveRuntimeFlag(RuntimeFlagKeys.PAYMENTS_ENABLED),
  ]);
  return {
    policy,
    availability: {
      booking_enabled: booking.enabled,
      payment_enabled: payment.enabled,
      technical_error: booking.reason === 'firestore_error' || payment.reason === 'firestore_error',
    },
  };
}
