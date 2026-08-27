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
import { assertValidRefundTransition } from "../lib/refundStateMachine";
import { aborted, notFound } from "../lib/errors";
import {
  DriverPayoutDoc,
  DriverProfileDoc,
  LedgerDirections,
  LedgerEntryStatuses,
  LedgerEntryTypes,
  LedgerParties,
  MissionStatuses,
  PaymentDoc,
  PaymentStatuses,
  PayoutStatuses,
  RefundDoc,
  RefundReason,
  RefundStatuses,
} from "../lib/types";
import { getPaymentProvider } from "./paymentProviderFactory";
import { addMinor, subtractMinor, toMinorUnits, DEFAULT_CURRENCY } from "../lib/money";
import { recalculateMissionFinancialBalance } from "../lib/missionFinancialBalance";
import { writeAuditLog, writeAuditLogInTransaction } from "../lib/audit";
import {
  logFinancialFailure,
  logFinancialSuccess,
  resolveCorrelationId,
  startFinancialOperationTimer,
} from "../lib/observability";
import { RuntimeFlagKeys, isRuntimeFlagEnabled } from "../lib/runtimeFlags";

// 🔒 Phase 7, Bloc X — codes de failure_code INTERNES (jamais exposés au
// client, voir CreateAndAuthorizePaymentOutcome/SubmitDriverPayoutOutcome :
// seul `failureMessage`, un texte générique, est éventuellement propagé).
// Distincts de `KILL_SWITCH_ERROR_CODE` (lib/runtimeFlags.ts), qui est le
// code HttpsError renvoyé par les gardes SERVEUR (createDeliveryRequest.ts,
// acceptDelivery.ts) qui lèvent AVANT toute écriture — ici, à l'inverse, on
// doit journaliser un échec métier cohérent (payment_failed / payout FAILED)
// via la voie de compensation existante, pas lever une exception brute.
const PAYMENTS_KILL_SWITCH_FAILURE_CODE = "payments_disabled";
const PAYOUTS_KILL_SWITCH_FAILURE_CODE = "driver_payouts_disabled";

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
  // 🔒 BLOC I (observabilité) — un SEUL correlation_id pour toute l'opération
  // "création + autorisation" (create payment ET authorize payment), généré
  // ici car aucun correlationId entrant n'existe à ce point de la chaîne
  // (déclenché par acceptDelivery(), pas par un webhook/évènement externe).
  const correlationId = resolveCorrelationId(undefined);
  const operationStartedAt = startFinancialOperationTimer();

  // 🔒 Phase 7, Bloc X (X-8) — kill switch. OFF => aucune NOUVELLE
  // exposition financière client (nouvelle autorisation de paiement) n'est
  // créée. Vérifié AVANT toute écriture Firestore (aucun `payments/{id}`
  // n'est créé) — utilise la MÊME voie de compensation que les autres échecs
  // précoces (`failMissionPayment`) : la mission bascule en `payment_failed`
  // et est désassignée, exactement comme un refus d'autorisation ordinaire,
  // pour ne jamais laisser la mission dans un état incohérent "assignée mais
  // sans paiement". N'affecte JAMAIS refund/cancel/dispute/reversal — ces
  // chemins n'appellent pas cette fonction (voir refundPayment(),
  // cancelMissionPaymentAuthorization(), reverseDriverPayout() ci-dessous).
  if (!(await isRuntimeFlagEnabled(RuntimeFlagKeys.PAYMENTS_ENABLED))) {
    return await failMissionPayment(
      missionId,
      null,
      PAYMENTS_KILL_SWITCH_FAILURE_CODE,
      "Nouvelle autorisation de paiement temporairement indisponible.",
      null,
      { correlationId, operationStartedAt, operation: "create_payment" }
    );
  }

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

    // 🔒 BLOC H (catalogue d'évènements financiers) — journalise la création
    // RÉELLE du PaymentIntent côté provider (distinct de `payment_captured`/
    // `payment_failed` déjà audités via processStripeWebhook.ts). N'est
    // JAMAIS le déclencheur d'un effet financier — purement traçabilité.
    await writeAuditLog({
      actorUserId: customerId,
      actorRole: "customer",
      action: "payment_created",
      sourceFunction: "createAndAuthorizeMissionPayment",
      targetId: paymentId,
      metadata: { missionId, providerPaymentIntentId: created.providerPaymentIntentId, amountMinor },
    });
    logFinancialSuccess(
      "create_payment",
      operationStartedAt,
      { missionId, paymentId },
      { correlationId, metadata: { providerPaymentIntentId: created.providerPaymentIntentId, amountMinor } }
    );

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
        created.providerPaymentIntentId,
        { correlationId, operationStartedAt, operation: "authorize_payment" }
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

    await writeAuditLog({
      actorUserId: customerId,
      actorRole: "customer",
      action: "payment_authorized",
      sourceFunction: "createAndAuthorizeMissionPayment",
      targetId: paymentId,
      metadata: { missionId, providerPaymentIntentId: created.providerPaymentIntentId, amountMinor },
    });
    logFinancialSuccess(
      "authorize_payment",
      operationStartedAt,
      { missionId, paymentId },
      { correlationId, metadata: { providerPaymentIntentId: created.providerPaymentIntentId, amountMinor } }
    );

    return { paymentId, status: PaymentStatuses.AUTHORIZED, success: true };
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return await failMissionPayment(missionId, paymentId, "provider_error", message, null, {
      correlationId,
      operationStartedAt,
      operation: "create_payment",
    });
  }
}

