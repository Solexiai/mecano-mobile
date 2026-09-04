// -----------------------------------------------------------------------------
// processStripeWebhook / processStripeConnectWebhook — Endpoints HTTP RÉELS
// (onRequest) recevant les webhooks Stripe signés (Phase 6, directive 38
// points, Bloc D / point 11 ; scindés en 2 endpoints au Bloc 8B LIVE, voir
// docs/PAYMENT_ARCHITECTURE.md §10.9 "BLOQUEUR WEBHOOK PRODUCTION").
//
// 🔒 POURQUOI DEUX ENDPOINTS (Bloc 8B LIVE) :
// docs.stripe.com/connect/webhooks documente que chaque endpoint webhook
// Stripe est scopé EXCLUSIVEMENT à "Your account" (événements PLATEFORME) OU
// "Connected accounts" (événements sur un compte CONNECTÉ) — jamais les deux
// à la fois dans un seul endpoint (paramètre API `connect: false|true`,
// sélecteur "Events from" dans Workbench). Chaque endpoint a SON PROPRE
// secret de signature `whsec_...`. Movi-K a besoin des deux scopes :
//   - `processStripeWebhook` (ce fichier, endpoint "Your account") :
//     9 événements PLATEFORME (payment_intent.*, charge.refund.updated,
//     refund.updated, payout.*, charge.dispute.*) — vérifiés avec
//     `STRIPE_PLATFORM_WEBHOOK_SECRET`.
//   - `processStripeConnectWebhook` (ce fichier, endpoint "Connected
//     accounts") : `account.updated` uniquement — vérifié avec
//     `STRIPE_CONNECT_WEBHOOK_SECRET`.
// Les DEUX endpoints appellent le MÊME `dispatchStripeEvent()` ci-dessous
// (logique métier factorisée, JAMAIS dupliquée) — seule la vérification de
// signature (secret utilisé) et le nom source d'audit diffèrent.
//
// EXIGENCES NON NÉGOCIABLES (inchangées, s'appliquent aux DEUX endpoints) :
//   - signature Stripe-Signature OBLIGATOIRE et vérifiée via
//     `StripeProvider.constructVerifiedEvent()` (stripe.webhooks.constructEvent)
//     sur le RAW BODY (`request.rawBody`, jamais `request.body` reparsé —
//     voir docs.stripe.com/webhooks#verify-events), avec le secret PROPRE à
//     l'endpoint qui reçoit la requête (jamais le secret de l'autre endpoint).
//   - AUCUNE confiance dans le payload avant vérification de signature :
//     toute signature absente/invalide => 400 immédiat, aucune écriture.
//   - IDEMPOTENCE stricte sur `event.id` via `provider_webhook_events/{id}`
//     (l'ID Stripe de l'évènement EST l'ID du document — verrou naturel,
//     PARTAGÉ entre les deux endpoints : un `event.id` Stripe est unique
//     tous endpoints confondus). Un évènement déjà `processed` est
//     ré-accusé 200 SANS ré-exécuter le moindre effet financier (retry-safe :
//     Stripe re-livre parfois le même évènement plusieurs fois).
//   - Chaque évènement traité est audité (`audit_logs`, action
//     `webhook_event_processed` / `webhook_event_failed`), avec
//     `sourceFunction` distinguant `processStripeWebhook` vs
//     `processStripeConnectWebhook` pour traçabilité.
//   - AUCUNE double écriture financière : le handler ne fait QUE relayer
//     vers les fonctions d'orchestration déjà validées
//     (captureMissionPayment/refundPayment/submitDriverPayout/
//     disputeOrchestration) qui possèdent CHACUNE leur propre idempotence
//     interne (idempotency_key / requestKey / provider_dispute_id comme ID
//     de document) — ce handler ne réimplémente jamais la logique métier.
//
// ÉVÈNEMENTS SUPPORTÉS :
//   processStripeWebhook (plateforme) :
//     payment_intent.succeeded / payment_intent.payment_failed
//     charge.refund.updated (succeeded/failed) / refund.updated
//     payout.paid / payout.failed
//     charge.dispute.created / charge.dispute.updated / charge.dispute.closed
//   processStripeConnectWebhook (Connected accounts) :
//     account.updated
// -----------------------------------------------------------------------------

