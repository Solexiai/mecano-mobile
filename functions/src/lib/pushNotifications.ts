// -----------------------------------------------------------------------------
// Push notifications — Movi-K (Phase 8D).
//
// Les notifications push sont un canal secondaire : la source de vérité reste
// Firestore (`users/{uid}/notifications` + `delivery_offers`). Une panne FCM
// ne doit JAMAIS faire échouer le dispatch d'une mission.
//
// Les tokens sont stockés dans la collection serveur-only `push_tokens` par
// `registerPushToken`. Aucun token n'est loggé et aucun client ne peut lire
// cette collection (deny-by-default dans firestore.rules).
// -----------------------------------------------------------------------------

import type { DocumentReference } from "firebase-admin/firestore";
import { admin, db } from "./admin";
import {
  logFinancialFailure,
  logFinancialSuccess,
  startFinancialOperationTimer,
} from "./observability";

export type SupportedPushLocale = "fr" | "en" | "es";

interface PushTokenDoc {
  token: string;
  user_id: string;
  locale?: string;
  platform?: string;
}

export interface DeliveryOfferPushCopy {
  title: string;
  body: string;
}

export type CustomerMissionPushType =
  | "driver_assigned"
  | "driver_to_pickup"
  | "arrived_at_pickup"
  | "picked_up"
  | "in_transit"
  | "arrived_at_dropoff"
  | "completed"
  | "cancelled";

const CUSTOMER_MISSION_PUSH_COPY: Record<
  CustomerMissionPushType,
  Record<SupportedPushLocale, DeliveryOfferPushCopy>
> = {
  driver_assigned: {
    fr: {
      title: "Chauffeur assign\u00e9",
      body: "Un chauffeur a \u00e9t\u00e9 assign\u00e9 \u00e0 votre livraison.",
    },
    en: {
      title: "Driver assigned",
      body: "A driver has been assigned to your delivery.",
    },
    es: {
      title: "Conductor asignado",
      body: "Se ha asignado un conductor a su entrega.",
    },
  },
  driver_to_pickup: {
    fr: {
      title: "En route vers le ramassage",
      body: "Votre chauffeur est en route vers le ramassage.",
    },
    en: {
      title: "On the way to pickup",
      body: "Your driver is on the way to the pickup.",
    },
    es: {
      title: "En camino a la recogida",
      body: "Su conductor est\u00e1 en camino a la recogida.",
    },
  },
  arrived_at_pickup: {
    fr: {
      title: "Arriv\u00e9 au ramassage",
      body: "Votre chauffeur est arriv\u00e9 au point de ramassage.",
    },
    en: {
      title: "Arrived at pickup",
      body: "Your driver has arrived at the pickup point.",
    },
    es: {
      title: "Lleg\u00f3 a la recogida",
      body: "Su conductor ha llegado al punto de recogida.",
    },
  },
  picked_up: {
    fr: {
      title: "Objet r\u00e9cup\u00e9r\u00e9",
      body: "Votre objet a \u00e9t\u00e9 r\u00e9cup\u00e9r\u00e9. La livraison est en cours.",
    },
    en: {
      title: "Item picked up",
      body: "Your item has been picked up. Delivery is in progress.",
    },
    es: {
      title: "Art\u00edculo recogido",
      body: "Su art\u00edculo ha sido recogido. La entrega est\u00e1 en curso.",
    },
  },
  in_transit: {
    fr: {
      title: "Livraison en cours",
      body: "Votre livraison est en route vers sa destination.",
    },
    en: {
      title: "Delivery in progress",
      body: "Your delivery is on its way to its destination.",
    },
    es: {
      title: "Entrega en curso",
      body: "Su entrega est\u00e1 en camino a su destino.",
    },
  },
  arrived_at_dropoff: {
    fr: {
      title: "Arriv\u00e9 \u00e0 destination",
      body: "Votre chauffeur est arriv\u00e9 \u00e0 destination.",
    },
    en: {
      title: "Arrived at destination",
      body: "Your driver has arrived at the destination.",
    },
    es: {
      title: "Lleg\u00f3 al destino",
      body: "Su conductor ha llegado al destino.",
    },
  },
  completed: {
    fr: {
      title: "Livraison compl\u00e9t\u00e9e",
      body: "Votre livraison est compl\u00e9t\u00e9e.",
    },
    en: {
      title: "Delivery completed",
      body: "Your delivery is completed.",
    },
    es: {
      title: "Entrega completada",
      body: "Su entrega est\u00e1 completada.",
    },
  },
  cancelled: {
    fr: {
      title: "Mission annul\u00e9e",
      body: "Votre demande de livraison a \u00e9t\u00e9 annul\u00e9e.",
    },
    en: {
      title: "Mission cancelled",
      body: "Your delivery request has been cancelled.",
    },
    es: {
      title: "Misi\u00f3n cancelada",
      body: "Su solicitud de entrega ha sido cancelada.",
    },
  },
};

