// ---------------------------------------------------------------------------
// Test d'intégration — processStripeWebhook (Phase 6, directive 38 points,
// Bloc D / point 11).
//
// Couvre :
//   - signature valide (payload signé avec le MÊME secret que le provider)
//   - signature invalide (mauvais secret) => 400, aucune écriture
//   - payload altéré après signature => 400, aucune écriture
//   - fournisseur non configuré => 503
//   - évènement dupliqué (même event.id rejoué) => 200, alreadyProcessed,
//     AUCUN doublon d'effet financier (ledger/dispute/payout/refund)
//   - évènement déjà `processed` dans provider_webhook_events => 200 sans
//     seconde exécution
//   - évènement de type inconnu => 200, `ignored` (pas d'effet, mais
//     enregistré comme processed)
//   - erreur temporaire lors du dispatch => 500, provider_webhook_events
//     passe à `failed`, `attempt_count`/`last_error` renseignés
//   - retry après erreur : un second appel avec le MÊME event.id après un
//     échec précédent retente le dispatch (attempt_count incrémenté) et
//     peut réussir
//   - payment_intent.succeeded / payment_intent.payment_failed : audit
//     écrit, related_payment_id/related_mission_id renseignés
//   - charge.refund.updated (succeeded) : related_refund_id/related_payment_id
//   - payout.paid / payout.failed : related_payout_id
//   - charge.dispute.created : crée disputes/{id} (idempotent si rejoué),
//     payment -> DISPUTED, ledger CHARGEBACK_FEE
//   - charge.dispute.updated (under_review) : disputes/{id}.status mis à jour
//   - charge.dispute.closed (won) : disputes/{id}.status -> WON PUIS -> CLOSED
//     dans le MÊME évènement (bug corrigé cette session), ledger
//     CHARGEBACK_WON, payment -> CAPTURED, closed_at renseigné
// ---------------------------------------------------------------------------

import type { Request } from "firebase-functions/v2/https";
import type { Response } from "express";
import Stripe from "stripe";
import { processStripeWebhook } from "../../src/functions/processStripeWebhook";
import { admin, db } from "../../src/lib/admin";
import {
  DisputeStatuses,
  PaymentStatuses,
} from "../../src/lib/types";
import { setPaymentProviderForTesting } from "../../src/payment/paymentProviderFactory";
import { StripeProvider } from "../../src/payment/stripeProvider";

const TEST_SECRET_KEY = "sk_test_fake_key_for_webhook_tests_only";
const TEST_WEBHOOK_SECRET = "whsec_fake_webhook_secret_for_tests";

// Instance Stripe RÉELLE (SDK), UNIQUEMENT pour signer les payloads de test
// localement — aucun appel réseau n'est jamais effectué (generateTestHeaderString
// est une fonction cryptographique pure, voir docs.stripe.com/webhooks#verify-events
// et node_modules/stripe/cjs/Webhooks.js).
const signingStripe = new Stripe(TEST_SECRET_KEY, { apiVersion: "2026-07-29.dahlia" });

function signPayload(payload: string, secret = TEST_WEBHOOK_SECRET): string {
  return signingStripe.webhooks.generateTestHeaderString({ payload, secret });
}

/** Construit une fausse Request Express minimale suffisante pour le handler. */
function buildFakeRequest(rawBody: string, signature: string | undefined): Request {
  return {
    rawBody: Buffer.from(rawBody, "utf8"),
    headers: signature ? { "stripe-signature": signature } : {},
  } as unknown as Request;
}

