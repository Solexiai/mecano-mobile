// -----------------------------------------------------------------------------
// refundPayment — Cloud Function callable (customer, admin, super_admin).
//
// PHASE 6 (directive 38 points, points 1 à 6) : remboursement réel, complet
// ou partiel (y compris plusieurs remboursements partiels successifs dans
// la limite du montant capturé), avant OU après versement chauffeur, avec
// idempotence déterministe et sans jamais modifier un payout historique.
//
// Toute la logique financière (validation du solde remboursable, détection
// post-payout, écriture ledger compensatoire, recalcul
// mission_financial_balance) est déléguée à
// `refundPayment()` de `payment/paymentOrchestration.ts` (schéma en 3 temps
// déjà validé pour createAndAuthorizeMissionPayment/capturePayment/
// submitDriverPayout). Cette Cloud Function callable se limite à :
//   1. authentifier/autoriser l'appelant (customer propriétaire du paiement,
//      OU admin/super_admin pour un remboursement administratif),
//   2. valider les entrées,
//   3. construire une `requestKey` déterministe pour la déduplication
//      client (retry réseau du même clic "rembourser" ne crée jamais deux
//      RefundDoc),
//   4. journaliser l'action (audit_logs),
//   5. déléguer à l'orchestration et renvoyer son résultat tel quel (jamais
//      de recalcul côté fonction callable).
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { db } from "../lib/admin";
import { requireSignedIn, isAdminOrAbove } from "../lib/auth";
import { failedPrecondition, invalidArgument, notFound, permissionDenied } from "../lib/errors";
import { writeAuditLog } from "../lib/audit";
import { PaymentDoc, RefundReason, RefundReasons } from "../lib/types";
import { refundPayment as refundPaymentOrchestration } from "../payment/paymentOrchestration";
import { STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET } from "../lib/secrets";
import {
  logFinancialSuccess,
  resolveCorrelationId,
  startFinancialOperationTimer,
} from "../lib/observability";

export interface RefundPaymentRequest {
  paymentId: string;
  /** Montant à rembourser en cents entiers. Omis/0 => remboursement TOTAL du solde restant. */
  amountMinor?: number;
  reason: RefundReason;
  /**
   * Identifiant stable de la DEMANDE cliente (généré une seule fois côté
   * Flutter au moment du clic, réutilisé lors d'un retry réseau) — permet
   * de construire une requestKey déterministe. Si omis, une clé dérivée de
   * paymentId+amountMinor+reason est utilisée (moins robuste face à deux
   * remboursements partiels légitimes de même montant/motif rapprochés,
   * donc fortement recommandé de le fournir).
   */
  clientRequestId?: string;
}

const VALID_REASONS: string[] = Object.values(RefundReasons);

