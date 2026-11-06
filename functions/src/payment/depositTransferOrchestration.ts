// -----------------------------------------------------------------------------
// depositTransferOrchestration.ts — virements au chauffeur financés par le
// dépôt de réservation (décision Daniel, 2026-11-06 ; lib/bookingDeposit.ts).
//
// Deux cas :
//   1. Livraison terminée : le solde capturé (prix − dépôt) est une
//      « destination charge » ; ses frais de plateforme ont été réduits du
//      dépôt (paymentOrchestration.ts). Sur une petite livraison, cette
//      réduction ne suffit pas : la part manquante du chauffeur
//      (`deposit_driver_shortfall_minor` sur le paiement) est virée depuis la
//      charge du dépôt.
//   2. Dépôt gardé (annulation tardive du client, carte refusée la veille) :
//      20 $ au chauffeur, 5 $ à Movi-K, comme les frais d'annulation
//      d'avant (25 $ + 5 $). Écritures au registre et snapshot « frais » pour
//      que les revenus du chauffeur et les bilans le voient.
//
// Même schéma en 3 temps que les autres opérations : réservation en
// transaction (deposit_transfers/{id}, idempotent), appel Stripe hors
// transaction avec clé stable, application du résultat.
// -----------------------------------------------------------------------------

import { admin, db } from "../lib/admin";
import { writeAuditLogInTransaction } from "../lib/audit";
import { buildIdempotencyKey } from "../lib/idempotency";
import { DEFAULT_CURRENCY, toMajorUnits } from "../lib/money";
import { driverConnectedAccountFor } from "../lib/stripeAccounts";
import {
  LedgerDirections,
  LedgerEntryStatuses,
  LedgerEntryTypes,
  LedgerParties,
  MissionStatuses,
  PaymentDoc,
  PaymentStatuses,
} from "../lib/types";
import { getPaymentProvider } from "./paymentProviderFactory";

/** Dépôt gardé : répartition (à confirmer par Daniel ; même esprit que 25 $ + 5 $). */
export const DEPOSIT_KEPT_SPLIT = Object.freeze({
  version: "MOVIK-DEPOSIT-KEPT-20261106-001",
  driver_minor: 2000,
  platform_minor: 500,
});

export type DepositTransferKind = "driver_shortfall" | "deposit_kept";
export type DepositTransferResult = "transferred" | "already_done" | "not_applicable" | "failed";

export function depositTransferId(missionId: string, kind: DepositTransferKind): string {
  return `${missionId}_${kind === "driver_shortfall" ? "shortfall" : "kept"}`;
}

export function depositKeptSnapshotId(missionId: string): string {
  return `deposit_kept_${missionId}`;
}

interface PreparedTransfer {
  transferId: string;
  depositPaymentId: string;
  sourceChargeId: string;
  connectedAccountId: string;
  amountMinor: number;
  driverId: string;
  customerId: string;
  storedEnvironment: string | null;
}

async function depositChargeOf(tx: FirebaseFirestore.Transaction, mission: Record<string, any>):
  Promise<{ paymentId: string; chargeId: string; environment: string | null } | null> {
  const paymentId = mission.deposit?.payment_id;
  if (typeof paymentId !== "string" || !paymentId) return null;
  const payment = (await tx.get(db.collection("payments").doc(paymentId))).data() as PaymentDoc | undefined;
  if (!payment || payment.purpose !== "deposit" || payment.status !== PaymentStatuses.CAPTURED) return null;
  if (typeof payment.provider_charge_id !== "string" || !payment.provider_charge_id) return null;
  return { paymentId, chargeId: payment.provider_charge_id, environment: payment.stripe_environment ?? null };
}

/**
 * Cas 1 — part du chauffeur non couverte par le solde d'une livraison
 * terminée. Appelé quand le paiement de livraison passe à « captured ».
 */
