// -----------------------------------------------------------------------------
// createDriverStripeAccount — Cloud Function callable (driver, self-service).
//
// Crée le compte Stripe Connect Express du chauffeur (point 9 : payouts) et
// renvoie le lien d'onboarding hébergé Stripe. Idempotent : si le chauffeur
// a déjà un `stripe_connected_account_id`, le renvoie sans en recréer un
// second (évite un compte fantôme orphelin chez Stripe).
// 2026-10-23 : réservé aux chauffeurs approuvés ; un compte existant non
// terminé reçoit un NOUVEAU lien d'inscription à chaque appel.
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { admin, authAdmin, db } from "../lib/admin";
import { requireSignedIn } from "../lib/auth";
import { failedPrecondition, internal, permissionDenied } from "../lib/errors";
import { getPaymentProvider } from "../payment/paymentProviderFactory";
import { isDriverAccountStale, storedAccountEnvironment } from "../lib/stripeAccounts";
import { STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET } from "../lib/secrets";
import { DriverProfileDoc, DriverStatuses, PlatformRoles } from "../lib/types";

export const createDriverStripeAccount = onCall(
  { secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET] },
  async (request) => {
    const ctx = requireSignedIn(request);
    if (!ctx.roles.includes(PlatformRoles.DRIVER)) {
      throw permissionDenied("Seul un compte avec le rôle driver peut créer un compte de versement.");
    }

    const driverRef = db.collection("driver_profiles").doc(ctx.uid);
    const driverSnap = await driverRef.get();
    const driver = driverSnap.exists ? (driverSnap.data() as DriverProfileDoc) : null;
    // 2026-10-23: payouts are set up only after Movi-K approved the file
    // (previously only the screen hid the button).
    if (!driver || driver.status !== DriverStatuses.APPROVED) {
      throw failedPrecondition("Votre dossier chauffeur doit d'abord être approuvé par Movi-K.");
    }
    const provider = getPaymentProvider();
    // Passage au vrai argent (2026-10-30): an account of another environment
    // is archived below and a new one is created in the active one.
    const stale = isDriverAccountStale(driver, provider.environment);
    if (driver.stripe_connected_account_id && !stale) {
      const accountId = driver.stripe_connected_account_id;
      if (driver.stripe_charges_enabled === true && driver.stripe_payouts_enabled === true) {
        return { success: true, connectedAccountId: accountId, onboardingUrl: null, alreadyExisted: true, active: true };
      }
      // Stripe onboarding links expire after a few minutes and work once:
      // never hand back the stored one, always make a fresh link so a driver
      // who stopped halfway can resume (2026-10-23).
      let freshUrl: string | null;
      try {
        freshUrl = await provider.createDriverOnboardingLink(accountId);
      } catch (err) {
        throw internal(`Impossible de créer le lien d'inscription Stripe: ${err instanceof Error ? err.message : String(err)}`);
      }
      if (freshUrl) {
        await driverRef.set({ stripe_onboarding_url: freshUrl, updated_at: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
      }
      return { success: !!freshUrl, connectedAccountId: accountId, onboardingUrl: freshUrl, alreadyExisted: true, active: false };
    }

    const userRecord = await authAdmin.getUser(ctx.uid).catch(() => null);
    const email = userRecord?.email ?? `${ctx.uid}@no-email.movik.ca`;

    let created;
    try {
      created = await provider.createDriverAccount({ driverId: ctx.uid, email, country: "CA" });
    } catch (err) {
      throw internal(
        `Impossible de créer le compte de versement fournisseur: ${
          err instanceof Error ? err.message : String(err)
        }`
      );
    }

    await driverRef.set(
      {
        stripe_connected_account_id: created.connectedAccountId,
        stripe_connected_account_environment: provider.environment,
        stripe_onboarding_url: created.onboardingUrl,
        stripe_charges_enabled: false,
        stripe_payouts_enabled: false,
        ...(stale
          ? {
              stripe_previous_accounts: admin.firestore.FieldValue.arrayUnion({
                account_id: driver.stripe_connected_account_id,
                environment: storedAccountEnvironment(driver),
                archived_at: admin.firestore.Timestamp.now(),
                archived_by: "driver",
              }),
            }
          : {}),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return {
      success: true,
      connectedAccountId: created.connectedAccountId,
      onboardingUrl: created.onboardingUrl,
      alreadyExisted: false,
      active: false,
    };
  }
);