const DELIVERY_OFFER_COPY: Record<SupportedPushLocale, DeliveryOfferPushCopy> = {
  fr: {
    title: "Nouvelle livraison disponible",
    body: "Une demande est disponible près de vous. Ouvrez Movi-k pour voir les détails.",
  },
  en: {
    title: "New delivery available",
    body: "A delivery request is available near you. Open Movi-k to view the details.",
  },
  es: {
    title: "Nueva entrega disponible",
    body: "Hay una solicitud de entrega cerca de ti. Abre Movi-k para ver los detalles.",
  },
};

export function normalizePushLocale(locale: unknown): SupportedPushLocale {
  return locale === "en" || locale === "es" ? locale : "fr";
}

export function deliveryOfferPushCopy(locale: unknown): DeliveryOfferPushCopy {
  return DELIVERY_OFFER_COPY[normalizePushLocale(locale)];
}

export function customerMissionPushCopy(
  notificationType: CustomerMissionPushType,
  locale: unknown
): DeliveryOfferPushCopy {
  return CUSTOMER_MISSION_PUSH_COPY[notificationType][normalizePushLocale(locale)];
}

function isPermanentTokenError(code: string | undefined): boolean {
  return code === "messaging/registration-token-not-registered" ||
    code === "messaging/invalid-registration-token";
}

/**
 * Envoie la notification push d'une offre de livraison à tous les appareils
 * enregistrés du chauffeur. Fail-soft : cette fonction journalise les erreurs
 * puis retourne, sans jamais casser le dispatch métier.
 */
export async function sendDeliveryOfferPush(params: {
  driverId: string;
  missionId: string;
  expiresAtMillis: number;
}): Promise<{ attempted: number; sent: number }> {
  const { driverId, missionId, expiresAtMillis } = params;
  const operationStartedAt = startFinancialOperationTimer();

  try {
    const tokenSnap = await db
      .collection("push_tokens")
      .where("user_id", "==", driverId)
      .get();

    if (tokenSnap.empty) {
      // Cas normal : le chauffeur peut être connecté sur Web sans Web Push,
      // ou n'avoir pas encore autorisé les notifications sur son téléphone.
      return { attempted: 0, sent: 0 };
    }

    const remainingMs = Math.max(0, expiresAtMillis - Date.now());
    if (remainingMs <= 0) {
      return { attempted: 0, sent: 0 };
    }

    const byLocale = new Map<SupportedPushLocale, Array<{
      token: string;
      ref: DocumentReference;
    }>>();

    for (const doc of tokenSnap.docs) {
      const data = doc.data() as PushTokenDoc;
      if (typeof data.token !== "string" || data.token.length < 20) continue;
      const locale = normalizePushLocale(data.locale);
      const group = byLocale.get(locale) ?? [];
      group.push({ token: data.token, ref: doc.ref });
      byLocale.set(locale, group);
    }

    let attempted = 0;
    let sent = 0;
    const staleRefs: DocumentReference[] = [];

    for (const [locale, devices] of byLocale.entries()) {
      const copy = deliveryOfferPushCopy(locale);

      // FCM limite sendEachForMulticast à 500 tokens par appel.
      for (let offset = 0; offset < devices.length; offset += 500) {
        const chunk = devices.slice(offset, offset + 500);
        const ttlSeconds = Math.max(1, Math.ceil(remainingMs / 1000));
        const response = await admin.messaging().sendEachForMulticast({
          tokens: chunk.map((d) => d.token),
          notification: {
            title: copy.title,
            body: copy.body,
          },
          data: {
            type: "delivery_offer",
            missionId,
            target: "driver_jobs",
          },
          android: {
            priority: "high",
            ttl: remainingMs,
            notification: {
              sound: "default",
              tag: `delivery-offer-${missionId}`,
            },
          },
          apns: {
            headers: {
              "apns-priority": "10",
              "apns-expiration": String(Math.floor(expiresAtMillis / 1000)),
            },
            payload: {
              aps: {
                sound: "default",
                category: "DELIVERY_OFFER",
              },
            },
          },
          webpush: {
            headers: {
              Urgency: "high",
              TTL: String(ttlSeconds),
            },
            notification: {
              tag: `delivery-offer-${missionId}`,
            },
          },
        });

        attempted += chunk.length;
        sent += response.successCount;

        response.responses.forEach((item, index) => {
          if (!item.success && isPermanentTokenError(item.error?.code)) {
            staleRefs.push(chunk[index].ref);
          }
        });
      }
    }

    if (staleRefs.length > 0) {
      const cleanupBatch = db.batch();
      for (const ref of staleRefs) cleanupBatch.delete(ref);
      await cleanupBatch.commit();
    }

    logFinancialSuccess(
      "driver_delivery_offer_push",
      operationStartedAt,
      { missionId },
      { metadata: { attempted, sent, staleTokensRemoved: staleRefs.length } }
    );

    return { attempted, sent };
  } catch (err) {
    logFinancialFailure(
      "driver_delivery_offer_push",
      operationStartedAt,
      "push_send_failed",
      { missionId },
      {
        metadata: {
          errorMessage: err instanceof Error ? err.message : String(err),
        },
      }
    );
    return { attempted: 0, sent: 0 };
  }
}