/**
 * Compensation : bascule la mission en `payment_failed` (jamais réassignée
 * automatiquement — voir commentaire sur MissionStatuses.PAYMENT_FAILED) et
 * marque `payments/{id}` FAILED si le document existe déjà.
 *
 * 🔒 BLOC I — `observability` est optionnel car `failMissionPayment` est
 * appelée pour des échecs très précoces (ex: profil de paiement manquant,
 * AVANT même la génération d'un `correlationId` d'opération) où l'appelant
 * ne dispose pas encore de contexte d'observabilité à propager ; dans ce cas
 * un correlation_id dédié est généré ICI plutôt que de ne rien journaliser.
 */
async function failMissionPayment(
  missionId: string,
  paymentId: string | null,
  failureCode: string,
  failureMessage: string,
  providerPaymentIntentId: string | null = null,
  observability?: { correlationId: string; operationStartedAt: number; operation: string }
): Promise<CreateAndAuthorizePaymentOutcome> {
  const obs = observability ?? {
    correlationId: resolveCorrelationId(undefined),
    operationStartedAt: startFinancialOperationTimer(),
    operation: "create_payment",
  };
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

  logFinancialFailure(
    obs.operation,
    obs.operationStartedAt,
    failureCode,
    { missionId, paymentId: paymentId ?? undefined },
    { correlationId: obs.correlationId, message: failureMessage, metadata: { providerPaymentIntentId } }
  );

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
  // 🔒 BLOC I — aucun correlation_id entrant (déclenché par completeDelivery(),
  // pas par un évènement externe) : en génère un nouveau, dédié à cette capture.
  const correlationId = resolveCorrelationId(undefined);
  const operationStartedAt = startFinancialOperationTimer();
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

  // 🔒 Bloc F (point 7, directive 38 points) : mission_financial_balance
  // reflète l'argent RÉELLEMENT capturé — recalcul HORS transaction (lecture
  // multi-collections), y compris sur échec de capture (recalcul idempotent,
  // sans effet si rien n'a changé côté payments/refunds/ledger/snapshots).
  await recalculateMissionFinancialBalance(missionId);

  if (result.success) {
    logFinancialSuccess(
      "capture_payment",
      operationStartedAt,
      { missionId, paymentId },
      { correlationId, metadata: { amountCapturedMinor: result.amountCapturedMinor } }
    );
  } else {
    logFinancialFailure(
      "capture_payment",
      operationStartedAt,
      result.failureMessage ? "capture_failed" : "capture_failed_unknown",
      { missionId, paymentId },
      { correlationId, message: result.failureMessage }
    );
  }

  return { success: result.success, status: result.status, failureMessage: result.failureMessage };
}

// -----------------------------------------------------------------------------
// Annulation de l'AUTORISATION — appelée par onMissionEndedClearTracking.ts
// quand une mission ASSIGNÉE (paiement déjà AUTHORIZED, jamais capturé) est
// annulée par le client. Suit le MÊME schéma en 3 temps que
// createAndAuthorizeMissionPayment / captureMissionPayment ci-dessus :
// jamais d'appel PaymentProvider DANS une transaction Firestore.
//
// BUG-001 (Phase 7, Bloc B) — CORRECTIF : avant ce correctif, aucune Cloud
// Function n'appelait `PaymentProvider.cancelAuthorization()` sur cette
// transition, laissant l'autorisation active côté provider (fonds bloqués
// sur la carte du client jusqu'à expiration naturelle) et
// `payments/{id}.status` figé à tort sur AUTHORIZED alors que la mission
// était déjà annulée. Voir docs/PHASE7_BUG_REPORT.md (BUG-001) pour le
// diagnostic complet et le test de régression associé
// (missionCancellationPaymentRelease.test.ts).
//
// 🔒 Portée STRICTEMENT limitée à un paiement encore AUTHORIZED (jamais
// capturé) — un paiement déjà CAPTURED/PARTIALLY_REFUNDED/etc. n'est JAMAIS
// touché par cette fonction : le remboursement post-capture reste
// exclusivement le chemin refundPayment() existant, inchangé. Aucune
// capture n'est jamais déclenchée ici, et aucun payout chauffeur n'est
// jamais créé pour un paiement annulé (submitDriverPayout() ne s'exécute
// que sur des financial_snapshots issus d'un paiement CAPTURED — recalcul
// de mission_financial_balance ci-dessous garantit la cohérence ledger).
// -----------------------------------------------------------------------------

export interface CancelMissionPaymentAuthorizationOutcome {
  /** true si l'annulation a été effectuée (ou l'était déjà) sans erreur. */
  success: boolean;
  /** true si le paiement était DÉJÀ CANCELLED (idempotence — aucun appel provider n'a été refait). */
  alreadyCancelled: boolean;
  /** true si le paiement n'était pas dans un état concerné (ex: déjà CAPTURED) — aucune action prise, ce n'est pas une erreur. */
  skipped: boolean;
  status: string;
  failureMessage?: string | null;
}

/**
 * Annule l'autorisation de paiement d'une mission côté provider quand le
 * client annule la mission AVANT toute capture. Idempotent : si
 * `payments/{id}.status` est déjà CANCELLED (livraison at-least-once du
 * trigger appelant), ne refait aucun appel provider ni aucune écriture
 * financière équivalente. Si le paiement n'est pas AUTHORIZED (ex: déjà
 * CAPTURED, ou jamais initialisé), ne fait rien et renvoie `skipped: true`
 * — ce n'est jamais un cas d'erreur, seulement "hors périmètre".
 */