/** Capture status()/send() sans jamais toucher au réseau. */
function buildFakeResponse(): { res: Response; statusCode: () => number; body: () => unknown } {
  let capturedStatus = 0;
  let capturedBody: unknown = undefined;
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

async function invokeWebhook(
  rawBody: string,
  signature: string | undefined
): Promise<{ status: number; body: unknown }> {
  const req = buildFakeRequest(rawBody, signature);
  const { res, statusCode, body } = buildFakeResponse();
  // processStripeWebhook est un HttpsFunction (onRequest) : appelable
  // directement comme (req, res) => Promise<void> — voir
  // node_modules/firebase-functions/lib/v2/providers/https.js (onRequest
  // retourne directement le handler, éventuellement enveloppé par
  // wrapTraceContext/withInit qui préservent la signature (req, res)).
  await (processStripeWebhook as unknown as (req: Request, res: Response) => Promise<void>)(req, res);
  return { status: statusCode(), body: body() };
}

function buildStripeEventPayload(id: string, type: string, dataObject: Record<string, unknown>): string {
  return JSON.stringify({
    id,
    object: "event",
    type,
    data: { object: dataObject },
    created: Math.floor(Date.now() / 1000),
  });
}

// -----------------------------------------------------------------------------
// Seed helpers
// -----------------------------------------------------------------------------

const CUSTOMER_ID = "webhook_customer_001";
const DRIVER_ID = "webhook_driver_001";

async function seedPayment(
  paymentId: string,
  missionId: string,
  opts: {
    status?: string;
    providerPaymentIntentId?: string;
    providerChargeId?: string;
    connectedAccountId?: string | null;
    amountCapturedMinor?: number;
  } = {}
): Promise<void> {
  const now = admin.firestore.Timestamp.now();
  const amountCapturedMinor = opts.amountCapturedMinor ?? 5000;
  await db
    .collection("payments")
    .doc(paymentId)
    .set({
      payment_id: paymentId,
      mission_id: missionId,
      customer_id: CUSTOMER_ID,
      driver_id: DRIVER_ID,
      status: opts.status ?? PaymentStatuses.CAPTURED,
      currency: "CAD",
      amount_authorized_minor: amountCapturedMinor,
      amount_captured_minor: amountCapturedMinor,
      amount_refunded_minor: 0,
      application_fee_minor: Math.round(amountCapturedMinor * 0.15),
      provider: "stripe",
      provider_customer_id: `fake_cus_${CUSTOMER_ID}`,
      provider_payment_method_id: `fake_pm_${CUSTOMER_ID}`,
      provider_payment_intent_id: opts.providerPaymentIntentId ?? `pi_${paymentId}`,
      provider_charge_id: opts.providerChargeId ?? `ch_${paymentId}`,
      connected_account_id: opts.connectedAccountId ?? null,
      idempotency_key: `createPayment:${paymentId}`,
      captured_at: now,
      created_at: now,
      updated_at: now,
    });
}

async function seedRefund(
  refundId: string,
  paymentId: string,
  missionId: string,
  providerRefundId: string
): Promise<void> {
  const now = admin.firestore.Timestamp.now();
  await db.collection("refunds").doc(refundId).set({
    refund_id: refundId,
    mission_id: missionId,
    payment_id: paymentId,
    amount_minor: 1000,
    reason: "customer_request",
    initiated_by_user_id: CUSTOMER_ID,
    initiated_by_role: "customer",
    is_admin_initiated: false,
    is_post_payout: false,
    related_payout_id: null,
    status: "processing",
    provider_refund_id: providerRefundId,
    reverse_transfer: false,
    refund_application_fee: false,
    idempotency_key: `refundPayment:${refundId}`,
    created_at: now,
    processing_at: now,
    completed_at: null,
    failed_reason: null,
  });
}

async function seedPayout(payoutId: string, providerPayoutId: string): Promise<void> {
  const now = admin.firestore.Timestamp.now();
  await db.collection("driver_payouts").doc(payoutId).set({
    driver_id: DRIVER_ID,
    financial_snapshot_ids: [],
    amount_minor: 2000,
    currency: "CAD",
    status: "processing",
    payout_hold_period_hours: 48,
    payout_eligible_at: now,
    provider_payout_id: providerPayoutId,
    connected_account_id: `acct_${DRIVER_ID}`,
    created_at: now,
    idempotency_key: `submitDriverPayout:${payoutId}`,
  });
}

async function getEventDoc(eventId: string) {
  const snap = await db.collection("provider_webhook_events").doc(eventId).get();
  return snap.exists ? snap.data()! : null;
}

async function seedDriverProfile(
  driverId: string,
  connectedAccountId: string,
  opts: { chargesEnabled?: boolean; payoutsEnabled?: boolean } = {}
): Promise<void> {
  await db.collection("driver_profiles").doc(driverId).set(
    {
      stripe_connected_account_id: connectedAccountId,
      stripe_charges_enabled: opts.chargesEnabled ?? false,
      stripe_payouts_enabled: opts.payoutsEnabled ?? false,
    },
    { merge: true }
  );
}

async function cleanupAll(opts: {
  eventIds?: string[];
  paymentIds?: string[];
  missionIds?: string[];
  refundIds?: string[];
  payoutIds?: string[];
  disputeIds?: string[];
  driverProfileIds?: string[];
}): Promise<void> {
  const batch = db.batch();
  (opts.eventIds ?? []).forEach((id) => batch.delete(db.collection("provider_webhook_events").doc(id)));
  (opts.paymentIds ?? []).forEach((id) => batch.delete(db.collection("payments").doc(id)));
  (opts.refundIds ?? []).forEach((id) => batch.delete(db.collection("refunds").doc(id)));
  (opts.payoutIds ?? []).forEach((id) => batch.delete(db.collection("driver_payouts").doc(id)));
  (opts.disputeIds ?? []).forEach((id) => batch.delete(db.collection("disputes").doc(id)));
  (opts.driverProfileIds ?? []).forEach((id) => batch.delete(db.collection("driver_profiles").doc(id)));
  for (const mid of opts.missionIds ?? []) {
    const ledgerSnap = await db.collection("transaction_ledger").where("mission_id", "==", mid).get();
    ledgerSnap.docs.forEach((d) => batch.delete(d.ref));
    batch.delete(db.collection("mission_financial_balance").doc(mid));
  }
  const auditSnap = await db
    .collection("audit_logs")
    .where("source_function", "in", ["processStripeWebhook", "openDispute", "transitionDisputeStatus"])
    .get();
  auditSnap.docs.forEach((d) => batch.delete(d.ref));
  await batch.commit();
}

// -----------------------------------------------------------------------------

describe("processStripeWebhook", () => {
  beforeAll(() => {
    // Injecte une VRAIE instance StripeProvider (clé de test factice) —
    // nécessaire pour que `provider instanceof StripeProvider` soit vrai
    // et que `constructVerifiedEvent` vérifie réellement la signature avec
    // le MÊME secret que celui utilisé pour signer dans les tests. Aucun
    // appel réseau Stripe n'est jamais déclenché par ce test (seules les
    // méthodes `webhooks.*`, purement cryptographiques locales, sont
    // exercées).
    setPaymentProviderForTesting(new StripeProvider(TEST_SECRET_KEY, TEST_WEBHOOK_SECRET));
  });

  afterAll(() => {
    setPaymentProviderForTesting(null);
  });

  // ---------------------------------------------------------------------
  // 1. Signature
  // ---------------------------------------------------------------------

  test("signature valide => 200, évènement enregistré `processed`", async () => {
    const eventId = "evt_sig_valid_001";
    const payload = buildStripeEventPayload(eventId, "some.unhandled.event", { id: "obj_1" });
    const sig = signPayload(payload);

    const { status, body } = await invokeWebhook(payload, sig);

    expect(status).toBe(200);
    expect(body).toEqual({ received: true });

    const doc = await getEventDoc(eventId);
    expect(doc).not.toBeNull();
    expect(doc!.processing_status).toBe("processed");
    expect(doc!.provider_event_id).toBe(eventId);
    expect(doc!.event_type).toBe("some.unhandled.event");

    await cleanupAll({ eventIds: [eventId] });
  });

  test("signature MANQUANTE => 400, aucune écriture", async () => {
    const eventId = "evt_sig_missing_001";
    const payload = buildStripeEventPayload(eventId, "some.unhandled.event", {});

    const { status, body } = await invokeWebhook(payload, undefined);

    expect(status).toBe(400);
    expect(typeof body).toBe("string");
    expect(body as string).toMatch(/Signature Stripe-Signature manquante/);

    const doc = await getEventDoc(eventId);
    expect(doc).toBeNull();
  });

  test("signature INVALIDE (mauvais secret) => 400, aucune écriture", async () => {
    const eventId = "evt_sig_invalid_001";
    const payload = buildStripeEventPayload(eventId, "some.unhandled.event", {});
    const badSig = signPayload(payload, "whsec_totally_wrong_secret");

    const { status, body } = await invokeWebhook(payload, badSig);

    expect(status).toBe(400);
    expect(body as string).toMatch(/Signature invalide/);

    const doc = await getEventDoc(eventId);
    expect(doc).toBeNull();
  });

  test("payload ALTÉRÉ après signature => 400, aucune écriture", async () => {
    const eventId = "evt_sig_tampered_001";
    const originalPayload = buildStripeEventPayload(eventId, "some.unhandled.event", { amount: 1000 });
    const sig = signPayload(originalPayload);
    // Le payload envoyé diffère de celui signé (falsification en transit) —
    // la signature ne correspond plus au corps réellement reçu.
    const tamperedPayload = buildStripeEventPayload(eventId, "some.unhandled.event", { amount: 999999 });

    const { status, body } = await invokeWebhook(tamperedPayload, sig);

    expect(status).toBe(400);
    expect(body as string).toMatch(/Signature invalide/);

    const doc = await getEventDoc(eventId);
    expect(doc).toBeNull();
  });

  test("fournisseur non configuré => 503", async () => {
    setPaymentProviderForTesting(null); // repli sur getPaymentProvider() réel
    // Sans STRIPE_SECRET_KEY (Secret Manager) disponible dans l'environnement
    // de test, getPaymentProvider() renvoie NotConfiguredPaymentProvider.
    const eventId = "evt_no_provider_001";
    const payload = buildStripeEventPayload(eventId, "some.unhandled.event", {});
    const sig = signPayload(payload);

    const { status, body } = await invokeWebhook(payload, sig);

    expect(status).toBe(503);
    expect(body as string).toMatch(/non configuré/);

    // Restaure le provider de test pour les tests suivants.
    setPaymentProviderForTesting(new StripeProvider(TEST_SECRET_KEY, TEST_WEBHOOK_SECRET));

    const doc = await getEventDoc(eventId);
    expect(doc).toBeNull();
  });

  // ---------------------------------------------------------------------
  // 2. Idempotence : doublon, déjà processed, erreur temporaire + retry
  // ---------------------------------------------------------------------

  test("évènement DUPLIQUÉ (même event.id rejoué deux fois) => 1 seul traitement effectif", async () => {
    const eventId = "evt_duplicate_001";
    const missionId = "webhook_mission_dup";
    const paymentId = "webhook_payment_dup";
    await seedPayment(paymentId, missionId, { providerPaymentIntentId: "pi_dup_001" });

    const payload = buildStripeEventPayload(eventId, "payment_intent.succeeded", { id: "pi_dup_001" });
    const sig = signPayload(payload);

    const first = await invokeWebhook(payload, sig);
    expect(first.status).toBe(200);
    expect(first.body).toEqual({ received: true });

    const second = await invokeWebhook(payload, sig);
    expect(second.status).toBe(200);
    expect(second.body).toEqual({ received: true, alreadyProcessed: true });

    const doc = await getEventDoc(eventId);
    expect(doc!.processing_status).toBe("processed");
    expect(doc!.attempt_count).toBe(1); // jamais incrémenté après un succès

    // Un seul audit_log "webhook_event_processed" pour cet évènement —
    // aucun doublon d'effet.
    const auditSnap = await db
      .collection("audit_logs")
      .where("target_id", "==", eventId)
      .where("action", "==", "webhook_event_processed")
      .get();
    expect(auditSnap.size).toBe(1);

    await cleanupAll({ eventIds: [eventId], paymentIds: [paymentId], missionIds: [missionId] });
  });

  // ---------------------------------------------------------------------
  // BLOC N (Phase 6) — Extension ciblée : idempotence RÉELLEMENT
  // CONCURRENTE (Promise.allSettled, pas 2 appels séquentiels comme le
  // test ci-dessus) sur le MÊME provider_event_id, avec preuve explicite
  // qu'AUCUN doublon d'effet métier n'est produit.
  //
  // Note architecturale (voir dispatchStripeEvent(), branche
  // payment_intent.succeeded, processStripeWebhook.ts:96-140) : cette
  // branche ne fait QUE journaliser un audit_log — elle n'appelle JAMAIS
  // PaymentProvider (le webhook confirme un état déjà obtenu par un appel
  // synchrone antérieur, il ne réexécute jamais capturePayment). Fabriquer
  // artificiellement un comptage `jest.spyOn` sur le PaymentProvider ici
  // serait donc trompeur — conformément à la directive, la preuve
  // d'idempotence porte ici sur le nombre d'ÉCRITURES MÉTIER (audit_logs +
  // provider_webhook_events.attempt_count), qui est le seul effet de bord
  // réel de ce chemin.
  // ---------------------------------------------------------------------
  test("WEBHOOK DUPLIQUÉ CONCURRENT (Promise.allSettled, même provider_event_id) => 1 seul traitement métier effectif (1 audit_log, attempt_count=1)", async () => {
    const eventId = "evt_duplicate_concurrent_001";
    const missionId = "webhook_mission_dup_concurrent";
    const paymentId = "webhook_payment_dup_concurrent";
    await seedPayment(paymentId, missionId, { providerPaymentIntentId: "pi_dup_concurrent_001" });

    const payload = buildStripeEventPayload(eventId, "payment_intent.succeeded", {
      id: "pi_dup_concurrent_001",
    });
    const sig = signPayload(payload);

    // Deux requêtes HTTP RÉELLEMENT concurrentes portant le MÊME
    // provider_event_id — la garde d'idempotence est le get-or-create
    // transactionnel sur provider_webhook_events/{event.id} (voir
    // processStripeWebhook.ts, avant dispatchStripeEvent()).
    const [first, second] = await Promise.all([invokeWebhook(payload, sig), invokeWebhook(payload, sig)]);

    // 🔒 Assertion CRITIQUE : les deux requêtes HTTP renvoient 200 (aucune
    // ne doit jamais échouer côté client à cause de la concurrence), mais
    // au plus une seule doit avoir réellement exécuté le dispatch.
    expect(first.status).toBe(200);
    expect(second.status).toBe(200);
    const bodies = [first.body, second.body] as { received: boolean; alreadyProcessed?: boolean }[];
    const freshCount = bodies.filter((b) => !b.alreadyProcessed).length;
    const alreadyProcessedCount = bodies.filter((b) => b.alreadyProcessed === true).length;
    // Exactement un seul traitement "frais", l'autre observe alreadyProcessed
    // (l'ordre exact d'arrivée n'est pas déterministe, seul le COMPTE l'est).
    expect(freshCount).toBe(1);
    expect(alreadyProcessedCount).toBe(1);

    const doc = await getEventDoc(eventId);
    expect(doc!.processing_status).toBe("processed");
    // 🔒 Preuve numérique explicite d'UN SEUL traitement effectif, malgré
    // la concurrence réelle des 2 requêtes HTTP.
    expect(doc!.attempt_count).toBe(1);

    // Un seul audit_log métier créé — aucun doublon financier/d'effet.
    const auditSnap = await db
      .collection("audit_logs")
      .where("target_id", "==", paymentId)
      .where("action", "==", "payment_captured")
      .get();
    expect(auditSnap.size).toBe(1);

    await cleanupAll({ eventIds: [eventId], paymentIds: [paymentId], missionIds: [missionId] });
  });

  test("évènement déjà `processed` (pré-existant en base) => 200 sans exécution", async () => {
    const eventId = "evt_already_processed_001";
    await db.collection("provider_webhook_events").doc(eventId).set({
      provider: "stripe",
      provider_event_id: eventId,
      event_type: "payment_intent.succeeded",
      received_at: admin.firestore.Timestamp.now(),
      processed_at: admin.firestore.Timestamp.now(),
      processing_status: "processed",
      attempt_count: 1,
      related_payment_id: null,
      related_payout_id: null,
      related_refund_id: null,
      related_dispute_id: null,
      related_mission_id: null,
    });

    // Ne seed AUCUN payment correspondant : si le handler tentait de
    // redispatcher, il ne trouverait rien de particulier à faire (mais
    // surtout on vérifie qu'aucun audit_log n'est créé, preuve qu'il n'y a
    // pas eu de second dispatch).
    const payload = buildStripeEventPayload(eventId, "payment_intent.succeeded", { id: "pi_ghost" });
    const sig = signPayload(payload);

    const { status, body } = await invokeWebhook(payload, sig);

    expect(status).toBe(200);
    expect(body).toEqual({ received: true, alreadyProcessed: true });

    const auditSnap = await db.collection("audit_logs").where("target_id", "==", eventId).get();
    expect(auditSnap.size).toBe(0);

    await cleanupAll({ eventIds: [eventId] });
  });

  test("évènement de type INCONNU => 200, ignoré, mais enregistré `processed`", async () => {
    const eventId = "evt_unknown_type_001";
    const payload = buildStripeEventPayload(eventId, "some.totally.unknown.event.type", { foo: "bar" });
    const sig = signPayload(payload);

    const { status, body } = await invokeWebhook(payload, sig);

    expect(status).toBe(200);
    expect(body).toEqual({ received: true });

    const doc = await getEventDoc(eventId);
    expect(doc!.processing_status).toBe("processed");
    expect(doc!.related_payment_id).toBeNull();
    expect(doc!.related_payout_id).toBeNull();
    expect(doc!.related_refund_id).toBeNull();
    expect(doc!.related_dispute_id).toBeNull();

    await cleanupAll({ eventIds: [eventId] });
  });

  test("erreur TEMPORAIRE lors du dispatch => 500, statut `failed`, puis RETRY réussi", async () => {
    // `charge.dispute.created` sans aucun `payments` correspondant lève
    // une erreur explicite dans dispatchStripeEvent() (voir
    // processStripeWebhook.ts: "Aucun payment trouvé pour
    // provider_charge_id=...") — utilisé ici comme scénario d'échec
    // temporaire déterministe et reproductible sans mock du réseau.
    const eventId = "evt_temp_error_001";
    const missionId = "webhook_mission_retry";
    const paymentId = "webhook_payment_retry";
    const chargeId = "ch_retry_001";
    const disputeId = "dp_retry_001";

    const payload = buildStripeEventPayload(eventId, "charge.dispute.created", {
      id: disputeId,
      charge: chargeId,
      amount: 1500,
      reason: "fraudulent",
      status: "warning_needs_response",
    });
    const sig = signPayload(payload);

    // ---- 1er appel : le payment n'existe pas encore => échec temporaire ----
    const first = await invokeWebhook(payload, sig);
    expect(first.status).toBe(500);
    const firstBody = first.body as { received: boolean; error: string };
    expect(firstBody.received).toBe(false);
    expect(firstBody.error).toMatch(/Aucun payment trouvé/);

    const docAfterFailure = await getEventDoc(eventId);
    expect(docAfterFailure!.processing_status).toBe("failed");
    expect(docAfterFailure!.attempt_count).toBe(1);
    expect(docAfterFailure!.last_error).toMatch(/Aucun payment trouvé/);

    const failAudit = await db
      .collection("audit_logs")
      .where("target_id", "==", eventId)
      .where("action", "==", "webhook_event_failed")
      .get();
    expect(failAudit.size).toBe(1);

    // ---- Correction de la condition d'échec (le payment est créé) ----
    await seedPayment(paymentId, missionId, { providerChargeId: chargeId });

    // ---- 2e appel (RETRY, même event.id) : doit maintenant réussir ----
    const second = await invokeWebhook(payload, sig);
    expect(second.status).toBe(200);
    expect(second.body).toEqual({ received: true });

    const docAfterRetry = await getEventDoc(eventId);
    expect(docAfterRetry!.processing_status).toBe("processed");
    // attempt_count incrémenté lors de la nouvelle tentative (2e passage).
    expect(docAfterRetry!.attempt_count).toBe(2);
    expect(docAfterRetry!.related_dispute_id).toBe(disputeId);
    expect(docAfterRetry!.related_payment_id).toBe(paymentId);

    // Le litige a bien été créé UNE SEULE FOIS malgré les deux passages
    // (openDispute() est idempotent sur l'ID du document = provider_dispute_id).
    const disputeSnap = await db.collection("disputes").doc(disputeId).get();
    expect(disputeSnap.exists).toBe(true);
    expect(disputeSnap.data()!.status).toBe(DisputeStatuses.OPENED);

    const chargebackFeeSnap = await db
      .collection("transaction_ledger")
      .where("mission_id", "==", missionId)
      .where("type", "==", "chargeback_fee")
      .get();
    expect(chargebackFeeSnap.size).toBe(1); // aucun doublon ledger

    await cleanupAll({
      eventIds: [eventId],
      paymentIds: [paymentId],
      missionIds: [missionId],
      disputeIds: [disputeId],
    });
  });

  // ---------------------------------------------------------------------
  // 3. Dispatch métier par type d'évènement
  // ---------------------------------------------------------------------

  test("payment_intent.succeeded => audit + related_payment_id/related_mission_id", async () => {
    const eventId = "evt_pi_succeeded_001";
    const missionId = "webhook_mission_pi_ok";
    const paymentId = "webhook_payment_pi_ok";
    await seedPayment(paymentId, missionId, { providerPaymentIntentId: "pi_ok_001" });

    const payload = buildStripeEventPayload(eventId, "payment_intent.succeeded", { id: "pi_ok_001" });
    const sig = signPayload(payload);

    const { status } = await invokeWebhook(payload, sig);
    expect(status).toBe(200);

    const doc = await getEventDoc(eventId);
    expect(doc!.related_payment_id).toBe(paymentId);
    expect(doc!.related_mission_id).toBe(missionId);

    const auditSnap = await db
      .collection("audit_logs")
      .where("target_id", "==", paymentId)
      .where("action", "==", "payment_captured")
      .get();
    expect(auditSnap.size).toBe(1);

    await cleanupAll({ eventIds: [eventId], paymentIds: [paymentId], missionIds: [missionId] });
  });

  test("payment_intent.payment_failed => audit payment_failed", async () => {
    const eventId = "evt_pi_failed_001";
    const missionId = "webhook_mission_pi_fail";
    const paymentId = "webhook_payment_pi_fail";
    await seedPayment(paymentId, missionId, { providerPaymentIntentId: "pi_fail_001" });

    const payload = buildStripeEventPayload(eventId, "payment_intent.payment_failed", { id: "pi_fail_001" });
    const sig = signPayload(payload);

    const { status } = await invokeWebhook(payload, sig);
    expect(status).toBe(200);

    const auditSnap = await db
      .collection("audit_logs")
      .where("target_id", "==", paymentId)
      .where("action", "==", "payment_failed")
      .get();
    expect(auditSnap.size).toBe(1);

    await cleanupAll({ eventIds: [eventId], paymentIds: [paymentId], missionIds: [missionId] });
  });

  test("charge.refund.updated (succeeded) => related_refund_id/related_payment_id + audit refund_succeeded", async () => {
    const eventId = "evt_refund_updated_001";
    const missionId = "webhook_mission_refund";
    const paymentId = "webhook_payment_refund";
    const refundId = "webhook_refund_001";
    const providerRefundId = "re_webhook_001";
    await seedPayment(paymentId, missionId, { providerPaymentIntentId: "pi_refund_001" });
    await seedRefund(refundId, paymentId, missionId, providerRefundId);

    const payload = buildStripeEventPayload(eventId, "charge.refund.updated", {
      id: providerRefundId,
      payment_intent: "pi_refund_001",
      status: "succeeded",
    });
    const sig = signPayload(payload);

    const { status } = await invokeWebhook(payload, sig);
    expect(status).toBe(200);

    const doc = await getEventDoc(eventId);
    expect(doc!.related_refund_id).toBe(refundId);
    expect(doc!.related_payment_id).toBe(paymentId);

    const auditSnap = await db
      .collection("audit_logs")
      .where("target_id", "==", refundId)
      .where("action", "==", "refund_succeeded")
      .get();
    expect(auditSnap.size).toBe(1);

    await cleanupAll({ eventIds: [eventId], paymentIds: [paymentId], missionIds: [missionId], refundIds: [refundId] });
  });

  test("payout.paid => related_payout_id + audit payout_paid", async () => {
    const eventId = "evt_payout_paid_001";
    const payoutId = "webhook_payout_paid_001";
    const providerPayoutId = "po_webhook_paid_001";
    await seedPayout(payoutId, providerPayoutId);

    const payload = buildStripeEventPayload(eventId, "payout.paid", { id: providerPayoutId, status: "paid" });
    const sig = signPayload(payload);

    const { status } = await invokeWebhook(payload, sig);
    expect(status).toBe(200);

    const doc = await getEventDoc(eventId);
    expect(doc!.related_payout_id).toBe(payoutId);

    const auditSnap = await db
      .collection("audit_logs")
      .where("target_id", "==", payoutId)
      .where("action", "==", "payout_paid")
      .get();
    expect(auditSnap.size).toBe(1);

    await cleanupAll({ eventIds: [eventId], payoutIds: [payoutId] });
  });

  test("payout.failed => related_payout_id + audit payout_failed", async () => {
    const eventId = "evt_payout_failed_001";
    const payoutId = "webhook_payout_failed_001";
    const providerPayoutId = "po_webhook_failed_001";
    await seedPayout(payoutId, providerPayoutId);

    const payload = buildStripeEventPayload(eventId, "payout.failed", { id: providerPayoutId, status: "failed" });
    const sig = signPayload(payload);

    const { status } = await invokeWebhook(payload, sig);
    expect(status).toBe(200);

    const auditSnap = await db
      .collection("audit_logs")
      .where("target_id", "==", payoutId)
      .where("action", "==", "payout_failed")
      .get();
    expect(auditSnap.size).toBe(1);

    await cleanupAll({ eventIds: [eventId], payoutIds: [payoutId] });
  });

  test("charge.dispute.created => crée disputes/{id}, payment -> DISPUTED, ledger CHARGEBACK_FEE", async () => {
    const eventId = "evt_dispute_created_001";
    const missionId = "webhook_mission_dispute_created";
    const paymentId = "webhook_payment_dispute_created";
    const chargeId = "ch_dispute_created_001";
    const disputeId = "dp_created_001";
    await seedPayment(paymentId, missionId, { providerChargeId: chargeId });

    const payload = buildStripeEventPayload(eventId, "charge.dispute.created", {
      id: disputeId,
      charge: chargeId,
      amount: 2500,
      reason: "fraudulent",
      status: "warning_needs_response",
    });
    const sig = signPayload(payload);

    const { status } = await invokeWebhook(payload, sig);
    expect(status).toBe(200);

    const disputeSnap = await db.collection("disputes").doc(disputeId).get();
    expect(disputeSnap.exists).toBe(true);
    expect(disputeSnap.data()!.status).toBe(DisputeStatuses.OPENED);
    expect(disputeSnap.data()!.mission_id).toBe(missionId);

    const paySnap = await db.collection("payments").doc(paymentId).get();
    expect(paySnap.data()!.status).toBe(PaymentStatuses.DISPUTED);

    const ledgerSnap = await db
      .collection("transaction_ledger")
      .where("mission_id", "==", missionId)
      .where("type", "==", "chargeback_fee")
      .get();
    expect(ledgerSnap.size).toBe(1);

    // Rejouer le MÊME évènement (nouvel event.id Stripe mais même
    // provider_dispute_id — cas réel d'un webhook redélivré avec un ID
    // d'évènement différent) ne doit jamais dupliquer le litige ni le frais.
    const eventId2 = "evt_dispute_created_001_replay";
    const payload2 = buildStripeEventPayload(eventId2, "charge.dispute.created", {
      id: disputeId,
      charge: chargeId,
      amount: 2500,
      reason: "fraudulent",
      status: "warning_needs_response",
    });
    const sig2 = signPayload(payload2);
    const replay = await invokeWebhook(payload2, sig2);
    expect(replay.status).toBe(200);

    const ledgerSnapAfterReplay = await db
      .collection("transaction_ledger")
      .where("mission_id", "==", missionId)
      .where("type", "==", "chargeback_fee")
      .get();
    expect(ledgerSnapAfterReplay.size).toBe(1); // toujours 1, jamais 2

    await cleanupAll({
      eventIds: [eventId, eventId2],
      paymentIds: [paymentId],
      missionIds: [missionId],
      disputeIds: [disputeId],
    });
  });

  test("charge.dispute.updated (under_review) => disputes/{id}.status mis à jour", async () => {
    const missionId = "webhook_mission_dispute_updated";
    const paymentId = "webhook_payment_dispute_updated";
    const chargeId = "ch_dispute_updated_001";
    const disputeId = "dp_updated_001";
    await seedPayment(paymentId, missionId, { providerChargeId: chargeId });

    // Ouverture préalable.
    const createdEventId = "evt_dispute_updated_created_001";
    const createdPayload = buildStripeEventPayload(createdEventId, "charge.dispute.created", {
      id: disputeId,
      charge: chargeId,
      amount: 1800,
      reason: "duplicate",
      status: "warning_needs_response",
    });
    await invokeWebhook(createdPayload, signPayload(createdPayload));

    // Mise à jour vers under_review.
    const updatedEventId = "evt_dispute_updated_001";
    const updatedPayload = buildStripeEventPayload(updatedEventId, "charge.dispute.updated", {
      id: disputeId,
      charge: chargeId,
      amount: 1800,
      reason: "duplicate",
      status: "under_review",
    });
    const { status } = await invokeWebhook(updatedPayload, signPayload(updatedPayload));
    expect(status).toBe(200);

    const disputeSnap = await db.collection("disputes").doc(disputeId).get();
    expect(disputeSnap.data()!.status).toBe(DisputeStatuses.UNDER_REVIEW);

    await cleanupAll({
      eventIds: [createdEventId, updatedEventId],
      paymentIds: [paymentId],
      missionIds: [missionId],
      disputeIds: [disputeId],
    });
  });

  test("charge.dispute.closed (won) => WON puis CLOSED dans le même évènement, ledger CHARGEBACK_WON, payment -> CAPTURED", async () => {
    const missionId = "webhook_mission_dispute_closed_won";
    const paymentId = "webhook_payment_dispute_closed_won";
    const chargeId = "ch_dispute_closed_won_001";
    const disputeId = "dp_closed_won_001";
    await seedPayment(paymentId, missionId, { providerChargeId: chargeId });

    // Ouverture préalable.
    const createdEventId = "evt_dispute_closed_won_created_001";
    const createdPayload = buildStripeEventPayload(createdEventId, "charge.dispute.created", {
      id: disputeId,
      charge: chargeId,
      amount: 3000,
      reason: "fraudulent",
      status: "warning_needs_response",
    });
    await invokeWebhook(createdPayload, signPayload(createdPayload));

    // Stripe envoie directement "closed" avec status="won" déjà positionné
    // (comportement réel documenté : le statut final est déjà présent dans
    // l'objet dispute au moment de l'évènement "closed" — voir le bug
    // corrigé cette session dans processStripeWebhook.ts).
    const closedEventId = "evt_dispute_closed_won_001";
    const closedPayload = buildStripeEventPayload(closedEventId, "charge.dispute.closed", {
      id: disputeId,
      charge: chargeId,
      amount: 3000,
      reason: "fraudulent",
      status: "won",
    });
    const { status } = await invokeWebhook(closedPayload, signPayload(closedPayload));
    expect(status).toBe(200);

    const disputeSnap = await db.collection("disputes").doc(disputeId).get();
    expect(disputeSnap.data()!.status).toBe(DisputeStatuses.CLOSED);
    expect(disputeSnap.data()!.closed_at).not.toBeNull();
    expect(disputeSnap.data()!.resolved_at).not.toBeNull();

    const paySnap = await db.collection("payments").doc(paymentId).get();
    expect(paySnap.data()!.status).toBe(PaymentStatuses.CAPTURED);

    const wonLedgerSnap = await db
      .collection("transaction_ledger")
      .where("mission_id", "==", missionId)
      .where("type", "==", "chargeback_won")
      .get();
    expect(wonLedgerSnap.size).toBe(1);

    await cleanupAll({
      eventIds: [createdEventId, closedEventId],
      paymentIds: [paymentId],
      missionIds: [missionId],
      disputeIds: [disputeId],
    });
  });

  // ---------------------------------------------------------------------
  // 6. account.updated (GAP-8B-01, Bloc 8B) — synchronisation onboarding
  //    Stripe Connect chauffeur (stripe_charges_enabled/stripe_payouts_enabled)
  // ---------------------------------------------------------------------
  test("account.updated => synchronise stripe_charges_enabled/stripe_payouts_enabled sur driver_profiles", async () => {
    const driverId = "webhook_driver_account_updated_001";
    const connectedAccountId = "acct_webhook_account_updated_001";
    await seedDriverProfile(driverId, connectedAccountId, { chargesEnabled: false, payoutsEnabled: false });

    const eventId = "evt_account_updated_001";
    const payload = buildStripeEventPayload(eventId, "account.updated", {
      id: connectedAccountId,
      charges_enabled: true,
      payouts_enabled: true,
      metadata: { movik_driver_id: driverId },
    });
    const { status } = await invokeWebhook(payload, signPayload(payload));
    expect(status).toBe(200);

    const driverSnap = await db.collection("driver_profiles").doc(driverId).get();
    expect(driverSnap.data()!.stripe_charges_enabled).toBe(true);
    expect(driverSnap.data()!.stripe_payouts_enabled).toBe(true);

    const eventDoc = await getEventDoc(eventId);
    expect(eventDoc!.related_driver_id).toBe(driverId);

    await cleanupAll({ eventIds: [eventId], driverProfileIds: [driverId] });
  });

  test("account.updated rejoué (même event.id) => idempotent, aucune double écriture/audit", async () => {
    const driverId = "webhook_driver_account_updated_002";
    const connectedAccountId = "acct_webhook_account_updated_002";
    await seedDriverProfile(driverId, connectedAccountId, { chargesEnabled: false, payoutsEnabled: false });

    const eventId = "evt_account_updated_002";
    const payload = buildStripeEventPayload(eventId, "account.updated", {
      id: connectedAccountId,
      charges_enabled: true,
      payouts_enabled: false,
      metadata: { movik_driver_id: driverId },
    });
    await invokeWebhook(payload, signPayload(payload));
    const { status } = await invokeWebhook(payload, signPayload(payload));
    expect(status).toBe(200);

    const driverSnap = await db.collection("driver_profiles").doc(driverId).get();
    expect(driverSnap.data()!.stripe_charges_enabled).toBe(true);
    expect(driverSnap.data()!.stripe_payouts_enabled).toBe(false);

    await cleanupAll({ eventIds: [eventId], driverProfileIds: [driverId] });
  });

  test("account.updated avec metadata.movik_driver_id pointant vers un profil dont le compte connecté diffère => IGNORÉ (pas d'écrasement)", async () => {
    const driverId = "webhook_driver_account_updated_003";
    const realConnectedAccountId = "acct_webhook_account_updated_003_real";
    const spoofedConnectedAccountId = "acct_webhook_account_updated_003_spoofed";
    await seedDriverProfile(driverId, realConnectedAccountId, { chargesEnabled: false, payoutsEnabled: false });

    const eventId = "evt_account_updated_003";
    const payload = buildStripeEventPayload(eventId, "account.updated", {
      id: spoofedConnectedAccountId,
      charges_enabled: true,
      payouts_enabled: true,
      metadata: { movik_driver_id: driverId },
    });
    const { status } = await invokeWebhook(payload, signPayload(payload));
    expect(status).toBe(200);

    const driverSnap = await db.collection("driver_profiles").doc(driverId).get();
    expect(driverSnap.data()!.stripe_charges_enabled).toBe(false);
    expect(driverSnap.data()!.stripe_payouts_enabled).toBe(false);

    await cleanupAll({ eventIds: [eventId], driverProfileIds: [driverId] });
  });

  test("account.updated sans metadata.movik_driver_id => IGNORÉ proprement (200, aucun crash)", async () => {
    const eventId = "evt_account_updated_004";
    const payload = buildStripeEventPayload(eventId, "account.updated", {
      id: "acct_webhook_account_updated_004_orphan",
      charges_enabled: true,
      payouts_enabled: true,
    });
    const { status } = await invokeWebhook(payload, signPayload(payload));
    expect(status).toBe(200);

    await cleanupAll({ eventIds: [eventId] });
  });
});
