// -----------------------------------------------------------------------------
// adminPilotSetup — admin only. Manages the private pilot (2026-10-22):
//   - "get": testers (email + uid), whether the pilot is on, booking terms status;
//   - "addTester" { email }: adds an EXISTING account, found by its email;
//   - "removeTester" { uid };
//   - "setEnabled" { enabled };
//   - "publishTrialTerms": publishes the trial booking terms
//     (config/trialBookingPolicy.ts), never over an approved non-trial policy.
// The public switches (system_config/runtime_flags) are never changed here.
// Every change is written to audit_logs.
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { writeAuditLogInTransaction } from "../lib/audit";
import { requireAdminOrAbove, requireSignedIn } from "../lib/auth";
import { parseBookingPolicy } from "../lib/bookingContract";
import { failedPrecondition, invalidArgument, notFound } from "../lib/errors";
import { PILOT_ACCESS_DOC_ID, RUNTIME_FLAGS_COLLECTION } from "../lib/runtimeFlags";
import { TRIAL_POLICY_VERSION, trialBookingPolicy } from "../config/trialBookingPolicy";

const MAX_TESTERS = 200;

export const adminPilotSetup = onCall(async (request) => {
  const ctx = requireSignedIn(request);
  requireAdminOrAbove(ctx);
  const data = (request.data ?? {}) as Record<string, unknown>;
  const action = data.action;
  const pilotRef = db.collection(RUNTIME_FLAGS_COLLECTION).doc(PILOT_ACCESS_DOC_ID);
  const policyRef = db.collection(RUNTIME_FLAGS_COLLECTION).doc("booking_policy");
  const audit = (tx: FirebaseFirestore.Transaction, name: string, metadata: Record<string, unknown>) =>
    writeAuditLogInTransaction(tx, {
      actorUserId: ctx.uid, actorRole: ctx.role ?? "admin", action: name,
      sourceFunction: "adminPilotSetup", targetId: PILOT_ACCESS_DOC_ID, metadata,
    });

  if (action === "get") {
    const [pilot, policy] = await Promise.all([pilotRef.get(), policyRef.get()]);
    const ids: string[] = Array.isArray(pilot.data()?.user_ids) ? pilot.data()!.user_ids : [];
    const users = ids.length
      ? (await admin.auth().getUsers(ids.map((uid) => ({ uid })))).users
      : [];
    const emails = new Map(users.map((u) => [u.uid, u.email ?? null]));
    const parsed = parseBookingPolicy(policy.data());
    return {
      enabled: pilot.data()?.enabled === true,
      testers: ids.map((uid) => ({ uid, email: emails.get(uid) ?? null })),
      terms: parsed
        ? { published: true, version: parsed.version, trial: policy.data()?.trial === true }
        : { published: false, version: null, trial: false },
    };
  }

  if (action === "addTester") {
    const email = typeof data.email === "string" ? data.email.trim().toLowerCase() : "";
    if (!email || email.length > 320 || !email.includes("@")) throw invalidArgument("Adresse courriel invalide.");
    let uid: string;
    try {
      uid = (await admin.auth().getUserByEmail(email)).uid;
    } catch {
      throw notFound("Aucun compte avec ce courriel. La personne doit d'abord créer son compte sur movi-k.com.");
    }
    await db.runTransaction(async (tx) => {
      const current = (await tx.get(pilotRef)).data();
      const ids: string[] = Array.isArray(current?.user_ids) ? current!.user_ids : [];
      if (!ids.includes(uid) && ids.length >= MAX_TESTERS) throw failedPrecondition("Liste de testeurs pleine.");
      tx.set(pilotRef, { user_ids: admin.firestore.FieldValue.arrayUnion(uid),
        updated_at: admin.firestore.FieldValue.serverTimestamp(), updated_by_user_id: ctx.uid }, { merge: true });
      audit(tx, "pilot_tester_added", { uid });
    });
    return { success: true, uid };
  }

  if (action === "removeTester") {
    const uid = typeof data.uid === "string" ? data.uid : "";
    if (!uid || uid.length > 128) throw invalidArgument("Compte invalide.");
    await db.runTransaction(async (tx) => {
      tx.set(pilotRef, { user_ids: admin.firestore.FieldValue.arrayRemove(uid),
        updated_at: admin.firestore.FieldValue.serverTimestamp(), updated_by_user_id: ctx.uid }, { merge: true });
      audit(tx, "pilot_tester_removed", { uid });
    });
    return { success: true };
  }

  if (action === "setEnabled") {
    if (typeof data.enabled !== "boolean") throw invalidArgument("Valeur invalide.");
    const enabled = data.enabled;
    await db.runTransaction(async (tx) => {
      tx.set(pilotRef, { enabled, updated_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_by_user_id: ctx.uid }, { merge: true });
      audit(tx, enabled ? "pilot_enabled" : "pilot_disabled", {});
    });
    return { success: true, enabled };
  }

  if (action === "publishTrialTerms") {
    const policy = trialBookingPolicy();
    if (!parseBookingPolicy(policy)) throw failedPrecondition("Conditions d'essai invalides.");
    await db.runTransaction(async (tx) => {
      const current = (await tx.get(policyRef)).data();
      if (current && parseBookingPolicy(current) && current.trial !== true) {
        throw failedPrecondition("Des conditions approuvées sont déjà publiées : elles ne sont jamais remplacées par la version d'essai.");
      }
      tx.set(policyRef, { ...policy, published_at: admin.firestore.FieldValue.serverTimestamp(),
        published_by_user_id: ctx.uid });
      audit(tx, "trial_booking_terms_published", { version: TRIAL_POLICY_VERSION });
    });
    return { success: true, version: TRIAL_POLICY_VERSION };
  }

  throw invalidArgument("Action inconnue.");
});