export async function cancelMissionPaymentAuthorization(
  missionId: string,
  paymentId: string
): Promise<CancelMissionPaymentAuthorizationOutcome> {
  const correlationId = resolveCorrelationId(undefined);
  const operationStartedAt = startFinancialOperationTimer();
  const payRef = db.collection("payments").doc(paymentId);

  // ---- Étape 1 : transaction de préparation ----
  // Lit l'état actuel du paiement et décide de l'action : soit il est déjà
  // CANCELLED (idempotence, rien à faire), soit il n'est pas AUTHORIZED
  // (hors périmètre, rien à faire), soit il EST AUTHORIZED et l'appel
  // provider doit être tenté HORS transaction ci-dessous.
  type PrepOutcome =
    | { kind: "already_cancelled" }
    | { kind: "skipped"; status: string }
    | { kind: "proceed"; providerPaymentIntentId: string; idempotencyKey: string };

  const prep: PrepOutcome = await db.runTransaction(async (tx): Promise<PrepOutcome> => {
    const paySnap = await tx.get(payRef);
    if (!paySnap.exists) return { kind: "skipped", status: "not_found" };
    const payment = paySnap.data() as PaymentDoc;

    if (payment.status === PaymentStatuses.CANCELLED) {
      return { kind: "already_cancelled" };
    }
    if (payment.status !== PaymentStatuses.AUTHORIZED) {
      // Déjà CAPTURED/FAILED/REFUNDED/etc. — jamais touché par ce chemin.
      return { kind: "skipped", status: payment.status };
    }

    const idempotencyKey = buildIdempotencyKey("cancelAuthorization", paymentId);
    return {
      kind: "proceed",
      providerPaymentIntentId: payment.provider_payment_intent_id!,
      idempotencyKey,
    };
  });

  if (prep.kind === "already_cancelled") {
    return { success: true, alreadyCancelled: true, skipped: false, status: PaymentStatuses.CANCELLED };
  }
  if (prep.kind === "skipped") {
    return { success: true, alreadyCancelled: false, skipped: true, status: prep.status };
  }

  // ---- Étape 2 : appel PaymentProvider RÉEL, HORS transaction ----
  const provider = getPaymentProvider();
  let cancelResult: { success: boolean; status: string };
  try {
    cancelResult = await provider.cancelAuthorization({
      providerPaymentIntentId: prep.providerPaymentIntentId,
      idempotencyKey: prep.idempotencyKey,
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    logFinancialFailure(
      "cancel_authorization",
      operationStartedAt,
      "provider_error",
      { missionId, paymentId },
      { correlationId, message }
    );
    return { success: false, alreadyCancelled: false, skipped: false, status: "error", failureMessage: message };
  }

  if (!cancelResult.success) {
    logFinancialFailure(
      "cancel_authorization",
      operationStartedAt,
      "provider_cancel_failed",
      { missionId, paymentId },
      { correlationId, message: `Statut provider inattendu: ${cancelResult.status}` }
    );
    return {
      success: false,
      alreadyCancelled: false,
      skipped: false,
      status: cancelResult.status,
      failureMessage: `Annulation refusée par le fournisseur de paiement (statut: ${cancelResult.status}).`,
    };
  }

  // ---- Étape 3 : transaction d'application ----
  // Relit l'état (défense contre une exécution concurrente qui aurait déjà
  // appliqué le résultat entre-temps — assertValidPaymentTransition() lève
  // si la transition n'est plus valide, auquel cas on la traite comme déjà
  // traitée par idempotence plutôt que de propager une erreur).
  const now = admin.firestore.Timestamp.now();
  const missionRef = db.collection("delivery_requests").doc(missionId);
  await db.runTransaction(async (tx) => {
    // ---- Tous les reads d'abord (contrainte Firestore transactions) ----
    const paySnap = await tx.get(payRef);
    if (!paySnap.exists) return;
    const payment = paySnap.data() as PaymentDoc;
    if (payment.status === PaymentStatuses.CANCELLED) return; // déjà appliqué (concurrence)
    assertValidPaymentTransition(payment.status, PaymentStatuses.CANCELLED);

    const missionSnap = await tx.get(missionRef);

    // ---- Puis tous les writes ----
    tx.update(payRef, {
      status: PaymentStatuses.CANCELLED,
      cancelled_at: now,
      updated_at: now,
    });

    if (missionSnap.exists) {
      tx.update(missionRef, { payment_status: PaymentStatuses.CANCELLED });
    }
  });

  await writeAuditLog({
    actorUserId: "system",
    actorRole: "system",
    action: "payment_authorization_cancelled",
    sourceFunction: "cancelMissionPaymentAuthorization",
    targetId: paymentId,
    metadata: { missionId, providerPaymentIntentId: prep.providerPaymentIntentId },
  });
  logFinancialSuccess(
    "cancel_authorization",
    operationStartedAt,
    { missionId, paymentId },
    { correlationId, metadata: { providerPaymentIntentId: prep.providerPaymentIntentId } }
  );

  // 🔒 Recalcul mission_financial_balance HORS transaction (multi-collections,
  // même pattern que captureMissionPayment/refundPayment ci-dessus) — un
  // paiement CANCELLED n'apporte aucun montant capturé, garantit que le
  // solde reflète bien 0 $ effectivement mouvementé pour cette mission.
  await recalculateMissionFinancialBalance(missionId);

  return { success: true, alreadyCancelled: false, skipped: false, status: PaymentStatuses.CANCELLED };
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
  // 🔒 BLOC I — un correlation_id couvre TOUTE la soumission (submission ->
  // paid|failed) de ce payout. Déclenché par calculateDriverPayout.ts ou par
  // le cron `processScheduledDriverPayouts`, jamais par un évènement externe
  // porteur de son propre correlationId — génération ici.
  const correlationId = resolveCorrelationId(undefined);
  const operationStartedAt = startFinancialOperationTimer();
  const payoutRef = db.collection("driver_payouts").doc(payoutId);

  // 🔒 Phase 7, Bloc X (X-9) — kill switch. `submitDriverPayout()` est LE
  // SEUL point du système qui appelle réellement
  // `PaymentProvider.createDriverPayout()` (calculateDriverPayout.ts ET
  // processScheduledDriverPayouts.ts convergent tous les deux ici avant tout
  // appel fournisseur) — l'enforcement à CE point unique garantit qu'il
  // n'existe aucun second chemin de contournement (directive X-9). OFF =>
  // AUCUN nouvel appel fournisseur. Le versement reste DÉLIBÉRÉMENT dans son
  // statut actuel (ELIGIBLE, jamais transitionné vers FAILED) : ce n'est pas
  // un échec métier du versement, seulement une pause temporaire — le cron
  // `processScheduledDriverPayouts` (ou un nouvel appel admin) le
  // resoumettra automatiquement dès que le flag repasse à `true`, sans
  // qu'aucune action de récupération manuelle (retry FAILED -> SCHEDULED) ne
  // soit nécessaire. N'affecte JAMAIS `reverseDriverPayout()` (compensation
  // comptable sur un versement déjà PAID) ni la réconciliation — ces chemins
  // n'appellent pas cette fonction.
  if (!(await isRuntimeFlagEnabled(RuntimeFlagKeys.DRIVER_PAYOUTS_ENABLED))) {
    logFinancialFailure(
      "submit_driver_payout",
      operationStartedAt,
      PAYOUTS_KILL_SWITCH_FAILURE_CODE,
      { payoutId },
      { correlationId }
    );
    return {
      success: false,
      status: PayoutStatuses.ELIGIBLE,
      failureMessage: "Versements chauffeur temporairement indisponibles.",
    };
  }

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
        // 🔒 BUG-FIX (Phase 7, Bloc C item 2) : NE JAMAIS faire `tx.update()`
        // puis `throw` dans le MÊME corps de transaction — Firestore annule
        // (rollback) intégralement toute transaction dont le callback lève,
        // donc cette écriture n'était JAMAIS committée malgré un retour
        // `status: FAILED` trompeur côté appelant. On se contente ici de
        // valider la transition (échoue immédiatement si invalide) puis de
        // lever un marqueur ; l'écriture réelle du statut FAILED est faite
        // dans une transaction SÉPARÉE par le bloc catch ci-dessous (même
        // schéma que le catch de l'appel provider en échec plus bas).
        assertValidPayoutTransition(payout.status, PayoutStatuses.FAILED);
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
      // 🔒 Écriture réelle du statut FAILED — transaction SÉPARÉE (la
      // transaction ci-dessus a déjà rollback son propre `tx.update()` en
      // levant). Re-vérifie la transition ET le statut terminal (défense
      // contre une exécution concurrente qui aurait déjà traité ce payout
      // entre les deux transactions).
      await db.runTransaction(async (tx) => {
        const snap = await tx.get(payoutRef);
        if (!snap.exists) return;
        const payout = snap.data() as DriverPayoutDoc;
        if (isTerminalPayout(payout.status)) return;
        assertValidPayoutTransition(payout.status, PayoutStatuses.FAILED);
        tx.update(payoutRef, {
          status: PayoutStatuses.FAILED,
          failed_at: admin.firestore.Timestamp.now(),
          failure_reason: "missing_connected_account",
        });
      });
      logFinancialFailure(
        "submit_driver_payout",
        operationStartedAt,
        "missing_connected_account",
        { payoutId },
        { correlationId }
      );
      return {
        success: false,
        status: PayoutStatuses.FAILED,
        failureMessage: "Aucun compte de versement connecté pour ce chauffeur.",
      };
    }
    throw err;
  }

  const { amountMinor, currency, connectedAccountId, idempotencyKey } = prepared;

  // 🔒 BLOC H — journalise la soumission RÉELLE au fournisseur (distinct de
  // `payout_created`, journalisé par calculateDriverPayout.ts au moment de
  // l'agrégation des snapshots, AVANT tout appel provider).
  await writeAuditLog({
    actorUserId: "system",
    actorRole: "system",
    action: "payout_submitted",
    sourceFunction: "submitDriverPayout",
    targetId: payoutId,
    metadata: { amountMinor, connectedAccountId },
  });
  logFinancialSuccess(
    "submit_driver_payout",
    operationStartedAt,
    { payoutId },
    { correlationId, metadata: { amountMinor, connectedAccountId } }
  );

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
    logFinancialFailure(
      "payout_processed",
      operationStartedAt,
      "provider_error",
      { payoutId },
      { correlationId, message }
    );
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

  // 🔒 Bloc F (point 7) : un payout PAID rend `driver_paid_minor` non-nul pour
  // CHAQUE mission dont un financial_snapshot est inclus dans ce versement —
  // recalcul de mission_financial_balance pour toutes ces missions, HORS
  // transaction (missionFinancialBalance.ts lit plusieurs collections).
  if (result.success) {
    const payoutSnapAfter = await payoutRef.get();
    const snapshotIds: string[] = payoutSnapAfter.exists
      ? (payoutSnapAfter.data() as DriverPayoutDoc).financial_snapshot_ids ?? []
      : [];
    const missionIds = new Set<string>();
    await Promise.all(
      snapshotIds.map(async (snapshotId) => {
        const snapDoc = await db.collection("financial_snapshots").doc(snapshotId).get();
        if (snapDoc.exists) {
          const missionId = snapDoc.data()!.mission_id as string;
          if (missionId) missionIds.add(missionId);
        }
      })
    );
    await Promise.all([...missionIds].map((mId) => recalculateMissionFinancialBalance(mId)));
  }

  if (result.success) {
    logFinancialSuccess(
      "payout_processed",
      operationStartedAt,
      { payoutId },
      { correlationId, metadata: { providerPayoutId: result.providerPayoutId, amountMinor } }
    );
  } else {
    logFinancialFailure(
      "payout_processed",
      operationStartedAt,
      result.failureCode ?? "provider_payout_failed",
      { payoutId },
      { correlationId }
    );
  }

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

// -----------------------------------------------------------------------------
// Reversal administratif de versement — point 20 (voir payoutStateMachine.ts,
// transition PAID -> REVERSED). Contrairement à un refund de charge, un
// versement Stripe déjà PAID ne peut PAS être annulé via l'API Stripe elle-
// même (les fonds ont quitté le compte connecté) — cette fonction N'INVENTE
// PAS un appel provider inexistant. Elle documente une COMPENSATION
// COMPTABLE administrative (ex: recouvrement négocié hors-bande avec le
// chauffeur, retenue sur un versement futur) : marque driver_payouts/{id}
// REVERSED et crée une entrée ledger DRIVER_PAYOUT_REVERSAL pour CHAQUE
// mission dont un financial_snapshot est inclus dans ce payout — jamais un
// second appel PaymentProvider.
// -----------------------------------------------------------------------------

export interface ReverseDriverPayoutInput {
  payoutId: string;
  reason: string;
  initiatedByUserId: string;
  initiatedByRole: string;
}

export interface ReverseDriverPayoutOutcome {
  payoutId: string;
  status: string;
  missionIds: string[];
}

export async function reverseDriverPayout(
  input: ReverseDriverPayoutInput
): Promise<ReverseDriverPayoutOutcome> {
  const { payoutId, reason, initiatedByUserId, initiatedByRole } = input;
  // 🔒 BLOC I — reversal administratif déclenché par un admin (Cloud Function
  // callable reverseDriverPayout.ts), aucun correlationId externe à propager.
  const correlationId = resolveCorrelationId(undefined);
  const operationStartedAt = startFinancialOperationTimer();
  const payoutRef = db.collection("driver_payouts").doc(payoutId);

  let missionIds: string[];
  try {
    const txOutcome = await db.runTransaction(async (tx) => {
      const snap = await tx.get(payoutRef);
      if (!snap.exists) throw notFound(`driver_payouts/${payoutId} introuvable.`);
      const payout = snap.data() as DriverPayoutDoc;
      assertValidPayoutTransition(payout.status, PayoutStatuses.REVERSED);

      // 🔒 Lecture des snapshots DANS la même transaction (plusieurs lectures
      // sont autorisées dans une transaction Firestore) pour attribuer le
      // MONTANT RÉELLEMENT gagné par mission (driver_net_mission_earnings),
      // jamais une répartition arbitraire du total du payout — cohérent avec
      // `computeMissionFinancialBalance()` qui recalculera automatiquement
      // `driver_paid_minor` à 0 pour ces missions dès que ce payout n'est
      // plus filtré par `status == "paid"`.
      const snapshotRefs = payout.financial_snapshot_ids.map((id) =>
        db.collection("financial_snapshots").doc(id)
      );
      const snapshotSnaps = await Promise.all(snapshotRefs.map((ref) => tx.get(ref)));

      const now = admin.firestore.Timestamp.now();
      tx.update(payoutRef, {
        status: PayoutStatuses.REVERSED,
        reversed_at: now,
        reversal_reason: reason,
      });

      const missionIdsFound: string[] = [];
      for (const snapDoc of snapshotSnaps) {
        if (!snapDoc.exists) continue;
        const snapshot = snapDoc.data()!;
        const missionId = snapshot.mission_id as string | undefined;
        if (!missionId) continue;
        missionIdsFound.push(missionId);

        const earnedMajor = (snapshot.driver_net_mission_earnings as number) ?? 0;
        const earnedMinor = toMinorUnits(earnedMajor, DEFAULT_CURRENCY);

        const ledgerRef = db.collection("transaction_ledger").doc();
        tx.set(ledgerRef, {
          ledger_entry_id: ledgerRef.id,
          mission_id: missionId,
          transaction_id: payoutId,
          type: LedgerEntryTypes.DRIVER_PAYOUT_REVERSAL,
          amount: earnedMajor,
          amount_minor: earnedMinor,
          currency: payout.currency,
          direction: LedgerDirections.DEBIT,
          party: LedgerParties.DRIVER,
          created_at: now,
          created_by: `reverseDriverPayout:${initiatedByUserId}`,
          source_event: "payout_reversed",
          status: LedgerEntryStatuses.CONFIRMED,
          reference_id: payoutId,
        });
      }

      writeAuditLogInTransaction(tx, {
        actorUserId: initiatedByUserId,
        actorRole: initiatedByRole,
        action: "payout_reversed",
        sourceFunction: "reverseDriverPayout",
        targetId: payoutId,
        metadata: {
          reason,
          amountMinor: payout.amount_minor,
          snapshotCount: payout.financial_snapshot_ids.length,
          missionIds: missionIdsFound,
        },
      });

      return { missionIds: missionIdsFound, amountMinor: payout.amount_minor };
    });
    missionIds = txOutcome.missionIds;

    // Recalcul HORS transaction (lecture multi-collections, voir
    // missionFinancialBalance.ts en-tête) — `driver_paid_minor` retombe à 0
    // pour ces missions car le payout n'est plus `status == "paid"`.
    await Promise.all(missionIds.map((mId) => recalculateMissionFinancialBalance(mId)));

    logFinancialSuccess(
      "payout_reversal",
      operationStartedAt,
      { payoutId },
      { correlationId, metadata: { reason, amountMinor: txOutcome.amountMinor, missionCount: missionIds.length } }
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    logFinancialFailure(
      "payout_reversal",
      operationStartedAt,
      "payout_reversal_failed",
      { payoutId },
      { correlationId, message }
    );
    throw err;
  }

  return { payoutId, status: PayoutStatuses.REVERSED, missionIds };
}

// -----------------------------------------------------------------------------
// Remboursement — point 1 de la directive 38 points Phase 6.
//
// Supporte : remboursement complet, partiel, plusieurs remboursements
// partiels dans la limite du montant capturé, remboursement avant/après
// payout, remboursement administratif. MÊME schéma en 3 temps que les
// fonctions ci-dessus — AUCUN appel PaymentProvider dans une transaction
// Firestore.
//
//   1. Transaction Firestore n°1 — valide le solde remboursable
//      (amount_captured_minor - somme des refunds déjà SUCCEEDED/PROCESSING
//      >= montant demandé), crée refunds/{id} en REQUESTED puis
//      immédiatement PROCESSING, fige idempotencyKey déterministe basé sur
//      refundId (PAS sur paymentId seul — plusieurs refunds partiels
//      distincts doivent avoir des clés distinctes).
//   2. Appel Stripe réel (provider.refundPayment()), HORS transaction.
//   3. Transaction Firestore n°2 — applique SUCCEEDED|FAILED, incrémente
//      payments/{id}.amount_refunded_minor, transitionne le PaymentDoc vers
//      PARTIALLY_REFUNDED ou REFUNDED (assertValidPaymentTransition), crée
//      les entrées ledger compensatoires (REFUND/PARTIAL_REFUND).
//
// Recalcule ensuite mission_financial_balance/{missionId} (point 7), HORS
// de la transaction n°2 elle-même (lecture multi-collections, voir
// missionFinancialBalance.ts).
// -----------------------------------------------------------------------------

export interface RefundPaymentInput {
  paymentId: string;
  amountMinor: number; // montant à rembourser, en cents entiers (peut être partiel)
  reason: RefundReason;
  initiatedByUserId: string;
  initiatedByRole: string;
  isAdminInitiated: boolean;
  /** Clé de déduplication CLIENT (ex: bouton "rembourser" cliqué 2x) — voir
   *  refundPayment.ts (Cloud Function) pour la construction déterministe. */
  requestKey: string;
  /** 🔒 BLOC I — propagé depuis refundPayment.ts (Cloud Function callable)
   *  si déjà généré à ce niveau, sinon généré ici. Permet au log
   *  `refund_requested` (émis par la Cloud Function) et aux logs
   *  `refund_success`/`refund_failure` (émis ici) de partager le même
   *  correlation_id. */
  correlationId?: string;
}

export interface RefundPaymentOutcome {
  success: boolean;
  refundId: string;
  status: string;
  providerRefundId?: string | null;
  failureMessage?: string | null;
  alreadyProcessed?: boolean;
}

export async function refundPayment(input: RefundPaymentInput): Promise<RefundPaymentOutcome> {
  const { paymentId, amountMinor, reason, initiatedByUserId, initiatedByRole, isAdminInitiated, requestKey } =
    input;
  const correlationId = resolveCorrelationId(input.correlationId);
  const operationStartedAt = startFinancialOperationTimer();

  const payRef = db.collection("payments").doc(paymentId);
  // 🔒 Idempotence déterministe basée sur requestKey (fourni par l'appelant,
  // construit à partir de paymentId + un identifiant stable de la DEMANDE,
  // ex: un id de bouton/action client généré une seule fois côté Flutter et
  // réutilisé lors d'un retry réseau) — PAS un id aléatoire régénéré à
  // chaque tentative. Deux appels avec le MÊME requestKey ne créent jamais
  // deux RefundDoc distincts : le second lit le premier et renvoie son
  // résultat (ou attend/échoue proprement s'il est encore en cours).
  const refundRef = db.collection("refunds").doc(requestKey);

  type PreparedRefund = {
    refundId: string;
    providerPaymentIntentId: string;
    amountToRefundMinor: number;
    reverseTransfer: boolean;
    refundApplicationFee: boolean;
    idempotencyKey: string;
    missionId: string;
    isPostPayout: boolean;
    relatedPayoutId: string | null;
  };

  // 🔒 La transaction RETOURNE son résultat (union discriminée) au lieu de
  // muter des `let` externes par fermeture — c'est le pattern déjà validé
  // et stable de submitDriverPayout() ci-dessus. Toute autre approche
  // (assignation à une variable capturée) casse l'inférence de type
  // TypeScript après la transaction (narrowing en `never`).
  type TxOutcome =
    | { kind: "already_terminal"; outcome: RefundPaymentOutcome }
    | { kind: "prepared"; data: PreparedRefund };

  let txResult: TxOutcome;
  try {
    txResult = await db.runTransaction(async (tx): Promise<TxOutcome> => {
      const [paySnap, existingRefundSnap] = await Promise.all([
        tx.get(payRef),
        tx.get(refundRef),
      ]);
      if (!paySnap.exists) throw new Error(`payments/${paymentId} introuvable.`);
      const payment = paySnap.data() as PaymentDoc;

      // ---- Idempotence : requête déjà traitée (même requestKey) ----
      if (existingRefundSnap.exists) {
        const existing = existingRefundSnap.data() as RefundDoc;
        if (existing.status === RefundStatuses.SUCCEEDED || existing.status === RefundStatuses.FAILED) {
          return {
            kind: "already_terminal",
            outcome: {
              success: existing.status === RefundStatuses.SUCCEEDED,
              refundId: existing.refund_id,
              status: existing.status,
              providerRefundId: existing.provider_refund_id,
              failureMessage: existing.failed_reason ?? null,
              alreadyProcessed: true,
            },
          };
        }
        if (existing.status === RefundStatuses.PROCESSING) {
          // Une exécution concurrente est déjà en train de traiter EXACTEMENT
          // cette demande (même requestKey) — on ne relance jamais un second
          // appel provider. L'appelant doit réessayer plus tard.
          throw new Error("REFUND_ALREADY_IN_PROGRESS");
        }
        // REQUESTED : ne devrait jamais être observable en dehors de cette
        // même transaction (REQUESTED->PROCESSING est écrit atomiquement
        // ci-dessous) — traité comme in_progress par prudence.
        throw new Error("REFUND_ALREADY_IN_PROGRESS");
      }

    // ---- Validation du solde remboursable (points 1, 2, 5, 6) ----
    if (!payment.provider_payment_intent_id) {
      throw new Error("PAYMENT_NOT_CAPTURABLE");
    }
    if (payment.status !== PaymentStatuses.CAPTURED && payment.status !== PaymentStatuses.PARTIALLY_REFUNDED) {
      throw new Error("PAYMENT_NOT_REFUNDABLE_STATUS");
    }

    // Somme des refunds déjà SUCCEEDED ou PROCESSING pour ce paiement
    // (empêche un dépassement du montant capturé même avec plusieurs
    // remboursements partiels concurrents — voir point 4, test de
    // concurrence : la lecture DANS la transaction garantit la
    // sérialisation Firestore standard sur les documents lus).
    const existingRefundsQuery = await tx.get(
      db.collection("refunds").where("payment_id", "==", paymentId)
    );
    let alreadyRefundedOrInFlightMinor = 0;
    for (const doc of existingRefundsQuery.docs) {
      const r = doc.data() as RefundDoc;
      if (r.status === RefundStatuses.SUCCEEDED || r.status === RefundStatuses.PROCESSING) {
        alreadyRefundedOrInFlightMinor = addMinor(alreadyRefundedOrInFlightMinor, r.amount_minor);
      }
    }
    const remainingRefundableMinor = subtractMinor(
      payment.amount_captured_minor,
      alreadyRefundedOrInFlightMinor
    );
    if (amountMinor <= 0 || amountMinor > remainingRefundableMinor) {
      throw new Error(
        `REFUND_AMOUNT_EXCEEDS_REFUNDABLE_BALANCE: demandé=${amountMinor}, disponible=${remainingRefundableMinor}`
      );
    }

    // ---- Détection remboursement post-payout (point 6) ----
    // Un remboursement est "post-payout" si un driver_payouts PAID inclut
    // déjà un financial_snapshot de cette mission — dans ce cas, on NE
    // MODIFIE JAMAIS ce payout historique (voir missionFinancialBalance.ts,
    // qui expose outstanding_driver_balance_minor pour tracer l'écart).
    const snapshotsQuery = await tx.get(
      db.collection("financial_snapshots").where("mission_id", "==", payment.mission_id)
    );
    const snapshotIds = snapshotsQuery.docs.map((d) => d.id);
    let isPostPayout = false;
    let relatedPayoutId: string | null = null;
    if (snapshotIds.length > 0) {
      const paidPayoutsQuery = await tx.get(
        db.collection("driver_payouts").where("driver_id", "==", payment.driver_id).where("status", "==", "paid")
      );
      for (const doc of paidPayoutsQuery.docs) {
        const includedIds: string[] = doc.data().financial_snapshot_ids ?? [];
        if (snapshotIds.some((id) => includedIds.includes(id))) {
          isPostPayout = true;
          relatedPayoutId = doc.id;
          break;
        }
      }
    }

    const now = admin.firestore.Timestamp.now();
    const idempotencyKey = buildIdempotencyKey("refundPayment", refundRef.id);

    const refundDoc: RefundDoc = {
      refund_id: refundRef.id,
      mission_id: payment.mission_id,
      payment_id: paymentId,
      amount_minor: amountMinor,
      reason,
      initiated_by_user_id: initiatedByUserId,
      initiated_by_role: initiatedByRole,
      is_admin_initiated: isAdminInitiated,
      is_post_payout: isPostPayout,
      related_payout_id: relatedPayoutId,
      status: RefundStatuses.PROCESSING,
      provider_refund_id: null,
      reverse_transfer: !!payment.connected_account_id,
      refund_application_fee: !!payment.connected_account_id,
      idempotency_key: idempotencyKey,
      created_at: now,
      processing_at: now,
      completed_at: null,
      failed_reason: null,
    };
    // REQUESTED->PROCESSING appliqué en une seule écriture atomique (jamais
    // observable en REQUESTED depuis l'extérieur de cette transaction) —
    // voir refundStateMachine.ts, transition valide.
      assertValidRefundTransition(RefundStatuses.REQUESTED, RefundStatuses.PROCESSING);
      tx.set(refundRef, refundDoc);

      return {
        kind: "prepared",
        data: {
          refundId: refundRef.id,
          providerPaymentIntentId: payment.provider_payment_intent_id,
          amountToRefundMinor: amountMinor,
          reverseTransfer: refundDoc.reverse_transfer,
          refundApplicationFee: refundDoc.refund_application_fee,
          idempotencyKey,
          missionId: payment.mission_id,
          isPostPayout,
          relatedPayoutId,
        },
      };
    });
  } catch (err) {
    if (err instanceof Error && err.message === "REFUND_ALREADY_IN_PROGRESS") {
      throw aborted(
        "Une demande de remboursement identique est déjà en cours de traitement. Veuillez réessayer dans quelques instants."
      );
    }
    throw err;
  }

  if (txResult.kind === "already_terminal") return txResult.outcome;
  const p = txResult.data;

  // ---- Étape 2 : appel Stripe réel, hors transaction ----
  const provider = getPaymentProvider();
  const result = await provider.refundPayment({
    providerPaymentIntentId: p.providerPaymentIntentId,
    amountMinor: p.amountToRefundMinor,
    reverseTransfer: p.reverseTransfer,
    refundApplicationFee: p.refundApplicationFee,
    idempotencyKey: p.idempotencyKey,
  });

  // ---- Étape 3 : transaction — applique le résultat ----
  await db.runTransaction(async (tx) => {
    const [refundSnap, paySnap] = await Promise.all([tx.get(refundRef), tx.get(payRef)]);
    if (!refundSnap.exists || !paySnap.exists) return;
    const refundData = refundSnap.data() as RefundDoc;
    const payment = paySnap.data() as PaymentDoc;
    const now = admin.firestore.Timestamp.now();

    if (result.success) {
      assertValidRefundTransition(refundData.status, RefundStatuses.SUCCEEDED);
      tx.update(refundRef, {
        status: RefundStatuses.SUCCEEDED,
        provider_refund_id: result.providerRefundId,
        completed_at: now,
      });

      const newAmountRefundedMinor = addMinor(payment.amount_refunded_minor, p.amountToRefundMinor);
      const isFullRefund = newAmountRefundedMinor >= payment.amount_captured_minor;
      const nextPaymentStatus = isFullRefund
        ? PaymentStatuses.REFUNDED
        : PaymentStatuses.PARTIALLY_REFUNDED;
      assertValidPaymentTransition(payment.status, nextPaymentStatus);
      tx.update(payRef, {
        amount_refunded_minor: newAmountRefundedMinor,
        status: nextPaymentStatus,
        updated_at: now,
      });

      // ---- Écriture ledger compensatoire (REFUND ou PARTIAL_REFUND) ----
      const ledgerRef = db.collection("transaction_ledger").doc();
      tx.set(ledgerRef, {
        ledger_entry_id: ledgerRef.id,
        mission_id: p.missionId,
        transaction_id: paymentId,
        type: isFullRefund ? LedgerEntryTypes.REFUND : LedgerEntryTypes.PARTIAL_REFUND,
        amount: p.amountToRefundMinor / 100, // 🔒 legacy ledger en dollars, voir money.ts
        amount_minor: p.amountToRefundMinor,
        currency: DEFAULT_CURRENCY,
        direction: LedgerDirections.DEBIT,
        party: LedgerParties.CUSTOMER,
        created_at: now,
        created_by: "refundPayment",
        source_event: p.isPostPayout ? "refund_after_payout" : "refund_before_payout",
        status: LedgerEntryStatuses.CONFIRMED,
        reference_id: p.relatedPayoutId,
      });
    } else {
      assertValidRefundTransition(refundData.status, RefundStatuses.FAILED);
      tx.update(refundRef, {
        status: RefundStatuses.FAILED,
        provider_refund_id: result.providerRefundId,
        failed_reason: result.failureCode ?? "provider_refund_failed",
        completed_at: now,
      });
    }
  });

  // Recalcul mission_financial_balance HORS transaction (lecture
  // multi-collections, voir missionFinancialBalance.ts en-tête).
  await recalculateMissionFinancialBalance(p.missionId);

  if (result.success) {
    logFinancialSuccess(
      "refund_payment",
      operationStartedAt,
      { missionId: p.missionId, paymentId, refundId: p.refundId },
      { correlationId, metadata: { amountMinor: p.amountToRefundMinor, providerRefundId: result.providerRefundId } }
    );
  } else {
    logFinancialFailure(
      "refund_payment",
      operationStartedAt,
      result.failureCode ?? "provider_refund_failed",
      { missionId: p.missionId, paymentId, refundId: p.refundId },
      { correlationId }
    );
  }

  return {
    success: result.success,
    refundId: p.refundId,
    status: result.success ? RefundStatuses.SUCCEEDED : RefundStatuses.FAILED,
    providerRefundId: result.providerRefundId,
    failureMessage: result.success ? null : (result.failureCode ?? "Remboursement refusé par le fournisseur."),
  };
}
