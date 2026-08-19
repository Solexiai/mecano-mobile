// -----------------------------------------------------------------------------
// audit_logs — trace immuable écrite par CHAQUE Cloud Function sensible.
// Voir docs/FIRESTORE_ARCHITECTURE.md #21 et lib/backend/models/audit_log.dart.
// -----------------------------------------------------------------------------

import { admin, db } from "./admin";

export interface AuditLogInput {
  actorUserId: string;
  actorRole: string;
  action: string;
  /**
   * Nom technique de la Cloud Function (ou du point d'entrée serveur) qui a
   * déclenché cette entrée d'audit. Sépare le NOM MÉTIER de l'action
   * (`action`, ex: "driver_approved") du COMPOSANT TECHNIQUE qui l'a exécutée
   * (ex: "approveDriver"), pour permettre une traçabilité technique précise
   * sans polluer le vocabulaire métier utilisé par les analystes/admins.
   */
  sourceFunction: string;
  targetId?: string | null;
  metadata?: Record<string, unknown>;
}

/**
 * Écrit une entrée d'audit. Doit être appelée DANS la même transaction /
 * exécution serveur que l'action principale qu'elle documente, pour garantir
 * qu'aucune opération sensible ne se produit sans trace.
 */
export async function writeAuditLog(input: AuditLogInput): Promise<void> {
  const ref = db.collection("audit_logs").doc();
  await ref.set({
    id: ref.id,
    actor_user_id: input.actorUserId,
    actor_role: input.actorRole,
    action: input.action,
    source_function: input.sourceFunction,
    target_id: input.targetId ?? null,
    metadata: input.metadata ?? {},
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/**
 * Variante utilisable À L'INTÉRIEUR d'une transaction Firestore existante
 * (ex: acceptDelivery). `transaction.set()` sur un nouveau document est
 * autorisé dans une transaction Firestore.
 */
export function writeAuditLogInTransaction(
  transaction: FirebaseFirestore.Transaction,
  input: AuditLogInput
): void {
  const ref = db.collection("audit_logs").doc();
  transaction.set(ref, {
    id: ref.id,
    actor_user_id: input.actorUserId,
    actor_role: input.actorRole,
    action: input.action,
    source_function: input.sourceFunction,
    target_id: input.targetId ?? null,
    metadata: input.metadata ?? {},
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  });
}
