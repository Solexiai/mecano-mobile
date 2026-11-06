// -----------------------------------------------------------------------------
// onPaymentCapturedSettleDeposit — dépôt de réservation (2026-11-06).
//
// Quand le paiement de livraison (le solde) passe à « captured » et que le
// solde ne couvrait pas toute la part du chauffeur
// (`deposit_driver_shortfall_minor`), la différence est virée au chauffeur
// depuis la charge du dépôt (payment/depositTransferOrchestration.ts).
// Idempotent : deposit_transfers/{mission}_shortfall.
// -----------------------------------------------------------------------------
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET } from "../lib/secrets";
import { PaymentDoc, PaymentStatuses } from "../lib/types";
import { settleDepositDriverShortfall } from "../payment/depositTransferOrchestration";

export const onPaymentCapturedSettleDeposit = onDocumentWritten(
  { document: "payments/{paymentId}", secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET] },
  async (event) => {
    const before = event.data?.before.data() as PaymentDoc | undefined;
    const after = event.data?.after.data() as PaymentDoc | undefined;
    if (!after || after.status !== PaymentStatuses.CAPTURED || before?.status === PaymentStatuses.CAPTURED) return;
    if (after.purpose === "deposit" || after.capture_purpose === "mission_fee") return;
    const shortfall = after.deposit_driver_shortfall_minor ?? 0;
    if (!Number.isSafeInteger(shortfall) || shortfall <= 0 || !after.mission_id) return;
    try {
      const result = await settleDepositDriverShortfall(after.mission_id);
      if (result === "failed") console.error("[deposit-transfer] virement complémentaire refusé", after.mission_id);
    } catch (error) {
      console.error("[deposit-transfer]", after.mission_id, error instanceof Error ? error.message : error);
    }
  }
);
