// -----------------------------------------------------------------------------
// driverTipOrchestration.ts — débit du pourboire (décision Daniel, 2026-11-09).
//
// Remplace l'ancien recordTip (registre seulement, jamais encaissé — SEC-03 /
// PAY-02 du rapport pré-lancement) par un VRAI paiement :
//   - débit de la carte enregistrée du client (PaymentIntent off-session) ;
//   - « destination charge » vers le compte Stripe du chauffeur SANS frais
//     de plateforme : Stripe vire 100 % du pourboire au chauffeur et prélève
//     ses frais sur le solde Movi-K ;
//   - document payments/tip_<mission> (purpose "tip"), entrée de registre
//     DRIVER_TIP en cents, champ `tip` sur la mission, cloche du chauffeur,
//     puis recalcul de mission_financial_balance (driver_tip_minor) et
//     miroir driver_transfers (onPaymentWrittenMirrorDriverTransfer).
//
// Même schéma en 3 temps que le dépôt (lib/bookingDeposit.ts) :
//   1. transaction : contrôles + document en capture_pending ;
//   2. appel Stripe HORS transaction, clé d'idempotence stable par tentative
//      (une coupure réseau reprend la même clé ; un refus est terminal pour
//      ce document et le prochain essai prend tip_<mission>_2, …) ;
//   3. transaction : résultat appliqué une seule fois (captured / failed).
// -----------------------------------------------------------------------------

import { admin, db } from "../lib/admin";
import { writeAuditLogInTransaction } from "../lib/audit";
import { failedPrecondition, notFound, permissionDenied } from "../lib/errors";
import { buildIdempotencyKey } from "../lib/idempotency";
import { DRIVER_TIP_POLICY, TipChoice, tipAmountMinor, tipBaseMinor, tipPaymentId } from "../lib/driverTip";
import { recalculateMissionFinancialBalance } from "../lib/missionFinancialBalance";
import { DEFAULT_CURRENCY, toMajorUnits } from "../lib/money";
import { normalizePushLocale } from "../lib/pushNotifications";
import { assertStripeReferenceEnvironmentConsistency } from "../lib/stripeEnvironment";
import { driverConnectedAccountFor } from "../lib/stripeAccounts";
import {
  DriverProfileDoc,
  LedgerDirections,
  LedgerEntryStatuses,
  LedgerEntryTypes,
  LedgerParties,
  MissionAssignmentModes,
  MissionStatuses,
  PaymentDoc,
  PaymentStatuses,
} from "../lib/types";
import { getPaymentProvider } from "./paymentProviderFactory";

const MAX_TIP_SEQUENCE = 5;

export interface ChargeDriverTipInput {
  customerId: string;
  missionId: string;
  choice: TipChoice;
  nowMillis?: number;
}

export interface ChargeDriverTipOutcome {
  success: boolean;
  paymentId: string;
  status: string;
  amountMinor: number;
  failureMessage?: string | null;
  /** Pourboire déjà versé lors d'un appel précédent : aucun nouveau débit. */
  reused: boolean;
}

/** Contrôles communs à la préparation (mission, client, délai, test interne). */
function assertMissionTippable(mission: Record<string, any> | undefined, customerId: string, nowMillis: number): void {
  if (!mission) throw notFound("Livraison introuvable.");
  if (mission.customer_id !== customerId) throw permissionDenied("Seul le client de cette livraison peut laisser un pourboire.");
  if (mission.status !== MissionStatuses.COMPLETED) {
    throw failedPrecondition("Le pourboire se laisse une fois la livraison terminée.");
  }
  if (mission.assignment_mode === MissionAssignmentModes.INTERNAL_TEST || mission.internal_test_authorized === true) {
    throw failedPrecondition("Aucun pourboire sur une livraison de test interne.");
  }
  if (typeof mission.driver_id !== "string" || !mission.driver_id) {
    throw failedPrecondition("Aucun chauffeur sur cette livraison.");
  }
  const completedAt = mission.completed_at?.toMillis?.() as number | undefined;
  if (typeof completedAt === "number" && nowMillis - completedAt > DRIVER_TIP_POLICY.window_ms) {
    throw failedPrecondition("Le pourboire n'est plus possible 30 jours après la livraison.");
  }
}

