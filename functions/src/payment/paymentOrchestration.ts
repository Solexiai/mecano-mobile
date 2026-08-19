// -----------------------------------------------------------------------------
// paymentOrchestration.ts — Orchestre les appels PaymentProvider (Stripe) qui
// DOIVENT s'exécuter HORS d'une transaction Firestore.
//
// 🔒 RAISON CRITIQUE : `db.runTransaction()` peut RÉESSAYER automatiquement
// tout son callback en cas de contention (ré-exécution complète, pas
// seulement un "retry réseau"). Si un appel Stripe (I/O externe, effet de
// bord réel : débit carte, virement) se trouvait DANS le callback, une
// contention Firestore anodine pourrait déclencher un DOUBLE appel Stripe.
// C'est pourquoi CHAQUE fonction ci-dessous suit le même schéma en 3 temps :
//
//   1. Transaction Firestore n°1 — lit l'état actuel, écrit un état
//      "intermédiaire" (ex: CREATED, CAPTURE_PENDING) + fige un
//      `idempotencyKey` déterministe. Aucun appel réseau ici.
//   2. Appel(s) PaymentProvider RÉELS, HORS transaction, protégés par cet
//      idempotencyKey (Stripe lui-même déduplique si l'appel est répété).
//   3. Transaction Firestore n°2 — relit l'état, applique le résultat
//      (succès -> état terminal ; échec -> état terminal FAILED +
//      compensation métier), toujours via
//      `assertValidPaymentTransition()`.
//
// Si l'étape 2 échoue avant de renvoyer un résultat (crash de la fonction,
// timeout réseau), l'état reste bloqué en intermédiaire — c'est INTENTIONNEL
// et détectable (reconciliation engine, point 27) plutôt que de deviner un
// résultat. Un admin peut relancer l'opération : le MÊME idempotencyKey est
// reconstruit de façon déterministe à partir du paymentId, donc relancer ne
// crée jamais un double mouvement d'argent chez Stripe.
// -----------------------------------------------------------------------------

import { admin, db } from "../lib/admin";
import { buildIdempotencyKey } from "../lib/idempotency";
import { assertValidPaymentTransition } from "../lib/paymentStateMachine";
import { assertValidPayoutTransition } from "../lib/payoutStateMachine";
import {
  DriverPayoutDoc,
  DriverProfileDoc,
  MissionStatuses,
  PaymentDoc,
  PaymentStatuses,
  PayoutStatuses,
} from "../lib/types";
import { getPaymentProvider } from "./paymentProviderFactory";
import { toMinorUnits, DEFAULT_CURRENCY } from "../lib/money";

export interface CreateAndAuthorizePaymentInput {
  missionId: string;
  customerId: string;
  driverId: string;
  customerTotalMajor: number; // dollars (frontière avec le pricingEngine legacy)
  applicationFeeMajor: number; // commission + frais de service, en dollars
}

export interface CreateAndAuthorizePaymentOutcome {
  paymentId: string;
  status: string;
  success: boolean;
  failureMessage?: string | null;
}

/**
 * Appelée par `acceptDelivery()` APRÈS que sa transaction principale (mission
 * assignée + financial_snapshot pending) ait déjà commité. Crée le
 * `payments/{id}`, autorise le paiement chez le fournisseur, puis écrit le
 * résultat. En cas d'échec d'autorisation (carte refusée, etc.), la mission
 * est basculée en `payment_failed` et désassignée — voir
 * MissionStatuses.PAYMENT_FAILED (types.ts).
 */
