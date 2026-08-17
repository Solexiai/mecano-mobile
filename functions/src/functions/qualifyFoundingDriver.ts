// -----------------------------------------------------------------------------
// qualifyFoundingDriver / revokeFoundingDriverStatus — Cloud Functions
// callable (admin/super_admin uniquement). Voir
// docs/FIRESTORE_ARCHITECTURE.md #13 (founding_driver_programs).
//
// 🔒 `slots_taken` est incrémenté de façon ATOMIQUE dans une transaction qui
// relit `total_slots`/`slots_taken`, pour éviter un dépassement de quota en
// cas de qualifications concurrentes (même pattern first-commit-wins que
// acceptDelivery, appliqué ici aux places du programme).
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { requireAdminOrAbove, requireSignedIn } from "../lib/auth";
import { failedPrecondition, invalidArgument, notFound } from "../lib/errors";
import { writeAuditLogInTransaction } from "../lib/audit";
import { FoundingDriverStatuses } from "../lib/types";

export interface QualifyFoundingDriverRequest {
  programId: string;
  driverId: string;
}

export const qualifyFoundingDriver = onCall<QualifyFoundingDriverRequest>(async (request) => {
  const ctx = requireSignedIn(request);
  requireAdminOrAbove(ctx);

  const { programId, driverId } = request.data;
  if (!programId || !driverId) throw invalidArgument("programId et driverId sont requis.");

  const programRef = db.collection("founding_driver_programs").doc(programId);
  const qualRef = programRef.collection("qualifications").doc(driverId);

  await db.runTransaction(async (tx) => {
    const [programSnap, qualSnap] = await Promise.all([tx.get(programRef), tx.get(qualRef)]);

    if (!programSnap.exists) throw notFound(`founding_driver_programs/${programId} introuvable.`);
    const program = programSnap.data()!;

    if (qualSnap.exists && qualSnap.data()!.status === FoundingDriverStatuses.QUALIFIED) {
      throw failedPrecondition("Ce chauffeur est déjà qualifié Founding Driver.");
    }

    // ---- Vérification atomique de disponibilité des places ----
    // Relecture DANS la transaction : si deux admins qualifient
    // simultanément le dernier slot disponible, Firestore ne laissera
    // qu'une des deux transactions committer avec la valeur à jour de
    // slots_taken — l'autre relira une valeur qui échoue à la vérification
    // ci-dessous après retry, garantissant qu'on ne dépasse jamais total_slots.
    if (program.slots_taken >= program.total_slots) {
      throw failedPrecondition("Programme Founding Driver complet (aucune place disponible).");
    }

    const now = admin.firestore.Timestamp.now();
    const promotionalPeriodEndsAt = admin.firestore.Timestamp.fromMillis(
      now.toMillis() + program.promotional_duration_months * 30 * 24 * 60 * 60 * 1000
    );

    tx.set(qualRef, {
      driver_id: driverId,
      program_id: programId,
      status: FoundingDriverStatuses.QUALIFIED,
      qualified_at: now,
      promotional_period_ends_at: promotionalPeriodEndsAt,
      suspension_reason: null,
      revocation_reason: null,
      status_changed_at: now,
      status_changed_by_user_id: ctx.uid,
    });

    tx.update(programRef, { slots_taken: admin.firestore.FieldValue.increment(1) });

    writeAuditLogInTransaction(tx, {
      actorUserId: ctx.uid,
      actorRole: ctx.role ?? "unknown",
      action: "qualifyFoundingDriver",
      sourceFunction: "qualifyFoundingDriver",
      targetId: driverId,
      metadata: { programId },
    });
  });

  return { success: true, driverId, programId };
});

export interface RevokeFoundingDriverStatusRequest {
  programId: string;
  driverId: string;
  reason: string;
}

export const revokeFoundingDriverStatus = onCall<RevokeFoundingDriverStatusRequest>(
  async (request) => {
    const ctx = requireSignedIn(request);
    requireAdminOrAbove(ctx);

    const { programId, driverId, reason } = request.data;
    if (!programId || !driverId) throw invalidArgument("programId et driverId sont requis.");
    if (!reason) throw invalidArgument("reason est requis.");

    const qualRef = db
      .collection("founding_driver_programs")
      .doc(programId)
      .collection("qualifications")
      .doc(driverId);

    await db.runTransaction(async (tx) => {
      const snap = await tx.get(qualRef);
      if (!snap.exists) throw notFound("Qualification introuvable.");

      const now = admin.firestore.Timestamp.now();
      tx.update(qualRef, {
        status: FoundingDriverStatuses.REVOKED,
        revocation_reason: reason,
        status_changed_at: now,
        status_changed_by_user_id: ctx.uid,
      });

      writeAuditLogInTransaction(tx, {
        actorUserId: ctx.uid,
        actorRole: ctx.role ?? "unknown",
        action: "revokeFoundingDriverStatus",
        sourceFunction: "revokeFoundingDriverStatus",
        targetId: driverId,
        metadata: { programId, reason },
      });
    });

    return { success: true, driverId, programId };
  }
);
