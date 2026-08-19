// -----------------------------------------------------------------------------
// createCustomerPaymentProfile — Cloud Function callable (customer, self-
// service). PHASE 6, point 1/4 : « le moyen de paiement doit être sécurisé
// AVANT ou PENDANT la mission, jamais seulement après. »
//
// Crée (ou renvoie, idempotent) le `payment_profiles/{customerId}` — la
// référence Stripe du client, jamais de données de carte brutes (celles-ci
// transitent uniquement entre le SDK client Stripe et Stripe lui-même ; ce
// backend ne voit jamais un numéro de carte).
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { admin, authAdmin, db } from "../lib/admin";
import { requireSignedIn } from "../lib/auth";
import { internal } from "../lib/errors";
import { getPaymentProvider } from "../payment/paymentProviderFactory";
import { STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET } from "../lib/secrets";
import { PaymentProfileDoc, PlatformRoles } from "../lib/types";

export const createCustomerPaymentProfile = onCall(
  { secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET] },
  async (request) => {
    const ctx = requireSignedIn(request);
    const customerId = ctx.uid;

    const profileRef = db.collection("payment_profiles").doc(customerId);
    const existing = await profileRef.get();
    if (existing.exists) {
      const data = existing.data() as PaymentProfileDoc;
      return { success: true, providerCustomerId: data.provider_customer_id, alreadyExisted: true };
    }

    const userRecord = await authAdmin.getUser(customerId).catch(() => null);
    const email = userRecord?.email ?? `${customerId}@no-email.movik.ca`;
    const displayName = userRecord?.displayName ?? "Client Movi-K";

    const provider = getPaymentProvider();
    let created;
    try {
      created = await provider.createCustomer({ userId: customerId, email, displayName });
    } catch (err) {
      throw internal(
        `Impossible de créer le profil de paiement fournisseur: ${
          err instanceof Error ? err.message : String(err)
        }`
      );
    }

    const now = admin.firestore.Timestamp.now();
    const profile: PaymentProfileDoc = {
      customer_id: customerId,
      provider: "stripe",
      provider_customer_id: created.providerCustomerId,
      default_payment_method_id: null,
      created_at: now,
      updated_at: now,
    };
    await profileRef.set(profile);

    return {
      success: true,
      providerCustomerId: created.providerCustomerId,
      alreadyExisted: false,
      note:
        (ctx.role ?? PlatformRoles.CUSTOMER) === PlatformRoles.CUSTOMER
          ? "Le client doit maintenant appeler attachCustomerPaymentMethod() après avoir collecté un moyen de paiement via le SDK Stripe côté client."
          : undefined,
    };
  }
);