export async function createAndAuthorizeMissionPayment(
  input: CreateAndAuthorizePaymentInput
): Promise<CreateAndAuthorizePaymentOutcome> {
  const { missionId, customerId, driverId, customerTotalMajor, applicationFeeMajor } = input;

  const paymentProfileSnap = await db.collection("payment_profiles").doc(customerId).get();
  if (!paymentProfileSnap.exists) {
    // Ne devrait jamais arriver si createDeliveryRequest() a bien validé le
    // profil de paiement — filet de sécurité défensif.
    return await failMissionPayment(missionId, null, "missing_payment_profile", "Aucun profil de paiement client.");
  }
  const paymentProfile = paymentProfileSnap.data()!;
  if (!paymentProfile.default_payment_method_id) {
    return await failMissionPayment(
      missionId,
      null,
      "missing_default_payment_method",
      "Aucun moyen de paiement par défaut enregistré."
    );
  }

  const driverSnap = await db.collection("driver_profiles").doc(driverId).get();
  const driver = driverSnap.data() as DriverProfileDoc | undefined;
  const connectedAccountId = driver?.stripe_connected_account_id ?? null;

  const amountMinor = toMinorUnits(customerTotalMajor, DEFAULT_CURRENCY);
  const applicationFeeMinor = toMinorUnits(applicationFeeMajor, DEFAULT_CURRENCY);

  // ---- Étape 1 : Transaction Firestore — crée payments/{id} en CREATED ----
  const paymentRef = db.collection("payments").doc();
  const paymentId = paymentRef.id;
  const createIdempotencyKey = buildIdempotencyKey("createPayment", paymentId);
  const authorizeIdempotencyKey = buildIdempotencyKey("authorizePayment", paymentId);

  await db.runTransaction(async (tx) => {
    const missionRef = db.collection("delivery_requests").doc(missionId);
    const missionSnap = await tx.get(missionRef);
    if (!missionSnap.exists) throw new Error(`Mission ${missionId} introuvable.`);

    const now = admin.firestore.Timestamp.now();
    // 🔒 Le document est créé DIRECTEMENT en AUTHORIZATION_PENDING (et non
    // CREATED) car l'étape 2 ci-dessous va IMMÉDIATEMENT tenter l'appel
    // provider.createPayment()+authorizePayment() — voir la machine d'état
    // (paymentStateMachine.ts) : CREATED n'autorise PAS de transition directe
    // vers AUTHORIZED (elle doit transiter par AUTHORIZATION_PENDING).
    // AUTHORIZATION_PENDING -> AUTHORIZED et AUTHORIZATION_PENDING -> FAILED
    // sont toutes deux des transitions valides, ce qui couvre les deux
    // issues possibles de l'étape 2.
    const payment: PaymentDoc = {
      payment_id: paymentId,
      mission_id: missionId,
      customer_id: customerId,
      driver_id: driverId,
      status: PaymentStatuses.AUTHORIZATION_PENDING,
      currency: DEFAULT_CURRENCY,
      amount_authorized_minor: 0,
      amount_captured_minor: 0,
      amount_refunded_minor: 0,
      application_fee_minor: applicationFeeMinor,
      provider: "stripe",
      provider_customer_id: paymentProfile.provider_customer_id,
      provider_payment_method_id: paymentProfile.default_payment_method_id,
      provider_payment_intent_id: null,
      provider_charge_id: null,
      connected_account_id: connectedAccountId,
      idempotency_key: createIdempotencyKey,
      authorized_at: null,
      authorization_expires_at: null,
      captured_at: null,
      cancelled_at: null,
      failed_at: null,
      failure_code: null,
      failure_message: null,
      created_at: now,
      updated_at: now,
    };
    tx.set(paymentRef, payment);
    tx.update(missionRef, {
      active_payment_id: paymentId,
      payment_status: PaymentStatuses.AUTHORIZATION_PENDING,
    });
  });

  // ---- Étape 2 : appels Stripe RÉELS, hors transaction ----
  const provider = getPaymentProvider();
  try {
    const created = await provider.createPayment({
      providerCustomerId: paymentProfile.provider_customer_id,
      providerPaymentMethodId: paymentProfile.default_payment_method_id,
      amountMinor,
      currency: DEFAULT_CURRENCY,
      connectedAccountId,
      applicationFeeMinor,
      idempotencyKey: createIdempotencyKey,
      metadata: { movik_mission_id: missionId, movik_payment_id: paymentId },
    });

    const authorized = await provider.authorizePayment({
      providerPaymentIntentId: created.providerPaymentIntentId,
      idempotencyKey: authorizeIdempotencyKey,
    });

    if (!authorized.success) {
      return await failMissionPayment(
        missionId,
        paymentId,
        authorized.failureCode ?? "authorization_failed",
        authorized.failureMessage ?? "Autorisation refusée par le fournisseur de paiement.",
        created.providerPaymentIntentId
      );
    }

    // ---- Étape 3 : Transaction Firestore — applique le succès ----
    await db.runTransaction(async (tx) => {
      const missionRef = db.collection("delivery_requests").doc(missionId);
      const payRef = db.collection("payments").doc(paymentId);
      const [missionSnap, paySnap] = await Promise.all([tx.get(missionRef), tx.get(payRef)]);
      if (!paySnap.exists) throw new Error(`payments/${paymentId} introuvable.`);
      const current = paySnap.data() as PaymentDoc;
      assertValidPaymentTransition(current.status, PaymentStatuses.AUTHORIZED);

      const now = admin.firestore.Timestamp.now();
      tx.update(payRef, {
        status: PaymentStatuses.AUTHORIZED,
        amount_authorized_minor: amountMinor,
        provider_payment_intent_id: created.providerPaymentIntentId,
        authorized_at: now,
        updated_at: now,
      });
      if (missionSnap.exists) {
        tx.update(missionRef, { payment_status: PaymentStatuses.AUTHORIZED });
      }
    });

    return { paymentId, status: PaymentStatuses.AUTHORIZED, success: true };
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return await failMissionPayment(missionId, paymentId, "provider_error", message);
  }
}

