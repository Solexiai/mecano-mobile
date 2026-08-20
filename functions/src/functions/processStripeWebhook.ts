// -----------------------------------------------------------------------------
// processStripeWebhook — Endpoint HTTP RÉEL (onRequest) recevant les
// webhooks Stripe signés (Phase 6, directive 38 points, Bloc D / point 11).
//
// EXIGENCES NON NÉGOCIABLES :
//   - signature Stripe-Signature OBLIGATOIRE et vérifiée via
//     `StripeProvider.constructVerifiedEvent()` (stripe.webhooks.constructEvent)
//     sur le RAW BODY (`request.rawBody`, jamais `request.body` reparsé —
//     voir docs.stripe.com/webhooks#verify-events).
//   - AUCUNE confiance dans le payload avant vérification de signature :
//     toute signature absente/invalide => 400 immédiat, aucune écriture.
//   - IDEMPOTENCE stricte sur `event.id` via `provider_webhook_events/{id}`
//     (l'ID Stripe de l'évènement EST l'ID du document — verrou naturel).
//     Un évènement déjà `processed` est ré-accusé 200 SANS ré-exécuter le
//     moindre effet financier (retry-safe : Stripe re-livre parfois le même
//     évènement plusieurs fois).
//   - Chaque évènement traité est audité (`audit_logs`, action
//     `webhook_event_processed` / `webhook_event_failed`).
//   - AUCUNE double écriture financière : le handler ne fait QUE relayer
//     vers les fonctions d'orchestration déjà validées
//     (captureMissionPayment/refundPayment/submitDriverPayout/
//     disputeOrchestration) qui possèdent CHACUNE leur propre idempotence
//     interne (idempotency_key / requestKey / provider_dispute_id comme ID
//     de document) — ce handler ne réimplémente jamais la logique métier.
//
// ÉVÈNEMENTS MINIMAUX SUPPORTÉS (point D du prompt) :
//   payment_intent.succeeded / payment_intent.payment_failed
//   charge.refund.updated (succeeded/failed)
//   payout.paid / payout.failed
//   charge.dispute.created / charge.dispute.updated / charge.dispute.closed
// -----------------------------------------------------------------------------

import { onRequest } from "firebase-functions/v2/https";
import type { Request } from "firebase-functions/v2/https";
import type { Response } from "express";
import Stripe from "stripe";
import { admin, db } from "../lib/admin";
import { writeAuditLog } from "../lib/audit";
import { getPaymentProvider } from "../payment/paymentProviderFactory";
import { StripeProvider } from "../payment/stripeProvider";
import { WebhookProcessingStatuses } from "../lib/types";
import { openDispute, transitionDisputeStatus } from "../payment/disputeOrchestration";
import { DisputeStatuses, DisputeStatus } from "../lib/types";

/**
 * Mappe le statut de litige brut Stripe vers notre `DisputeStatus` interne.
 * Stripe utilise `warning_needs_response|warning_under_review|needs_response
 * |under_review|charge_refunded|won|lost` — on ne garde QUE les valeurs
 * pertinentes pour notre machine d'état (opened/under_review/won/lost).
 * Toute valeur non reconnue est journalisée et IGNORÉE (jamais une
 * transition inventée).
 */
function mapStripeDisputeStatus(stripeStatus: string): DisputeStatus | null {
  switch (stripeStatus) {
    case "warning_needs_response":
    case "needs_response":
      return DisputeStatuses.OPENED;
    case "warning_under_review":
    case "under_review":
      return DisputeStatuses.UNDER_REVIEW;
    case "won":
      return DisputeStatuses.WON;
    case "lost":
      return DisputeStatuses.LOST;
    default:
      return null;
  }
}

/**
 * Traite un évènement Stripe déjà VÉRIFIÉ (signature valide). Retourne les
 * identifiants liés pour traçabilité dans `provider_webhook_events`.
 * Toute exception ici est capturée par l'appelant, qui marque l'évènement
 * `failed` (jamais `processed`) — permet un retry Stripe ultérieur.
 */
