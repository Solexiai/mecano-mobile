// -----------------------------------------------------------------------------
// resolveReconciliationAnomaly — Cloud Function callable (admin/super_admin
// uniquement). Permet à un admin de marquer une anomalie de réconciliation
// comme reconnue (`acknowledged`) ou résolue (`resolved`) APRÈS
// investigation manuelle.
//
// 🔒 NE CORRIGE JAMAIS L'ANOMALIE FINANCIÈRE ELLE-MÊME — voir
// reconciliationEngine.ts. Cette fonction ne modifie QUE le statut de
// SUIVI de l'anomalie dans `reconciliation_reports/{id}.anomalies[i]`.
// Toute correction financière réelle (ex: refund manquant côté provider
// détecté) doit être appliquée via les primitives dédiées existantes
// (refundPayment, createLedgerEntry, calculateDriverPayout, etc.) — jamais
// par cette fonction, qui documente seulement qu'un humain a traité le cas.
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { requireAdminOrAbove, requireSignedIn } from "../lib/auth";
import { invalidArgument } from "../lib/errors";
import { writeAuditLog } from "../lib/audit";
import { resolveReconciliationAnomaly as resolveAnomaly } from "../lib/reconciliationEngine";

export interface ResolveReconciliationAnomalyRequest {
  reportId: string;
  anomalyIndex: number;
  newStatus: "acknowledged" | "resolved";
  resolutionNotes: string;
}

export const resolveReconciliationAnomaly = onCall<ResolveReconciliationAnomalyRequest>(
  async (request) => {
    const ctx = requireSignedIn(request);
    requireAdminOrAbove(ctx);
    const { reportId, anomalyIndex, newStatus, resolutionNotes } = request.data;

    if (!reportId) throw invalidArgument("reportId est requis.");
    if (typeof anomalyIndex !== "number" || anomalyIndex < 0) {
      throw invalidArgument("anomalyIndex doit être un entier positif.");
    }
    if (newStatus !== "acknowledged" && newStatus !== "resolved") {
      throw invalidArgument("newStatus doit être 'acknowledged' ou 'resolved'.");
    }
    if (!resolutionNotes || !resolutionNotes.trim()) {
      throw invalidArgument("resolutionNotes est requis (justification de la décision admin).");
    }

    await resolveAnomaly({
      reportId,
      anomalyIndex,
      newStatus,
      resolutionNotes,
      resolvedByUserId: ctx.uid,
    });

    await writeAuditLog({
      actorUserId: ctx.uid,
      actorRole: ctx.role ?? "admin",
      action: "reconciliation_anomaly_resolved",
      sourceFunction: "resolveReconciliationAnomaly",
      targetId: reportId,
      metadata: { anomalyIndex, newStatus, resolutionNotes },
    });

    return { success: true, reportId, anomalyIndex, newStatus };
  }
);
