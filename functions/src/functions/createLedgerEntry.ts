// -----------------------------------------------------------------------------
// createLedgerEntry — Cloud Function callable (admin/super_admin uniquement)
// pour les CORRECTIONS MANUELLES exceptionnelles (ex: correction financière
// suite litige). Le flux normal (mission complétée) crée ses entrées
// directement dans `completeDelivery()`/`recordTip()` — cette fonction est
// réservée aux ajustements administratifs et aux entrées compensatoires.
//
// 🔒 APPEND-ONLY : cette fonction ne fait jamais un update/delete d'une
// entrée existante. Si `referenceId` est fourni, elle vérifie que l'entrée
// référencée existe et la marque `reversed` (elle-même, pas de suppression)
// tandis qu'une NOUVELLE entrée `confirmed` est créée pour la correction.
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { requireAdminOrAbove, requireSignedIn } from "../lib/auth";
import { invalidArgument, notFound } from "../lib/errors";
import { writeAuditLogInTransaction } from "../lib/audit";
import { recalculateMissionFinancialBalance } from "../lib/missionFinancialBalance";
import { toMinorUnits, DEFAULT_CURRENCY } from "../lib/money";
import {
  logFinancialFailure,
  logFinancialSuccess,
  resolveCorrelationId,
  startFinancialOperationTimer,
} from "../lib/observability";
import {
  LedgerDirection,
  LedgerEntryStatuses,
  LedgerEntryType,
  LedgerParty,
} from "../lib/types";

export interface CreateLedgerEntryRequest {
  missionId?: string;
  transactionId?: string;
  type: LedgerEntryType;
  amount: number;
  direction: LedgerDirection;
  party: LedgerParty;
  sourceEvent: string;
  referenceId?: string; // si correction d'une entrée existante
  /**
   * Motif métier de l'ajustement manuel (ex: "correction suite litige #123").
   * Optionnel mais recommandé — utilisé par l'événement d'audit
   * `financial_adjustment_created` (champ reason). Si absent, `sourceEvent`
   * est utilisé comme repli.
   */
  reason?: string;
  /**
   * Identifiant de corrélation optionnel (ex: propagé depuis un flux appelant
   * — support ticket, script d'ajustement en lot). Purement traçabilité,
   * jamais utilisé pour la logique métier.
   */
  correlationId?: string;
}

