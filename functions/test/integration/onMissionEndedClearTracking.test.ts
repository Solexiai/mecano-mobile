// ---------------------------------------------------------------------------
// Test d'intégration — onMissionEndedClearTracking (Phase 5, partie 2).
//
// Couvre :
// - Transition vers 'cancelled'/'disputed'/'refunded' AVEC driver_id assigné
//   ET driver_locations.active_delivery_id pointant vers CETTE mission :
//   le champ doit être remis à null (positif).
// - Transition vers un statut NON terminal (ex: in_transit) : ne doit RIEN
//   modifier (négatif).
// - Mission sans driver_id (jamais assignée) : ne doit RIEN modifier
//   (négatif — rien à nettoyer).
// - driver_locations.active_delivery_id pointant déjà vers UNE AUTRE
//   mission (le chauffeur a enchaîné) : ne doit PAS écraser cette valeur
//   plus récente (négatif — protection contre une race avec acceptDelivery).
// - Transition DÉJÀ terminale -> terminale (ex: cancelled -> disputed) :
//   ne redéclenche pas d'écriture (le nettoyage a déjà eu lieu à la
//   première transition terminale).
// - Statut 'completed' : volontairement PAS géré par ce trigger (déjà géré
//   par completeDelivery() lui-même, voir en-tête du fichier source) —
//   vérifié ici pour documenter explicitement la non-duplication.
// ---------------------------------------------------------------------------

import type { Change, FirestoreEvent, QueryDocumentSnapshot } from "firebase-functions/v2/firestore";
import { onMissionEndedClearTracking } from "../../src/functions/onMissionEndedClearTracking";
import { db } from "../../src/lib/admin";

const MISSION_ID = "clear_tracking_mission_001";
const DRIVER_ID = "clear_tracking_driver_a";

function fakeSnap(data: Record<string, unknown> | undefined): QueryDocumentSnapshot {
  return {
    data: () => data,
  } as unknown as QueryDocumentSnapshot;
}

function buildEvent(
  before: Record<string, unknown> | undefined,
  after: Record<string, unknown> | undefined
): FirestoreEvent<Change<QueryDocumentSnapshot> | undefined, { missionId: string }> {
  return {
    data: {
      before: fakeSnap(before),
      after: fakeSnap(after),
    } as unknown as Change<QueryDocumentSnapshot>,
    params: { missionId: MISSION_ID },
  } as unknown as FirestoreEvent<Change<QueryDocumentSnapshot> | undefined, { missionId: string }>;
}

async function cleanup(): Promise<void> {
  await Promise.all([
    db.collection("driver_locations").doc(DRIVER_ID).delete(),
    db.collection("delivery_requests").doc(MISSION_ID).delete(),
  ]);
}