import { onRequest } from "firebase-functions/v2/https";
import type { Request } from "firebase-functions/v2/https";
import type { Response } from "express";
import Stripe from "stripe";
import { admin, db } from "../lib/admin";
import { writeAuditLog } from "../lib/audit";
import { getPaymentProvider } from "../payment/paymentProviderFactory";
import { StripeProvider } from "../payment/stripeProvider";
import { DriverProfileDoc, WebhookProcessingStatuses } from "../lib/types";
import { openDispute, transitionDisputeStatus } from "../payment/disputeOrchestration";
import { DisputeStatuses, DisputeStatus } from "../lib/types";
import {
  logFinancialFailure,
  logFinancialSuccess,
  startFinancialOperationTimer,
} from "../lib/observability";
import {
  isWebhookLivemodeConsistent,
  STRIPE_WEBHOOK_LIVEMODE_MISMATCH_ERROR_CODE,
} from "../lib/stripeEnvironment";
import {
  STRIPE_CONNECT_WEBHOOK_SECRET,
  STRIPE_PLATFORM_WEBHOOK_SECRET,
  STRIPE_SECRET_KEY,
} from "../lib/secrets";

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
 *
 * `sourceFunctionName` est propagé jusqu'aux `writeAuditLog()` internes
 * (payment_captured/failed, refund_succeeded/failed, payout_paid/failed,
 * driver_stripe_account_status_synced) afin que `audit_logs.source_function`
 * reflète TOUJOURS l'endpoint HTTP réel qui a reçu la requête Stripe
 * (`processStripeWebhook` plateforme ou `processStripeConnectWebhook`),
 * jamais une valeur littérale figée — essentiel pour la traçabilité une fois
 * les deux endpoints déployés (voir docs/PAYMENT_ARCHITECTURE.md §10.9).
 */