export const createLedgerEntry = onCall<CreateLedgerEntryRequest>(async (request) => {
  const ctx = requireSignedIn(request);
  requireAdminOrAbove(ctx);

  const input = request.data;
  if (typeof input.amount !== "number" || input.amount <= 0) {
    throw invalidArgument("amount doit être un nombre strictement positif.");
  }
  if (!input.type || !input.direction || !input.party || !input.sourceEvent) {
    throw invalidArgument("type, direction, party, sourceEvent sont requis.");
  }

  // 🔒 BLOC I (observabilité) — le correlationId peut déjà être fourni par
  // l'appelant (support, script d'ajustement en lot) : on le propage tel
  // quel, sinon on en génère un nouveau.
  const correlationId = resolveCorrelationId(input.correlationId);
  const operationStartedAt = startFinancialOperationTimer();

  let newEntryId: string;
  try {
    newEntryId = await db.runTransaction(async (tx) => {
    const now = admin.firestore.Timestamp.now();

    // Si correction : marquer l'entrée originale `reversed` (jamais supprimée).
    if (input.referenceId) {
      const originalRef = db.collection("transaction_ledger").doc(input.referenceId);
      const originalSnap = await tx.get(originalRef);
      if (!originalSnap.exists) {
        throw notFound(`transaction_ledger/${input.referenceId} introuvable.`);
      }
      tx.update(originalRef, { status: LedgerEntryStatuses.REVERSED });
    }

    const entryRef = db.collection("transaction_ledger").doc();
    tx.set(entryRef, {
      ledger_entry_id: entryRef.id,
      mission_id: input.missionId ?? null,
      transaction_id: input.transactionId ?? null,
      type: input.type,
      amount: input.amount,
      currency: "CAD",
      direction: input.direction,
      party: input.party,
      created_at: now,
      created_by: `createLedgerEntry:${ctx.uid}`,
      source_event: input.sourceEvent,
      status: input.referenceId
        ? LedgerEntryStatuses.COMPENSATED
        : LedgerEntryStatuses.CONFIRMED,
      reference_id: input.referenceId ?? null,
    });

    writeAuditLogInTransaction(tx, {
      actorUserId: ctx.uid,
      actorRole: ctx.role ?? "unknown",
      action: "createLedgerEntry",
      sourceFunction: "createLedgerEntry",
      targetId: entryRef.id,
      metadata: { ...input },
    });

    // 🔒 BLOC H (catalogue d'évènements financiers) — évènement métier
    // normalisé distinct de l'action technique `createLedgerEntry` ci-dessus
    // (jamais renommée, pour ne pas casser les tests existants qui la
    // référencent). Cette entrée d'audit documente explicitement la
    // création d'un AJUSTEMENT FINANCIER MANUEL, sans jamais modifier
    // l'entrée ledger existante elle-même pour "corriger" l'audit — seule
    // une NOUVELLE entrée ledger (déjà créée ci-dessus) et une NOUVELLE
    // entrée d'audit documentent la correction.
    writeAuditLogInTransaction(tx, {
      actorUserId: ctx.uid,
      actorRole: ctx.role ?? "unknown",
      action: "financial_adjustment_created",
      sourceFunction: "createLedgerEntry",
      targetId: entryRef.id,
      metadata: {
        missionId: input.missionId ?? null,
        amountMinor: toMinorUnits(input.amount, DEFAULT_CURRENCY),
        ledgerEntryId: entryRef.id,
        type: input.type,
        reason: input.reason ?? input.sourceEvent,
        createdAt: now,
        // 🔒 BLOC H (audit Firestore, contrat pré-existant) — reflète
        // FIDÈLEMENT ce que l'appelant a fourni, jamais un ID généré côté
        // serveur : `null` si absent. Le correlationId RÉSOLU (fourni ou
        // généré) est utilisé séparément pour l'observabilité (Bloc I,
        // Cloud Logging), jamais réinjecté ici.
        correlationId: input.correlationId ?? null,
        referenceId: input.referenceId ?? null,
      },
    });

    return entryRef.id;
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    logFinancialFailure(
      "financial_adjustment_created",
      operationStartedAt,
      "ledger_entry_creation_failed",
      { missionId: input.missionId },
      { correlationId, message, metadata: { type: input.type, sourceEvent: input.sourceEvent } }
    );
    throw err;
  }

  // 🔒 BLOC I (observabilité) — pas de duplication du contenu complet de
  // l'entrée ledger : seuls les identifiants métier et le montant (déjà en
  // cents) sont journalisés, jamais l'objet input brut.
  logFinancialSuccess(
    "financial_adjustment_created",
    operationStartedAt,
    { missionId: input.missionId ?? null },
    {
      correlationId,
      metadata: {
        ledgerEntryId: newEntryId,
        amountMinor: toMinorUnits(input.amount, DEFAULT_CURRENCY),
        type: input.type,
        referenceId: input.referenceId ?? null,
      },
    }
  );

  // 🔒 Bloc F (point 7) : un ajustement manuel modifie adjustments_minor de
  // mission_financial_balance — recalcul HORS transaction si missionId fourni
  // (une entrée ledger admin peut être rattachée à une transaction globale
  // sans mission, ex: correction comptable multi-missions — dans ce cas
  // aucun recalcul n'est possible/pertinent ici).
  if (input.missionId) {
    await recalculateMissionFinancialBalance(input.missionId);
  }

  return { success: true, ledgerEntryId: newEntryId };
});
