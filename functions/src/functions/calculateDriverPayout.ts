// -----------------------------------------------------------------------------
// calculateDriverPayout — Cloud Function callable (admin/super_admin).
//
// PHASE 6 (point 9 du cahier des charges) : « driver payout avec
// payout_hold_period / payout_eligible_at CONFIGURABLE ». Réécriture
// complète depuis la version legacy (float `amount`, statut bare-string) :
//
// 1. Agrège les financial_snapshots CONFIRMED non encore inclus dans un
//    payout (`driver_net_mission_earnings`, en dollars — frontière legacy
//    documentée dans lib/money.ts).
// 2. Convertit le total en cents entiers (amount_minor) UNE SEULE FOIS, à
//    la frontière (point 32).
// 3. Résout la période de rétention applicable via
//    `payout_policy_configs/default` (jamais hardcodée) et calcule
//    `payout_eligible_at = now + hold_period_hours`.
// 4. Crée `driver_payouts/{id}` dans le statut initial adéquat de la
//    machine d'état (payoutStateMachine.ts) : ELIGIBLE si la rétention est
//    nulle (0h) et un compte connecté existe déjà, sinon PENDING/HELD.
// 5. Si le versement est immédiatement ELIGIBLE, déclenche l'appel réel au
//    fournisseur via `submitDriverPayout()` (paymentOrchestration.ts, même
//    schéma en 3 temps que createAndAuthorizeMissionPayment/
//    captureMissionPayment — AUCUN appel PaymentProvider ne se produit dans
//    la transaction Firestore ci-dessous).
//
// Si la rétention n'est pas encore écoulée, le versement reste en
// PENDING/HELD : c'est `processScheduledPayouts` (tâche planifiée, voir
// TODO ci-dessous) qui le fera transiter vers ELIGIBLE puis appellera
// `submitDriverPayout()` une fois `payout_eligible_at` atteint. Cette
// fonction callable NE bloque JAMAIS en attente de la rétention.
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { requireAdminOrAbove, requireSignedIn } from "../lib/auth";
import { invalidArgument } from "../lib/errors";
import { writeAuditLogInTransaction } from "../lib/audit";
import { buildIdempotencyKey } from "../lib/idempotency";
import { toMinorUnits, DEFAULT_CURRENCY } from "../lib/money";
import {
  logFinancialFailure,
  logFinancialSuccess,
  resolveCorrelationId,
  startFinancialOperationTimer,
} from "../lib/observability";
import {
  DriverPayoutDoc,
  DriverProfileDoc,
  LedgerDirections,
  LedgerEntryStatuses,
  LedgerEntryTypes,
  LedgerParties,
  PayoutStatus,
  PayoutStatuses,
} from "../lib/types";
import { readPayoutPolicyConfig, resolveHoldPeriodHours } from "./updatePayoutPolicyConfiguration";
import { submitDriverPayout } from "../payment/paymentOrchestration";

export interface CalculateDriverPayoutRequest {
  driverId: string;
}

