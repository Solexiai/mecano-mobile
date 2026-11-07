// -----------------------------------------------------------------------------
// updateAppVersionPolicy — Cloud Function callable (admin/super_admin).
//
// Point d'entrée UNIQUE pour modifier `app_config/app_versions` (version
// minimale de l'app Android — voir lib/appVersionPolicy.ts). Même patron que
// updateRuntimeFlags : lecture de l'ancienne valeur DANS la transaction,
// écrasement, audit avec old/new.
//
// Action `get` : lecture pour le Centre de commande (le document est
// public, mais l'admin passe par ici pour avoir les défauts résolus).
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { requireAdminOrAbove, requireSignedIn } from "../lib/auth";
import { invalidArgument } from "../lib/errors";
import { writeAuditLogInTransaction } from "../lib/audit";
import {
  APP_CONFIG_COLLECTION,
  APP_VERSIONS_DOC_ID,
  AppVersionPolicyDoc,
  parseMinBuild,
  readAppVersionPolicy,
} from "../lib/appVersionPolicy";

export interface UpdateAppVersionPolicyRequest {
  action: "get" | "save";
  /** Numéro de build Android minimal (0 = aucun minimum). Requis pour `save`. */
  android_min_build?: number;
  /** Note libre (max 200 caractères). */
  note?: string;
}

export interface UpdateAppVersionPolicyResponse {
  success: true;
  android_min_build: number;
  note: string;
  previous_android_min_build: number | null;
}

export const updateAppVersionPolicy = onCall<UpdateAppVersionPolicyRequest>(async (request) => {
  const ctx = requireSignedIn(request);
  requireAdminOrAbove(ctx);

  const data = request.data ?? ({} as UpdateAppVersionPolicyRequest);
  const ref = db.collection(APP_CONFIG_COLLECTION).doc(APP_VERSIONS_DOC_ID);

  if (data.action === "get") {
    const snap = await ref.get();
    const current = readAppVersionPolicy(snap.data());
    const result: UpdateAppVersionPolicyResponse = {
      success: true,
      ...current,
      previous_android_min_build: null,
    };
    return result;
  }
  if (data.action !== "save") {
    throw invalidArgument("action doit être 'get' ou 'save'.");
  }

  const parsed = parseMinBuild(data.android_min_build);
  if (!parsed.ok) throw invalidArgument(parsed.reason);
  const note = typeof data.note === "string" ? data.note.trim() : "";
  if (note.length > 200) throw invalidArgument("note : 200 caractères maximum.");

  const previous = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const before = readAppVersionPolicy(snap.data());
    const doc: AppVersionPolicyDoc = {
      android_min_build: parsed.value,
      note,
      updated_at: admin.firestore.Timestamp.now(),
      updated_by_user_id: ctx.uid,
    };
    tx.set(ref, doc);
    writeAuditLogInTransaction(tx, {
      actorUserId: ctx.uid,
      actorRole: ctx.role ?? "unknown",
      action: "app_version_policy_updated",
      sourceFunction: "updateAppVersionPolicy",
      targetId: `${APP_CONFIG_COLLECTION}/${APP_VERSIONS_DOC_ID}`,
      metadata: {
        oldValues: before,
        newValues: { android_min_build: parsed.value, note },
        wasBootstrapped: !snap.exists,
      },
    });
    return before;
  });

  const result: UpdateAppVersionPolicyResponse = {
    success: true,
    android_min_build: parsed.value,
    note,
    previous_android_min_build: previous.android_min_build,
  };
  return result;
});
