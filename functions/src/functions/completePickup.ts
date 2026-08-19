// -----------------------------------------------------------------------------
// completePickup — Cloud Function callable (driver assigné uniquement).
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { requireSignedIn } from "../lib/auth";
import { failedPrecondition, invalidArgument, notFound, permissionDenied } from "../lib/errors";
import { MissionStatuses } from "../lib/types";

export interface CompletePickupRequest {
  missionId: string;
  proofOfPickupUrl?: string;
}

export const completePickup = onCall<CompletePickupRequest>(async (request) => {
  const ctx = requireSignedIn(request);
  const { missionId, proofOfPickupUrl } = request.data;
  if (!missionId) throw invalidArgument("missionId est requis.");

  const missionRef = db.collection("delivery_requests").doc(missionId);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(missionRef);
    if (!snap.exists) throw notFound(`delivery_requests/${missionId} introuvable.`);
    const mission = snap.data()!;

    if (mission.driver_id !== ctx.uid) {
      throw permissionDenied("Seul le chauffeur assigné peut confirmer le ramassage.");
    }
    if (![MissionStatuses.ASSIGNED, MissionStatuses.DRIVER_TO_PICKUP, MissionStatuses.ARRIVED_AT_PICKUP].includes(mission.status)) {
      throw failedPrecondition(`Transition invalide depuis le statut '${mission.status}'.`);
    }

    const now = admin.firestore.Timestamp.now();

    // IMPORTANT: Firestore exige que TOUTES les lectures d'une transaction
    // précèdent TOUTES les écritures. On lit donc le stop pickup (sequence 0)
    // AVANT le premier tx.update() sur la mission.
    const stopsSnap = await tx.get(
      missionRef.collection("stops").where("sequence", "==", 0).limit(1)
    );

    tx.update(missionRef, { status: MissionStatuses.PICKED_UP, picked_up_at: now });

    if (!stopsSnap.empty) {
      tx.update(stopsSnap.docs[0].ref, { completed_at: now });
    }

    const eventRef = missionRef.collection("tracking_events").doc();
    tx.set(eventRef, {
      event_type: "picked_up",
      actor_uid: ctx.uid,
      occurred_at: now,
      metadata: proofOfPickupUrl ? { proof_of_pickup_url: proofOfPickupUrl } : {},
    });
  });

  return { success: true, missionId };
});
