// -----------------------------------------------------------------------------
// onPaymentWrittenMirrorDriverTransfer — option A (2026-10-27).
//
// Les paiements sont des « destination charges » Stripe Connect : à la
// capture, Stripe vire la part du chauffeur (montant capturé moins
// application_fee) sur son compte connecté, puis la dépose sur son compte
// bancaire selon le calendrier du compte Express. Le chauffeur ne peut pas
// lire payments/{id} (données client, références fournisseur) : ce
// déclencheur en tient un MIROIR minimal, driver_transfers/{paymentId},
// lisible par le chauffeur propriétaire seulement (firestore.rules) et
// affiché dans son onglet Revenus > Versements.
//
// Dérivé pur et idempotent : rejouer l'évènement réécrit le même document ;
// un paiement sans compte connecté ou jamais capturé n'a pas de miroir.
// -----------------------------------------------------------------------------

import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { admin, db } from "../lib/admin";
import { connectTransferShare } from "../lib/payoutMode";
import { DriverTransferDoc, PaymentDoc } from "../lib/types";

export function buildDriverTransferDoc(paymentId: string, payment: PaymentDoc): DriverTransferDoc | null {
  const share = connectTransferShare(payment);
  if (!share || !payment.connected_account_id || !payment.driver_id || !payment.mission_id) return null;
  const status: DriverTransferDoc["status"] =
    share.reversedMinor <= 0 ? "transferred" : share.netMinor <= 0 ? "reversed" : "partially_reversed";
  return {
    payment_id: paymentId,
    mission_id: payment.mission_id,
    driver_id: payment.driver_id,
    connected_account_id: payment.connected_account_id,
    currency: payment.currency,
    amount_minor: share.amountMinor,
    reversed_minor: share.reversedMinor,
    net_minor: share.netMinor,
    status,
    capture_purpose: payment.capture_purpose ?? null,
    captured_at: payment.captured_at ?? null,
    stripe_environment: payment.stripe_environment ?? null,
    updated_at: admin.firestore.Timestamp.now(),
  };
}

/** Écrit (ou laisse absent) le miroir d'un paiement. Exporté pour les tests. */
export async function mirrorDriverTransfer(paymentId: string, payment: PaymentDoc | undefined): Promise<boolean> {
  const doc = payment ? buildDriverTransferDoc(paymentId, payment) : null;
  if (!doc) return false;
  await db.collection("driver_transfers").doc(paymentId).set(doc, { merge: true });
  return true;
}

export const onPaymentWrittenMirrorDriverTransfer = onDocumentWritten(
  { document: "payments/{paymentId}", retry: true },
  async (event) => {
    const after = event.data?.after.data() as PaymentDoc | undefined;
    await mirrorDriverTransfer(event.params.paymentId, after);
  }
);
