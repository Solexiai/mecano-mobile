// -----------------------------------------------------------------------------
// appConfig.ts — Paramètres de configuration NON SECRETS (Bloc 8B LIVE,
// fermeture du gap "Connect return/refresh URL").
//
// CONTEXTE DU GAP (voir docs/PAYMENT_ARCHITECTURE.md §10.3/§10.7) :
// `stripeProvider.ts::createDriverAccount()` devait rediriger le navigateur
// du chauffeur, après l'onboarding hébergé Stripe, vers une URL PUBLIQUE de
// l'app Movi-K. Cette URL était codée en dur sur `https://movik.ca/...` —
// un domaine qui, à l'audit (vérification réseau réelle, pas une supposition),
// résout en DNS mais échoue le handshake TLS (`movik.ca` ne sert PAS l'app
// Movi-K actuellement). Le domaine RÉELLEMENT en ligne, vérifié par
// `curl -sI` (HTTP 200, `<title>movik_connect</title>`), est
// `https://mecano-mobile-delta.vercel.app`.
//
// SOLUTION : `defineString` (PAS `defineSecret` — c'est une URL publique,
// pas un secret) avec une valeur par défaut égale au domaine RÉELLEMENT
// vérifié en ligne aujourd'hui. Si Daniel connecte plus tard un domaine
// public final différent (ex. movik.ca une fois correctement configuré),
// il suffit de définir le paramètre `APP_PUBLIC_BASE_URL` (Firebase Console
// > Functions > Configuration, ou `firebase functions:config`/`.env`) SANS
// toucher au code — voir instructions non techniques dans le RAPPORT LIVE.
//
// AUCUNE valeur ici n'est un secret : cette URL est destinée à apparaître
// dans la barre d'adresse du navigateur du chauffeur, elle ne doit jamais
// être déclarée via `defineSecret`/Secret Manager.
// -----------------------------------------------------------------------------

import { defineString } from "firebase-functions/params";

/**
 * Domaine public de base de l'app Movi-K (web), SANS slash final.
 * Valeur par défaut = domaine Vercel réellement vérifié en ligne au moment
 * de l'audit Bloc 8B LIVE (2026-09-02). À surcharger via la configuration
 * Firebase si/quand un domaine public final différent est branché.
 */
export const APP_PUBLIC_BASE_URL = defineString("APP_PUBLIC_BASE_URL", {
  default: "https://mecano-mobile-delta.vercel.app",
});

/**
 * Retourne l'URL de retour "onboarding Stripe Connect complété" — route
 * Flutter FR par défaut (le driver n'a pas de préférence de langue connue
 * côté Stripe ; la route FR redirige elle-même selon `LocaleProvider`
 * persisté localement si le chauffeur en a déjà une, voir
 * `driver_stripe_onboarding_return_screen.dart`).
 */
export function getDriverStripeReturnUrl(): string {
  return `${APP_PUBLIC_BASE_URL.value()}/fr/chauffeur/onboarding/complete`;
}

/**
 * Retourne l'URL de "refresh/retry" (lien d'onboarding Stripe expiré ou
 * abandonné avant complétion — Stripe redirige ici, pas vers `return_url`).
 */
export function getDriverStripeRefreshUrl(): string {
  return `${APP_PUBLIC_BASE_URL.value()}/fr/chauffeur/onboarding/refresh`;
}