/**
 * Compensation : bascule la mission en `payment_failed` (jamais réassignée
 * automatiquement — voir commentaire sur MissionStatuses.PAYMENT_FAILED) et
 * marque `payments/{id}` FAILED si le document existe déjà.
 */
async function failMissionPayment(
  missionId: string,
  paymentId: string | null,
  failureCode: string,
  failureMessage: string,
  providerPaymentIntentId: string | null = null
): Promise<CreateAndAuthorizePaymentOutcome> {
  await db.runTransaction(async (tx) => {
    const missionRef = db.collection("delivery_requests").doc(missionId);
    const missionSnap = await tx.get(missionRef);
    if (!missionSnap.exists) return;
    const mission = missionSnap.data()!;
    const driverId = mission.driver_id as string | null;

    let payRef: FirebaseFirestore.DocumentReference | null = null;
    let paySnap: FirebaseFirestore.DocumentSnapshot | null = null;
    if (paymentId) {
      payRef = db.collection("payments").doc(paymentId);
      paySnap = await tx.get(payRef);
    }

    const now = admin.firestore.Timestamp.now();

    if (payRef && paySnap && paySnap.exists) {
      const current = paySnap.data() as PaymentDoc;
      if (!["failed", "cancelled"].includes(current.status)) {
        assertValidPaymentTransition(current.status, PaymentStatuses.FAILED);
      }
      tx.update(payRef, {
        status: PaymentStatuses.FAILED,
        provider_payment_intent_id: providerPaymentIntentId ?? current.provider_payment_intent_id,
        failed_at: now,
        failure_code: failureCode,
        failure_message: failureMessage,
        updated_at: now,
      });
    }

    tx.update(missionRef, {
      status: MissionStatuses.PAYMENT_FAILED,
      payment_status: PaymentStatuses.FAILED,
      driver_id: null,
      driver_display_name: null,
    });

    if (driverId) {
      const driverRef = db.collection("driver_profiles").doc(driverId);
      tx.update(driverRef, { online_status: "online" });
      tx.set(db.collection("driver_locations").doc(driverId), { active_delivery_id: null }, { merge: true });
    }

    const eventRef = missionRef.collection("tracking_events").doc();
    tx.set(eventRef, {
      event_type: "payment_failed",
      actor_uid: "system",
      occurred_at: now,
      metadata: { failure_code: failureCode, failure_message: failureMessage },
    });
  });

  return {
    paymentId: paymentId ?? "",
    status: PaymentStatuses.FAILED,
    success: false,
    failureMessage,
  };
}

// -----------------------------------------------------------------------------
// Capture — appelée par completeDelivery() APRÈS que sa transaction
// principale (mission completed + snapshot confirmed + ledger) ait commité.
// -----------------------------------------------------------------------------

export interface CaptureOutcome {
  success: boolean;
  status: string;
  failureMessage?: string | null;
}