async function dispatchStripeEvent(event: Stripe.Event): Promise<{
  relatedPaymentId: string | null;
  relatedPayoutId: string | null;
  relatedRefundId: string | null;
  relatedDisputeId: string | null;
  relatedMissionId: string | null;
}> {
  let relatedPaymentId: string | null = null;
  let relatedPayoutId: string | null = null;
  let relatedRefundId: string | null = null;
  let relatedDisputeId: string | null = null;
  let relatedMissionId: string | null = null;

  switch (event.type) {
    // ---- Paiement : autorisation/capture réussie ou échouée ----
    case "payment_intent.succeeded":
    case "payment_intent.payment_failed": {
      const intent = event.data.object as Stripe.PaymentIntent;
      const paySnap = await db
        .collection("payments")
        .where("provider_payment_intent_id", "==", intent.id)
        .limit(1)
        .get();
      if (!paySnap.empty) {
        const doc = paySnap.docs[0];
        relatedPaymentId = doc.id;
        relatedMissionId = (doc.data().mission_id as string) ?? null;
        // 🔒 Le webhook ne fait qu'ENREGISTRER/CONFIRMER l'état déjà obtenu
        // par l'appel synchrone (authorizePayment/capturePayment déjà
        // exécutés par createAndAuthorizeMissionPayment/captureMissionPayment).
        // Il ne réexécute JAMAIS capturePayment lui-même — il journalise
        // uniquement la confirmation provider pour audit/réconciliation.
        await writeAuditLog({
          actorUserId: "system",
          actorRole: "system",
          action: event.type === "payment_intent.succeeded" ? "payment_captured" : "payment_failed",
          sourceFunction: "processStripeWebhook",
          targetId: doc.id,
          metadata: { providerPaymentIntentId: intent.id, eventType: event.type },
        });
      }
      break;
    }

    // ---- Refund : confirmation succès/échec côté provider ----
    case "charge.refund.updated":
    case "refund.updated": {
      const refundObj = event.data.object as Stripe.Refund;
      const providerPaymentIntentId =
        typeof refundObj.payment_intent === "string"
          ? refundObj.payment_intent
          : refundObj.payment_intent?.id ?? null;
      if (providerPaymentIntentId) {
        const paySnap = await db
          .collection("payments")
          .where("provider_payment_intent_id", "==", providerPaymentIntentId)
          .limit(1)
          .get();
        if (!paySnap.empty) {
          relatedPaymentId = paySnap.docs[0].id;
          relatedMissionId = (paySnap.docs[0].data().mission_id as string) ?? null;
        }
      }
      const refundSnap = await db
        .collection("refunds")
        .where("provider_refund_id", "==", refundObj.id)
        .limit(1)
        .get();
      if (!refundSnap.empty) relatedRefundId = refundSnap.docs[0].id;

      // 🔒 Comme pour le paiement : le refund réel a déjà été déclenché par
      // `refundPayment()` (Cloud Function callable), qui applique lui-même
      // SUCCEEDED|FAILED de façon idempotente via son idempotency_key. Ce
      // webhook ne fait que confirmer/journaliser — jamais de second appel
      // provider.refundPayment().
      await writeAuditLog({
        actorUserId: "system",
        actorRole: "system",
        action: refundObj.status === "succeeded" ? "refund_succeeded" : "refund_failed",
        sourceFunction: "processStripeWebhook",
        targetId: relatedRefundId ?? refundObj.id,
        metadata: { providerRefundId: refundObj.id, status: refundObj.status },
      });
      break;
    }

    // ---- Payout : succès/échec du versement chauffeur ----
    case "payout.paid":
    case "payout.failed": {
      const payout = event.data.object as Stripe.Payout;
      const payoutSnap = await db
        .collection("driver_payouts")
        .where("provider_payout_id", "==", payout.id)
        .limit(1)
        .get();
      if (!payoutSnap.empty) {
        relatedPayoutId = payoutSnap.docs[0].id;
      }
      // 🔒 Le versement réel est déclenché par `submitDriverPayout()`
      // (paymentOrchestration.ts), qui applique déjà PAID|FAILED de façon
      // idempotente. Ce webhook journalise uniquement la confirmation
      // provider — utile en cas de payout FAILED asynchrone après un
      // succès apparent immédiat (ex: compte bancaire invalide découvert
      // après coup côté banque du chauffeur).
      await writeAuditLog({
        actorUserId: "system",
        actorRole: "system",
        action: event.type === "payout.paid" ? "payout_paid" : "payout_failed",
        sourceFunction: "processStripeWebhook",
        targetId: relatedPayoutId ?? payout.id,
        metadata: { providerPayoutId: payout.id, status: payout.status },
      });
      break;
    }

    // ---- Dispute / chargeback : ouverture, mise à jour, clôture ----
    case "charge.dispute.created": {
      const dispute = event.data.object as Stripe.Dispute;
      const chargeId = typeof dispute.charge === "string" ? dispute.charge : dispute.charge.id;
      const paySnap = await db
        .collection("payments")
        .where("provider_charge_id", "==", chargeId)
        .limit(1)
        .get();
      if (paySnap.empty) {
        throw new Error(`Aucun payment trouvé pour provider_charge_id=${chargeId} (dispute ${dispute.id}).`);
      }
      const paymentId = paySnap.docs[0].id;
      relatedPaymentId = paymentId;
      relatedMissionId = (paySnap.docs[0].data().mission_id as string) ?? null;

      const outcome = await openDispute({
        providerDisputeId: dispute.id,
        paymentId,
        amountMinor: dispute.amount,
        reason: dispute.reason ?? "unknown",
        evidenceDueAt: dispute.evidence_details?.due_by
          ? new Date(dispute.evidence_details.due_by * 1000)
          : null,
        providerMetadata: {
          network_reason_code: dispute.network_reason_code ?? null,
          status: dispute.status,
        },
      });
      relatedDisputeId = outcome.disputeId;
      break;
    }

    case "charge.dispute.updated":
    case "charge.dispute.closed": {
      const dispute = event.data.object as Stripe.Dispute;
      relatedDisputeId = dispute.id;
      const mappedStatus = mapStripeDisputeStatus(dispute.status);
      if (mappedStatus) {
        // 🔒 transitionDisputeStatus() est déjà idempotente sur une
        // self-transition (dispute.status === newStatus => skipped=true,
        // aucun effet dupliqué) — on peut donc l'appeler sans risque même
        // si un webhook "updated" précédent a déjà appliqué ce même statut.
        const outcome = await transitionDisputeStatus({
          disputeId: dispute.id,
          newStatus: mappedStatus,
        });
        relatedDisputeId = outcome.disputeId;
      }
      if (event.type === "charge.dispute.closed") {
        // 🔒 BUG CORRIGÉ : Stripe envoie `charge.dispute.closed` avec le
        // statut FINAL déjà positionné (won/lost) — le mappedStatus
        // ci-dessus vient donc de faire OPENED/UNDER_REVIEW -> WON|LOST
        // (ou était déjà à ce statut). Il faut ENCORE appliquer la
        // clôture administrative WON|LOST -> CLOSED (disputeStateMachine.ts)
        // dans le MÊME évènement, jamais seulement quand mappedStatus est
        // null. Idempotent : transitionDisputeStatus() no-op proprement si
        // déjà CLOSED (self-transition), et lève une erreur explicite
        // uniquement si le litige n'a pas encore atteint WON/LOST/REVERSED
        // (impossible en pratique côté Stripe, mais on lit l'état réel
        // plutôt que de supposer).
        const disputeSnap = await db.collection("disputes").doc(dispute.id).get();
        if (disputeSnap.exists) {
          const currentStatus = disputeSnap.data()?.status as DisputeStatus;
          if (
            currentStatus === DisputeStatuses.WON ||
            currentStatus === DisputeStatuses.LOST ||
            currentStatus === DisputeStatuses.REVERSED
          ) {
            const outcome = await transitionDisputeStatus({
              disputeId: dispute.id,
              newStatus: DisputeStatuses.CLOSED,
            });
            relatedDisputeId = outcome.disputeId;
          }
        }
      }
      break;
    }

    default:
      // Évènement reçu mais non couvert par notre dispatch minimal — pas
      // une erreur : accusé réception (`ignored`), aucun effet.
      break;
  }

  return { relatedPaymentId, relatedPayoutId, relatedRefundId, relatedDisputeId, relatedMissionId };
}

