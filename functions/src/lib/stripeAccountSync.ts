// -----------------------------------------------------------------------------
// stripeAccountSync.ts — one place that copies a connected account's state
// (as Stripe reports it) onto the driver profile (2026-11-06).
//
// Used by the `account.updated` webhook and by `syncDriverStripeAccount`
// (driver's "Vérifier l'état chez Stripe" / admin's "Actualiser depuis
// Stripe"). Writes only when something changed, always audited. Never
// decides anything about payouts: `isDriverPayoutReady` still rules.
// -----------------------------------------------------------------------------
import { admin, db } from "./admin";
import { writeAuditLog } from "./audit";
import type { DriverProfileDoc } from "./types";

export interface DriverAccountStatus {
  chargesEnabled: boolean;
  payoutsEnabled: boolean;
  detailsSubmitted: boolean;
  /** Number of requirements Stripe still asks the driver for. */
  currentlyDue: number;
  disabledReason: string | null;
}

export function driverAccountStatusChanged(driver: DriverProfileDoc, s: DriverAccountStatus): boolean {
  return (
    (driver.stripe_charges_enabled ?? false) !== s.chargesEnabled ||
    (driver.stripe_payouts_enabled ?? false) !== s.payoutsEnabled ||
    (driver.stripe_details_submitted ?? false) !== s.detailsSubmitted ||
    (driver.stripe_requirements_currently_due ?? 0) !== s.currentlyDue ||
    (driver.stripe_requirements_disabled_reason ?? null) !== s.disabledReason
  );
}

/** Returns true when the profile was updated. */
export async function applyDriverAccountStatus(params: {
  driverId: string;
  driver: DriverProfileDoc;
  connectedAccountId: string;
  status: DriverAccountStatus;
  actorUserId: string;
  actorRole: string;
  sourceFunction: string;
}): Promise<boolean> {
  const { driverId, driver, connectedAccountId, status, actorUserId, actorRole, sourceFunction } = params;
  if (!driverAccountStatusChanged(driver, status)) return false;
  await db.collection("driver_profiles").doc(driverId).update({
    stripe_charges_enabled: status.chargesEnabled,
    stripe_payouts_enabled: status.payoutsEnabled,
    stripe_details_submitted: status.detailsSubmitted,
    stripe_requirements_currently_due: status.currentlyDue,
    stripe_requirements_disabled_reason: status.disabledReason,
    stripe_account_synced_at: admin.firestore.FieldValue.serverTimestamp(),
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  });
  await writeAuditLog({
    actorUserId,
    actorRole,
    action: "driver_stripe_account_status_synced",
    sourceFunction,
    targetId: driverId,
    metadata: {
      connectedAccountId,
      chargesEnabled: status.chargesEnabled,
      payoutsEnabled: status.payoutsEnabled,
      detailsSubmitted: status.detailsSubmitted,
      currentlyDue: status.currentlyDue,
      disabledReason: status.disabledReason,
      previousChargesEnabled: driver.stripe_charges_enabled ?? false,
      previousPayoutsEnabled: driver.stripe_payouts_enabled ?? false,
    },
  });
  return true;
}
