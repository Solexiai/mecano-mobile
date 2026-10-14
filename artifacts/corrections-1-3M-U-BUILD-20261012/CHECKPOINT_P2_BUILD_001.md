# MOVI-K — CHECKPOINT P2-BUILD-001 — 12 octobre 2026

## Verdict

**FERMÉ — PÉRIMÈTRE BUILD/TEST LOCAL VALIDÉ — NON DÉPLOYÉ.**

Autorisation reçue : obtenir uniquement la dépendance officielle `cupertino_icons` compatible, l'intégrer si nécessaire, et exécuter des contrôles locaux. Autorisation générale antérieure pour un commit local validé ; aucun push, merge ou déploiement.

## Référence Git

Dépôt : Solexiai/mecano-mobile
Worktree : C:\Users\Utilisateur\movik-gps-history-fix-20261009
Branche : fix/gps-client-history-scope-20261009
HEAD de départ : `95821161a15fb691d881e1652662f7befb5f1797`.

Le départ était sans changement suivi et sans fichier stagé. Les preuves non suivies existantes ont été conservées.

## Dépendance autorisée

Version : **cupertino_icons 1.0.9** ; source officielle **https://pub.dev** ; éditeur vérifié **flutter.dev**. Version 2.0.0 non retenue pour éviter un changement inutile de version majeure. Flutter du poste : **3.47.1** ; Dart : **3.13.1**. Le pubspec du package officiel 1.0.9 exige Dart ^3.9.0 et déclare une police CupertinoIcons.ttf, sans autre dépendance de production.

La commande `dart pub cache add cupertino_icons --version 1.0.9` a ajouté exclusivement ce package au cache officiel. `flutter pub get --offline` a ensuite réussi ; delta de `pubspec.lock` : **une seule entrée de dépendance directe**, source `https://pub.dev`, version 1.0.9, SHA-256 d'archive `41e005c33bd814be4d3096aff55b1908d419fde52ca656c8c47719ec745873cd`.

Aucune mise à jour d'autres dépendances. `pubspec.yaml` déclare la version exacte 1.0.9.

## Build Web

Référence d'origine (lot U) : build Web réussi mais avertissement `Expected to find fonts for (MaterialIcons, packages/cupertino_icons/CupertinoIcons), but found (MaterialIcons)`, et FontManifest limité à MaterialIcons.

Après ajout, nouveau build réellement exécuté avec `flutter --no-version-check build web --no-pub --output=artifacts/corrections-1-3M-U-BUILD-20261012/web-build-verified` : **code de sortie 0**, compilation Web réussie et dry-run Wasm réussi. `FLUTTER_STORAGE_BASE_URL` pointait vers une adresse loopback indisponible afin de bloquer la récupération d'autres artefacts, en plus de `--no-pub` ; son avertissement générique était distinct de l'ancien avertissement de police. Aucun nouveau téléchargement demandé pendant cette compilation.

Le nouvel avertissement de build indique simplement que la police est **tree-shaken**, de 257628 à 1472 octets : ce n'est pas une absence de police. L'ancien avertissement `Expected to find fonts` n'apparaît plus dans la sortie finale.

L'asset `assets/FontManifest.json` contient `packages/cupertino_icons/CupertinoIcons` et `packages/cupertino_icons/assets/CupertinoIcons.ttf`. Le fichier TTF compilé est présent (1472 octets), avec SHA-256 `3D90C370AA4CF00DC57EE2B902F6652147C0F81E03E483DF584A9C08B1687C9D`. Le fichier de police original en cache (257628 octets) porte SHA-256 `67C44FE9183B002E79DDE7F6977E2988661C9A3E4A3C5FCE968787EFDBED823C`.

## Tests et qualité

- Nouveau test permanent `test/build/cupertino_icons_asset_test.dart` : **2 réussis / 0 échec**, prouvant l'entrée FontManifest et la disponibilité du TTF dans le bundle Flutter de test, puis l'identité de police/package de `CupertinoIcons.heart_fill` dans un véritable widget Cupertino.
- Non-régression de l'accueil/menu `test/home/public_menu_locale_test.dart` : **13 réussis / 0 échec** avec transport local existant, FR/EN/ES et formats responsive.
- Bilan de la validation finale ciblée : **15 tests réussis / 0 échec**.
- `flutter analyze --no-pub` ciblé sur le nouveau test et `lib/widgets/app_shell.dart` : **No issues found**, code 0.
- Dart format appliqué au nouveau test.
- `git diff --check` : code 0.

Les résultats proviennent des processus exécutés sur le PC et des artefacts conservés. Les scripts de premier build sous PowerShell ont initialement signalé une erreur de traitement de stderr lors de l'avertissement de l'adresse loopback ; leur sortie ne sert pas de validation de code de sortie. La nouvelle compilation sous cmd.exe s'est terminée correctement (code 0).

## Limites, sécurité et registre

Les essais vérifient le bundling de la police et le widget Flutter, **pas un rendu Chrome/Safari/iOS/Android réel**, et ne certifient pas chaque glyphe Cupertino en production. Aucun usage précis précédemment défectueux dans Movi-K n'avait été démontré ; la fiche portait sur l'avertissement de build et la police manquante. Aucun code de logique métier ni fichier Firebase, Stripe, tarif, commission, snapshot ou ledger modifié.

Dossier de preuves local : `artifacts/corrections-1-3M-U-BUILD-20261012/`. Les builds compilés et le cache Pub restent locaux, non destinés au commit.

Registre : **P0 0 / P1 0 / P2 5 ouverts**, 27 fiches conservées (22 fermées dans leur périmètre validé). Les cinq autres P2 sont P2-L-01, GAP-M-05, GAP-M-06, GAP-S-02, GAP-S-04. Les P3 et prérequis du pilote restent présents. Test de tuiles 1.3L toujours BLOQUÉ ET REPORTÉ.

**Aucun push GitHub, merge, déploiement ni validation production.**