export async function sendCustomerMissionStatusPush(params: {
  customerId: string;
  missionId: string;
  notificationType: CustomerMissionPushType;
}): Promise<{ attempted: number; sent: number }> {
  const { customerId, missionId, notificationType } = params;
  const operationStartedAt = startFinancialOperationTimer();

  try {
    const tokenSnap = await db
      .collection("push_tokens")
      .where("user_id", "==", customerId)
      .get();

    if (tokenSnap.empty) {
      return { attempted: 0, sent: 0 };
    }

    const byLocale = new Map<
      SupportedPushLocale,
      Array<{ token: string; ref: DocumentReference }>
    >();

    for (const doc of tokenSnap.docs) {
      const tokenData = doc.data() as PushTokenDoc;
      if (typeof tokenData.token !== "string" || tokenData.token.length < 20) {
        continue;
      }

      const locale = normalizePushLocale(tokenData.locale);
      const group = byLocale.get(locale) ?? [];
      group.push({ token: tokenData.token, ref: doc.ref });
      byLocale.set(locale, group);
    }

    let attempted = 0;
    let sent = 0;
    const staleRefs: DocumentReference[] = [];
    const ttlMs = 24 * 60 * 60 * 1000;
    const ttlSeconds = 24 * 60 * 60;
    const expiresAtSeconds = Math.floor((Date.now() + ttlMs) / 1000);

    for (const [locale, devices] of byLocale.entries()) {
      const copy = customerMissionPushCopy(notificationType, locale);

      for (let offset = 0; offset < devices.length; offset += 500) {
        const chunk = devices.slice(offset, offset + 500);

        const response = await admin.messaging().sendEachForMulticast({
          tokens: chunk.map((device) => device.token),
          notification: {
            title: copy.title,
            body: copy.body,
          },
          data: {
            type: "mission_status",
            notificationType,
            missionId,
            target: "customer_tracking",
          },
          android: {
            priority: "high",
            ttl: ttlMs,
            notification: {
              sound: "default",
              tag: `mission-status-${missionId}`,
            },
          },
          apns: {
            headers: {
              "apns-priority": "10",
              "apns-expiration": String(expiresAtSeconds),
              "apns-collapse-id": `mission-status-${missionId}`,
            },
            payload: {
              aps: {
                sound: "default",
                category: "MISSION_STATUS",
              },
            },
          },
          webpush: {
            headers: {
              Urgency: "high",
              TTL: String(ttlSeconds),
            },
            notification: {
              tag: `mission-status-${missionId}`,
            },
          },
        });

        attempted += chunk.length;
        sent += response.successCount;

        response.responses.forEach((item, index) => {
          if (!item.success && isPermanentTokenError(item.error?.code)) {
            staleRefs.push(chunk[index].ref);
          }
        });
      }
    }

    if (staleRefs.length > 0) {
      const cleanupBatch = db.batch();
      for (const ref of staleRefs) {
        cleanupBatch.delete(ref);
      }
      await cleanupBatch.commit();
    }

    logFinancialSuccess(
      "customer_mission_status_push",
      operationStartedAt,
      { missionId },
      {
        metadata: {
          notificationType,
          attempted,
          sent,
          staleTokensRemoved: staleRefs.length,
        },
      }
    );

    return { attempted, sent };
  } catch (err) {
    logFinancialFailure(
      "customer_mission_status_push",
      operationStartedAt,
      "push_send_failed",
      { missionId },
      {
        metadata: {
          notificationType,
          errorMessage: err instanceof Error ? err.message : String(err),
        },
      }
    );

    return { attempted: 0, sent: 0 };
  }
}