async function dispatchStripeEvent(
  event: Stripe.Event,
  sourceFunctionName: "processStripeWebhook" | "processStripeConnectWebhook"
): Promise<{
  relatedPaymentId: string | null;
  relatedPayoutId: string | null;
  relatedRefundId: string | null;
  relatedDisputeId: string | null;
  relatedMissionId: string | null;
  relatedDriverId: string | null;
}> {
  let relatedPaymentId: string | null = null;
  let relatedPayoutId: string | null = null;
  let relatedRefundId: string | null = null;
  let relatedDisputeId: string | null = null;
  let relatedMissionId: string | null = null;
  let relatedDriverId: string | null = null;

  switch (event.type) {
    // ---- Paiement : autorisation/capture réussie ou échouée ----
    case "payment_intent.succeeded":
    case "payment_intent.payment_failed": {
      const branchStartedAt = startFinancialOperationTimer();
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
        const isSucceeded = event.type === "payment_intent.succeeded";
        // 🔒 Le webhook ne fait qu'ENREGISTRER/CONFIRMER l'état déjà obtenu
        // par l'appel synchrone (authorizePayment/capturePayment déjà
        // exécutés par createAndAuthorizeMissionPayment/captureMissionPayment).
        // Il ne réexécute JAMAIS capturePayment lui-même — il journalise
        // uniquement la confirmation provider pour audit/réconciliation.
        await writeAuditLog({
          actorUserId: "system",
          actorRole: "system",
          action: isSucceeded ? "payment_captured" : "payment_failed",
          sourceFunction: sourceFunctionName,
          targetId: doc.id,
          metadata: { providerPaymentIntentId: intent.id, eventType: event.type },
        });
        // 🔒 BLOC I (observabilité) — event.id (provider_event_id) sert de
        // correlation ID métier pour ce webhook, cohérent avec le log
        // principal `stripe_webhook_processing` ci-dessous.
        if (isSucceeded) {
          logFinancialSuccess(
            "payment_captured",
            branchStartedAt,
            { missionId: relatedMissionId, paymentId: doc.id, providerEventId: event.id },
            { correlationId: event.id, metadata: { eventType: event.type } }
          );
        } else {
          logFinancialFailure(
            "payment_failed",
            branchStartedAt,
            "provider_payment_failed",
            { missionId: relatedMissionId, paymentId: doc.id, providerEventId: event.id },
            { correlationId: event.id, metadata: { eventType: event.type } }
          );
        }
      }
      break;
    }

    // ---- Refund : confirmation succès/échec côté provider ----
    case "charge.refund.updated":
    case "refund.updated": {
      const branchStartedAt = startFinancialOperationTimer();
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
        sourceFunction: sourceFunctionName,
        targetId: relatedRefundId ?? refundObj.id,
        metadata: { providerRefundId: refundObj.id, status: refundObj.status },
      });
      if (refundObj.status === "succeeded") {
        logFinancialSuccess(
          "refund_succeeded",
          branchStartedAt,
          {
            missionId: relatedMissionId,
            paymentId: relatedPaymentId,
            refundId: relatedRefundId,
            providerEventId: event.id,
          },
          { correlationId: event.id, metadata: { eventType: event.type } }
        );
      } else {
        logFinancialFailure(
          "refund_failed",
          branchStartedAt,
          "provider_refund_failed",
          {
            missionId: relatedMissionId,
            paymentId: relatedPaymentId,
            refundId: relatedRefundId,
            providerEventId: event.id,
          },
          { correlationId: event.id, metadata: { eventType: event.type, status: refundObj.status } }
        );
      }
      break;
    }

    // ---- Payout : succès/échec du versement chauffeur ----
    case "payout.paid":
    case "payout.failed": {
      const branchStartedAt = startFinancialOperationTimer();
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
        sourceFunction: sourceFunctionName,
        targetId: relatedPayoutId ?? payout.id,
        metadata: { providerPayoutId: payout.id, status: payout.status },
      });
      if (event.type === "payout.paid") {
        logFinancialSuccess(
          "payout_paid",
          branchStartedAt,
          { payoutId: relatedPayoutId, providerEventId: event.id },
          { correlationId: event.id, metadata: { eventType: event.type } }
        );
      } else {
        logFinancialFailure(
          "payout_failed",
          branchStartedAt,
          "provider_payout_failed",
          { payoutId: relatedPayoutId, providerEventId: event.id },
          { correlationId: event.id, metadata: { eventType: event.type, status: payout.status } }
        );
      }
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

    // ---- Connect : synchronisation statut onboarding compte chauffeur ----
    case "account.updated": {
      // 🔒 GAP-8B-01 (Bloc 8B, comblé cette session) : sans ce handler,
      // `driver_profiles.stripe_charges_enabled`/`stripe_payouts_enabled`
      // restaient figés à `false` pour toujours après `createDriverStripeAccount`
      // (aucun autre code ne les mettait à jour) — l'admin ne pouvait JAMAIS
      // voir qu'un chauffeur avait réellement complété son onboarding Stripe
      // hébergé. Les payouts eux-mêmes ne dépendent QUE de
      // `stripe_connected_account_id` (voir calculateDriverPayout.ts /
      // paymentOrchestration.ts) — ce n'était donc pas un bloqueur fonctionnel
      // des versements, mais une donnée d'état trompeuse pour l'admin/support.
      const branchStartedAt = startFinancialOperationTimer();
      const account = event.data.object as Stripe.Account;
      const driverId = (account.metadata?.movik_driver_id as string | undefined) ?? null;

      if (driverId) {
        const driverRef = db.collection("driver_profiles").doc(driverId);
        const driverSnap = await driverRef.get();
        if (driverSnap.exists) {
          const driver = driverSnap.data() as DriverProfileDoc;
          // 🔒 Ne met à jour QUE si ce compte Stripe est bien celui déjà
          // enregistré pour ce chauffeur (défense contre un metadata
          // falsifié/obsolète pointant vers le mauvais profil).
          if (driver.stripe_connected_account_id === account.id) {
            relatedDriverId = driverId;
            const chargesEnabled = account.charges_enabled === true;
            const payoutsEnabled = account.payouts_enabled === true;
            if (
              driver.stripe_charges_enabled !== chargesEnabled ||
              driver.stripe_payouts_enabled !== payoutsEnabled
            ) {
              await driverRef.update({
                stripe_charges_enabled: chargesEnabled,
                stripe_payouts_enabled: payoutsEnabled,
                updated_at: admin.firestore.FieldValue.serverTimestamp(),
              });
              await writeAuditLog({
                actorUserId: "system",
                actorRole: "system",
                action: "driver_stripe_account_status_synced",
                sourceFunction: sourceFunctionName,
                targetId: driverId,
                metadata: {
                  connectedAccountId: account.id,
                  chargesEnabled,
                  payoutsEnabled,
                  previousChargesEnabled: driver.stripe_charges_enabled ?? false,
                  previousPayoutsEnabled: driver.stripe_payouts_enabled ?? false,
                },
              });
              logFinancialSuccess(
                "driver_stripe_account_status_synced",
                branchStartedAt,
                { providerEventId: event.id },
                {
                  correlationId: event.id,
                  metadata: { driverId, connectedAccountId: account.id, chargesEnabled, payoutsEnabled },
                }
              );
            }
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

  return {
    relatedPaymentId,
    relatedPayoutId,
    relatedRefundId,
    relatedDisputeId,
    relatedMissionId,
    relatedDriverId,
  };
}

/**
 * Fabrique un handler `onRequest` webhook Stripe générique, partagé par
 * `processStripeWebhook` (plateforme) et `processStripeConnectWebhook`
 * (Connected accounts). SEULE différence entre les deux endpoints : le
 * secret utilisé pour vérifier la signature (`webhookSecretValue`, propre à
 * CET endpoint — jamais celui de l'autre) et le nom source d'audit
 * (`sourceFunctionName`, pour distinguer les deux dans `audit_logs`). La
 * logique métier (`dispatchStripeEvent`) et l'idempotence
 * (`provider_webhook_events/{event.id}`) sont 100% PARTAGÉES — aucune
 * duplication (voir bloc de commentaire en tête de fichier).
 */
function buildStripeWebhookHandler(
  sourceFunctionName: "processStripeWebhook" | "processStripeConnectWebhook",
  getWebhookSecretValue: () => string
): (request: Request, response: Response) => Promise<void> {
  return async (request: Request, response: Response) => {
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
      // 🔒 Secret PROPRE à cet endpoint (voir bloc de commentaire en tête de
      // fichier) — jamais le secret legacy `STRIPE_WEBHOOK_SECRET`, jamais
      // celui de l'AUTRE endpoint webhook.
      event = provider.constructVerifiedEvent(
        request.rawBody,
        signatureHeader,
        getWebhookSecretValue()
      );
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      response.status(400).send(`Signature invalide: ${message}`);
      return;
    }

    // ---- 1bis. Défense-en-profondeur : event.livemode ↔ environnement actif ----
    // 🔒 Ne remplace JAMAIS la vérification de signature ci-dessus (déjà
    // effectuée) — `event.livemode` est un champ natif Stripe authentifié
    // PAR CETTE MÊME signature. Ce contrôle détecte une incohérence
    // OPÉRATIONNELLE (endpoint webhook mal configuré côté Dashboard Stripe,
    // replay manuel depuis le mauvais mode, transition de clé mal
    // séquencée) : un évènement authentiquement signé mais appartenant au
    // MAUVAIS mode (test reçu alors que Movi-K tourne en live, ou
    // l'inverse) ne doit JAMAIS déclencher la moindre logique métier ni la
    // moindre écriture financière — voir isWebhookLivemodeConsistent()
    // dans lib/stripeEnvironment.ts pour le détail de la justification.
    if (!isWebhookLivemodeConsistent({ activeEnvironment: provider.environment, eventLivemode: event.livemode })) {
      const startedAtMismatch = Date.now();
      const mismatchMessage =
        `Évènement Stripe livemode=${event.livemode} reçu alors que l'environnement actif est ` +
        `"${provider.environment}" — évènement IGNORÉ, aucune logique métier exécutée.`;

      // Enregistré (registre PARTAGÉ, verrou naturel sur event.id) avec un
      // statut IGNORED — ni PROCESSED (aucun effet métier n'a eu lieu, ne
      // doit jamais être confondu avec un traitement réussi), ni FAILED
      // (qui inviterait Stripe à RETENTER indéfiniment un évènement dont le
      // mismatch structurel ne sera JAMAIS résolu par un nouvel essai —
      // voir doc processStripeWebhook.ts §HTTP retry semantics). Écriture
      // idempotente : un retry Stripe sur le même event.id retombe ici et
      // ré-accuse simplement réception sans dupliquer l'audit ci-dessous.
      const mismatchEventRef = db.collection("provider_webhook_events").doc(event.id);
      const mismatchSnap = await mismatchEventRef.get();
      if (!mismatchSnap.exists) {
        await mismatchEventRef.set({
          provider: "stripe",
          provider_event_id: event.id,
          event_type: event.type,
          received_at: admin.firestore.Timestamp.now(),
          processed_at: null,
          processing_status: WebhookProcessingStatuses.IGNORED,
          attempt_count: 1,
          processing_attempts: 1,
          last_error: mismatchMessage,
          error_code: STRIPE_WEBHOOK_LIVEMODE_MISMATCH_ERROR_CODE,
          related_payment_id: null,
          related_payout_id: null,
          related_refund_id: null,
          related_dispute_id: null,
          related_mission_id: null,
          related_driver_id: null,
        });

        await writeAuditLog({
          actorUserId: "system",
          actorRole: "system",
          action: "webhook_livemode_mismatch",
          sourceFunction: sourceFunctionName,
          targetId: event.id,
          metadata: {
            eventType: event.type,
            correlationId: event.id,
            operation: sourceFunctionName,
            result: "ignored",
            errorCode: STRIPE_WEBHOOK_LIVEMODE_MISMATCH_ERROR_CODE,
            eventLivemode: event.livemode,
            activeEnvironment: provider.environment,
          },
        });

        // 🔒 BLOC I (observabilité) — sévérité ERROR : une incohérence
        // livemode est une anomalie CRITIQUE de configuration, jamais un
        // évènement métier ordinaire à ignorer silencieusement.
        logFinancialFailure(
          "stripe_webhook_livemode_check",
          startedAtMismatch,
          STRIPE_WEBHOOK_LIVEMODE_MISMATCH_ERROR_CODE,
          { providerEventId: event.id },
          {
            correlationId: event.id,
            message: mismatchMessage,
            metadata: {
              eventType: event.type,
              sourceFunction: sourceFunctionName,
              eventLivemode: event.livemode,
              activeEnvironment: provider.environment,
            },
          }
        );
      }

      // 🔒 200 explicite (jamais 500) : Stripe considère 2xx comme un
      // accusé de réception définitif et n'effectue AUCUN retry. Un
      // mismatch structurel event.livemode ↔ environnement actif ne sera
      // JAMAIS résolu par un nouvel essai — répondre 500 ici créerait une
      // boucle de retries infinie et inutile (violerait explicitement
      // l'exigence "comportement HTTP évitant une boucle infinie de
      // retries").
      response.status(200).send({ received: true, ignored: true, reason: "livemode_mismatch" });
      return;
    }

    // ---- 2. Idempotence : registre provider_webhook_events/{event.id} ----
    // Partagé entre les deux endpoints — un `event.id` Stripe est unique
    // tous endpoints confondus, aucun risque de collision entre plateforme
    // et Connect.
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
        related_driver_id: null,
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
      const related = await dispatchStripeEvent(event, sourceFunctionName);
      const durationMs = Date.now() - startedAt;

      await eventRef.update({
        processing_status: WebhookProcessingStatuses.PROCESSED,
        processed_at: admin.firestore.Timestamp.now(),
        related_payment_id: related.relatedPaymentId,
        related_payout_id: related.relatedPayoutId,
        related_refund_id: related.relatedRefundId,
        related_dispute_id: related.relatedDisputeId,
        related_mission_id: related.relatedMissionId,
        related_driver_id: related.relatedDriverId,
        last_error: null,
        error_code: null,
      });

      await writeAuditLog({
        actorUserId: "system",
        actorRole: "system",
        action: "webhook_event_processed",
        sourceFunction: sourceFunctionName,
        targetId: event.id,
        metadata: {
          eventType: event.type,
          correlationId: event.id,
          operation: sourceFunctionName,
          result: "success",
          durationMs,
          ...related,
        },
      });

      // 🔒 BLOC I (observabilité) — log de synthèse TOUJOURS émis pour
      // reconstruire : webhook reçu -> event vérifié -> opération métier
      // exécutée -> résultat. `provider_event_id` (event.id) sert de
      // correlation ID métier principal, cohérent avec les logs de
      // branche déjà émis dans dispatchStripeEvent() (payment_captured,
      // refund_succeeded, payout_paid, dispute_*, etc.) et avec l'audit
      // `writeAuditLog` ci-dessus (déjà en place, non modifié).
      logFinancialSuccess(
        "stripe_webhook_processing",
        startedAt,
        {
          providerEventId: event.id,
          missionId: related.relatedMissionId,
          paymentId: related.relatedPaymentId,
          refundId: related.relatedRefundId,
          payoutId: related.relatedPayoutId,
          disputeId: related.relatedDisputeId,
        },
        { correlationId: event.id, metadata: { eventType: event.type, sourceFunction: sourceFunctionName } }
      );

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
        sourceFunction: sourceFunctionName,
        targetId: event.id,
        metadata: {
          eventType: event.type,
          correlationId: event.id,
          operation: sourceFunctionName,
          result: "failure",
          durationMs,
          errorCode: "webhook_dispatch_failed",
          errorMessage: message,
        },
      });

      // 🔒 BLOC I (observabilité) — même schéma que la branche succès :
      // le correlation ID reste event.id même en échec, pour permettre
      // de retrouver TOUS les logs (branches + synthèse) d'un même
      // évènement Stripe, y compris à travers des retries.
      logFinancialFailure(
        "stripe_webhook_processing",
        startedAt,
        "webhook_dispatch_failed",
        { providerEventId: event.id },
        {
          correlationId: event.id,
          message,
          metadata: { eventType: event.type, sourceFunction: sourceFunctionName },
        }
      );

      // 🔒 500 explicite => Stripe RETENTE automatiquement cet évènement
      // (comportement standard webhooks Stripe sur échec serveur). Le
      // registre `provider_webhook_events` reste en `failed`, permettant
      // au prochain essai de repasser par le même chemin (retry-safe).
      response.status(500).send({ received: false, error: message });
    }
  };
}

