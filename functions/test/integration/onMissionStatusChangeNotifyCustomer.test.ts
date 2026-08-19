// ---------------------------------------------------------------------------
// Test d'intégration — onMissionStatusChangeNotifyCustomer (Phase 5, partie 3).
//
// Invocation directe du handler (`.run(event)`) avec un FirestoreEvent
// fabriqué à la main, même approche que onMissionEndedClearTracking.test.ts
// — pas besoin de l'émulateur Firestore trigger runtime, juste de
// vérifier que la fonction écrit le bon document dans
// `users/{customer_id}/notifications/{id}` avec le bon schéma.
//
// Couvre les 8 transitions notifiées (assigned, driver_to_pickup,
// arrived_at_pickup, picked_up, in_transit, arrived_at_dropoff, completed,
// cancelled), l'absence de notification pour une transition non pertinente
// et pour une "non-transition" (before.status === after.status), l'absence
// de notification croisée vers un autre utilisateur, le missionId correct,
// et les clés i18n titleKey/bodyKey correctes.
// ---------------------------------------------------------------------------

import type { Change, FirestoreEvent, QueryDocumentSnapshot } from "firebase-functions/v2/firestore";
import { onMissionStatusChangeNotifyCustomer } from "../../src/functions/onMissionStatusChangeNotifyCustomer";
import { db } from "../../src/lib/admin";
import { MissionStatuses } from "../../src/lib/types";

const MISSION_ID = "notif_trigger_mission_001";
const CUSTOMER_ID = "notif_trigger_customer_a";
const OTHER_CUSTOMER_ID = "notif_trigger_customer_b";

function fakeSnap(data: Record<string, unknown> | undefined): QueryDocumentSnapshot {
  return {
    data: () => data,
  } as unknown as QueryDocumentSnapshot;
}

function buildEvent(
  before: Record<string, unknown> | undefined,
  after: Record<string, unknown> | undefined,
  missionId: string = MISSION_ID
): FirestoreEvent<Change<QueryDocumentSnapshot> | undefined, { missionId: string }> {
  return {
    data: {
      before: fakeSnap(before),
      after: fakeSnap(after),
    } as unknown as Change<QueryDocumentSnapshot>,
    params: { missionId },
  } as unknown as FirestoreEvent<Change<QueryDocumentSnapshot> | undefined, { missionId: string }>;
}

async function notificationsFor(customerId: string) {
  return db.collection("users").doc(customerId).collection("notifications").get();
}

async function cleanup(): Promise<void> {
  const [a, b] = await Promise.all([
    notificationsFor(CUSTOMER_ID),
    notificationsFor(OTHER_CUSTOMER_ID),
  ]);
  await Promise.all([
    ...a.docs.map((d) => d.ref.delete()),
    ...b.docs.map((d) => d.ref.delete()),
  ]);
}