// 🔒 BUG LIVE-01 (audit Bloc 8B, passage Stripe LIVE) — cette fonction
// appelle réellement Stripe (via `refundPaymentOrchestration` ->
// `provider.refundPayment()`) mais ne déclarait PAS `secrets` dans ses
// options `onCall`. En Cloud Functions v2, un secret Secret Manager n'est
// injecté dans le runtime QUE si la fonction le déclare explicitement — sans
// cette déclaration, `STRIPE_SECRET_KEY.value()` échoue en production même
// avec un secret correctement configuré, ce qui aurait fait échouer
// SILENCIEUSEMENT tout remboursement réel (503 "fournisseur non
// configuré"). Corrigé ICI, avant toute demande de secrets LIVE à Daniel.
export const refundPayment = onCall<RefundPaymentRequest>(
  { secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET] },
  async (request) => {
  const ctx = requireSignedIn(request);
  const { paymentId, reason, clientRequestId } = request.data;
  const amountMinorInput = request.data.amountMinor;

  if (!paymentId) throw invalidArgument("paymentId est requis.");
  if (!reason || !VALID_REASONS.includes(reason)) {
    throw invalidArgument(`reason invalide. Valeurs autorisées: ${VALID_REASONS.join(", ")}.`);
  }
  if (
    amountMinorInput !== undefined &&
    (typeof amountMinorInput !== "number" ||
      !Number.isInteger(amountMinorInput) ||
      amountMinorInput < 0)
  ) {
    throw invalidArgument("amountMinor doit être un entier positif de cents (ou omis pour un remboursement total).");
  }

  const payRef = db.collection("payments").doc(paymentId);
  const paySnap = await payRef.get();
  if (!paySnap.exists) throw notFound(`payments/${paymentId} introuvable.`);
  const payment = paySnap.data() as PaymentDoc;

  const isAdminInitiated = isAdminOrAbove(ctx);
  if (!isAdminInitiated && payment.customer_id !== ctx.uid) {
    throw permissionDenied("Seul le client de ce paiement (ou un administrateur) peut demander un remboursement.");
  }

  // Remboursement total du solde restant si amountMinor omis/0 : calculé
  // ICI pour la requestKey déterministe uniquement — la validation
  // définitive du solde remboursable (contre les refunds concurrents) est
  // refaite dans la transaction Firestore de l'orchestration, jamais fiée
  // à ce calcul pré-transaction.
  const remainingApprox = payment.amount_captured_minor - payment.amount_refunded_minor;
  if (remainingApprox <= 0) {
    throw failedPrecondition("Ce paiement est déjà entièrement remboursé.");
  }
  const amountMinor = amountMinorInput && amountMinorInput > 0 ? amountMinorInput : remainingApprox;

  // 🔒 requestKey déterministe : PAS un id aléatoire régénéré à chaque
  // tentative. Si clientRequestId est fourni (recommandé), il porte toute
  // la déduplication. Sinon, repli sur une clé dérivée des paramètres
  // métier (moins robuste pour des remboursements partiels identiques
  // rapprochés dans le temps, mais déterministe).
  const requestKey = clientRequestId
    ? `refund_${paymentId}_${clientRequestId}`
    : `refund_${paymentId}_${amountMinor}_${reason}`;

  // 🔒 BLOC I — un correlation_id est généré ICI, au point d'entrée le plus
  // externe de ce flux (Cloud Function callable), et propagé jusqu'à
  // l'orchestration (refundPayment() ci-dessous) afin que "refund requested"
  // et "refund success/failure" partagent le MÊME correlation_id.
  const correlationId = resolveCorrelationId(undefined);
  const requestStartedAt = startFinancialOperationTimer();

  await writeAuditLog({
    actorUserId: ctx.uid,
    actorRole: ctx.role ?? (isAdminInitiated ? "admin" : "customer"),
    action: "refund_requested",
    sourceFunction: "refundPayment",
    targetId: paymentId,
    metadata: { amountMinor, reason, isAdminInitiated, requestKey, correlationId },
  });
  logFinancialSuccess(
    "refund_requested",
    requestStartedAt,
    { paymentId },
    { correlationId, metadata: { amountMinor, reason, isAdminInitiated } }
  );

  const outcome = await refundPaymentOrchestration({
    paymentId,
    amountMinor,
    reason,
    initiatedByUserId: ctx.uid,
    initiatedByRole: ctx.role ?? (isAdminInitiated ? "admin" : "customer"),
    isAdminInitiated,
    requestKey,
    correlationId,
  });

  await writeAuditLog({
    actorUserId: ctx.uid,
    actorRole: ctx.role ?? (isAdminInitiated ? "admin" : "customer"),
    action: outcome.success ? "refund_succeeded" : "refund_failed",
    sourceFunction: "refundPayment",
    targetId: paymentId,
    metadata: {
      refundId: outcome.refundId,
      amountMinor,
      status: outcome.status,
      alreadyProcessed: outcome.alreadyProcessed ?? false,
      failureMessage: outcome.failureMessage ?? null,
    },
  });

  return outcome;
  }
);
