// -----------------------------------------------------------------------------
// runReconciliation — points d'entrée Cloud Functions du moteur de
// réconciliation (Phase 6, Bloc G, point 27).
//
// Deux modes d'exécution :
//   1. `runReconciliationNow` (onCall, admin/super_admin) — déclenchement
//      manuel sur une fenêtre temporelle explicite fournie par l'appelant
//      (ex: ré-audit ciblé après une anomalie suspectée).
//   2. `runDailyReconciliation` (onSchedule, cron quotidien) — exécute
//      automatiquement la réconciliation sur les dernières 24h glissantes,
//      sans intervention humaine, suivant le même schéma que
//      `processScheduledDriverPayouts.ts`.
//
// Aucune des deux fonctions n'applique de correction financière — voir
// reconciliationEngine.ts pour la garantie "jamais de correction silencieuse".
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { admin } from "../lib/admin";
import { requireAdminOrAbove, requireSignedIn } from "../lib/auth";
import { invalidArgument } from "../lib/errors";
import { writeAuditLog } from "../lib/audit";
import { STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET } from "../lib/secrets";
import { runReconciliation } from "../lib/reconciliationEngine";

export interface RunReconciliationNowRequest {
  periodStartMillis: number;
  periodEndMillis: number;
}

export const runReconciliationNow = onCall<RunReconciliationNowRequest>(
  { secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET] },
  async (request) => {
    const ctx = requireSignedIn(request);
    requireAdminOrAbove(ctx);

    const { periodStartMillis, periodEndMillis } = request.data;
    if (typeof periodStartMillis !== "number" || typeof periodEndMillis !== "number") {
      throw invalidArgument("periodStartMillis et periodEndMillis (nombres, ms epoch) sont requis.");
    }
    if (periodEndMillis <= periodStartMillis) {
      throw invalidArgument("periodEndMillis doit être strictement supérieur à periodStartMillis.");
    }

    const { reportId, report } = await runReconciliation({ periodStartMillis, periodEndMillis });

    await writeAuditLog({
      actorUserId: ctx.uid,
      actorRole: ctx.role ?? "admin",
      action: "reconciliation_anomaly_detected",
      sourceFunction: "runReconciliationNow",
      targetId: reportId,
      metadata: {
        status: report.status,
        anomalyCount: report.anomalies.length,
        periodStartMillis,
        periodEndMillis,
      },
    });

    return {
      success: true,
      reportId,
      status: report.status,
      anomalyCount: report.anomalies.length,
      totalPaymentsChecked: report.total_payments_checked,
      totalPayoutsChecked: report.total_payouts_checked,
      totalRefundsChecked: report.total_refunds_checked,
      reconciliationDifferenceMinor: report.reconciliation_difference_minor,
    };
  }
);

export const runDailyReconciliation = onSchedule(
  { schedule: "every day 03:00", secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET] },
  async () => {
    const now = admin.firestore.Timestamp.now();
    const periodEndMillis = now.toMillis();
    const periodStartMillis = periodEndMillis - 24 * 3600 * 1000;

    const { reportId, report } = await runReconciliation({ periodStartMillis, periodEndMillis });

    await writeAuditLog({
      actorUserId: "system",
      actorRole: "system",
      action:
        report.anomalies.length > 0 ? "reconciliation_anomaly_detected" : "reconciliation_completed_ok",
      sourceFunction: "runDailyReconciliation",
      targetId: reportId,
      metadata: {
        status: report.status,
        anomalyCount: report.anomalies.length,
        periodStartMillis,
        periodEndMillis,
      },
    });
  }
);
