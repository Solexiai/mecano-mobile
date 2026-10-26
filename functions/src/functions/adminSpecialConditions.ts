// -----------------------------------------------------------------------------
// adminSpecialConditions — admin only (Centre de commande > 5 · Conditions
// spéciales, owner decision 2026-10-26).
//   - "get": the conditions saved (or none), and whether the supplement is
//     in force right now;
//   - "save" { conditions }: validated, written to system_config/
//     special_conditions, audited.
// The supplement is shown to the customer with its reason before paying and
// locked in each quote; it ends by itself. The pause stops new prices and
// bookings; deliveries already booked continue.
// -----------------------------------------------------------------------------
import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { writeAuditLogInTransaction } from "../lib/audit";
import { requireAdminOrAbove, requireSignedIn } from "../lib/auth";
import { invalidArgument } from "../lib/errors";
import {
  activeConditionSurcharge, defaultSpecialConditions, parseSpecialConditions, SPECIAL_CONDITIONS_DOC,
} from "../lib/specialConditions";

export const adminSpecialConditions = onCall(async (request) => {
  const ctx = requireSignedIn(request);
  requireAdminOrAbove(ctx);
  const data = (request.data ?? {}) as Record<string, unknown>;

  if (data.action === "get") {
    const snap = await db.doc(SPECIAL_CONDITIONS_DOC).get();
    const errors: string[] = [];
    const conditions = snap.exists ? parseSpecialConditions(snap.data(), errors) : defaultSpecialConditions();
    return {
      saved: snap.exists,
      conditions,
      surchargeInForce: errors.length === 0 && activeConditionSurcharge(conditions) !== null,
      now: Date.now(),
    };
  }

  if (data.action === "save") {
    const errors: string[] = [];
    const conditions = parseSpecialConditions(data.conditions, errors);
    if (errors.length) throw invalidArgument(errors.join(" "));
    await db.runTransaction(async (tx) => {
      tx.set(db.doc(SPECIAL_CONDITIONS_DOC), {
        ...conditions,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_by_user_id: ctx.uid,
      });
      writeAuditLogInTransaction(tx, {
        actorUserId: ctx.uid, actorRole: ctx.role ?? "admin", action: "special_conditions_saved",
        sourceFunction: "adminSpecialConditions", targetId: "special_conditions",
        metadata: { surcharge: conditions.surcharge, pause: conditions.pause.active },
      });
    });
    return { success: true, surchargeInForce: activeConditionSurcharge(conditions) !== null };
  }

  throw invalidArgument("Action inconnue.");
});
