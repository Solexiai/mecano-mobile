// ---------------------------------------------------------------------------
// Test d'intégration E2E — BLOC S (Phase 6, directive 38 points) : CYCLE
// DISPUTE / CHARGEBACK COMPLET, en utilisant EXCLUSIVEMENT le vrai endpoint
// webhook Stripe SIGNÉ (`processStripeWebhook`, réellement vérifié via
// `StripeProvider.constructVerifiedEvent()`, comme déjà validé de façon
// unitaire par `processStripeWebhook.test.ts`) et la vraie orchestration de
// litige (`disputeOrchestration.ts` via `openDispute`/`transitionDisputeStatus`,
// déclenchées UNIQUEMENT par le dispatch webhook — jamais appelées
// directement ici) ainsi que `updateDisputeStatus` (Cloud Function callable
// admin) pour les résolutions comptables tardives que Stripe ne notifie
// jamais par webhook (late-win/REVERSED).
//
// 🔒 Choix architectural délibéré (précédent établi par
// processStripeWebhook.test.ts ET disputeOrchestration.test.ts) : le
// PAIEMENT préalable est seedé DIRECTEMENT en Firestore (CAPTURED), et non
// obtenu via la chaîne complète calculateDeliveryQuote->...->completeDelivery.
// Raison : la vérification de signature Stripe exige une VRAIE instance
// `StripeProvider` comme provider actif (`getPaymentProvider() instanceof
// StripeProvider`), alors que la chaîne de livraison (acceptDelivery/
// completeDelivery) a besoin d'un `FakePaymentProvider` pour ne jamais
// appeler le réseau Stripe réel lors de l'autorisation/capture. Les deux
// exigences sont mutuellement exclusives pour UN SEUL provider actif à un
// instant donné — le seed direct du paiement CAPTURED est donc la
// précondition légitime (le cycle de paiement lui-même est déjà couvert
// exhaustivement par le Bloc P/E2E principal), conformément à la directive :
// "Ne modifie pas artificiellement les statuts Firestore si les
// orchestrations/webhooks existent" — ici, aucune orchestration de PAIEMENT
// n'est simulée : seul son état initial CAPTURED est posé comme donnée de
// départ, et TOUT le cycle de litige qui suit passe exclusivement par le
// vrai webhook signé + les vraies orchestrations de dispute.
//
// Couvre (scénarios minimum requis par le Bloc S) :
//   SCÉNARIO 1 — OPENED -> UNDER_REVIEW -> WON -> CLOSED, 100% via webhooks
//     Stripe signés réels (charge.dispute.created/updated/closed).
//   SCÉNARIO 2 — OPENED -> LOST (webhook updated, PAS closed) -> REVERSED
//     (résolution admin tardive, Stripe n'envoie jamais cet état par
//     webhook) -> CLOSED (admin).
//   SCÉNARIO 3 — Webhook DUPLIQUÉ (même event.id charge.dispute.created
//     rejoué deux fois) => idempotence stricte, AUCUN doublon de dispute/
//     ledger/audit.
//
// Chaque scénario vérifie : une seule dispute métier créée par provider
// event, aucun double ledger, aucune double compensation, provider_event_id
// traité une seule fois, audit dispute_opened/updated/closed, balance
// cohérente, réconciliation cohérente (aucune anomalie pertinente).
//
// Signature invalide / event invalide : DÉJÀ couvert exhaustivement par
// processStripeWebhook.test.ts (tests "signature MANQUANTE", "signature
// INVALIDE", "payload ALTÉRÉ") — non re-testé ici pour éviter toute
// duplication/régression, conformément à la directive Bloc S.
// ---------------------------------------------------------------------------

import type { CallableRequest, Request } from "firebase-functions/v2/https";
import type { Response } from "express";
import type { DecodedIdToken } from "firebase-admin/auth";
import Stripe from "stripe";

import { processStripeWebhook } from "../../src/functions/processStripeWebhook";
import { updateDisputeStatus, UpdateDisputeStatusRequest } from "../../src/functions/updateDisputeStatus";
import { runReconciliationNow, RunReconciliationNowRequest } from "../../src/functions/runReconciliation";

