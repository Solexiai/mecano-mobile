// -----------------------------------------------------------------------------
// adminStripeEnvironment — passage au vrai argent (Centre de commande > 6 ·
// Interrupteurs, 2026-10-30). Admin only.
//   - "get": which Stripe environment production runs on (test | live), the
//     drivers whose payout account belongs to another environment, and the
//     payments still open in another environment (to finish or cancel before
//     switching). Never exposes a key or a secret.
//   - "archive_stale_driver_accounts": for every such driver, moves the
//     account to `stripe_previous_accounts` and clears the Stripe fields,
//     so the driver sees "Configurer les versements" again and does the
//     Stripe onboarding in the active environment. Audited. Nothing is
//     deleted at Stripe.
// -----------------------------------------------------------------------------
import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { writeAuditLogInTransaction } from "../lib/audit";
import { requireAdminOrAbove, requireSignedIn } from "../lib/auth";
import { invalidArgument } from "../lib/errors";
import { STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET } from "../lib/secrets";
import { isDriverAccountStale, storedAccountEnvironment } from "../lib/stripeAccounts";
import type { StripeEnvironment } from "../lib/stripeEnvironment";
import { DriverProfileDoc, PaymentStatuses } from "../lib/types";
import { getPaymentProvider } from "../payment/paymentProviderFactory";
import { NotConfiguredPaymentProvider } from "../payment/paymentProvider";

/** Payment states where money may still move (authorize/capture ahead). */
const OPEN_PAYMENT_STATUSES: string[] = [
  PaymentStatuses.CREATED,
  PaymentStatuses.REQUIRES_PAYMENT_METHOD,
  PaymentStatuses.AUTHORIZATION_PENDING,
  PaymentStatuses.AUTHORIZED,
  PaymentStatuses.CAPTURE_PENDING,
  PaymentStatuses.CAPTURE_FAILED,
];

async function staleDrivers(environment: StripeEnvironment) {
  const snap = await db.collection("driver_profiles").where("stripe_connected_account_id", "!=", null).get();
  return snap.docs
    .map((d) => ({ id: d.id, data: d.data() as DriverProfileDoc }))
    .filter((d) => isDriverAccountStale(d.data, environment));
}

export const adminStripeEnvironment = onCall(
  { secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET] },
  async (request) => {
    const ctx = requireSignedIn(request);
    requireAdminOrAbove(ctx);
    const data = (request.data ?? {}) as Record<string, unknown>;
    const provider = getPaymentProvider();
    const configured = !(provider instanceof NotConfiguredPaymentProvider);
    const environment = provider.environment;

    if (data.action === "get") {
      const [drivers, payments] = await Promise.all([
        staleDrivers(environment),
        db.collection("payments").where("status", "in", OPEN_PAYMENT_STATUSES).get(),
      ]);
      const otherEnvironmentOpenPayments = payments.docs.filter((d) => {
        const tag = d.data().stripe_environment ?? null;
        // Untagged payments predate the tag: they were made in test.
        return (tag ?? "test") !== environment;
      });
      return {
        configured,
        environment,
        stale_drivers: drivers.map((d) => ({
          uid: d.id,
          name: d.data.full_name ?? null,
          environment: storedAccountEnvironment(d.data),
        })),
        open_payments_other_environment: otherEnvironmentOpenPayments.map((d) => ({
          payment_id: d.id,
          mission_id: d.data().mission_id ?? null,
          status: d.data().status,
          environment: d.data().stripe_environment ?? "test",
        })),
      };
    }

    if (data.action === "archive_stale_driver_accounts") {
      const drivers = await staleDrivers(environment);
      const now = admin.firestore.Timestamp.now();
      for (const d of drivers) {
        await db.runTransaction(async (tx) => {
          const ref = db.collection("driver_profiles").doc(d.id);
          const current = (await tx.get(ref)).data() as DriverProfileDoc | undefined;
          if (!current || !isDriverAccountStale(current, environment)) return;
          tx.update(ref, {
            stripe_previous_accounts: admin.firestore.FieldValue.arrayUnion({
              account_id: current.stripe_connected_account_id,
              environment: storedAccountEnvironment(current),
              archived_at: now,
              archived_by: "admin",
            }),
            stripe_connected_account_id: null,
            stripe_connected_account_environment: null,
            stripe_onboarding_url: null,
            stripe_charges_enabled: false,
            stripe_payouts_enabled: false,
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
          });
          writeAuditLogInTransaction(tx, {
            actorUserId: ctx.uid,
            actorRole: ctx.role ?? "admin",
            action: "driver_stripe_account_archived",
            sourceFunction: "adminStripeEnvironment",
            targetId: d.id,
            metadata: {
              account_id: current.stripe_connected_account_id,
              from_environment: storedAccountEnvironment(current),
              active_environment: environment,
            },
          });
        });
      }
      return { success: true, environment, archived: drivers.length };
    }

    throw invalidArgument("Action inconnue.");
  }
);
