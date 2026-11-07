// -----------------------------------------------------------------------------
// appVersionPolicy.ts — version minimale de l'application Android
// (2026-11-06, demande de Daniel : « que tout le monde se mette à jour »).
//
// Android n'autorise aucune app à se réinstaller toute seule : le maximum
// permis est la « mise à jour dans l'app » de Google Play (In-App Updates),
// que l'app déclenche au démarrage. Ce document dit à l'app QUELLE forme
// prendre :
//   - build installé < `android_min_build`  -> mise à jour IMMÉDIATE
//     (écran Google plein écran, impossible de continuer sans mettre à jour) ;
//   - sinon, s'il existe une version plus récente sur Play -> mise à jour
//     SOUPLE (téléchargement en arrière-plan, bandeau « Redémarrer »).
//
// DOCUMENT : `app_config/app_versions` (singleton). Lisible par TOUT LE
// MONDE (firestore.rules) — il ne contient qu'un numéro de build, et l'app
// doit pouvoir le lire avant toute connexion. Écriture STRICTEMENT par la
// Cloud Function `updateAppVersionPolicy` (admin/super_admin, audit).
//
// FAIL-SAFE : document absent, champ absent ou type invalide => aucun
// minimum (0) : l'app ne bloque jamais personne par accident ; la mise à
// jour souple reste proposée par Play. Un minimum trop élevé (plus haut que
// la version publiée) bloquerait tout le monde : la fonction refuse donc une
// valeur supérieure à `MAX_BUILD_NUMBER`, et l'admin voit un avertissement
// explicite dans le Centre de commande.
// -----------------------------------------------------------------------------

import { admin } from "./admin";

export const APP_CONFIG_COLLECTION = "app_config";
export const APP_VERSIONS_DOC_ID = "app_versions";

/** Borne de sécurité (Google Play : versionCode < 2 100 000 000). */
export const MAX_BUILD_NUMBER = 100_000;

export interface AppVersionPolicyDoc {
  /** Numéro de build Android (versionCode) minimal accepté ; 0 = aucun. */
  android_min_build: number;
  /** Note libre de l'admin (ex. « dépôt 25 $ requis »), affichée dans l'admin. */
  note: string;
  updated_at: admin.firestore.Timestamp;
  updated_by_user_id: string;
}

export const APP_VERSION_POLICY_DEFAULTS = {
  android_min_build: 0,
  note: "",
} as const;

/**
 * Valide un numéro de build fourni par l'admin. Retourne l'entier ou un
 * message d'erreur (jamais une exception : l'appelant choisit le code).
 */
export function parseMinBuild(value: unknown): { ok: true; value: number } | { ok: false; reason: string } {
  if (typeof value !== "number" || !Number.isInteger(value)) {
    return { ok: false, reason: "android_min_build doit être un entier (numéro de build Android)." };
  }
  if (value < 0) return { ok: false, reason: "android_min_build ne peut pas être négatif (0 = aucun minimum)." };
  if (value > MAX_BUILD_NUMBER) {
    return {
      ok: false,
      reason: `android_min_build ne peut pas dépasser ${MAX_BUILD_NUMBER} (un minimum plus haut que la version publiée bloquerait tout le monde).`,
    };
  }
  return { ok: true, value };
}

/** Lecture tolérante d'un document (absent/corrompu => défauts). */
export function readAppVersionPolicy(data: FirebaseFirestore.DocumentData | undefined): {
  android_min_build: number;
  note: string;
} {
  const min = data?.android_min_build;
  const note = data?.note;
  return {
    android_min_build: typeof min === "number" && Number.isInteger(min) && min >= 0 ? min : APP_VERSION_POLICY_DEFAULTS.android_min_build,
    note: typeof note === "string" ? note : APP_VERSION_POLICY_DEFAULTS.note,
  };
}