describe("onMissionEndedClearTracking — nettoyage à l'annulation/dispute/remboursement", () => {
  afterEach(cleanup);

  it("efface active_delivery_id quand une mission ASSIGNÉE passe à 'cancelled'", async () => {
    await db
      .collection("driver_locations")
      .doc(DRIVER_ID)
      .set({ active_delivery_id: MISSION_ID }, { merge: true });

    await onMissionEndedClearTracking.run(
      buildEvent(
        { status: "in_transit", driver_id: DRIVER_ID },
        { status: "cancelled", driver_id: DRIVER_ID }
      )
    );

    const locationSnap = await db.collection("driver_locations").doc(DRIVER_ID).get();
    expect(locationSnap.data()!.active_delivery_id).toBeNull();
  });

  it("efface active_delivery_id quand une mission passe à 'disputed'", async () => {
    await db
      .collection("driver_locations")
      .doc(DRIVER_ID)
      .set({ active_delivery_id: MISSION_ID }, { merge: true });

    await onMissionEndedClearTracking.run(
      buildEvent(
        { status: "arrived_at_dropoff", driver_id: DRIVER_ID },
        { status: "disputed", driver_id: DRIVER_ID }
      )
    );

    const locationSnap = await db.collection("driver_locations").doc(DRIVER_ID).get();
    expect(locationSnap.data()!.active_delivery_id).toBeNull();
  });

  it("efface active_delivery_id quand une mission passe à 'refunded'", async () => {
    await db
      .collection("driver_locations")
      .doc(DRIVER_ID)
      .set({ active_delivery_id: MISSION_ID }, { merge: true });

    await onMissionEndedClearTracking.run(
      buildEvent(
        { status: "completed", driver_id: DRIVER_ID },
        { status: "refunded", driver_id: DRIVER_ID }
      )
    );

    const locationSnap = await db.collection("driver_locations").doc(DRIVER_ID).get();
    expect(locationSnap.data()!.active_delivery_id).toBeNull();
  });

  it("[négatif] ne modifie RIEN pour une transition vers un statut NON terminal (ex: in_transit)", async () => {
    await db
      .collection("driver_locations")
      .doc(DRIVER_ID)
      .set({ active_delivery_id: MISSION_ID }, { merge: true });

    await onMissionEndedClearTracking.run(
      buildEvent(
        { status: "picked_up", driver_id: DRIVER_ID },
        { status: "in_transit", driver_id: DRIVER_ID }
      )
    );

    const locationSnap = await db.collection("driver_locations").doc(DRIVER_ID).get();
    expect(locationSnap.data()!.active_delivery_id).toBe(MISSION_ID);
  });

  it("[négatif] ne modifie RIEN si la mission n'a jamais eu de driver_id assigné", async () => {
    await onMissionEndedClearTracking.run(
      buildEvent(
        { status: "searching_driver", driver_id: null },
        { status: "cancelled", driver_id: null }
      )
    );
    // Aucun document driver_locations ne doit avoir été créé.
    const locationSnap = await db.collection("driver_locations").doc(DRIVER_ID).get();
    expect(locationSnap.exists).toBe(false);
  });

  it("[négatif] n'écrase PAS active_delivery_id si le chauffeur a déjà enchaîné une AUTRE mission", async () => {
    const NEWER_MISSION_ID = "clear_tracking_mission_newer";
    await db
      .collection("driver_locations")
      .doc(DRIVER_ID)
      .set({ active_delivery_id: NEWER_MISSION_ID }, { merge: true });

    await onMissionEndedClearTracking.run(
      buildEvent(
        { status: "arrived_at_dropoff", driver_id: DRIVER_ID },
        { status: "cancelled", driver_id: DRIVER_ID }
      )
    );

    const locationSnap = await db.collection("driver_locations").doc(DRIVER_ID).get();
    expect(locationSnap.data()!.active_delivery_id).toBe(NEWER_MISSION_ID);
  });

  it("[négatif] ne redéclenche pas d'écriture pour une transition DÉJÀ terminale -> terminale (cancelled -> disputed)", async () => {
    await db
      .collection("driver_locations")
      .doc(DRIVER_ID)
      .set({ active_delivery_id: "une_valeur_deja_presente" }, { merge: true });

    await onMissionEndedClearTracking.run(
      buildEvent(
        { status: "cancelled", driver_id: DRIVER_ID },
        { status: "disputed", driver_id: DRIVER_ID }
      )
    );

    const locationSnap = await db.collection("driver_locations").doc(DRIVER_ID).get();
    // Inchangé : la transition n'est pas ENTRANTE vers un statut terminal
    // (elle l'était déjà), donc le trigger ne touche à rien ici — le
    // nettoyage a déjà eu lieu lors du premier passage à 'cancelled'.
    expect(locationSnap.data()!.active_delivery_id).toBe("une_valeur_deja_presente");
  });

  it("[négatif] volontairement PAS déclenché pour 'completed' (déjà géré par completeDelivery())", async () => {
    await db
      .collection("driver_locations")
      .doc(DRIVER_ID)
      .set({ active_delivery_id: MISSION_ID }, { merge: true });

    await onMissionEndedClearTracking.run(
      buildEvent(
        { status: "arrived_at_dropoff", driver_id: DRIVER_ID },
        { status: "completed", driver_id: DRIVER_ID }
      )
    );

    // Le trigger ne gère pas 'completed' -> valeur inchangée ici (dans un
    // vrai flux, c'est completeDelivery() qui l'aurait déjà mise à null).
    const locationSnap = await db.collection("driver_locations").doc(DRIVER_ID).get();
    expect(locationSnap.data()!.active_delivery_id).toBe(MISSION_ID);
  });

  it("[négatif] ne plante pas si driver_locations n'existe pas encore pour ce chauffeur", async () => {
    await expect(
      onMissionEndedClearTracking.run(
        buildEvent(
          { status: "in_transit", driver_id: DRIVER_ID },
          { status: "cancelled", driver_id: DRIVER_ID }
        )
      )
    ).resolves.toBeUndefined();
  });

  it("ne plante pas si event.data est absent (défensif)", async () => {
    const emptyEvent = {
      data: undefined,
      params: { missionId: MISSION_ID },
    } as unknown as FirestoreEvent<Change<QueryDocumentSnapshot> | undefined, { missionId: string }>;
    await expect(onMissionEndedClearTracking.run(emptyEvent)).resolves.toBeUndefined();
  });
});
