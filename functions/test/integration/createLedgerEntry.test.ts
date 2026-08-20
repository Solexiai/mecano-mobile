// ---------------------------------------------------------------------------
// Test d'intégration — createLedgerEntry() (Bloc H, Tâche 1 + Tâche 4).
//
// Objectif : vérifier que createLedgerEntry() reste APPEND-ONLY (jamais de
// modification de l'entrée ledger existante pour "corriger" l'audit) ET
// qu'elle journalise explicitement l'événement métier
// `financial_adjustment_created` (distinct de l'action technique
// `createLedgerEntry` déjà existante) avec les champs minimum requis :
// actor, source, mission_id si applicable, amount_minor, ledger_entry_id,
// reason/type, created_at, correlation_id si disponible.
// ---------------------------------------------------------------------------

import type { CallableRequest, Request } from "firebase-functions/v2/https";
import type { DecodedIdToken } from "firebase-admin/auth";
import { createLedgerEntry, CreateLedgerEntryRequest } from "../../src/functions/createLedgerEntry";
import { admin, db } from "../../src/lib/admin";
import { LedgerDirections, LedgerEntryStatuses, LedgerEntryTypes, LedgerParties } from "../../src/lib/types";

const ADMIN_ID = "ledger_admin_001";
const NON_ADMIN_ID = "ledger_stranger_001";
const MISSION_ID = "ledger_adjustment_mission_001";

function buildRequest<T>(uid: string, role: string, data: T): CallableRequest<T> {
  return {
    data,
    auth: {
      uid,
      token: { role } as unknown as DecodedIdToken,
      rawToken: "fake-raw-token-for-emulator-test",
    },
    rawRequest: {} as Request,
    acceptsStreaming: false,
  };
}

async function cleanup(ledgerEntryIds: string[]): Promise<void> {
  const batch = db.batch();
  ledgerEntryIds.forEach((id) => batch.delete(db.collection("transaction_ledger").doc(id)));
  batch.delete(db.collection("mission_financial_balance").doc(MISSION_ID));
  await batch.commit();

  const auditSnap = await db
    .collection("audit_logs")
    .where("source_function", "==", "createLedgerEntry")
    .get();
  const batch2 = db.batch();
  auditSnap.docs.forEach((d) => {
    const targetId = d.data().target_id as string | undefined;
    if (targetId && ledgerEntryIds.includes(targetId)) batch2.delete(d.ref);
  });
  await batch2.commit();
}

