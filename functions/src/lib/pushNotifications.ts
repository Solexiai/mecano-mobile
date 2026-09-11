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