export const processStripeWebhook = onRequest(
  { secrets: ["STRIPE_SECRET_KEY", "STRIPE_WEBHOOK_SECRET"] },
  async (request: Request, response: Response) => {
    // ---- 1. Signature obligatoire, sur le RAW BODY exclusivement ----
    const signatureHeader = request.headers["stripe-signature"];
    if (!signatureHeader || typeof signatureHeader !== "string") {
      response.status(400).send("Signature Stripe-Signature manquante.");
      return;
    }

    const provider = getPaymentProvider();
    if (!(provider instanceof StripeProvider)) {
      // Fournisseur non configuré (pas de STRIPE_SECRET_KEY) — échec
      // explicite, jamais de simulation silencieuse d'un traitement réussi.
      response.status(503).send("Fournisseur de paiement non configuré.");
      return;
    }

    let event: Stripe.Event;
    try {
      event = provider.constructVerifiedEvent(request.rawBody, signatureHeader);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      response.status(400).send(`Signature invalide: ${message}`);
      return;
    }

    // ---- 2. Idempotence : registre provider_webhook_events/{event.id} ----
    const eventRef = db.collection("provider_webhook_events").doc(event.id);
    const now = admin.firestore.Timestamp.now();

    // get-or-create atomique : si déjà `processed`, on accuse réception
    // SANS ré-exécuter le moindre effet (retry-safe, exactement-une-fois
    // du point de vue des effets financiers).
    const acquireResult = await db.runTransaction(async (tx) => {
      const snap = await tx.get(eventRef);
      if (snap.exists) {
        const data = snap.data()!;
        if (data.processing_status === WebhookProcessingStatuses.PROCESSED) {
          return { alreadyProcessed: true as const };
        }
        // received/failed : on retente (compteur d'essais incrémenté),
        // jamais une nouvelle écriture financière DUPLIQUÉE puisque le
        // dispatch lui-même délègue à des opérations idempotentes.
        tx.update(eventRef, {
          attempt_count: admin.firestore.FieldValue.increment(1),
          processing_attempts: admin.firestore.FieldValue.increment(1),
          received_at: now,
        });
        return { alreadyProcessed: false as const };
      }
      tx.set(eventRef, {
        provider: "stripe",
        provider_event_id: event.id,
        event_type: event.type,
        received_at: now,
        processed_at: null,
        processing_status: WebhookProcessingStatuses.RECEIVED,
        attempt_count: 1,
        processing_attempts: 1,
        last_error: null,
        error_code: null,
        related_payment_id: null,
        related_payout_id: null,
        related_refund_id: null,
        related_dispute_id: null,
        related_mission_id: null,
      });
      return { alreadyProcessed: false as const };
    });

    if (acquireResult.alreadyProcessed) {
      response.status(200).send({ received: true, alreadyProcessed: true });
      return;
    }

    // ---- 3. Dispatch métier (délégation aux orchestrations idempotentes) ----
    const startedAt = Date.now();
    try {
      const related = await dispatchStripeEvent(event);
      const durationMs = Date.now() - startedAt;

      await eventRef.update({
        processing_status: WebhookProcessingStatuses.PROCESSED,
        processed_at: admin.firestore.Timestamp.now(),
        related_payment_id: related.relatedPaymentId,
        related_payout_id: related.relatedPayoutId,
        related_refund_id: related.relatedRefundId,
        related_dispute_id: related.relatedDisputeId,
        related_mission_id: related.relatedMissionId,
        last_error: null,
        error_code: null,
      });

      await writeAuditLog({
        actorUserId: "system",
        actorRole: "system",
        action: "webhook_event_processed",
        sourceFunction: "processStripeWebhook",
        targetId: event.id,
        metadata: {
          eventType: event.type,
          correlationId: event.id,
          operation: "processStripeWebhook",
          result: "success",
          durationMs,
          ...related,
        },
      });

      response.status(200).send({ received: true });
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      const durationMs = Date.now() - startedAt;

      await eventRef.update({
        processing_status: WebhookProcessingStatuses.FAILED,
        last_error: message,
        error_code: "webhook_dispatch_failed",
      });

      await writeAuditLog({
        actorUserId: "system",
        actorRole: "system",
        action: "webhook_event_failed",
        sourceFunction: "processStripeWebhook",
        targetId: event.id,
        metadata: {
          eventType: event.type,
          correlationId: event.id,
          operation: "processStripeWebhook",
          result: "failure",
          durationMs,
          errorCode: "webhook_dispatch_failed",
          errorMessage: message,
        },
      });

      // 🔒 500 explicite => Stripe RETENTE automatiquement cet évènement
      // (comportement standard webhooks Stripe sur échec serveur). Le
      // registre `provider_webhook_events` reste en `failed`, permettant
      // au prochain essai de repasser par le même chemin (retry-safe).
      response.status(500).send({ received: false, error: message });
    }
  }
);
