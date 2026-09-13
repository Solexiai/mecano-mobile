// -----------------------------------------------------------------------------
// registerPushToken / unregisterPushToken — Phase 8D (FCM/APNs).
//
// Le client n'écrit JAMAIS directement ses tokens dans Firestore. Ces deux
// callables exigent une session Firebase Auth valide et écrivent via Admin SDK
// dans la collection serveur-only `push_tokens`.
//
// Le document est indexé par SHA-256 du token :
// - aucun token brut dans un ID/URL Firestore;
// - un même appareil/token ne peut appartenir qu'au dernier utilisateur
//   authentifié qui l'a enregistré;
// - la réinscription est idempotente.
// -----------------------------------------------------------------------------

import { createHash } from "crypto";
import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { requireSignedIn } from "../lib/auth";
import { invalidArgument } from "../lib/errors";
import { normalizePushLocale } from "../lib/pushNotifications";

interface RegisterPushTokenRequest {
  token: string;
  platform?: string;
  locale?: string;
}

interface UnregisterPushTokenRequest {
  token: string;
}

const ALLOWED_PLATFORMS = new Set(["android", "ios", "web", "macos", "unknown"]);

function normalizeToken(raw: unknown): string {
  if (typeof raw !== "string") {
    throw invalidArgument("token est requis.");
  }
  const token = raw.trim();
  if (token.length < 20 || token.length > 4096) {
    throw invalidArgument("token invalide.");
  }
  return token;
}

function tokenDocumentId(token: string): string {
  return createHash("sha256").update(token, "utf8").digest("hex");
}

export const registerPushToken = onCall<RegisterPushTokenRequest>(async (request) => {
  const ctx = requireSignedIn(request);
  const token = normalizeToken(request.data?.token);
  const platformRaw = request.data?.platform;
  const platform = typeof platformRaw === "string" && ALLOWED_PLATFORMS.has(platformRaw)
    ? platformRaw
    : "unknown";
  const locale = normalizePushLocale(request.data?.locale);
  const now = admin.firestore.Timestamp.now();
  const ref = db.collection("push_tokens").doc(tokenDocumentId(token));
  const existing = await ref.get();

  await ref.set({
    token,
    user_id: ctx.uid,
    platform,
    locale,
    created_at: existing.exists
      ? existing.data()?.created_at ?? now
      : now,
    updated_at: now,
  });

  return { success: true };
});

export const unregisterPushToken = onCall<UnregisterPushTokenRequest>(async (request) => {
  const ctx = requireSignedIn(request);
  const token = normalizeToken(request.data?.token);
  const ref = db.collection("push_tokens").doc(tokenDocumentId(token));
  const snap = await ref.get();

  // Idempotent et ownership-safe : un utilisateur ne peut jamais supprimer
  // le token actuellement rattaché à un autre compte.
  if (snap.exists && snap.data()?.user_id === ctx.uid) {
    await ref.delete();
  }

  return { success: true };
});
