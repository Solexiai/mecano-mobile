// Driver Connect accounts per Stripe environment (passage au vrai argent,
// 2026-10-30): an account of another environment, or an untagged one while
// live is active, is treated as absent (fail closed).
import {
  driverConnectedAccountFor, isDriverAccountStale, isDriverPayoutReady, storedAccountEnvironment,
} from "../../src/lib/stripeAccounts";

const untagged = { stripe_connected_account_id: "acct_old", stripe_charges_enabled: true, stripe_payouts_enabled: true };
const live = { ...untagged, stripe_connected_account_id: "acct_live", stripe_connected_account_environment: "live" as const };
const testTagged = { ...untagged, stripe_connected_account_environment: "test" as const };

test("untagged accounts were created in test", () => {
  expect(storedAccountEnvironment(untagged)).toBe("test");
  expect(storedAccountEnvironment(live)).toBe("live");
  expect(storedAccountEnvironment({ stripe_connected_account_id: null })).toBeNull();
  expect(storedAccountEnvironment(undefined)).toBeNull();
});

test("in test: untagged and test-tagged accounts work, a live one does not", () => {
  expect(driverConnectedAccountFor(untagged, "test")).toBe("acct_old");
  expect(driverConnectedAccountFor(testTagged, "test")).toBe("acct_old");
  expect(driverConnectedAccountFor(live, "test")).toBeNull();
  expect(isDriverAccountStale(live, "test")).toBe(true);
  expect(isDriverPayoutReady(untagged, "test")).toBe(true);
});

test("in live: only a live-tagged account counts; the old test account is stale", () => {
  expect(driverConnectedAccountFor(untagged, "live")).toBeNull();
  expect(driverConnectedAccountFor(testTagged, "live")).toBeNull();
  expect(driverConnectedAccountFor(live, "live")).toBe("acct_live");
  expect(isDriverAccountStale(untagged, "live")).toBe(true);
  expect(isDriverAccountStale(live, "live")).toBe(false);
  expect(isDriverAccountStale({ stripe_connected_account_id: null }, "live")).toBe(false);
  expect(isDriverPayoutReady(untagged, "live")).toBe(false);
  expect(isDriverPayoutReady(live, "live")).toBe(true);
  expect(isDriverPayoutReady({ ...live, stripe_payouts_enabled: false }, "live")).toBe(false);
});