import { admin, db } from "../../src/lib/admin";
import { DisputeStatuses, LedgerEntryTypes, PaymentStatuses } from "../../src/lib/types";
import { setPaymentProviderForTesting } from "../../src/payment/paymentProviderFactory";
import { StripeProvider } from "../../src/payment/stripeProvider";
import { FakePaymentProvider } from "../testUtils/fakePaymentProvider";
import type { ProviderPaymentSummary } from "../../src/payment/paymentProvider";

// -----------------------------------------------------------------------------
// Signature Stripe — MÊME pattern que processStripeWebhook.test.ts : une
// instance Stripe RÉELLE (SDK) sert UNIQUEMENT à signer localement les
// payloads de test (fonction cryptographique pure, aucun appel réseau).
// -----------------------------------------------------------------------------
const TEST_SECRET_KEY = "sk_test_fake_key_for_dispute_e2e_tests_only";
const TEST_WEBHOOK_SECRET = "whsec_fake_webhook_secret_for_dispute_e2e_tests";
const signingStripe = new Stripe(TEST_SECRET_KEY, { apiVersion: "2026-07-29.dahlia" });

// 🔒 Bloc 8B LIVE (BLOQUEUR WEBHOOK PRODUCTION) : `processStripeWebhook`
// (endpoint PLATEFORME, seul utilisé par ce fichier — tous les évènements
// de dispute/chargeback ici sont des évènements PLATEFORME, jamais
// `account.updated`) vérifie désormais la signature avec
// `STRIPE_PLATFORM_WEBHOOK_SECRET.value()` (et non plus le legacy
// `STRIPE_WEBHOOK_SECRET`) — voir lib/secrets.ts et
// docs/PAYMENT_ARCHITECTURE.md §10.9. `SecretParam.value()` lit
// `process.env.<NOM>` à l'exécution (confirmé via
// node_modules/firebase-functions/lib/params/types.js), donc on doit fixer
// cette variable d'environnement AVANT tout appel à `invokeWebhook()` pour
// que la vérification de signature (avec le MÊME secret que celui utilisé
// pour signer ci-dessous) réussisse.
process.env.STRIPE_PLATFORM_WEBHOOK_SECRET = TEST_WEBHOOK_SECRET;

function signPayload(payload: string): string {
  return signingStripe.webhooks.generateTestHeaderString({ payload, secret: TEST_WEBHOOK_SECRET });
}

function buildFakeRequest(rawBody: string, signature: string | undefined): Request {
  return {
    rawBody: Buffer.from(rawBody, "utf8"),
    headers: signature ? { "stripe-signature": signature } : {},
  } as unknown as Request;
}

function buildFakeResponse(): { res: Response; statusCode: () => number; body: () => unknown } {
  let capturedStatus = 0;
  let capturedBody: unknown;
  const res = {
    status(code: number) {
      capturedStatus = code;
      return this;
    },
    send(body: unknown) {
      capturedBody = body;
      return this;
    },
  } as unknown as Response;
  return { res, statusCode: () => capturedStatus, body: () => capturedBody };
}

async function invokeWebhook(rawBody: string, signature: string | undefined): Promise<{ status: number; body: unknown }> {
  const req = buildFakeRequest(rawBody, signature);
  const { res, statusCode, body } = buildFakeResponse();
  await (processStripeWebhook as unknown as (req: Request, res: Response) => Promise<void>)(req, res);
  return { status: statusCode(), body: body() };
}

// `livemode: false` explicite — cohérent avec `TEST_SECRET_KEY = "sk_test_..."`
// utilisé par ce fichier (provider.environment === "test") : voir
// isWebhookLivemodeConsistent() dans lib/stripeEnvironment.ts, câblé dans
// processStripeWebhook.ts (Phase 8B item 2) — un évènement sans champ
// `livemode` explicite serait `undefined !== false`, ce qui déclencherait
// à tort le rejet défense-en-profondeur pour CE fichier de test (dont le
// but est de tester le cycle de vie dispute/chargeback, pas l'isolation
// d'environnement — voir processStripeWebhook.test.ts pour ces tests dédiés).
function buildStripeEventPayload(id: string, type: string, dataObject: Record<string, unknown>): string {
  return JSON.stringify({
    id,
    object: "event",
    type,
    livemode: false,
    data: { object: dataObject },
    created: Math.floor(Date.now() / 1000),
  });
}

