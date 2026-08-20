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

  const newEntryId = await db.runTransaction(async (tx) => {
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

    return entryRef.id;
  });

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