describe("onMissionStatusChangeNotifyCustomer — transitions notifiées", () => {
  afterEach(cleanup);

  it.each([
    [MissionStatuses.ASSIGNED, "driver_assigned", "notif_driver_assigned_title", "notif_driver_assigned_body"],
    [MissionStatuses.DRIVER_TO_PICKUP, "driver_to_pickup", "notif_driver_to_pickup_title", "notif_driver_to_pickup_body"],
    [MissionStatuses.ARRIVED_AT_PICKUP, "arrived_at_pickup", "notif_arrived_at_pickup_title", "notif_arrived_at_pickup_body"],
    [MissionStatuses.PICKED_UP, "picked_up", "notif_picked_up_title", "notif_picked_up_body"],
    [MissionStatuses.IN_TRANSIT, "in_transit", "notif_in_transit_title", "notif_in_transit_body"],
    [MissionStatuses.ARRIVED_AT_DROPOFF, "arrived_at_dropoff", "notif_arrived_at_dropoff_title", "notif_arrived_at_dropoff_body"],
    [MissionStatuses.COMPLETED, "completed", "notif_completed_title", "notif_completed_body"],
    [MissionStatuses.CANCELLED, "cancelled", "notif_cancelled_title", "notif_cancelled_body"],
  ])(
    "transition vers '%s' crée une notification {type: '%s', title_key: '%s', body_key: '%s'} pour le customer",
    async (status, type, titleKey, bodyKey) => {
      await onMissionStatusChangeNotifyCustomer.run(
        buildEvent(
          { status: "searching_driver", customer_id: CUSTOMER_ID },
          { status, customer_id: CUSTOMER_ID }
        )
      );

      const notifs = await notificationsFor(CUSTOMER_ID);
      expect(notifs.size).toBe(1);
      const data = notifs.docs[0].data();
      expect(data.type).toBe(type);
      expect(data.title_key).toBe(titleKey);
      expect(data.body_key).toBe(bodyKey);
      expect(data.related_mission_id).toBe(MISSION_ID);
      expect(data.is_read).toBe(false);
      expect(data.id).toBe(notifs.docs[0].id);
      expect(data.created_at).toBeDefined();
    }
  );

  it("ne crée AUCUNE notification pour un autre utilisateur que le customer_id de la mission (pas de fuite croisée)", async () => {
    await onMissionStatusChangeNotifyCustomer.run(
      buildEvent(
        { status: "searching_driver", customer_id: CUSTOMER_ID },
        { status: MissionStatuses.ASSIGNED, customer_id: CUSTOMER_ID }
      )
    );
    const otherNotifs = await notificationsFor(OTHER_CUSTOMER_ID);
    expect(otherNotifs.size).toBe(0);
  });

  it("ne crée PAS de notification si before.status === after.status (pas une transition de statut)", async () => {
    await onMissionStatusChangeNotifyCustomer.run(
      buildEvent(
        { status: MissionStatuses.IN_TRANSIT, customer_id: CUSTOMER_ID },
        { status: MissionStatuses.IN_TRANSIT, customer_id: CUSTOMER_ID }
      )
    );
    const notifs = await notificationsFor(CUSTOMER_ID);
    expect(notifs.size).toBe(0);
  });

  it("ne crée PAS de notification pour un statut sans spec définie (ex: 'delivered', 'disputed')", async () => {
    await onMissionStatusChangeNotifyCustomer.run(
      buildEvent(
        { status: "searching_driver", customer_id: CUSTOMER_ID },
        { status: "delivered", customer_id: CUSTOMER_ID }
      )
    );
    const notifs = await notificationsFor(CUSTOMER_ID);
    expect(notifs.size).toBe(0);
  });

  it("ne plante pas et ne crée rien si customer_id est absent (garde-fou défensif)", async () => {
    await expect(
      onMissionStatusChangeNotifyCustomer.run(
        buildEvent({ status: "searching_driver" }, { status: MissionStatuses.ASSIGNED })
      )
    ).resolves.toBeUndefined();
  });

  it("ne plante pas si event.data est absent (défensif)", async () => {
    const emptyEvent = {
      data: undefined,
      params: { missionId: MISSION_ID },
    } as unknown as FirestoreEvent<Change<QueryDocumentSnapshot> | undefined, { missionId: string }>;
    await expect(onMissionStatusChangeNotifyCustomer.run(emptyEvent)).resolves.toBeUndefined();
  });

  it("le missionId de la notification correspond exactement au missionId de l'event (multi-missions)", async () => {
    const otherMissionId = "notif_trigger_mission_other";
    await onMissionStatusChangeNotifyCustomer.run(
      buildEvent(
        { status: "searching_driver", customer_id: CUSTOMER_ID },
        { status: MissionStatuses.ASSIGNED, customer_id: CUSTOMER_ID },
        otherMissionId
      )
    );
    const notifs = await notificationsFor(CUSTOMER_ID);
    expect(notifs.size).toBe(1);
    expect(notifs.docs[0].data().related_mission_id).toBe(otherMissionId);
  });
});