function authedRequest<T>(uid: string, role: string, data: T): CallableRequest<T> {
  return {
    data,
    auth: { uid, token: { role } as unknown as DecodedIdToken, rawToken: "fake-raw-token" },
    rawRequest: {} as Request,
    acceptsStreaming: false,
  };
}

// -----------------------------------------------------------------------------
// Seed / cleanup helpers — préfixe dédié pour ne jamais interférer avec les
// autres fichiers de test exécutés dans la même suite d'intégration.
// -----------------------------------------------------------------------------
const CUSTOMER_ID = "e2edispute_customer_001";
const DRIVER_ID = "e2edispute_driver_001";
const ADMIN_ID = "e2edispute_admin_001";

async function seedPayment(
  paymentId: string,
  missionId: string,
  providerChargeId: string,
  providerPaymentIntentId: string,
  amountCapturedMinor = 6000
): Promise<void> {
  const now = admin.firestore.Timestamp.now();
  await db.collection("payments").doc(paymentId).set({
    payment_id: paymentId,
    mission_id: missionId,
    customer_id: CUSTOMER_ID,
    driver_id: DRIVER_ID,
    status: PaymentStatuses.CAPTURED,
    currency: "CAD",
    amount_authorized_minor: amountCapturedMinor,
    amount_captured_minor: amountCapturedMinor,
    amount_refunded_minor: 0,
    application_fee_minor: Math.round(amountCapturedMinor * 0.15),
    provider: "stripe",
    provider_customer_id: `fake_cus_${CUSTOMER_ID}`,
    provider_payment_method_id: `fake_pm_${CUSTOMER_ID}`,
    provider_payment_intent_id: providerPaymentIntentId,
    provider_charge_id: providerChargeId,
    connected_account_id: null,
    idempotency_key: `createPayment:${paymentId}`,
    captured_at: now,
    created_at: now,
    updated_at: now,
  });
}

async function getEventDoc(eventId: string) {
  const snap = await db.collection("provider_webhook_events").doc(eventId).get();
  return snap.exists ? snap.data()! : null;
}

async function cleanupAll(opts: {
  eventIds: string[];
  paymentIds: string[];
  missionIds: string[];
  disputeIds: string[];
}): Promise<void> {
  const batch = db.batch();
  opts.eventIds.forEach((id) => batch.delete(db.collection("provider_webhook_events").doc(id)));
  opts.paymentIds.forEach((id) => batch.delete(db.collection("payments").doc(id)));
  opts.disputeIds.forEach((id) => batch.delete(db.collection("disputes").doc(id)));
  for (const mid of opts.missionIds) {
    const ledgerSnap = await db.collection("transaction_ledger").where("mission_id", "==", mid).get();
    ledgerSnap.docs.forEach((d) => batch.delete(d.ref));
    batch.delete(db.collection("mission_financial_balance").doc(mid));
  }
  await batch.commit();

  const auditSnap = await db
    .collection("audit_logs")
    .where("source_function", "in", [
      "processStripeWebhook",
      "openDispute",
      "transitionDisputeStatus",
      "updateDisputeStatus",
    ])
    .get();
  const recent = auditSnap.docs.filter(
    (d) => ((d.data().created_at as FirebaseFirestore.Timestamp)?.toMillis?.() ?? 0) > Date.now() - 3600 * 1000
  );
  await Promise.all(recent.map((d) => d.ref.delete()));

  const reconAudit = await db
    .collection("audit_logs")
    .where("action", "==", "reconciliation_anomaly_detected")
    .get();
  await Promise.all(
    reconAudit.docs
      .filter((d) => (d.data().metadata?.periodStartMillis ?? 0) > Date.now() - 3600 * 1000)
      .map((d) => d.ref.delete())
  );
}

// -----------------------------------------------------------------------------

