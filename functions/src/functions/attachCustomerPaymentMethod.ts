// -----------------------------------------------------------------------------
// attachCustomerPaymentMethod — Cloud Function callable (customer).
//
// Reçoit un `providerPaymentMethodId` OPAQUE (jeton déjà créé côté client via
// le SDK Stripe — jamais un numéro de carte brut, voir point 4 du cahier des
// charges). Attache ce moyen de paiement au `provider_customer_id` du client
// et le définit comme moyen par défaut de sa mission courante/future.
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { requireSignedIn } from "../lib/auth";
import { failedPrecondition, invalidArgument, notFound } from "../lib/errors";
import { getPaymentProvider } from "../payment/paymentProviderFactory";
import { STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET } from "../lib/secrets";
import { PaymentProfileDoc } from "../lib/types";

export interface AttachCustomerPaymentMethodRequest {
  providerPaymentMethodId: string;
}

export const attachCustomerPaymentMethod = onCall<AttachCustomerPaymentMethodRequest>(
  { secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET] },
  async (request) => {
    const ctx = requireSignedIn(request);
    const { providerPaymentMethodId } = request.data;
    if (!providerPaymentMethodId || typeof providerPaymentMethodId !== "string") {
      throw invalidArgument("providerPaymentMethodId est requis.");
    }

    const profileRef = db.collection("payment_profiles").doc(ctx.uid);
    const profileSnap = await profileRef.get();
    if (!profileSnap.exists) {
      throw notFound(
        "Aucun payment_profiles trouvé — appelez createCustomerPaymentProfile() d'abord."
      );
    }
    const profile = profileSnap.data() as PaymentProfileDoc;

    const provider = getPaymentProvider();
    const result = await provider.attachPaymentMethod({
      providerCustomerId: profile.provider_customer_id,
      providerPaymentMethodId,
    });

    if (!result.success) {
      throw failedPrecondition("Le fournisseur de paiement a refusé l'association de ce moyen de paiement.");
    }

    await profileRef.update({
      default_payment_method_id: result.providerPaymentMethodId,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, providerPaymentMethodId: result.providerPaymentMethodId };
  }
);
