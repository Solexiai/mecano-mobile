// -----------------------------------------------------------------------------
// applyDriverPromotion — Cloud Function callable (admin/super_admin uniquement).
// Voir docs/FIRESTORE_ARCHITECTURE.md #12 (driver_promotions).
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { requireAdminOrAbove, requireSignedIn } from "../lib/auth";
import { invalidArgument, notFound } from "../lib/errors";
import { writeAuditLog } from "../lib/audit";

export interface ApplyDriverPromotionRequest {
  driverId: string;
  promotionalCommissionRate: number; // ex: 0.08 pour 8%
  startsAtMillis: number;
  endsAtMillis: number;
  reason?: string;
}

export const applyDriverPromotion = onCall<ApplyDriverPromotionRequest>(async (request) => {
  const ctx = requireSignedIn(request);
  requireAdminOrAbove(ctx);

  const input = request.data;
  if (!input.driverId) throw invalidArgument("driverId est requis.");
  if (typeof input.promotionalCommissionRate !== "number" || input.promotionalCommissionRate < 0 || input.promotionalCommissionRate > 1) {
    throw invalidArgument("promotionalCommissionRate doit être compris entre 0 et 1.");
  }
  if (!input.startsAtMillis || !input.endsAtMillis || input.endsAtMillis <= input.startsAtMillis) {
    throw invalidArgument("startsAtMillis/endsAtMillis invalides (endsAt doit être après startsAt).");
  }

  const driverSnap = await db.collection("driver_profiles").doc(input.driverId).get();
  if (!driverSnap.exists) throw notFound(`driver_profiles/${input.driverId} introuvable.`);

  const promoRef = db.collection("driver_promotions").doc();
  await promoRef.set({
    driver_id: input.driverId,
    promotional_commission_rate: input.promotionalCommissionRate,
    starts_at: admin.firestore.Timestamp.fromMillis(input.startsAtMillis),
    ends_at: admin.firestore.Timestamp.fromMillis(input.endsAtMillis),
    is_active: true,
    created_by_user_id: ctx.uid,
    reason: input.reason ?? null,
  });

  // Rafraîchit le cache d'affichage driver_pricing_profiles (jamais utilisé
  // pour un calcul financier réel — voir note dans FIRESTORE_ARCHITECTURE.md #11).
  await db.collection("driver_pricing_profiles").doc(input.driverId).set(
    {
      driver_id: input.driverId,
      resolved_commission_rate: input.promotionalCommissionRate,
      resolved_program: "promotional",
      resolved_reason: "active_driver_promotion",
      last_resolved_at: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  await writeAuditLog({
    actorUserId: ctx.uid,
    actorRole: ctx.role ?? "unknown",
    action: "applyDriverPromotion",
    sourceFunction: "applyDriverPromotion",
    targetId: input.driverId,
    metadata: { promoId: promoRef.id, ...input },
  });

  return { success: true, promotionId: promoRef.id };
});
