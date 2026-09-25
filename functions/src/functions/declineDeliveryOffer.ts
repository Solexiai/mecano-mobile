// Decline an existing offer; never creates/assigns a mission or touches money.
import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { requireSignedIn } from "../lib/auth";
import { invalidArgument, notFound, permissionDenied } from "../lib/errors";
import { liveOffer } from "../lib/dispatchEligibility";

export const declineDeliveryOffer = onCall<{ offerId: string }>(async (request) => {
  const ctx = requireSignedIn(request);
  const id = request.data?.offerId;
  if (typeof id !== "string" || !id || id.includes("/")) throw invalidArgument("offerId invalide.");
  const ref = db.collection("delivery_offers").doc(id);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw notFound("Offre introuvable.");
    const offer = snap.data()!;
    if (offer.driver_id !== ctx.uid) throw permissionDenied();
    if (offer.status !== "pending") return; // Idempotent, including concurrent accepts.
    const mission = await tx.get(db.collection("delivery_requests").doc(offer.mission_id));
    const open = mission.exists && !mission.data()!.driver_id &&
      ["searching_driver", "offered"].includes(mission.data()!.status);
    const status = !open ? "superseded" : liveOffer(offer, Date.now()) ? "declined" : "expired";
    tx.update(ref, { status, responded_at: admin.firestore.Timestamp.now() });
  });
  return { success: true };
});
