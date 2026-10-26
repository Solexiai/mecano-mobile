// -----------------------------------------------------------------------------
// getPaymentReceipt — reçu de paiement d'une livraison (2026-10-26).
//
// Le client propriétaire de la mission obtient le lien du reçu hébergé par
// Stripe pour le montant réellement débité. Lecture seule : aucun montant,
// aucune capture, aucun remboursement n'est créé ou modifié. Le lien est
// redemandé à Stripe à chaque appel (il n'est jamais stocké).
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { db } from "../lib/admin";
import { requireSignedIn } from "../lib/auth";
import { failedPrecondition, invalidArgument, notFound, permissionDenied } from "../lib/errors";
import { STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET } from "../lib/secrets";
import { PaymentDoc, PaymentStatuses } from "../lib/types";
import { getPaymentProvider } from "../payment/paymentProviderFactory";

export interface GetPaymentReceiptRequest {
  missionId: string;
}

/** Débité, même remboursé ensuite : le reçu Stripe montre les deux. */
const RECEIPT_STATUSES: readonly string[] = [
  PaymentStatuses.CAPTURED,
  PaymentStatuses.PARTIALLY_REFUNDED,
  PaymentStatuses.REFUNDED,
  PaymentStatuses.DISPUTED,
  PaymentStatuses.CHARGEBACK,
];

export const getPaymentReceipt = onCall<GetPaymentReceiptRequest>(
  { secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET] },
  async (request) => {
    const ctx = requireSignedIn(request);
    const missionId = request.data?.missionId;
    if (typeof missionId !== "string" || !/^[a-zA-Z0-9_-]{1,128}$/.test(missionId)) {
      throw invalidArgument("missionId invalide.");
    }
    const mission = (await db.collection("delivery_requests").doc(missionId).get()).data();
    if (!mission) throw notFound("Livraison introuvable.");
    if (mission.customer_id !== ctx.uid) throw permissionDenied("Reçu inaccessible.");

    const payments = await db.collection("payments")
      .where("mission_id", "==", missionId)
      .where("customer_id", "==", ctx.uid)
      .get();
    const charged = payments.docs
      .map((d) => d.data() as PaymentDoc)
      .filter((p) => RECEIPT_STATUSES.includes(p.status) &&
        typeof p.provider_charge_id === "string" && p.provider_charge_id.length > 0)
      .sort((a, b) => (b.captured_at?.toMillis() ?? 0) - (a.captured_at?.toMillis() ?? 0));
    const payment = charged[0];
    if (!payment) throw failedPrecondition("Aucun montant n'a encore été débité pour cette livraison.");

    const provider = getPaymentProvider();
    if (payment.stripe_environment && payment.stripe_environment !== provider.environment) {
      throw failedPrecondition("Ce paiement appartient à un autre environnement Stripe.");
    }
    const url = await provider.getChargeReceiptUrl(payment.provider_charge_id!);
    if (!url) throw failedPrecondition("Stripe n'a pas de reçu pour ce paiement.");
    return { url };
  }
);
