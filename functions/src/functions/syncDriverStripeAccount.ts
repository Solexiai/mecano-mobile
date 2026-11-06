// -----------------------------------------------------------------------------
// syncDriverStripeAccount — « Vérifier l'état chez Stripe » (2026-11-06).
//
// Reads the driver's connected account at the payment provider and copies
// its state onto the profile (same fields, same audit as the webhook).
// Needed because Stripe only pushes `account.updated` when something
// changes: a driver who just finished the form, or an admin looking at a
// file, can ask for the current state instead of waiting.
//   - no `driverId`: the signed-in driver syncs their own account;
//   - `driverId`: admin or above syncs that driver's account.
// Never creates an account, never hands out a link, never pays anything.
// -----------------------------------------------------------------------------
import { onCall } from "firebase-functions/v2/https";
import { db } from "../lib/admin";
import { requireAdminOrAbove, requireSignedIn } from "../lib/auth";
import { failedPrecondition, invalidArgument, notFound } from "../lib/errors";
import { STRIPE_SECRET_KEY } from "../lib/secrets";
import { driverConnectedAccountFor, isDriverPayoutReady } from "../lib/stripeAccounts";
import { applyDriverAccountStatus } from "../lib/stripeAccountSync";
import type { DriverProfileDoc } from "../lib/types";
import { getPaymentProvider } from "../payment/paymentProviderFactory";

export const syncDriverStripeAccount = onCall({ secrets: [STRIPE_SECRET_KEY] }, async (request) => {
  const ctx = requireSignedIn(request);
  const data = (request.data ?? {}) as { driverId?: unknown };
  let driverId = ctx.uid;
  if (data.driverId !== undefined) {
    if (typeof data.driverId !== "string" || !data.driverId.trim()) {
      throw invalidArgument("driverId invalide.");
    }
    requireAdminOrAbove(ctx);
    driverId = data.driverId.trim();
  }

  const driverSnap = await db.collection("driver_profiles").doc(driverId).get();
  if (!driverSnap.exists) throw notFound("Dossier chauffeur introuvable.");
  const driver = driverSnap.data() as DriverProfileDoc;

  const provider = getPaymentProvider();
  const connectedAccountId = driverConnectedAccountFor(driver, provider.environment);
  if (!connectedAccountId) {
    throw failedPrecondition(
      "Aucun compte de versement dans le mode actuel : commencez (ou refaites) la configuration des versements."
    );
  }

  const status = await provider.getDriverAccountStatus(connectedAccountId);
  if (!status) {
    throw failedPrecondition("Stripe n'a pas répondu. Réessayez dans quelques instants.");
  }

  const updated = await applyDriverAccountStatus({
    driverId,
    driver,
    connectedAccountId,
    status,
    actorUserId: ctx.uid,
    actorRole: ctx.role ?? (driverId === ctx.uid ? "driver" : "admin"),
    sourceFunction: "syncDriverStripeAccount",
  });

  const merged: DriverProfileDoc = {
    ...driver,
    stripe_charges_enabled: status.chargesEnabled,
    stripe_payouts_enabled: status.payoutsEnabled,
  };
  return {
    success: true,
    updated,
    charges_enabled: status.chargesEnabled,
    payouts_enabled: status.payoutsEnabled,
    details_submitted: status.detailsSubmitted,
    requirements_currently_due: status.currentlyDue,
    disabled_reason: status.disabledReason,
    payout_ready: isDriverPayoutReady(merged, provider.environment),
  };
});
