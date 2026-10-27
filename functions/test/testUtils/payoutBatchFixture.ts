// ---------------------------------------------------------------------------
// Fixture partagée — chemin de versement groupé Movi-K (option A, 2026-10-27).
//
// Depuis l'option A, `calculateDriverPayout` et `processScheduledDriverPayouts`
// ne font rien en mode `stripe_direct` (défaut) : Stripe vire la part du
// chauffeur à la capture. Les suites qui exercent le chemin groupé doivent
// donc (1) passer la politique en `movik_batch` et (2) donner à chaque
// snapshot une mission dont le paiement actif est CAPTURÉ sans compte
// connecté — un snapshot sans paiement capturé n'est jamais versé.
// ---------------------------------------------------------------------------

import { admin, db } from "../../src/lib/admin";
import { PAYOUT_POLICY_CONFIG_DOC } from "../../src/lib/payoutMode";
import { MissionStatuses, PaymentStatuses, PayoutModes } from "../../src/lib/types";

/** Active le chemin groupé sans toucher aux rétentions déjà écrites. */
export async function seedMovikBatchPayoutMode(): Promise<void> {
  await db.doc(PAYOUT_POLICY_CONFIG_DOC).set({ payout_mode: PayoutModes.MOVIK_BATCH }, { merge: true });
}

export async function clearPayoutMode(): Promise<void> {
  await db.doc(PAYOUT_POLICY_CONFIG_DOC).set(
    { payout_mode: admin.firestore.FieldValue.delete() },
    { merge: true }
  );
}

export interface SeedCapturedPaymentOptions {
  customerId?: string;
  amountCapturedMinor?: number;
  applicationFeeMinor?: number;
  /** Compte connecté sur le paiement : Stripe a alors déjà viré la part. */
  connectedAccountId?: string | null;
  status?: string;
}

/**
 * Mission COMPLETED + paiement actif (capturé par défaut) pour un snapshot.
 * L'identifiant du paiement est dérivé de la mission : `pay_${missionId}`.
 */
export async function seedMissionWithPayment(
  missionId: string,
  driverId: string,
  opts: SeedCapturedPaymentOptions = {}
): Promise<string> {
  const paymentId = `pay_${missionId}`;
  const now = admin.firestore.Timestamp.now();
  const captured = opts.amountCapturedMinor ?? 10000;
  await Promise.all([
    db.collection("delivery_requests").doc(missionId).set(
      {
        customer_id: opts.customerId ?? `customer_for_${missionId}`,
        driver_id: driverId,
        status: MissionStatuses.COMPLETED,
        active_payment_id: paymentId,
        payment_status: opts.status ?? PaymentStatuses.CAPTURED,
        created_at: now,
      },
      { merge: true }
    ),
    db.collection("payments").doc(paymentId).set({
      payment_id: paymentId,
      mission_id: missionId,
      customer_id: opts.customerId ?? `customer_for_${missionId}`,
      driver_id: driverId,
      status: opts.status ?? PaymentStatuses.CAPTURED,
      currency: "CAD",
      amount_authorized_minor: captured,
      amount_captured_minor: captured,
      amount_refunded_minor: 0,
      application_fee_minor: opts.applicationFeeMinor ?? 1500,
      provider: "stripe",
      provider_customer_id: null,
      provider_payment_method_id: null,
      provider_payment_intent_id: `pi_${paymentId}`,
      provider_charge_id: null,
      connected_account_id: opts.connectedAccountId ?? null,
      idempotency_key: `createPayment:${paymentId}`,
      captured_at: now,
      created_at: now,
      updated_at: now,
    }),
  ]);
  return paymentId;
}

export async function cleanupMissionsWithPayments(missionIds: string[]): Promise<void> {
  const batch = db.batch();
  for (const missionId of missionIds) {
    batch.delete(db.collection("delivery_requests").doc(missionId));
    batch.delete(db.collection("payments").doc(`pay_${missionId}`));
    batch.delete(db.collection("driver_transfers").doc(`pay_${missionId}`));
  }
  await batch.commit();
}
