// -----------------------------------------------------------------------------
// createDriverStripeAccount — Cloud Function callable (driver, self-service).
//
// Crée le compte Stripe Connect Express du chauffeur (point 9 : payouts) et
// renvoie le lien d'onboarding hébergé Stripe. Idempotent : si le chauffeur
// a déjà un `stripe_connected_account_id`, le renvoie sans en recréer un
// second (évite un compte fantôme orphelin chez Stripe).
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { admin, authAdmin, db } from "../lib/admin";
import { requireSignedIn } from "../lib/auth";
import { internal, permissionDenied } from "../lib/errors";
import { getPaymentProvider } from "../payment/paymentProviderFactory";
import { STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET } from "../lib/secrets";
import { DriverProfileDoc, PlatformRoles } from "../lib/types";

export const createDriverStripeAccount = onCall(
  { secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET] },
  async (request) => {
    const ctx = requireSignedIn(request);
    if (!ctx.roles.includes(PlatformRoles.DRIVER)) {
      throw permissionDenied("Seul un compte avec le rôle driver peut créer un compte de versement.");
    }

    const driverRef = db.collection("driver_profiles").doc(ctx.uid);
    const driverSnap = await driverRef.get();
    if (driverSnap.exists) {
      const driver = driverSnap.data() as DriverProfileDoc;
      if (driver.stripe_connected_account_id) {
        return {
          success: true,
          connectedAccountId: driver.stripe_connected_account_id,
          onboardingUrl: driver.stripe_onboarding_url ?? null,
          alreadyExisted: true,
        };
      }
    }

    const userRecord = await authAdmin.getUser(ctx.uid).catch(() => null);
    const email = userRecord?.email ?? `${ctx.uid}@no-email.movik.ca`;

    const provider = getPaymentProvider();
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
        stripe_onboarding_url: created.onboardingUrl,
        stripe_charges_enabled: false,
        stripe_payouts_enabled: false,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return {
      success: true,
      connectedAccountId: created.connectedAccountId,
      onboardingUrl: created.onboardingUrl,
      alreadyExisted: false,
    };
  }
);