export async function captureMissionPayment(
  missionId: string,
  paymentId: string
): Promise<CaptureOutcome> {
  const payRef = db.collection("payments").doc(paymentId);

  // Étape 1 : transaction — CAPTURE_PENDING.
  const { providerPaymentIntentId, amountToCaptureMinor, idempotencyKey } = await db.runTransaction(
    async (tx) => {
      const paySnap = await tx.get(payRef);
      if (!paySnap.exists) throw new Error(`payments/${paymentId} introuvable.`);
      const payment = paySnap.data() as PaymentDoc;
      assertValidPaymentTransition(payment.status, PaymentStatuses.CAPTURE_PENDING);

      const key = buildIdempotencyKey("capturePayment", paymentId);
      tx.update(payRef, { status: PaymentStatuses.CAPTURE_PENDING, updated_at: admin.firestore.Timestamp.now() });

      return {
        providerPaymentIntentId: payment.provider_payment_intent_id!,
        amountToCaptureMinor: payment.amount_authorized_minor,
        idempotencyKey: key,
      };
    }
  );

  // Étape 2 : appel Stripe réel, hors transaction.
  const provider = getPaymentProvider();
  const result = await provider.capturePayment({
    providerPaymentIntentId,
    amountToCaptureMinor,
    idempotencyKey,
  });

  // Étape 3 : transaction — applique le résultat.
  await db.runTransaction(async (tx) => {
    const paySnap = await tx.get(payRef);
    if (!paySnap.exists) return;
    const payment = paySnap.data() as PaymentDoc;
    const now = admin.firestore.Timestamp.now();

    if (result.success) {
      assertValidPaymentTransition(payment.status, PaymentStatuses.CAPTURED);
      tx.update(payRef, {
        status: PaymentStatuses.CAPTURED,
        amount_captured_minor: result.amountCapturedMinor,
        provider_charge_id: result.providerChargeId,
        captured_at: now,
        updated_at: now,
      });
    } else {
      // 🔒 Cas grave documenté (marchandise déjà livrée, capture refusée) :
      // enregistré comme FAILED, jamais masqué. La réconciliation (point 27)
      // et le tableau de bord admin doivent le faire remonter comme anomalie
      // nécessitant une action de recouvrement manuelle.
      assertValidPaymentTransition(payment.status, PaymentStatuses.FAILED);
      tx.update(payRef, {
        status: PaymentStatuses.FAILED,
        failed_at: now,
        failure_code: result.failureMessage ? "capture_failed" : "capture_failed_unknown",
        failure_message: result.failureMessage ?? "Capture refusée par le fournisseur.",
        updated_at: now,
      });
    }

    const missionRef = db.collection("delivery_requests").doc(missionId);
    tx.update(missionRef, {
      payment_status: result.success ? PaymentStatuses.CAPTURED : PaymentStatuses.FAILED,
    });
  });

  return { success: result.success, status: result.status, failureMessage: result.failureMessage };
}

// -----------------------------------------------------------------------------
// Versement chauffeur — appelée par calculateDriverPayout.ts UNIQUEMENT quand
// le versement est déjà ELIGIBLE (payout_eligible_at <= now) et possède un
// connected_account_id valide. Suit le même schéma en 3 temps que
// createAndAuthorizeMissionPayment / captureMissionPayment ci-dessus :
// jamais d'appel PaymentProvider DANS une transaction Firestore.
// -----------------------------------------------------------------------------

export interface SubmitDriverPayoutOutcome {
  success: boolean;
  status: string;
  providerPayoutId?: string | null;
  failureMessage?: string | null;
}

/**
 * Fait transiter driver_payouts/{payoutId} de ELIGIBLE -> SCHEDULED ->
 * PROCESSING -> (PAID | FAILED), en appelant réellement
 * `PaymentProvider.createDriverPayout()` HORS transaction. Si
 * `connected_account_id` est absent (chauffeur pas encore onboardé Stripe
 * Connect), échoue proprement en FAILED sans jamais tenter l'appel —
 * jamais de simulation silencieuse d'un versement réussi.
 */