describe("createLedgerEntry — ajustement financier manuel (append-only + audit financial_adjustment_created)", () => {
  const createdLedgerIds: string[] = [];

  afterEach(async () => {
    await cleanup(createdLedgerIds.splice(0, createdLedgerIds.length));
  });

  it("crée une entrée ledger CONFIRMED et journalise financial_adjustment_created avec tous les champs minimum requis", async () => {
    const result = await createLedgerEntry.run(
      buildRequest<CreateLedgerEntryRequest>(ADMIN_ID, "admin", {
        missionId: MISSION_ID,
        type: LedgerEntryTypes.DRIVER_ADJUSTMENT,
        amount: 12.5,
        direction: LedgerDirections.CREDIT,
        party: LedgerParties.DRIVER,
        sourceEvent: "correction_litige_123",
        reason: "Correction suite litige #123 — chauffeur sous-payé.",
        correlationId: "corr_test_001",
      })
    );
    expect(result.success).toBe(true);
    expect(result.ledgerEntryId).toBeTruthy();
    createdLedgerIds.push(result.ledgerEntryId as string);

    // ---- L'entrée ledger elle-même est bien CONFIRMED (pas COMPENSATED,
    // aucune référence à une entrée antérieure).
    const ledgerSnap = await db.collection("transaction_ledger").doc(result.ledgerEntryId as string).get();
    expect(ledgerSnap.exists).toBe(true);
    expect(ledgerSnap.data()!.status).toBe(LedgerEntryStatuses.CONFIRMED);
    expect(ledgerSnap.data()!.mission_id).toBe(MISSION_ID);

    // ---- L'action technique existante `createLedgerEntry` reste présente
    // (jamais renommée) — non-régression explicite.
    const technicalAudit = await db
      .collection("audit_logs")
      .where("action", "==", "createLedgerEntry")
      .where("target_id", "==", result.ledgerEntryId)
      .get();
    expect(technicalAudit.size).toBe(1);

    // ---- L'événement métier `financial_adjustment_created` existe RÉELLEMENT
    // (pas seulement une couverture indirecte) avec tous les champs minimum.
    const businessAudit = await db
      .collection("audit_logs")
      .where("action", "==", "financial_adjustment_created")
      .where("target_id", "==", result.ledgerEntryId)
      .get();
    expect(businessAudit.size).toBe(1);
    const entry = businessAudit.docs[0].data();
    expect(entry.actor_user_id).toBe(ADMIN_ID); // actor
    expect(entry.source_function).toBe("createLedgerEntry"); // source
    expect(entry.metadata.missionId).toBe(MISSION_ID); // mission_id si applicable
    expect(entry.metadata.amountMinor).toBe(1250); // amount_minor (12.50$ -> 1250 cents entiers)
    expect(Number.isInteger(entry.metadata.amountMinor)).toBe(true);
    expect(entry.metadata.ledgerEntryId).toBe(result.ledgerEntryId); // ledger_entry_id
    expect(entry.metadata.type).toBe(LedgerEntryTypes.DRIVER_ADJUSTMENT); // reason/type
    expect(entry.metadata.reason).toBe("Correction suite litige #123 — chauffeur sous-payé."); // reason
    expect(entry.metadata.createdAt).toBeTruthy(); // created_at
    expect(entry.metadata.correlationId).toBe("corr_test_001"); // correlation_id si disponible
  });

  it("utilise sourceEvent comme repli pour `reason` si aucun `reason` explicite n'est fourni", async () => {
    const result = await createLedgerEntry.run(
      buildRequest<CreateLedgerEntryRequest>(ADMIN_ID, "admin", {
        missionId: MISSION_ID,
        type: LedgerEntryTypes.CUSTOMER_ADJUSTMENT,
        amount: 5,
        direction: LedgerDirections.DEBIT,
        party: LedgerParties.CUSTOMER,
        sourceEvent: "correction_manuelle_sans_motif_explicite",
      })
    );
    createdLedgerIds.push(result.ledgerEntryId as string);

    const businessAudit = await db
      .collection("audit_logs")
      .where("action", "==", "financial_adjustment_created")
      .where("target_id", "==", result.ledgerEntryId)
      .get();
    expect(businessAudit.size).toBe(1);
    expect(businessAudit.docs[0].data().metadata.reason).toBe("correction_manuelle_sans_motif_explicite");
    // correlation_id absent -> explicitement null, jamais `undefined` non tracé.
    expect(businessAudit.docs[0].data().metadata.correlationId).toBeNull();
  });

  it(
    "correction d'une entrée existante (referenceId) : l'entrée ORIGINALE est marquée `reversed` " +
      "(jamais modifiée pour effacer sa valeur d'origine), une NOUVELLE entrée COMPENSATED est créée, " +
      "et financial_adjustment_created référence bien la NOUVELLE entrée",
    async () => {
      // Première entrée (celle qui sera "corrigée").
      const original = await createLedgerEntry.run(
        buildRequest<CreateLedgerEntryRequest>(ADMIN_ID, "admin", {
          missionId: MISSION_ID,
          type: LedgerEntryTypes.DRIVER_ADJUSTMENT,
          amount: 20,
          direction: LedgerDirections.CREDIT,
          party: LedgerParties.DRIVER,
          sourceEvent: "premier_ajustement_erronne",
        })
      );
      createdLedgerIds.push(original.ledgerEntryId as string);

      const originalAmountBefore = (
        await db.collection("transaction_ledger").doc(original.ledgerEntryId as string).get()
      ).data()!.amount;

      // Correction : référence l'entrée originale.
      const correction = await createLedgerEntry.run(
        buildRequest<CreateLedgerEntryRequest>(ADMIN_ID, "admin", {
          missionId: MISSION_ID,
          type: LedgerEntryTypes.DRIVER_ADJUSTMENT,
          amount: 25,
          direction: LedgerDirections.CREDIT,
          party: LedgerParties.DRIVER,
          sourceEvent: "correction_du_premier_ajustement",
          referenceId: original.ledgerEntryId as string,
          reason: "Le montant initial de 20$ était incorrect, corrigé à 25$.",
        })
      );
      createdLedgerIds.push(correction.ledgerEntryId as string);

      // L'entrée ORIGINALE n'a JAMAIS son `amount` modifié — seul son statut change.
      const originalAfter = (
        await db.collection("transaction_ledger").doc(original.ledgerEntryId as string).get()
      ).data()!;
      expect(originalAfter.amount).toBe(originalAmountBefore);
      expect(originalAfter.status).toBe(LedgerEntryStatuses.REVERSED);

      // La NOUVELLE entrée est COMPENSATED et référence l'originale.
      const correctionSnap = (
        await db.collection("transaction_ledger").doc(correction.ledgerEntryId as string).get()
      ).data()!;
      expect(correctionSnap.status).toBe(LedgerEntryStatuses.COMPENSATED);
      expect(correctionSnap.reference_id).toBe(original.ledgerEntryId);

      // L'audit financial_adjustment_created référence la NOUVELLE entrée créée.
      const businessAudit = await db
        .collection("audit_logs")
        .where("action", "==", "financial_adjustment_created")
        .where("target_id", "==", correction.ledgerEntryId)
        .get();
      expect(businessAudit.size).toBe(1);
      expect(businessAudit.docs[0].data().metadata.ledgerEntryId).toBe(correction.ledgerEntryId);
      expect(businessAudit.docs[0].data().metadata.referenceId).toBe(original.ledgerEntryId);
    }
  );

  it("refuse (permission-denied) si l'appelant n'est pas admin/super_admin", async () => {
    await expect(
      createLedgerEntry.run(
        buildRequest<CreateLedgerEntryRequest>(NON_ADMIN_ID, "customer", {
          missionId: MISSION_ID,
          type: LedgerEntryTypes.DRIVER_ADJUSTMENT,
          amount: 10,
          direction: LedgerDirections.CREDIT,
          party: LedgerParties.DRIVER,
          sourceEvent: "tentative_non_autorisee",
        })
      )
    ).rejects.toThrow();
  });

  it("refuse (invalid-argument) un montant <= 0", async () => {
    await expect(
      createLedgerEntry.run(
        buildRequest<CreateLedgerEntryRequest>(ADMIN_ID, "admin", {
          missionId: MISSION_ID,
          type: LedgerEntryTypes.DRIVER_ADJUSTMENT,
          amount: 0,
          direction: LedgerDirections.CREDIT,
          party: LedgerParties.DRIVER,
          sourceEvent: "montant_invalide",
        })
      )
    ).rejects.toThrow();
  });
});