describe("E2E DISPUTE / CHARGEBACK (Bloc S) — webhooks Stripe signés réels -> orchestration dispute -> balance -> réconciliation", () => {
  beforeAll(() => {
    // 🔒 Instance RÉELLE StripeProvider (clé/secret de test) — nécessaire
    // pour que `provider instanceof StripeProvider` soit vrai dans
    // processStripeWebhook.ts et que la signature soit vérifiée avec le
    // MÊME secret utilisé pour signer côté test. Aucun appel réseau Stripe
    // n'est jamais déclenché (seules les méthodes `webhooks.*`, purement
    // cryptographiques locales, sont exercées).
    setPaymentProviderForTesting(new StripeProvider(TEST_SECRET_KEY, TEST_WEBHOOK_SECRET));
  });

  afterAll(() => {
    setPaymentProviderForTesting(null);
  });

  it(
    "SCÉNARIO 1 — OPENED -> UNDER_REVIEW -> WON -> CLOSED via webhooks Stripe signés réels : " +
      "1 seule dispute, 1 seul ledger CHARGEBACK_FEE, 1 seul CHARGEBACK_WON, payment CAPTURED final, réconciliation cohérente",
    async () => {
      const missionId = "e2edispute_mission_won_1";
      const paymentId = "e2edispute_payment_won_1";
      const chargeId = "ch_e2edispute_won_1";
      const piId = "pi_e2edispute_won_1";
      const disputeId = "dp_e2edispute_won_1";
      const amountCapturedMinor = 6000;
      await seedPayment(paymentId, missionId, chargeId, piId, amountCapturedMinor);

      // ---- 1. charge.dispute.created -> OPENED ----
      const createdEventId = "evt_e2edispute_won_created_1";
      const createdPayload = buildStripeEventPayload(createdEventId, "charge.dispute.created", {
        id: disputeId,
        charge: chargeId,
        amount: amountCapturedMinor,
        reason: "fraudulent",
        status: "warning_needs_response",
      });
      const created = await invokeWebhook(createdPayload, signPayload(createdPayload));
      expect(created.status).toBe(200);

      let disputeSnap = await db.collection("disputes").doc(disputeId).get();
      expect(disputeSnap.exists).toBe(true);
      expect(disputeSnap.data()!.status).toBe(DisputeStatuses.OPENED);
      expect(disputeSnap.data()!.mission_id).toBe(missionId);

      let paySnap = await db.collection("payments").doc(paymentId).get();
      expect(paySnap.data()!.status).toBe(PaymentStatuses.DISPUTED);

      let feeLedger = await db
        .collection("transaction_ledger")
        .where("mission_id", "==", missionId)
        .where("type", "==", LedgerEntryTypes.CHARGEBACK_FEE)
        .get();
      expect(feeLedger.size).toBe(1);

      let openedAudit = await db
        .collection("audit_logs")
        .where("target_id", "==", disputeId)
        .where("action", "==", "dispute_opened")
        .get();
      expect(openedAudit.size).toBe(1);

      // ---- 2. charge.dispute.updated (under_review) -> UNDER_REVIEW ----
      const underReviewEventId = "evt_e2edispute_won_underreview_1";
      const underReviewPayload = buildStripeEventPayload(underReviewEventId, "charge.dispute.updated", {
        id: disputeId,
        charge: chargeId,
        amount: amountCapturedMinor,
        reason: "fraudulent",
        status: "under_review",
      });
      const underReview = await invokeWebhook(underReviewPayload, signPayload(underReviewPayload));
      expect(underReview.status).toBe(200);

      disputeSnap = await db.collection("disputes").doc(disputeId).get();
      expect(disputeSnap.data()!.status).toBe(DisputeStatuses.UNDER_REVIEW);

      // ---- 3. charge.dispute.updated (won) -> WON, payment -> CAPTURED, ledger CHARGEBACK_WON ----
      const wonEventId = "evt_e2edispute_won_updated_won_1";
      const wonPayload = buildStripeEventPayload(wonEventId, "charge.dispute.updated", {
        id: disputeId,
        charge: chargeId,
        amount: amountCapturedMinor,
        reason: "fraudulent",
        status: "won",
      });
      const won = await invokeWebhook(wonPayload, signPayload(wonPayload));
      expect(won.status).toBe(200);

      disputeSnap = await db.collection("disputes").doc(disputeId).get();
      expect(disputeSnap.data()!.status).toBe(DisputeStatuses.WON);

      paySnap = await db.collection("payments").doc(paymentId).get();
      expect(paySnap.data()!.status).toBe(PaymentStatuses.CAPTURED);

      let wonLedger = await db
        .collection("transaction_ledger")
        .where("mission_id", "==", missionId)
        .where("type", "==", LedgerEntryTypes.CHARGEBACK_WON)
        .get();
      expect(wonLedger.size).toBe(1);

      // ---- 4. charge.dispute.closed (won) -> WON (self-transition, no-op) PUIS CLOSED ----
      const closedEventId = "evt_e2edispute_won_closed_1";
      const closedPayload = buildStripeEventPayload(closedEventId, "charge.dispute.closed", {
        id: disputeId,
        charge: chargeId,
        amount: amountCapturedMinor,
        reason: "fraudulent",
        status: "won",
      });
      const closed = await invokeWebhook(closedPayload, signPayload(closedPayload));
      expect(closed.status).toBe(200);

      disputeSnap = await db.collection("disputes").doc(disputeId).get();
      expect(disputeSnap.data()!.status).toBe(DisputeStatuses.CLOSED);
      expect(disputeSnap.data()!.closed_at).not.toBeNull();
      expect(disputeSnap.data()!.resolved_at).not.toBeNull();

      // 🔒 AUCUN doublon de ledger CHARGEBACK_WON malgré la self-transition
      // WON->WON traversée dans le même évènement "closed" avant CLOSED.
      wonLedger = await db
        .collection("transaction_ledger")
        .where("mission_id", "==", missionId)
        .where("type", "==", LedgerEntryTypes.CHARGEBACK_WON)
        .get();
      expect(wonLedger.size).toBe(1);
      feeLedger = await db
        .collection("transaction_ledger")
        .where("mission_id", "==", missionId)
        .where("type", "==", LedgerEntryTypes.CHARGEBACK_FEE)
        .get();
      expect(feeLedger.size).toBe(1);

      // 🔒 Une seule dispute métier créée par ce jeu de 4 provider events.
      const disputesForThisId = await db.collection("disputes").where("provider_dispute_id", "==", disputeId).get();
      expect(disputesForThisId.size).toBe(1);

      // 🔒 Chaque provider event traité UNE SEULE fois (attempt_count=1, processed).
      for (const eventId of [createdEventId, underReviewEventId, wonEventId, closedEventId]) {
        const evt = await getEventDoc(eventId);
        expect(evt!.processing_status).toBe("processed");
        expect(evt!.attempt_count).toBe(1);
      }

      // 🔒 Audit dispute_opened/updated/closed présents (un de chaque type
      // pertinent, sans doublon).
      const closedAudit = await db
        .collection("audit_logs")
        .where("target_id", "==", disputeId)
        .where("action", "==", "dispute_closed")
        .get();
      expect(closedAudit.size).toBe(1);
      const updatedAudit = await db
        .collection("audit_logs")
        .where("target_id", "==", disputeId)
        .where("action", "==", "dispute_updated")
        .get();
      // under_review + won = 2 transitions non-terminales journalisées "dispute_updated".
      expect(updatedAudit.size).toBe(2);

      // ---- Balance cohérente ----
      const balanceSnap = await db.collection("mission_financial_balance").doc(missionId).get();
      expect(balanceSnap.exists).toBe(true);
      expect(balanceSnap.data()!.customer_charged_minor).toBe(amountCapturedMinor);

      // ---- Réconciliation cohérente ----
      // 🔒 Bascule vers un FakePaymentProvider UNIQUEMENT pour cet appel de
      // réconciliation (le webhook signé ci-dessus a déjà été traité) —
      // injecte le paiement capturé pour que la vérification
      // payment_missing_in_provider/amount_mismatch ne signale pas un faux
      // positif (le paiement n'a jamais réellement existé chez un vrai
      // Stripe, ce test ne fait QUE de la vérification cryptographique
      // locale de signature).
      const providerPayments: ProviderPaymentSummary[] = [
        { providerPaymentIntentId: piId, amountMinor: amountCapturedMinor, status: "succeeded", createdAtMillis: Date.now() },
      ];
      setPaymentProviderForTesting(new FakePaymentProvider({ providerPayments }));
      const periodStartMillis = Date.now() - 3600 * 1000;
      const periodEndMillis = Date.now() + 3600 * 1000;
      const reconciliation = await runReconciliationNow.run(
        authedRequest<RunReconciliationNowRequest>(ADMIN_ID, "admin", { periodStartMillis, periodEndMillis })
      );
      const reportSnap = await db.collection("reconciliation_reports").doc(reconciliation.reportId).get();
      const relevantAnomalies = (reportSnap.data()!.anomalies as Array<Record<string, unknown>>).filter(
        (a) => a.mission_id === missionId || a.payment_id === paymentId
      );
      expect(relevantAnomalies).toHaveLength(0);
      // Restaure le provider StripeProvider pour les tests suivants du fichier.
      setPaymentProviderForTesting(new StripeProvider(TEST_SECRET_KEY, TEST_WEBHOOK_SECRET));

      await cleanupAll({
        eventIds: [createdEventId, underReviewEventId, wonEventId, closedEventId],
        paymentIds: [paymentId],
        missionIds: [missionId],
        disputeIds: [disputeId],
      });
    }
  );

  it(
    "SCÉNARIO 2 — OPENED -> LOST (webhook updated, PAS closed) -> REVERSED (admin, résolution tardive) -> CLOSED (admin) : " +
      "ledger CHARGEBACK_LOST puis CHARGEBACK_REVERSAL, payment CHARGEBACK puis REFUNDED, aucune double compensation",
    async () => {
      const missionId = "e2edispute_mission_reversed_1";
      const paymentId = "e2edispute_payment_reversed_1";
      const chargeId = "ch_e2edispute_reversed_1";
      const piId = "pi_e2edispute_reversed_1";
      const disputeId = "dp_e2edispute_reversed_1";
      const amountCapturedMinor = 4500;
      await seedPayment(paymentId, missionId, chargeId, piId, amountCapturedMinor);

      // ---- 1. charge.dispute.created -> OPENED ----
      const createdEventId = "evt_e2edispute_reversed_created_1";
      const createdPayload = buildStripeEventPayload(createdEventId, "charge.dispute.created", {
        id: disputeId,
        charge: chargeId,
        amount: amountCapturedMinor,
        reason: "duplicate",
        status: "warning_needs_response",
      });
      const created = await invokeWebhook(createdPayload, signPayload(createdPayload));
      expect(created.status).toBe(200);

      // ---- 2. charge.dispute.updated (status=lost, PAS closed) -> LOST, payment -> CHARGEBACK ----
      // 🔒 Contrairement à Scénario 1, cet évènement est "updated" (pas
      // "closed") : Stripe peut notifier une perte SANS clôturer
      // immédiatement le litige (résolution comptable ultérieure encore
      // possible côté plateforme, ex: appel en cours). Le dispute reste
      // donc LOST (pas encore CLOSED) après cet évènement.
      const lostEventId = "evt_e2edispute_reversed_lost_1";
      const lostPayload = buildStripeEventPayload(lostEventId, "charge.dispute.updated", {
        id: disputeId,
        charge: chargeId,
        amount: amountCapturedMinor,
        reason: "duplicate",
        status: "lost",
      });
      const lost = await invokeWebhook(lostPayload, signPayload(lostPayload));
      expect(lost.status).toBe(200);

      let disputeSnap = await db.collection("disputes").doc(disputeId).get();
      expect(disputeSnap.data()!.status).toBe(DisputeStatuses.LOST);
      expect(disputeSnap.data()!.closed_at).toBeNull(); // PAS encore clôturé

      let paySnap = await db.collection("payments").doc(paymentId).get();
      expect(paySnap.data()!.status).toBe(PaymentStatuses.CHARGEBACK);

      const lostLedger = await db
        .collection("transaction_ledger")
        .where("mission_id", "==", missionId)
        .where("type", "==", LedgerEntryTypes.CHARGEBACK_LOST)
        .get();
      expect(lostLedger.size).toBe(1);
      expect(lostLedger.docs[0].data().direction).toBe("debit");

      // ---- 3. Résolution tardive (REVERSED) — jamais notifiée par un
      // webhook Stripe réel avec ce statut brut (Stripe ne renvoie pas
      // "reversed" comme dispute.status) : appliquée via updateDisputeStatus
      // (Cloud Function callable, admin/super_admin uniquement), exactement
      // comme le prévoit disputeStateMachine.ts (LOST -> REVERSED). ----
      const reversedOutcome = await updateDisputeStatus.run(
        authedRequest<UpdateDisputeStatusRequest>(ADMIN_ID, "admin", {
          disputeId,
          newStatus: DisputeStatuses.REVERSED,
        })
      );
      expect(reversedOutcome.status).toBe(DisputeStatuses.REVERSED);
      expect(reversedOutcome.skipped).toBe(false);

      disputeSnap = await db.collection("disputes").doc(disputeId).get();
      expect(disputeSnap.data()!.status).toBe(DisputeStatuses.REVERSED);
      expect(disputeSnap.data()!.closed_at).toBeNull(); // REVERSED n'est pas terminal

      paySnap = await db.collection("payments").doc(paymentId).get();
      expect(paySnap.data()!.status).toBe(PaymentStatuses.REFUNDED);

      const reversalLedger = await db
        .collection("transaction_ledger")
        .where("mission_id", "==", missionId)
        .where("type", "==", LedgerEntryTypes.CHARGEBACK_REVERSAL)
        .get();
      expect(reversalLedger.size).toBe(1);
      expect(reversalLedger.docs[0].data().direction).toBe("credit");

      // 🔒 AUCUNE double compensation : le CHARGEBACK_LOST original reste
      // intact (append-only), un SEUL CHARGEBACK_REVERSAL vient s'y ajouter,
      // jamais de modification/suppression rétroactive.
      const lostLedgerAfter = await db
        .collection("transaction_ledger")
        .where("mission_id", "==", missionId)
        .where("type", "==", LedgerEntryTypes.CHARGEBACK_LOST)
        .get();
      expect(lostLedgerAfter.size).toBe(1);
      expect(lostLedgerAfter.docs[0].id).toBe(lostLedger.docs[0].id);
      expect(lostLedgerAfter.docs[0].data()).toEqual(lostLedger.docs[0].data());

      // ---- 4. Clôture administrative (CLOSED) — aucun nouvel effet ledger ----
      const closedOutcome = await updateDisputeStatus.run(
        authedRequest<UpdateDisputeStatusRequest>(ADMIN_ID, "admin", {
          disputeId,
          newStatus: DisputeStatuses.CLOSED,
        })
      );
      expect(closedOutcome.status).toBe(DisputeStatuses.CLOSED);

      disputeSnap = await db.collection("disputes").doc(disputeId).get();
      expect(disputeSnap.data()!.status).toBe(DisputeStatuses.CLOSED);
      expect(disputeSnap.data()!.closed_at).not.toBeNull();

      // Toujours exactement 1 CHARGEBACK_LOST + 1 CHARGEBACK_REVERSAL — la
      // clôture administrative n'ajoute AUCUNE entrée ledger.
      const finalLostLedger = await db
        .collection("transaction_ledger")
        .where("mission_id", "==", missionId)
        .where("type", "==", LedgerEntryTypes.CHARGEBACK_LOST)
        .get();
      expect(finalLostLedger.size).toBe(1);
      const finalReversalLedger = await db
        .collection("transaction_ledger")
        .where("mission_id", "==", missionId)
        .where("type", "==", LedgerEntryTypes.CHARGEBACK_REVERSAL)
        .get();
      expect(finalReversalLedger.size).toBe(1);

      // 🔒 Une seule dispute métier créée par ce jeu d'évènements.
      const disputesForThisId = await db.collection("disputes").where("provider_dispute_id", "==", disputeId).get();
      expect(disputesForThisId.size).toBe(1);

      // ---- Audit dispute_opened/updated/closed ----
      const openedAudit = await db
        .collection("audit_logs")
        .where("target_id", "==", disputeId)
        .where("action", "==", "dispute_opened")
        .get();
      expect(openedAudit.size).toBe(1);
      const closedAudit = await db
        .collection("audit_logs")
        .where("target_id", "==", disputeId)
        .where("action", "==", "dispute_closed")
        .get();
      expect(closedAudit.size).toBe(1);

      // ---- Balance cohérente ----
      const balanceSnap = await db.collection("mission_financial_balance").doc(missionId).get();
      expect(balanceSnap.exists).toBe(true);
      expect(balanceSnap.data()!.customer_charged_minor).toBe(amountCapturedMinor);

      // ---- Réconciliation cohérente ----
      const providerPayments: ProviderPaymentSummary[] = [
        { providerPaymentIntentId: piId, amountMinor: amountCapturedMinor, status: "succeeded", createdAtMillis: Date.now() },
      ];
      setPaymentProviderForTesting(new FakePaymentProvider({ providerPayments }));
      const periodStartMillis = Date.now() - 3600 * 1000;
      const periodEndMillis = Date.now() + 3600 * 1000;
      const reconciliation = await runReconciliationNow.run(
        authedRequest<RunReconciliationNowRequest>(ADMIN_ID, "admin", { periodStartMillis, periodEndMillis })
      );
      const reportSnap = await db.collection("reconciliation_reports").doc(reconciliation.reportId).get();
      const relevantAnomalies = (reportSnap.data()!.anomalies as Array<Record<string, unknown>>).filter(
        (a) => a.mission_id === missionId || a.payment_id === paymentId
      );
      expect(relevantAnomalies).toHaveLength(0);
      setPaymentProviderForTesting(new StripeProvider(TEST_SECRET_KEY, TEST_WEBHOOK_SECRET));

      await cleanupAll({
        eventIds: [createdEventId, lostEventId],
        paymentIds: [paymentId],
        missionIds: [missionId],
        disputeIds: [disputeId],
      });
    }
  );

  it(
    "SCÉNARIO 3 — Webhook DUPLIQUÉ (même event.id charge.dispute.created rejoué deux fois) : " +
      "idempotence stricte, AUCUN doublon de dispute/ledger/audit, provider_event_id traité une seule fois",
    async () => {
      const missionId = "e2edispute_mission_dup_1";
      const paymentId = "e2edispute_payment_dup_1";
      const chargeId = "ch_e2edispute_dup_1";
      const piId = "pi_e2edispute_dup_1";
      const disputeId = "dp_e2edispute_dup_1";
      const amountCapturedMinor = 3300;
      await seedPayment(paymentId, missionId, chargeId, piId, amountCapturedMinor);

      const eventId = "evt_e2edispute_dup_created_1";
      const payload = buildStripeEventPayload(eventId, "charge.dispute.created", {
        id: disputeId,
        charge: chargeId,
        amount: amountCapturedMinor,
        reason: "fraudulent",
        status: "warning_needs_response",
      });
      const sig = signPayload(payload);

      const first = await invokeWebhook(payload, sig);
      expect(first.status).toBe(200);
      expect(first.body).toEqual({ received: true });

      // 🔒 EXACT même event.id rejoué (retry Stripe réel, ou double
      // livraison réseau) — le garde-fou est le get-or-create transactionnel
      // sur provider_webhook_events/{event.id}, IDENTIQUE quel que soit le
      // type d'évènement métier dispatché.
      const second = await invokeWebhook(payload, sig);
      expect(second.status).toBe(200);
      expect(second.body).toEqual({ received: true, alreadyProcessed: true });

      const evt = await getEventDoc(eventId);
      expect(evt!.processing_status).toBe("processed");
      expect(evt!.attempt_count).toBe(1); // jamais incrémenté après un succès

      // Une seule dispute créée, jamais deux.
      const disputesForThisId = await db.collection("disputes").where("provider_dispute_id", "==", disputeId).get();
      expect(disputesForThisId.size).toBe(1);

      // Un seul ledger CHARGEBACK_FEE, jamais deux (aucune double compensation).
      const feeLedger = await db
        .collection("transaction_ledger")
        .where("mission_id", "==", missionId)
        .where("type", "==", LedgerEntryTypes.CHARGEBACK_FEE)
        .get();
      expect(feeLedger.size).toBe(1);

      // Un seul audit_log "dispute_opened", jamais deux.
      const openedAudit = await db
        .collection("audit_logs")
        .where("target_id", "==", disputeId)
        .where("action", "==", "dispute_opened")
        .get();
      expect(openedAudit.size).toBe(1);

      // Un seul audit_log "webhook_event_processed" pour cet event.id.
      const webhookAudit = await db
        .collection("audit_logs")
        .where("target_id", "==", eventId)
        .where("action", "==", "webhook_event_processed")
        .get();
      expect(webhookAudit.size).toBe(1);

      const paySnap = await db.collection("payments").doc(paymentId).get();
      expect(paySnap.data()!.status).toBe(PaymentStatuses.DISPUTED);

      await cleanupAll({
        eventIds: [eventId],
        paymentIds: [paymentId],
        missionIds: [missionId],
        disputeIds: [disputeId],
      });
    }
  );
});
