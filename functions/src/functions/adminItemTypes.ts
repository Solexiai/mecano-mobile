// -----------------------------------------------------------------------------
// adminItemTypes — admin only (owner decision 2026-10-26). The "Types d'objets
// et véhicules" screen: which vehicles may carry each item type.
//   - "get": the saved mapping, each type marked saved or proposed;
//   - "save" { mapping }: replaces photo_intake.category_vehicle_categories
//     in system_config/booking_capacity (every type, known vehicles only).
// Nothing else in booking_capacity changes (capacities, photo_intake.enabled).
// The price does not depend on the vehicle. Every save goes to audit_logs.
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { writeAuditLogInTransaction } from "../lib/audit";
import { requireAdminOrAbove, requireSignedIn } from "../lib/auth";
import { invalidArgument } from "../lib/errors";
import { ITEM_VEHICLES, parseItemVehicles, PROPOSED_ITEM_VEHICLES } from "../lib/itemTypes";
import { PHOTO_CATEGORIES } from "../lib/photoIntake";
import { normalizeVehicleCategory } from "../lib/vehicleCategory";

const CONFIG = db.collection("system_config").doc("booking_capacity");

export const adminItemTypes = onCall(async (request) => {
  const ctx = requireSignedIn(request);
  requireAdminOrAbove(ctx);
  const data = (request.data ?? {}) as Record<string, unknown>;

  if (data.action === "get") {
    const config = (await CONFIG.get()).data();
    const saved = config?.photo_intake?.category_vehicle_categories;
    const types = PHOTO_CATEGORIES.map((category) => {
      const raw = saved && typeof saved === "object" ? (saved as Record<string, unknown>)[category] : undefined;
      if (!Array.isArray(raw)) {
        return { category, vehicles: PROPOSED_ITEM_VEHICLES[category], saved: false };
      }
      const known = raw.filter((v): v is string => typeof v === "string").map(normalizeVehicleCategory);
      return { category, vehicles: ITEM_VEHICLES.filter((v) => known.includes(v)), saved: true };
    });
    return {
      configured: !!config,
      photoIntakeEnabled: config?.photo_intake?.enabled === true,
      vehicles: [...ITEM_VEHICLES],
      types,
    };
  }

  if (data.action === "save") {
    const mapping = parseItemVehicles(data.mapping);
    if (!mapping) throw invalidArgument("Tableau invalide : chaque type avec des véhicules connus.");
    const version = `admin-${new Date().toISOString().slice(0, 10)}`;
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(CONFIG);
      const fields = {
        category_vehicle_categories: mapping,
        version,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_by_user_id: ctx.uid,
      };
      if (snap.exists && snap.data()?.photo_intake) {
        tx.update(CONFIG, Object.fromEntries(Object.entries(fields).map(([k, v]) => [`photo_intake.${k}`, v])));
      } else {
        // First save (production had no booking_capacity, 2026-10-26): only
        // the grid is created. `enabled` stays false: it opens nothing in the
        // older measured-capacity path; the live price-first booking reads
        // the grid directly (quoteBeforeAssignment.vehicleCategoriesForLoad).
        tx.set(CONFIG, { photo_intake: { enabled: false, ...fields } }, { merge: true });
      }
      writeAuditLogInTransaction(tx, {
        actorUserId: ctx.uid, actorRole: ctx.role ?? "admin", action: "item_types_vehicles_saved",
        sourceFunction: "adminItemTypes", targetId: "booking_capacity",
        metadata: { version, not_offered: PHOTO_CATEGORIES.filter((c) => mapping[c].length === 0) },
      });
    });
    return { success: true, version };
  }

  throw invalidArgument("Action inconnue.");
});