/**
 * Débite le pourboire et le vire au chauffeur. Idempotent par livraison : un
 * pourboire déjà versé est renvoyé tel quel, sans nouveau débit.
 */
export async function chargeDriverTip(input: ChargeDriverTipInput): Promise<ChargeDriverTipOutcome> {
  const nowMillis = input.nowMillis ?? Date.now();
  const provider = getPaymentProvider();
  const missionRef = db.collection("delivery_requests").doc(input.missionId);

  // Lectures hors transaction : profil de paiement du client et compte
  // Stripe du chauffeur (environnement actif seulement, fail closed).
  const missionBefore = (await missionRef.get()).data();
  assertMissionTippable(missionBefore, input.customerId, nowMillis);
  const driverId = missionBefore!.driver_id as string;
  const profile = (await db.collection("payment_profiles").doc(input.customerId).get()).data();
  if (!profile?.provider_customer_id || !profile?.default_payment_method_id) {
    throw failedPrecondition("Aucune carte enregistrée. Ajoutez une carte pour laisser un pourboire.");
  }
  assertStripeReferenceEnvironmentConsistency({
    activeEnvironment: provider.environment,
    storedEnvironment: profile.stripe_environment ?? null,
  });
  const driver = (await db.collection("driver_profiles").doc(driverId).get()).data() as DriverProfileDoc | undefined;
  const connectedAccountId = driverConnectedAccountFor(driver, provider.environment);
  if (!connectedAccountId) {
    throw failedPrecondition("Ce chauffeur ne peut pas encore recevoir de pourboire. Réessayez plus tard.");
  }

  // ---- 1. Réservation de la tentative ---------------------------------------
  let paymentId = tipPaymentId(input.missionId);
  const prepared = await db.runTransaction(async (tx) => {
    const mission = (await tx.get(missionRef)).data();
    assertMissionTippable(mission, input.customerId, nowMillis);
    if (mission!.driver_id !== driverId) throw failedPrecondition("Le chauffeur de cette livraison a changé. Réessayez.");
    let existing: PaymentDoc | undefined;
    let sequence = 1;
    for (; sequence <= MAX_TIP_SEQUENCE; sequence += 1) {
      paymentId = tipPaymentId(input.missionId, sequence);
      existing = (await tx.get(db.collection("payments").doc(paymentId))).data() as PaymentDoc | undefined;
      if (!existing || existing.status !== PaymentStatuses.FAILED) break;
    }
    if (sequence > MAX_TIP_SEQUENCE) {
      throw failedPrecondition("Trop d'essais refusés. Mettez votre carte à jour ou écrivez à infos@movi-k.com.");
    }
    if (existing?.status === PaymentStatuses.CAPTURED) {
      return { kind: "done" as const, amountMinor: existing.amount_captured_minor };
    }
    if (existing?.status === PaymentStatuses.CAPTURE_PENDING) {
      // Coupure réseau lors d'un essai précédent : même montant, même clé.
      return {
        kind: "charge" as const,
        amountMinor: existing.amount_requested_minor ?? existing.service_amount_minor ?? 0,
        percent: existing.tip_percent ?? null,
        providerCustomerId: existing.provider_customer_id as string,
        providerPaymentMethodId: existing.provider_payment_method_id as string,
        connectedAccountId: existing.connected_account_id as string,
      };
    }
    if (existing) throw failedPrecondition("Le pourboire de cette livraison est dans un état inattendu. Écrivez à infos@movi-k.com.");

    const amountMinor = tipAmountMinor(input.choice, tipBaseMinor(mission!));
    const percent = input.choice.kind === "percent" ? input.choice.percent : null;
    const now = admin.firestore.Timestamp.fromMillis(nowMillis);
    const doc: PaymentDoc = {
      payment_id: paymentId,
      mission_id: input.missionId,
      customer_id: input.customerId,
      driver_id: driverId,
      status: PaymentStatuses.CAPTURE_PENDING,
      currency: DEFAULT_CURRENCY,
      amount_authorized_minor: 0,
      amount_requested_minor: amountMinor,
      service_amount_minor: amountMinor,
      amount_captured_minor: 0,
      amount_refunded_minor: 0,
      application_fee_minor: 0,
      purpose: "tip",
      tip_percent: percent,
      provider: "stripe",
      provider_customer_id: profile.provider_customer_id as string,
      provider_payment_method_id: profile.default_payment_method_id as string,
      provider_payment_intent_id: null,
      provider_charge_id: null,
      connected_account_id: connectedAccountId,
      idempotency_key: buildIdempotencyKey("driverTip", paymentId),
      capture_attempt_count: 1,
      created_at: now,
      updated_at: now,
      stripe_environment: provider.environment,
    };
    tx.set(db.collection("payments").doc(paymentId), doc);
    return {
      kind: "charge" as const,
      amountMinor,
      percent,
      providerCustomerId: doc.provider_customer_id as string,
      providerPaymentMethodId: doc.provider_payment_method_id as string,
      connectedAccountId,
    };
  });
  if (prepared.kind === "done") {
    return { success: true, paymentId, status: PaymentStatuses.CAPTURED, amountMinor: prepared.amountMinor, reused: true };
  }

  // ---- 2. Débit, hors transaction ------------------------------------------
  const tipPercent = prepared.percent;
  const payRef = db.collection("payments").doc(paymentId);
  const result = await provider.chargeSavedPaymentMethod({
    providerCustomerId: prepared.providerCustomerId,
    providerPaymentMethodId: prepared.providerPaymentMethodId,
    amountMinor: prepared.amountMinor,
    currency: DEFAULT_CURRENCY,
    connectedAccountId: prepared.connectedAccountId,
    // 100 % au chauffeur : aucun frais de plateforme (frais Stripe absorbés par Movi-K).
    applicationFeeMinor: 0,
    idempotencyKey: buildIdempotencyKey("driverTip", paymentId, "1"),
    metadata: {
      movik_purpose: "driver_tip",
      movik_mission_id: input.missionId,
      movik_payment_id: paymentId,
      movik_customer_id: input.customerId,
      movik_driver_id: driverId,
      movik_tip_policy: DRIVER_TIP_POLICY.version,
    },
  });
  if (result.indeterminate) {
    // Réponse Stripe inconnue : le document reste en capture_pending ; le
    // prochain essai reprend la même clé (Stripe renvoie le même résultat).
    throw failedPrecondition("Le pourboire n'a pas pu être confirmé. Réessayez dans un instant.");
  }

  // ---- 3. Résultat, appliqué une seule fois -----------------------------------
  const applied = await db.runTransaction(async (tx) => {
    const current = (await tx.get(payRef)).data() as PaymentDoc | undefined;
    if (!current || current.status !== PaymentStatuses.CAPTURE_PENDING) return false;
    const now = admin.firestore.Timestamp.now();
    if (!result.success) {
      tx.update(payRef, {
        status: PaymentStatuses.FAILED,
        provider_payment_intent_id: result.providerPaymentIntentId,
        failed_at: now,
        failure_code: result.failureCode ?? null,
        failure_message: result.failureMessage ?? null,
        updated_at: now,
      });
      writeAuditLogInTransaction(tx, {
        actorUserId: input.customerId, actorRole: "customer", action: "driver_tip_refused",
        sourceFunction: "tipDriver", targetId: paymentId,
        metadata: { missionId: input.missionId, failureCode: result.failureCode ?? null },
      });
      return true;
    }
    const amountMinor = result.amountCapturedMinor;
    tx.update(payRef, {
      status: PaymentStatuses.CAPTURED,
      amount_captured_minor: amountMinor,
      provider_payment_intent_id: result.providerPaymentIntentId,
      provider_charge_id: result.providerChargeId,
      captured_at: now,
      updated_at: now,
      failure_code: null,
      failure_message: null,
    });
    const ledgerRef = db.collection("transaction_ledger").doc();
    tx.set(ledgerRef, {
      ledger_entry_id: ledgerRef.id,
      mission_id: input.missionId,
      transaction_id: paymentId,
      type: LedgerEntryTypes.DRIVER_TIP,
      purpose: "tip",
      amount: toMajorUnits(amountMinor),
      amount_minor: amountMinor,
      currency: DEFAULT_CURRENCY,
      direction: LedgerDirections.CREDIT,
      party: LedgerParties.DRIVER,
      created_at: now,
      created_by: "tipDriver",
      source_event: "driver_tip_captured",
      status: LedgerEntryStatuses.CONFIRMED,
      reference_id: null,
    });
    tx.update(missionRef, {
      tip: {
        amount_minor: amountMinor,
        percent: tipPercent,
        payment_id: paymentId,
        status: "paid",
        paid_at: now,
      },
    });
    const notifRef = db.collection("users").doc(driverId).collection("notifications").doc();
    tx.set(notifRef, {
      id: notifRef.id,
      type: "driver_tip_received",
      title_key: "notif_driver_tip_received_title",
      body_key: "notif_driver_tip_received_body",
      is_read: false,
      created_at: now,
      related_mission_id: input.missionId,
      metadata: { amount_minor: amountMinor },
    });
    writeAuditLogInTransaction(tx, {
      actorUserId: input.customerId, actorRole: "customer", action: "driver_tip_captured",
      sourceFunction: "tipDriver", targetId: paymentId,
      metadata: { missionId: input.missionId, driverId, amountMinor, percent: tipPercent },
    });
    return true;
  });

  if (result.success && applied) {
    // driver_tip_minor de mission_financial_balance (lecture multi-collections,
    // toujours hors transaction — voir missionFinancialBalance.ts).
    await recalculateMissionFinancialBalance(input.missionId);
    await sendDriverTipPush(driverId, input.missionId, result.amountCapturedMinor);
  }
  return {
    success: result.success,
    paymentId,
    status: result.success ? PaymentStatuses.CAPTURED : PaymentStatuses.FAILED,
    amountMinor: result.success ? result.amountCapturedMinor : 0,
    failureMessage: result.failureMessage ?? null,
    reused: false,
  };
}

