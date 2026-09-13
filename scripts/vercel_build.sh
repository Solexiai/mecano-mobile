#!/usr/bin/env bash
# =============================================================================
# Movi-K — Vercel build script (Phase 8 fix: "flutter: command not found")
# =============================================================================
#
# CONTEXTE
#   L'image de build Vercel ne contient PAS le SDK Flutter. Ce script rend le
#   build Flutter Web reproductible en installant une version PINNÉE du SDK
#   Flutter localement (dans ./.flutter, jamais committé — voir .gitignore),
#   puis en l'utilisant explicitement pour builder l'application web.
#
#   Ce script ne dépend d'AUCUN Flutter global pré-installé par Vercel.
#
# VERSION PINNÉE
#   3.47.1 — c'est la version stable exacte réellement utilisée pour tous les
#   builds/tests locaux réussis de Phase 7 (voir .metadata + `flutter --version`
#   dans l'environnement de développement), et elle satisfait la contrainte SDK
#   Dart du projet (`environment.sdk: ^3.9.2` dans pubspec.yaml — Dart 3.13.1
#   embarqué dans Flutter 3.47.1 est compatible).
#   Le tag git "3.47.1" existe officiellement sur flutter/flutter, donc le
#   clone --branch 3.47.1 est reproductible (pas de "stable" flottant).
#
# USAGE (Vercel Build Command) :
#   bash scripts/vercel_build.sh
#
# =============================================================================

set -euo pipefail

# --- Configuration (version pinnée, PAS de "stable" flottant) --------------
FLUTTER_VERSION="3.47.1"
FLUTTER_REPO_URL="https://github.com/flutter/flutter.git"
FLUTTER_DIR=".flutter"

echo "=============================================================="
echo "Movi-K — Vercel Build — Flutter ${FLUTTER_VERSION} (pinné)"
echo "=============================================================="

# --- 1. Installation du SDK Flutter (pinné, local, non committé) -----------
if [ -x "${FLUTTER_DIR}/bin/flutter" ]; then
  echo "[1/5] SDK Flutter déjà présent dans ${FLUTTER_DIR} (cache) — skip clone."
else
  echo "[1/5] Clonage du SDK Flutter ${FLUTTER_VERSION} dans ${FLUTTER_DIR}..."
  rm -rf "${FLUTTER_DIR}"
  git clone \
    --depth 1 \
    --branch "${FLUTTER_VERSION}" \
    "${FLUTTER_REPO_URL}" \
    "${FLUTTER_DIR}"
fi

FLUTTER_BIN="./${FLUTTER_DIR}/bin/flutter"
DART_BIN="./${FLUTTER_DIR}/bin/dart"

if [ ! -x "${FLUTTER_BIN}" ]; then
  echo "ERREUR: ${FLUTTER_BIN} introuvable après clonage." >&2
  exit 1
fi

# --- 2. Vérification de la version installée --------------------------------
echo "[2/5] Vérification de la version Flutter installée..."
"${FLUTTER_BIN}" --version

# --- 3. Activation du support Web (idempotent) ------------------------------
echo "[3/5] Activation du support web (flutter config --enable-web)..."
"${FLUTTER_BIN}" config --enable-web

# --- 4. Récupération des dépendances Dart/Flutter ---------------------------
echo "[4/5] flutter pub get..."
"${FLUTTER_BIN}" pub get

# --- 5. Build Web release ----------------------------------------------------
#
# GOOGLE_MAPS_API_KEY est injectée par Vercel comme variable d'environnement
# et transmise à Flutter via --dart-define.
#
# FCM_WEB_VAPID_KEY (Phase 8D) est une clé PUBLIQUE Web Push. Elle est aussi
# transmise via --dart-define lorsqu'elle existe. Son absence NE doit jamais
# casser le build : le Web garde alors les notifications in-app Firestore,
# tandis qu'Android peut continuer à utiliser FCM normalement.
#
# SÉCURITÉ — ne jamais logger les valeurs. On expose seulement un booléen
# configuré/non configuré. `set -x` est volontairement absent.
GOOGLE_MAPS_API_KEY="${GOOGLE_MAPS_API_KEY:-}"
FCM_WEB_VAPID_KEY="${FCM_WEB_VAPID_KEY:-}"

if [ -n "${GOOGLE_MAPS_API_KEY}" ]; then
  echo "[5/5] GOOGLE_MAPS_API_KEY: configurée (valeur non affichée)."
else
  echo "[5/5] GOOGLE_MAPS_API_KEY: absente — autocomplete en mode fail-closed."
fi

if [ -n "${FCM_WEB_VAPID_KEY}" ]; then
  echo "[5/5] FCM_WEB_VAPID_KEY: configurée (valeur non affichée)."
else
  echo "[5/5] FCM_WEB_VAPID_KEY: absente — Web Push désactivé, notifications in-app conservées."
fi

echo "[5/5] flutter build web --release (dart-defines sensibles masqués)"
"${FLUTTER_BIN}" build web --release \
  --dart-define=GOOGLE_MAPS_API_KEY="${GOOGLE_MAPS_API_KEY}" \
  --dart-define=FCM_WEB_VAPID_KEY="${FCM_WEB_VAPID_KEY}"

echo "=============================================================="
echo "Build terminé. Sortie attendue : build/web/index.html"
echo "=============================================================="

if [ ! -f "build/web/index.html" ]; then
  echo "ERREUR: build/web/index.html absent après le build." >&2
  exit 1
fi

echo "OK — build/web/index.html présent."