export const calculateDriverPayout = onCall<CalculateDriverPayoutRequest>(async (request) => {
  const ctx = requireSignedIn(request);
  requireAdminOrAbove(ctx);
  const { driverId } = request.data;
  if (!driverId) throw invalidArgument("driverId est requis.");

  // 🔒 BLOC I (observabilité) — point d'entrée admin de la création d'un
  // versement (distinct de sa SOUMISSION au fournisseur, déjà instrumentée
  // dans submitDriverPayout()). Aucun correlationId entrant possible ici
  // (déclenchement manuel admin) : génération systématique.
  const correlationId = resolveCorrelationId(undefined);
  const operationStartedAt = startFinancialOperationTimer();

  const snapshotsQuery = await db
    .collection("financial_snapshots")
    .where("driver_id", "==", driverId)
    .where("status", "==", "confirmed")
    .get();
  const eligibleSnapshots = snapshotsQuery.docs.filter((d) => !d.data().included_in_payout_id);
  if (eligibleSnapshots.length === 0) {
    return { success: true, payoutId: null, amountMinor: 0, message: "Aucun snapshot éligible." };
  }
  const totalMajor = eligibleSnapshots.reduce(
    (sum, d) => sum + (d.data().driver_net_mission_earnings as number),
    0
  );
  // 🔒 Frontière legacy -> Phase 6 (point 32) : conversion en cents entiers
  // UNE SEULE FOIS ici, jamais de recalcul flottant en aval.
  const amountMinor = toMinorUnits(totalMajor, DEFAULT_CURRENCY);

  const driverSnap = await db.collection("driver_profiles").doc(driverId).get();
  const driver = driverSnap.data() as DriverProfileDoc | undefined;
  const connectedAccountId = driver?.stripe_connected_account_id ?? null;

  const policy = await readPayoutPolicyConfig();
  const holdPeriodHours = resolveHoldPeriodHours(policy, driver);

  const payoutRef = db.collection("driver_payouts").doc();
  const idempotencyKey = buildIdempotencyKey("createDriverPayout", payoutRef.id);

  let payoutId: string;
  let initialStatus: PayoutStatus;
  try {
    ({ payoutId, initialStatus } = await db.runTransaction(async (tx) => {
    const now = admin.firestore.Timestamp.now();
    const eligibleAtMillis = now.toMillis() + holdPeriodHours * 3600 * 1000;
    const payoutEligibleAt = admin.firestore.Timestamp.fromMillis(eligibleAtMillis);

    // Statut initial explicite : PENDING tant que la rétention n'est pas
    // écoulée. Si holdPeriodHours === 0 ET un compte connecté existe déjà,
    // le versement démarre directement ELIGIBLE (transition valide
    // pending -> eligible immédiate, sans attendre un cron).
    const initial =
      holdPeriodHours === 0 && connectedAccountId ? PayoutStatuses.ELIGIBLE : PayoutStatuses.PENDING;

    const payout: DriverPayoutDoc = {
      driver_id: driverId,
      financial_snapshot_ids: eligibleSnapshots.map((d) => d.id),
      amount_minor: amountMinor,
      currency: DEFAULT_CURRENCY,
      status: initial,
      payout_hold_period_hours: holdPeriodHours,
      payout_eligible_at: payoutEligibleAt,
      provider_payout_id: null,
      connected_account_id: connectedAccountId,
      created_at: now,
      scheduled_at: null,
      processing_at: null,
      paid_at: null,
      failed_at: null,
      failure_reason: null,
      idempotency_key: idempotencyKey,
    };
    tx.set(payoutRef, payout);

    for (const snap of eligibleSnapshots) {
      tx.update(snap.ref, { included_in_payout_id: payoutRef.id });
    }

    const ledgerRef = db.collection("transaction_ledger").doc();
    tx.set(ledgerRef, {
      ledger_entry_id: ledgerRef.id,
      mission_id: null,
      transaction_id: payoutRef.id,
      type: LedgerEntryTypes.DRIVER_PAYOUT,
      amount: totalMajor,
      currency: DEFAULT_CURRENCY,
      direction: LedgerDirections.DEBIT,
      party: LedgerParties.DRIVER,
      created_at: now,
      created_by: "calculateDriverPayout",
      source_event: "payout_batch_created",
      status: LedgerEntryStatuses.CONFIRMED,
      reference_id: null,
    });

    writeAuditLogInTransaction(tx, {
      actorUserId: ctx.uid,
      actorRole: ctx.role ?? "unknown",
      action: "calculateDriverPayout",
      sourceFunction: "calculateDriverPayout",
      targetId: driverId,
      metadata: {
        payoutId: payoutRef.id,
        amountMinor,
        snapshotCount: eligibleSnapshots.length,
        holdPeriodHours,
        initialStatus: initial,
      },
    });

    // 🔒 BLOC H (catalogue d'évènements financiers) — action métier normalisée
    // distincte de l'action technique `calculateDriverPayout` ci-dessus (jamais
    // renommée pour ne pas casser les tests existants qui la référencent).
    writeAuditLogInTransaction(tx, {
      actorUserId: ctx.uid,
      actorRole: ctx.role ?? "unknown",
      action: "payout_created",
      sourceFunction: "calculateDriverPayout",
      targetId: payoutRef.id,
      metadata: { driverId, amountMinor, snapshotCount: eligibleSnapshots.length, initialStatus: initial },
    });

    return { payoutId: payoutRef.id, initialStatus: initial };
  }));
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    logFinancialFailure(
      "payout_creation",
      operationStartedAt,
      "payout_creation_failed",
      { payoutId: payoutRef.id },
      { correlationId, message, metadata: { driverId, amountMinor } }
    );
    throw err;
  }

  logFinancialSuccess(
    "payout_creation",
    operationStartedAt,
    { payoutId },
    {
      correlationId,
      metadata: { driverId, amountMinor, snapshotCount: eligibleSnapshots.length, initialStatus },
    }
  );

  // Si déjà ELIGIBLE (rétention nulle + compte connecté existant), on
  // déclenche immédiatement l'appel réel au fournisseur, HORS de la
  // transaction ci-dessus (voir submitDriverPayout — schéma en 3 temps).
  if (initialStatus === PayoutStatuses.ELIGIBLE) {
    const outcome = await submitDriverPayout(payoutId);
    return {
      success: outcome.success,
      payoutId,
      amountMinor,
      status: outcome.status,
      message: outcome.success
        ? "Versement transmis au fournisseur."
        : (outcome.failureMessage ?? "Versement refusé par le fournisseur."),
    };
  }

  return {
    success: true,
    payoutId,
    amountMinor,
    status: initialStatus,
    message: `Versement créé, en attente de rétention (${holdPeriodHours}h).`,
  };
});
