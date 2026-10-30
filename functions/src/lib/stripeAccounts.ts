// -----------------------------------------------------------------------------
// stripeAccounts.ts — the driver's Stripe Connect account, per environment
// (passage au vrai argent, 2026-10-30).
//
// Movi-K has one Firebase project; test and live Stripe differ only by the
// active secret key (see stripeEnvironment.ts). A Connect account created in
// test does not exist in live. Every account created from now on is tagged
// with its environment (`stripe_connected_account_environment`); accounts
// created before the tag existed were all created in test.
//
// FAIL CLOSED, same policy as stripeEnvironment.ts: an account of another
// environment, or an untagged account while live is active, is treated as
// ABSENT. It is never sent to Stripe as a transfer destination.
// -----------------------------------------------------------------------------
import type { StripeEnvironment } from "./stripeEnvironment";
import type { DriverProfileDoc } from "./types";

type DriverStripeFields = Pick<
  DriverProfileDoc,
  | "stripe_connected_account_id"
  | "stripe_connected_account_environment"
  | "stripe_charges_enabled"
  | "stripe_payouts_enabled"
>;

/** Environment the stored account belongs to (untagged = created in test). */
export function storedAccountEnvironment(driver: DriverStripeFields | null | undefined): StripeEnvironment | null {
  if (!driver?.stripe_connected_account_id) return null;
  const tag = driver.stripe_connected_account_environment;
  return tag === "live" || tag === "test" ? tag : "test";
}

/** The Connect account usable in `environment`, or null. */
export function driverConnectedAccountFor(
  driver: DriverStripeFields | null | undefined,
  environment: StripeEnvironment
): string | null {
  const id = driver?.stripe_connected_account_id;
  if (typeof id !== "string" || !id) return null;
  return storedAccountEnvironment(driver) === environment ? id : null;
}

/** An account exists but belongs to another environment (to redo at Stripe). */
export function isDriverAccountStale(
  driver: DriverStripeFields | null | undefined,
  environment: StripeEnvironment
): boolean {
  return !!driver?.stripe_connected_account_id && driverConnectedAccountFor(driver, environment) === null;
}

/** Stripe can pay this driver in `environment` (account of that environment, finished at Stripe). */
export function isDriverPayoutReady(
  driver: DriverStripeFields | null | undefined,
  environment: StripeEnvironment
): boolean {
  return (
    driverConnectedAccountFor(driver, environment) !== null &&
    driver?.stripe_charges_enabled === true &&
    driver?.stripe_payouts_enabled === true
  );
}

/** Message shown to a driver who cannot be paid yet. */
export const DRIVER_PAYOUT_NOT_READY_MESSAGE =
  "Configurez vos versements (Stripe) dans votre tableau de bord avant d’accepter une livraison.";
