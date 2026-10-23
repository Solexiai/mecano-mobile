import { cardHoldMinor, isLateCancellation, MISSION_FEE_POLICY, missionFeeAmounts } from '../../src/lib/missionFees';

const now = Date.parse('2026-10-22T12:00:00Z');
const hours = (h: number) => new Date(now + h * 3600000).toISOString();
const mission = (over: Record<string, unknown> = {}) => ({
  status: 'assigned', driver_id: 'd', booking_snapshot: { load: { requested_at: hours(24) } }, ...over,
});

test('owner amounts: 30 $ charged = 25 $ driver + 5 $ Movi-K', () => {
  expect(MISSION_FEE_POLICY).toMatchObject({ total_minor: 3000, driver_minor: 2500, platform_minor: 500 });
  expect(missionFeeAmounts(12345)).toEqual({ total_minor: 3000, driver_minor: 2500, platform_minor: 500 });
  expect(missionFeeAmounts(3000)).toEqual({ total_minor: 3000, driver_minor: 2500, platform_minor: 500 });
  // Never more than the card hold; same 25/5 split.
  expect(missionFeeAmounts(1200)).toEqual({ total_minor: 1200, driver_minor: 1000, platform_minor: 200 });
  expect(missionFeeAmounts(0)).toEqual({ total_minor: 0, driver_minor: 0, platform_minor: 0 });
});

test('owner decision 2026-10-23: the card hold is never below the 30 $ fee', () => {
  expect(cardHoldMinor(2500)).toBe(3000);
  expect(cardHoldMinor(3000)).toBe(3000);
  expect(cardHoldMinor(12345)).toBe(12345);
  // With a 30 $ minimum hold, a 25 $ delivery still carries the full fee.
  expect(missionFeeAmounts(cardHoldMinor(2500))).toEqual({ total_minor: 3000, driver_minor: 2500, platform_minor: 500 });
});

test('free before a driver accepts', () => {
  for (const status of ['draft', 'quoted', 'searching_driver', 'offered', 'payment_failed']) {
    expect(isLateCancellation(mission({ status, driver_id: null }), now)).toBe(false);
  }
});

test('after acceptance: free more than 2 hours before pickup, otherwise late', () => {
  expect(isLateCancellation(mission(), now)).toBe(false);
  expect(isLateCancellation(mission({ booking_snapshot: { load: { requested_at: hours(2.5) } } }), now)).toBe(false);
  expect(isLateCancellation(mission({ booking_snapshot: { load: { requested_at: hours(1.5) } } }), now)).toBe(true);
  // A reserved agenda slot is the pickup time.
  expect(isLateCancellation(mission({ scheduling: { pickup_at: hours(1) } }), now)).toBe(true);
  // "As soon as possible": the driver is coming now.
  expect(isLateCancellation(mission({ booking_snapshot: { load: { requested_at: null } } }), now)).toBe(true);
});

test('driver already on the way or on site: late whatever the planned time', () => {
  expect(isLateCancellation(mission({ status: 'driver_to_pickup' }), now)).toBe(true);
  expect(isLateCancellation(mission({ status: 'arrived_at_pickup' }), now)).toBe(true);
});

test('internal test missions never carry a fee', () => {
  expect(isLateCancellation(mission({ assignment_mode: 'internal_test', booking_snapshot: { load: { requested_at: null } } }), now)).toBe(false);
});
