// -----------------------------------------------------------------------------
// adminServiceSettings — admin only (Centre de commande > Où et quand ?,
// owner decision 2026-10-26).
//   - "get": the service zones and the booking hours in force (saved, or the
//     launch defaults), each marked saved or not;
//   - "save" { zones?, hours? }: validates and writes system_config/
//     service_zones (circles) and/or system_config/booking_hours. Audited.
// An address outside every zone, or a time outside the hours, is refused
// before any price.
// -----------------------------------------------------------------------------
import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { writeAuditLogInTransaction } from "../lib/audit";
import { requireAdminOrAbove, requireSignedIn } from "../lib/auth";
import { BOOKING_HOURS_DOC, DEFAULT_BOOKING_HOURS, parseBookingHours } from "../lib/bookingHours";
import { invalidArgument } from "../lib/errors";
import { DEFAULT_SERVICE_ZONES, ServiceZoneCircle } from "../lib/serviceZones";

const ZONES_DOC = "system_config/service_zones";

export function parseZones(raw: unknown, errors: string[]): ServiceZoneCircle[] {
  if (!Array.isArray(raw) || raw.length === 0 || raw.length > 20) {
    errors.push("Zones : entre 1 et 20 zones.");
    return [];
  }
  return raw.map((z, i) => {
    const r = (z ?? {}) as Record<string, unknown>;
    const name = typeof r.name === "string" ? r.name.trim() : "";
    const label = name || `Zone ${i + 1}`;
    const lat = r.center_lat, lng = r.center_lng, radius = r.radius_km;
    if (!name || name.length > 80) errors.push(`${label} : nom requis (80 caractères au plus).`);
    if (typeof lat !== "number" || !Number.isFinite(lat) || Math.abs(lat) > 90 ||
        typeof lng !== "number" || !Number.isFinite(lng) || Math.abs(lng) > 180) {
      errors.push(`${label} : centre invalide.`);
    }
    if (typeof radius !== "number" || !Number.isFinite(radius) || radius < 1 || radius > 200) {
      errors.push(`${label} : rayon entre 1 et 200 km.`);
    }
    return { name, type: "circle" as const, center_lat: lat as number, center_lng: lng as number, radius_km: radius as number };
  });
}

export const adminServiceSettings = onCall(async (request) => {
  const ctx = requireSignedIn(request);
  requireAdminOrAbove(ctx);
  const data = (request.data ?? {}) as Record<string, unknown>;

  if (data.action === "get") {
    const [zonesSnap, hoursSnap] = await Promise.all([db.doc(ZONES_DOC).get(), db.doc(BOOKING_HOURS_DOC).get()]);
    const zonesData = zonesSnap.data();
    const hoursErrors: string[] = [];
    const savedHours = hoursSnap.exists ? parseBookingHours(hoursSnap.data(), hoursErrors) : null;
    return {
      zones: {
        saved: zonesSnap.exists,
        enabled: zonesSnap.exists ? zonesData?.enabled === true : DEFAULT_SERVICE_ZONES.enabled,
        list: zonesSnap.exists
          ? (Array.isArray(zonesData?.zones) ? zonesData!.zones : []).filter((z: unknown) =>
            z && typeof z === "object" && (z as { type?: unknown }).type === "circle")
          : DEFAULT_SERVICE_ZONES.zones,
      },
      hours: {
        saved: !!savedHours && hoursErrors.length === 0,
        ...(savedHours && hoursErrors.length === 0 ? savedHours : DEFAULT_BOOKING_HOURS),
      },
    };
  }

  if (data.action === "save") {
    const errors: string[] = [];
    const zones = data.zones === undefined ? null : parseZones(data.zones, errors);
    const hours = data.hours === undefined ? null : parseBookingHours(data.hours, errors);
    if (!zones && !hours) errors.push("Rien à enregistrer.");
    if (errors.length) throw invalidArgument(errors.join(" "));
    await db.runTransaction(async (tx) => {
      const now = admin.firestore.FieldValue.serverTimestamp();
      if (zones) tx.set(db.doc(ZONES_DOC), { enabled: true, zones, updated_at: now, updated_by_user_id: ctx.uid });
      if (hours) tx.set(db.doc(BOOKING_HOURS_DOC), { ...hours, updated_at: now, updated_by_user_id: ctx.uid });
      writeAuditLogInTransaction(tx, {
        actorUserId: ctx.uid, actorRole: ctx.role ?? "admin", action: "service_settings_saved",
        sourceFunction: "adminServiceSettings", targetId: "service_settings",
        metadata: { zones: zones?.map((z) => `${z.name} ${z.radius_km} km`) ?? null, hours: hours ?? null },
      });
    });
    return { success: true };
  }

  throw invalidArgument("Action inconnue.");
});
