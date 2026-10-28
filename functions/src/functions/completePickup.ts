// -----------------------------------------------------------------------------
// completePickup — Cloud Function callable (driver assigné uniquement).
//
// PHOTO AU RAMASSAGE (décision du propriétaire, 2026-10-26) : obligatoire,
// comme à la livraison. Le chauffeur photographie l'article chargé
// (Storage `delivery_proofs/{missionId}/pickup_proof_*.jpg`) ; l'URL est
// dénormalisée sur la mission (`proof_of_pickup_url`) pour que le client la
// voie dans le détail, et reste tracée dans `tracking_events`.
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { requireSignedIn } from "../lib/auth";
import { failedPrecondition, invalidArgument, notFound, permissionDenied } from "../lib/errors";
import { assertProofUrlForMission } from "../lib/proofUrl";
import { MissionStatuses } from "../lib/types";
import { requireMissionProgressPermission } from "../lib/driverSuspensionPolicy";

export interface CompletePickupRequest {
  missionId: string;
  proofOfPickupUrl: string;
}

export const completePickup = onCall<CompletePickupRequest>(async (request) => {
  const ctx = requireSignedIn(request);
  const { missionId, proofOfPickupUrl } = request.data;
  if (!missionId) throw invalidArgument("missionId est requis.");
  // SEC-04 (2026-10-28) : URL Cloud Storage du dossier de preuves de CETTE mission.
  const proofUrl = assertProofUrlForMission(proofOfPickupUrl, missionId, "proofOfPickupUrl");

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

    // This read participates in the transaction, so an urgent suspension
    // committed concurrently forces Firestore to retry and refuse progress.
    await requireMissionProgressPermission(tx, ctx.uid);

    const now = admin.firestore.Timestamp.now();

    // IMPORTANT: Firestore exige que TOUTES les lectures d'une transaction
    // précèdent TOUTES les écritures. On lit donc le stop pickup (sequence 0)
    // AVANT le premier tx.update() sur la mission.
    const stopsSnap = await tx.get(
      missionRef.collection("stops").where("sequence", "==", 0).limit(1)
    );

    tx.update(missionRef, {
      status: MissionStatuses.PICKED_UP,
      picked_up_at: now,
      proof_of_pickup_url: proofUrl,
    });

    if (!stopsSnap.empty) {
      tx.update(stopsSnap.docs[0].ref, { completed_at: now });
    }

    const eventRef = missionRef.collection("tracking_events").doc();
    tx.set(eventRef, {
      event_type: "picked_up",
      actor_uid: ctx.uid,
      occurred_at: now,
      metadata: { proof_of_pickup_url: proofUrl },
    });
  });

  return { success: true, missionId };
});