export async function submitDriverPayout(payoutId: string): Promise<SubmitDriverPayoutOutcome> {
  const payoutRef = db.collection("driver_payouts").doc(payoutId);

  // ---- Étape 1 : transaction — ELIGIBLE -> SCHEDULED -> PROCESSING ----
  type PreparedPayout = {
    amountMinor: number;
    currency: string;
    connectedAccountId: string;
    idempotencyKey: string;
  };
  let prepared: PreparedPayout | null = null;
  try {
    prepared = await db.runTransaction(async (tx) => {
      const snap = await tx.get(payoutRef);
      if (!snap.exists) throw new Error(`driver_payouts/${payoutId} introuvable.`);
      const payout = snap.data() as DriverPayoutDoc;

      if (!payout.connected_account_id) {
        assertValidPayoutTransition(payout.status, PayoutStatuses.FAILED);
        const now = admin.firestore.Timestamp.now();
        tx.update(payoutRef, {
          status: PayoutStatuses.FAILED,
          failed_at: now,
          failure_reason: "missing_connected_account",
        });
        throw new Error("MISSING_CONNECTED_ACCOUNT");
      }

      assertValidPayoutTransition(payout.status, PayoutStatuses.SCHEDULED);
      assertValidPayoutTransition(PayoutStatuses.SCHEDULED, PayoutStatuses.PROCESSING);

      const now = admin.firestore.Timestamp.now();
      tx.update(payoutRef, {
        status: PayoutStatuses.PROCESSING,
        scheduled_at: now,
        processing_at: now,
      });

      return {
        amountMinor: payout.amount_minor,
        currency: payout.currency,
        connectedAccountId: payout.connected_account_id,
        idempotencyKey: payout.idempotency_key,
      };
    });
  } catch (err) {
    if (err instanceof Error && err.message === "MISSING_CONNECTED_ACCOUNT") {
      return {
        success: false,
        status: PayoutStatuses.FAILED,
        failureMessage: "Aucun compte de versement connecté pour ce chauffeur.",
      };
    }
    throw err;
  }

  const { amountMinor, currency, connectedAccountId, idempotencyKey } = prepared;

  // ---- Étape 2 : appel Stripe réel, hors transaction ----
  const provider = getPaymentProvider();
  let result;
  try {
    result = await provider.createDriverPayout({
      connectedAccountId,
      amountMinor,
      currency: currency as typeof DEFAULT_CURRENCY,
      idempotencyKey,
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(payoutRef);
      if (!snap.exists) return;
      const payout = snap.data() as DriverPayoutDoc;
      if (isTerminalPayout(payout.status)) return;
      assertValidPayoutTransition(payout.status, PayoutStatuses.FAILED);
      tx.update(payoutRef, {
        status: PayoutStatuses.FAILED,
        failed_at: admin.firestore.Timestamp.now(),
        failure_reason: message,
      });
    });
    return { success: false, status: PayoutStatuses.FAILED, failureMessage: message };
  }

  // ---- Étape 3 : transaction — applique le résultat ----
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(payoutRef);
    if (!snap.exists) return;
    const payout = snap.data() as DriverPayoutDoc;
    const now = admin.firestore.Timestamp.now();

    if (result.success) {
      assertValidPayoutTransition(payout.status, PayoutStatuses.PAID);
      tx.update(payoutRef, {
        status: PayoutStatuses.PAID,
        provider_payout_id: result.providerPayoutId,
        paid_at: now,
      });
    } else {
      assertValidPayoutTransition(payout.status, PayoutStatuses.FAILED);
      tx.update(payoutRef, {
        status: PayoutStatuses.FAILED,
        provider_payout_id: result.providerPayoutId,
        failed_at: now,
        failure_reason: result.failureCode ?? "provider_payout_failed",
      });
    }
  });

  return {
    success: result.success,
    status: result.success ? PayoutStatuses.PAID : PayoutStatuses.FAILED,
    providerPayoutId: result.providerPayoutId,
    failureMessage: result.success ? null : (result.failureCode ?? "Versement refusé par le fournisseur."),
  };
}

function isTerminalPayout(status: string): boolean {
  return status === PayoutStatuses.PAID || status === PayoutStatuses.REVERSED;
}