// -----------------------------------------------------------------------------
// Endpoint PLATEFORME ("Your account" dans Stripe Workbench/API
// `connect: false`) — reçoit les 9 événements plateforme. Secret dédié :
// `STRIPE_PLATFORM_WEBHOOK_SECRET`.
// -----------------------------------------------------------------------------
export const processStripeWebhook = onRequest(
  { secrets: [STRIPE_SECRET_KEY, STRIPE_PLATFORM_WEBHOOK_SECRET] },
  buildStripeWebhookHandler("processStripeWebhook", () => STRIPE_PLATFORM_WEBHOOK_SECRET.value())
);

// -----------------------------------------------------------------------------
// Endpoint CONNECT ("Connected accounts" dans Stripe Workbench/API
// `connect: true`) — reçoit UNIQUEMENT `account.updated` (voir
// dispatchStripeEvent, case "account.updated" — logique INCHANGÉE, partagée
// avec l'endpoint plateforme). Secret dédié : `STRIPE_CONNECT_WEBHOOK_SECRET`.
// -----------------------------------------------------------------------------
export const processStripeConnectWebhook = onRequest(
  { secrets: [STRIPE_SECRET_KEY, STRIPE_CONNECT_WEBHOOK_SECRET] },
  buildStripeWebhookHandler("processStripeConnectWebhook", () => STRIPE_CONNECT_WEBHOOK_SECRET.value())
);
