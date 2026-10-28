// -----------------------------------------------------------------------------
// Reprise de capture après livraison (PAY-03 / PAY-11, 2026-10-27).
//
//   - retryFailedCaptures      : cron, toutes les 30 min — recontrôle les
//                                 captures non concluantes, relance celles
//                                 dont l'échéance (J+1, J+3) est passée.
//   - retryFailedCapture       : callable — le client propriétaire (après
//                                 avoir mis sa carte à jour) ou un admin
//                                 relance immédiatement.
//   - startPaymentRecoveryCardSetup : callable — session Stripe Checkout
//                                 (mode setup) pour que le client enregistre
//                                 une nouvelle carte ; le profil de paiement
//                                 est mis à jour par completeSavedSetup().
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { admin, db } from "../lib/admin";
import { isAdminOrAbove, requireSignedIn } from "../lib/auth";
import { failedPrecondition, invalidArgument, notFound, permissionDenied } from "../lib/errors";
import { STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET } from "../lib/secrets";
import { APP_PUBLIC_BASE_URL } from "../lib/appConfig";
import { PaymentDoc, PaymentStatuses } from "../lib/types";
import { getPaymentProvider } from "../payment/paymentProviderFactory";
import { verifyCardSetup } from "../lib/bookingPayment";
import { completeSavedSetup } from "./bookingCardSetup";
import {
  processCaptureRecoveryBatch,
  retryFailedCapture as retryFailedCaptureOrchestration,
} from "../payment/captureRecovery";

const options = { secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET] };

function paymentId(value: unknown): string {
  if (typeof value !== "string" || !/^[a-zA-Z0-9_-]{1,100}$/.test(value)) throw invalidArgument("paymentId invalide.");
  return value;
}

/** Identifiant du setup de carte de reprise (un par tentative : une session
 *  Checkout terminée ne peut pas servir deux fois). Lu par completeSavedSetup
 *  et par le webhook checkout.session.completed via metadata.movik_quote_id. */
export function recoverySetupId(id: string, attempt: number): string {
  return `recovery_${id}_${Math.max(1, attempt)}`;
}

export const retryFailedCaptures = onSchedule(
  { schedule: "every 30 minutes", timeZone: "America/Toronto", ...options },
  async () => {
    const result = await processCaptureRecoveryBatch();
    if (result.errors > 0 || result.failed > 0) {
      console.error("[capture-recovery] attention requise", result);
    } else if (result.rechecked + result.retried > 0) {
      console.log("[capture-recovery]", result);
    }
  }
);

export const retryFailedCapture = onCall(options, async (request) => {
  const ctx = requireSignedIn(request);
  const id = paymentId(request.data?.paymentId);
  const snap = await db.collection("payments").doc(id).get();
  if (!snap.exists) throw notFound("Paiement introuvable.");
  const payment = snap.data() as PaymentDoc;
  const isAdmin = isAdminOrAbove(ctx);
  if (!isAdmin && payment.customer_id !== ctx.uid) throw permissionDenied("Paiement inaccessible.");
  if (payment.status !== PaymentStatuses.CAPTURE_FAILED) {
    throw failedPrecondition(
      payment.status === PaymentStatuses.CAPTURED
        ? "Ce paiement est déjà encaissé."
        : "Aucune relance possible dans l'état actuel du paiement."
    );
  }
  const outcome = await retryFailedCaptureOrchestration(id, {
    trigger: isAdmin ? "admin" : "customer",
    actorUserId: ctx.uid,
  });
  return {
    success: outcome.success,
    status: outcome.status,
    attempt: outcome.attempt,
    indeterminate: outcome.indeterminate,
    // Message générique : jamais le détail Stripe brut au client.
    message: outcome.success
      ? null
      : outcome.indeterminate
        ? "Réponse du fournisseur de paiement en attente ; nous revérifions sous peu."
        : outcome.status === PaymentStatuses.FAILED
          ? "Le paiement n'a pas pu être encaissé. Notre équipe vous contactera."
          : "La carte a été refusée. Mettez votre carte à jour puis réessayez.",
  };
});

export const startPaymentRecoveryCardSetup = onCall(options, async (request) => {
  const ctx = requireSignedIn(request);
  const id = paymentId(request.data?.paymentId);
  const snap = await db.collection("payments").doc(id).get();
  if (!snap.exists) throw notFound("Paiement introuvable.");
  const payment = snap.data() as PaymentDoc;
  if (payment.customer_id !== ctx.uid) throw permissionDenied("Paiement inaccessible.");
  if (payment.status !== PaymentStatuses.CAPTURE_FAILED) {
    throw failedPrecondition("Aucune mise à jour de carte n'est attendue pour ce paiement.");
  }
  const provider = getPaymentProvider();
  const profileRef = db.doc(`payment_profiles/${ctx.uid}`);
  const profile = (await profileRef.get()).data();
  if (!profile?.provider_customer_id) throw failedPrecondition("Profil de paiement introuvable.");
  if (profile.stripe_environment !== provider.environment) {
    throw failedPrecondition("Le profil de paiement appartient à un autre environnement.");
  }
  const setupId = recoverySetupId(id, payment.capture_attempt_count ?? 1);
  const ref = db.doc(`booking_payment_setups/${setupId}`);
  const saved: FirebaseFirestore.DocumentData = await db.runTransaction(async (tx) => {
    const old = (await tx.get(ref)).data();
    if (old) return old;
    const locale = ["fr", "en", "es"].includes(request.data?.locale) ? request.data.locale : "fr";
    const base = new URL(APP_PUBLIC_BASE_URL.value());
    if (base.protocol !== "https:") throw failedPrecondition("Le domaine de retour de paiement doit être configuré en HTTPS.");
    const row = {
      user_id: ctx.uid,
      quote_id: setupId,
      payment_id: id,
      customer_id: profile.provider_customer_id,
      stripe_environment: provider.environment,
      locale,
      return_url: `${base.origin}/${locale}/livraison/suivi/${payment.mission_id}`,
      created_at: admin.firestore.Timestamp.now(),
    };
    tx.set(ref, row);
    return row;
  });
  if (saved.user_id !== ctx.uid || saved.stripe_environment !== provider.environment) {
    throw permissionDenied("Session inaccessible.");
  }
  const setup = saved.session_id
    ? await provider.getCardSetup(saved.session_id)
    : await provider.createCardSetup({
        customerId: saved.customer_id,
        userId: ctx.uid,
        quoteId: setupId,
        returnUrl: saved.return_url,
        locale: saved.locale,
      });
  await ref.set({ session_id: setup.id }, { merge: true });
  const method = verifyCardSetup(setup, {
    customerId: saved.customer_id, userId: ctx.uid, quoteId: setupId, environment: provider.environment,
  });
  if (method) {
    await completeSavedSetup(setupId);
    return { ready: true, url: null };
  }
  if (!setup.url) throw failedPrecondition("La session Stripe a expiré. Réessayez.");
  return { ready: false, url: setup.url };
});