export async function settleDepositDriverShortfall(missionId: string): Promise<DepositTransferResult> {
  const provider = getPaymentProvider();
  const missionRef = db.collection("delivery_requests").doc(missionId);
  const transferRef = db.collection("deposit_transfers").doc(depositTransferId(missionId, "driver_shortfall"));

  const prepared = await db.runTransaction(async (tx): Promise<{ outcome: DepositTransferResult } | { outcome: "transfer"; data: PreparedTransfer }> => {
    const existing = (await tx.get(transferRef)).data();
    if (existing?.status === "succeeded") return { outcome: "already_done" };
    const mission = (await tx.get(missionRef)).data();
    if (!mission || mission.deposit?.status !== "captured") return { outcome: "not_applicable" };
    const balanceId = mission.active_payment_id;
    if (typeof balanceId !== "string" || !balanceId) return { outcome: "not_applicable" };
    const balance = (await tx.get(db.collection("payments").doc(balanceId))).data() as PaymentDoc | undefined;
    const shortfall = balance?.deposit_driver_shortfall_minor ?? 0;
    if (!balance || balance.purpose === "deposit" || balance.status !== PaymentStatuses.CAPTURED ||
        balance.capture_purpose === "mission_fee" || !Number.isSafeInteger(shortfall) || shortfall <= 0 ||
        !balance.connected_account_id) {
      return { outcome: "not_applicable" };
    }
    const deposit = await depositChargeOf(tx, mission);
    if (!deposit) return { outcome: "not_applicable" };
    const amount = Math.min(shortfall, mission.deposit.amount_minor as number);
    const now = admin.firestore.Timestamp.now();
    if (!existing) {
      tx.set(transferRef, {
        transfer_id: transferRef.id, kind: "driver_shortfall", mission_id: missionId,
        driver_id: balance.driver_id, customer_id: mission.customer_id,
        deposit_payment_id: deposit.paymentId, balance_payment_id: balanceId,
        connected_account_id: balance.connected_account_id, amount_minor: amount, currency: DEFAULT_CURRENCY,
        status: "processing", provider_transfer_id: null, stripe_environment: provider.environment,
        attempts: 1, created_at: now, updated_at: now,
      });
    } else {
      tx.update(transferRef, { status: "processing", attempts: (existing.attempts ?? 1) + 1, updated_at: now });
    }
    return { outcome: "transfer", data: {
      transferId: transferRef.id, depositPaymentId: deposit.paymentId, sourceChargeId: deposit.chargeId,
      connectedAccountId: balance.connected_account_id, amountMinor: amount, driverId: balance.driver_id,
      customerId: mission.customer_id as string, storedEnvironment: deposit.environment } };
  });
  if (prepared.outcome !== "transfer") return prepared.outcome;
  return runTransfer(prepared.data, "driver_shortfall", missionId, provider.environment, null);
}

/**
 * Cas 2 — dépôt gardé : 20 $ au chauffeur (virement depuis la charge du
 * dépôt), 5 $ à Movi-K (reste sur la plateforme). Appelé au passage de la
 * mission à « annulée » avec `deposit.status == kept`.
 */
export async function settleKeptDeposit(missionId: string): Promise<DepositTransferResult> {
  const provider = getPaymentProvider();
  const missionRef = db.collection("delivery_requests").doc(missionId);
  const transferRef = db.collection("deposit_transfers").doc(depositTransferId(missionId, "deposit_kept"));

  const prepared = await db.runTransaction(async (tx): Promise<{ outcome: DepositTransferResult } | { outcome: "transfer"; data: PreparedTransfer }> => {
    const existing = (await tx.get(transferRef)).data();
    if (existing?.status === "succeeded") return { outcome: "already_done" };
    const mission = (await tx.get(missionRef)).data();
    if (!mission || mission.status !== MissionStatuses.CANCELLED || mission.deposit?.status !== "kept") return { outcome: "not_applicable" };
    const driverId = typeof mission.driver_id === "string" && mission.driver_id ? mission.driver_id as string : null;
    if (!driverId) return { outcome: "not_applicable" };
    const driver = (await tx.get(db.collection("driver_profiles").doc(driverId))).data();
    const connectedAccountId = driverConnectedAccountFor(driver as any, provider.environment);
    if (!connectedAccountId) {
      // Pas de compte de versement actif : rien ne part, l'admin le voit.
      const now = admin.firestore.Timestamp.now();
      tx.set(transferRef, { transfer_id: transferRef.id, kind: "deposit_kept", mission_id: missionId, driver_id: driverId,
        customer_id: mission.customer_id, status: "not_collectable", failure_code: "no_connected_account",
        amount_minor: DEPOSIT_KEPT_SPLIT.driver_minor, currency: DEFAULT_CURRENCY, created_at: now, updated_at: now }, { merge: true });
      return { outcome: "not_applicable" };
    }
    const deposit = await depositChargeOf(tx, mission);
    if (!deposit) return { outcome: "not_applicable" };
    const amount = Math.min(DEPOSIT_KEPT_SPLIT.driver_minor, mission.deposit.amount_minor as number);
    const now = admin.firestore.Timestamp.now();
    if (!existing) {
      tx.set(transferRef, {
        transfer_id: transferRef.id, kind: "deposit_kept", mission_id: missionId, driver_id: driverId,
        customer_id: mission.customer_id, deposit_payment_id: deposit.paymentId, balance_payment_id: null,
        connected_account_id: connectedAccountId, amount_minor: amount, currency: DEFAULT_CURRENCY,
        status: "processing", provider_transfer_id: null, stripe_environment: provider.environment,
        attempts: 1, created_at: now, updated_at: now,
      });
    } else {
      tx.update(transferRef, { status: "processing", attempts: (existing.attempts ?? 1) + 1, updated_at: now });
    }
    return { outcome: "transfer", data: {
      transferId: transferRef.id, depositPaymentId: deposit.paymentId, sourceChargeId: deposit.chargeId,
      connectedAccountId, amountMinor: amount, driverId, customerId: mission.customer_id as string,
      storedEnvironment: deposit.environment } };
  });
  if (prepared.outcome !== "transfer") return prepared.outcome;
  return runTransfer(prepared.data, "deposit_kept", missionId, provider.environment, {
    platformMinor: DEPOSIT_KEPT_SPLIT.platform_minor,
  });
}