const TIP_PUSH_COPY = {
  fr: { title: "Pourboire reçu 🎉", body: (a: string) => `Un client vous a laissé ${a} de pourboire. Merci pour votre excellent service !` },
  en: { title: "Tip received 🎉", body: (a: string) => `A customer left you a ${a} tip. Thanks for your great service!` },
  es: { title: "Propina recibida 🎉", body: (a: string) => `Un cliente te dejó ${a} de propina. ¡Gracias por tu excelente servicio!` },
} as const;

export function formatTipAmount(amountMinor: number, locale: "fr" | "en" | "es"): string {
  const dollars = (amountMinor / 100).toFixed(2);
  return locale === "en" ? `$${dollars}` : `${dollars.replace(".", ",")} $`;
}

/** Avis au chauffeur ; ne fait jamais échouer le pourboire. */
async function sendDriverTipPush(driverId: string, missionId: string, amountMinor: number): Promise<void> {
  try {
    const tokens = await db.collection("push_tokens").where("user_id", "==", driverId).get();
    for (const doc of tokens.docs) {
      const data = doc.data();
      if (typeof data.token !== "string" || data.token.length < 20) continue;
      const locale = normalizePushLocale(data.locale);
      const copy = TIP_PUSH_COPY[locale];
      await admin.messaging().send({
        token: data.token,
        notification: { title: copy.title, body: copy.body(formatTipAmount(amountMinor, locale)) },
        data: { type: "driver_tip_received", missionId, target: "driver_earnings" },
        android: { priority: "high", notification: { sound: "default", tag: `driver-tip-${missionId}` } },
      }).catch(() => undefined);
    }
  } catch (error) {
    console.error("[driver-tip] avis au chauffeur non envoyé", missionId, error instanceof Error ? error.message : error);
  }
}