async function runTransfer(
  data: PreparedTransfer,
  kind: DepositTransferKind,
  missionId: string,
  activeEnvironment: string,
  kept: { platformMinor: number } | null
): Promise<DepositTransferResult> {
  const provider = getPaymentProvider();
  const transferRef = db.collection("deposit_transfers").doc(data.transferId);
  const missionRef = db.collection("delivery_requests").doc(missionId);
  if (data.storedEnvironment && data.storedEnvironment !== activeEnvironment) {
    await transferRef.update({ status: "failed", failure_code: "stripe_environment_mismatch", updated_at: admin.firestore.Timestamp.now() });
    return "failed";
  }
  const attempt = (await transferRef.get()).data()?.attempts ?? 1;
  const result = await provider.createTransfer({
    connectedAccountId: data.connectedAccountId,
    amountMinor: data.amountMinor,
    currency: DEFAULT_CURRENCY,
    sourceChargeId: data.sourceChargeId,
    transferGroup: `mission_${missionId}`,
    idempotencyKey: buildIdempotencyKey("depositTransfer", data.transferId, String(attempt)),
    metadata: { movik_mission_id: missionId, movik_kind: kind, movik_deposit_payment_id: data.depositPaymentId },
  });

  await db.runTransaction(async (tx) => {
    const now = admin.firestore.Timestamp.now();
    const current = (await tx.get(transferRef)).data();
    if (current?.status === "succeeded") return;
    if (!result.success) {
      tx.update(transferRef, { status: "failed", failure_code: result.failureCode ?? null,
        failure_message: result.failureMessage ?? null, updated_at: now });
      writeAuditLogInTransaction(tx, {
        actorUserId: "system", actorRole: "system", action: "deposit_transfer_failed",
        sourceFunction: "depositTransferOrchestration", targetId: missionId,
        metadata: { kind, amountMinor: data.amountMinor, failureCode: result.failureCode ?? null },
      });
      return;
    }
    tx.update(transferRef, { status: "succeeded", provider_transfer_id: result.providerTransferId, succeeded_at: now, updated_at: now });
    tx.update(missionRef, {
      [`deposit.${kind === "driver_shortfall" ? "driver_shortfall_transfer" : "kept_transfer"}`]: {
        transfer_id: data.transferId, amount_minor: data.amountMinor, provider_transfer_id: result.providerTransferId, at: now,
      },
      "deposit.updated_at": now,
    });
    if (kept) {
      // Dépôt gardé : le registre et un snapshot « frais » décrivent ce que
      // la mission rapporte (20 $ chauffeur, 5 $ Movi-K), comme pour les
      // frais d'annulation d'avant.
      const snapshotRef = db.collection("financial_snapshots").doc(depositKeptSnapshotId(missionId));
      const total = data.amountMinor + kept.platformMinor;
      tx.set(snapshotRef, {
        snapshot_id: snapshotRef.id,
        snapshot_kind: "mission_fee",
        fee_kind: "deposit_kept",
        fee_policy_version: DEPOSIT_KEPT_SPLIT.version,
        mission_id: missionId,
        customer_id: data.customerId,
        driver_id: data.driverId,
        payment_id: data.depositPaymentId,
        customer_total: toMajorUnits(total),
        customer_total_minor: total,
        customer_service_fee: 0,
        customer_tax: 0,
        platform_commission_amount: toMajorUnits(kept.platformMinor),
        driver_offer_amount: toMajorUnits(data.amountMinor),
        driver_net_mission_earnings: toMajorUnits(data.amountMinor),
        driver_total_payout: toMajorUnits(data.amountMinor),
        created_at: now,
        confirmed_at: now,
        status: "confirmed",
      }, { merge: true });
      const entries: Array<Record<string, unknown>> = [
        { type: LedgerEntryTypes.PLATFORM_COMMISSION, amount: toMajorUnits(kept.platformMinor), amount_minor: kept.platformMinor,
          direction: LedgerDirections.CREDIT, party: LedgerParties.PLATFORM },
        { type: LedgerEntryTypes.DRIVER_EARNING, amount: toMajorUnits(data.amountMinor), amount_minor: data.amountMinor,
          direction: LedgerDirections.CREDIT, party: LedgerParties.DRIVER },
      ];
      for (const entry of entries) {
        const ref = db.collection("transaction_ledger").doc();
        tx.set(ref, {
          ledger_entry_id: ref.id, mission_id: missionId, transaction_id: data.depositPaymentId,
          currency: DEFAULT_CURRENCY, created_at: now, created_by: "settleKeptDeposit",
          source_event: "deposit_kept", fee_kind: "deposit_kept", status: LedgerEntryStatuses.CONFIRMED,
          reference_id: snapshotRef.id, ...entry,
        });
      }
    }
    writeAuditLogInTransaction(tx, {
      actorUserId: "system", actorRole: "system", action: "deposit_transfer_succeeded",
      sourceFunction: "depositTransferOrchestration", targetId: missionId,
      metadata: { kind, amountMinor: data.amountMinor, providerTransferId: result.providerTransferId },
    });
  });
  return result.success ? "transferred" : "failed";
}
