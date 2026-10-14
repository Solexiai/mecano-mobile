# CHECKPOINT MOVI-K — LOT 1.3M-U

Date : 12 octobre 2026. **Lot traité ; deux anomalies fermées dans le périmètre local/simulé, une anomalie bloquée et ouverte. Aucun déploiement.**

## 1. Reprise et état Git

- Dépôt : Solexiai/mecano-mobile.
- Worktree exclusif : C:\Users\Utilisateur\movik-gps-history-fix-20261009.
- Branche : fix/gps-client-history-scope-20261009.
- HEAD initial confirmé : 7700931ee7a91b8b9a29c2f91ca3ccdf857e6c29, commit P2-COPY-001 présent.
- Index initial vide et fichiers suivis propres. Les fichiers non suivis historiques ont été préservés.
- HEAD après les deux corrections : cbbaf266df2fccad1da71c7f58bafbae87aea091 ; index et fichiers suivis propres avant la dernière mise à jour documentaire.
- La sauvegarde documentaire du présent bilan est distincte des deux correctifs. Son HEAD exact, l'index et l'état final sont consignés dans FINAL_GIT_RESULT.json après le commit.
- Aucun changement de branche, des autres worktrees, de main/release, ni push/merge/déploiement.

## 2. Diagnostic et résultat par anomalie

| Anomalie | Preuve et correction | Statut |
|---|---|---|
| P2-I18N-001 | hero_clean.png avait du texte français incorporé ; sélection identique en FR/EN/ES. Reproduction : 4 réussis / 9 échoués. Original conservé en FR ; nouvelle hero_neutral.png sans slogan français en EN/ES et description accessible traduite. Sélection réactive au changement de langue. | FERMÉ — PÉRIMÈTRE LOCAL/SIMULÉ VALIDÉ — NON DÉPLOYÉ |
| P2-I18N-002 | AppBar utilisait le DrawerButton implicite et son tooltip Material anglais par défaut. Reproduction correcte avant modification : 6 réussis / 7 échoués. Bouton explicite avec tooltip HomeCopy traduit ; même icône, même ouverture du Drawer et mêmes routes. | FERMÉ — PÉRIMÈTRE LOCAL/SIMULÉ VALIDÉ — NON DÉPLOYÉ |
| P2-BUILD-001 | Nouveau build Web réussi mais avertissement CupertinoIcons reproduit. Package absent de pubspec/lock/package_config et des caches Pub locaux examinés ; FontManifest final contient uniquement MaterialIcons. Aucun usage direct dans le code Movi-K trouvé. Icône réellement manquante à l'écran non démontrée. | QUALIFIÉ — BLOQUÉ : ressource locale indisponible ; NON FERMÉ |

Le SDK utilise lui-même CupertinoIcons dans certains composants Cupertino ; cela ne démontre pas qu'un écran Movi-K précis affiche une icône manquante. Aucun contournement par suppression de l'avertissement, remplacement arbitraire de police ou désactivation du tree-shaking. Aucun changement de dépendance.

## 3. Ressource graphique et rendu

Image originale examinée et conservée à l'identique : assets/home/hero_clean.png, 524×350, 417088 octets, SHA256 45b11258e45ea649dfa51c070052893427520f0f0212c8462a4b63b64e638365.

Aucune variante neutre/localisée équivalente trouvée parmi les ressources pertinentes. Retouche générative contrôlée : suppression du slogan, de sa flèche et de la petite inscription française sur le véhicule ; scène, couleurs, van, chauffeur et marque conservés visuellement. Nouvelle assets/home/hero_neutral.png : 1535×1025, 1791300 octets, SHA256 c687035e45b047a6b9516bf40f672ec05cdd0f9b6a51d9be171bcb11b00726e5. Proportions affichées identiques et original FR préservé. La retouche n'est pas une identité pixel par pixel ; poids supérieur, impact sur le chargement non mesuré. Le logo officiel indépendant de l'en-tête est inchangé.

21 PNG réels examinés : 12 dans hero-verified/ et 9 dans menu-final/. Inventaire exact, résolutions et SHA256 dans INTEGRITY_QUALITY.json. FR/EN/ES : 375×812, 430×932, 1440×900, et 375×812 à 200 %. Les scénarios desktop du menu vérifient ses liens et l'absence normale de tiroir ; aucun tooltip desktop inventé.

Captures de widgets Flutter, jamais présentées comme Chrome. Vues mobiles de l'illustration défilées jusqu'au visuel. Images effectivement décodées, MediaQuery et surface de test concordants. Infobulles complètes et lisibles, retour à la ligne correct à 200 %, aucun chevauchement permanent constaté dans les régions examinées. Certains autres boutons restent en police Ahem dans flutter_tester : leur typographie plateforme n'est pas validée par ces PNG. Les captures initiales non adéquates (hero-final/, menu-verified/) restent conservées mais exclues des preuves de rendu retenues.

## 4. Tests réellement exécutés

Commande commune : flutter --no-version-check test --no-pub --dart-define=no_default_http_client=true --concurrency=1 --reporter=json, suivie des fichiers ciblés.

| Exécution | Réussis | Échoués | Ignorés | Interprétation |
|---|---:|---:|---:|---|
| hero-reproduction | 4 | 9 | 0 | Défaut EN/ES avant correction produit |
| hero-permanent | 13 | 0 | 0 | Test permanent final de la ressource et des langues |
| hero-regression | 73 | 0 | 0 | Accueil, disposition, Marketplace et contrat de texte public |
| menu-reproduction-final | 6 | 7 | 0 | Défaut tooltip FR/ES avant correction produit |
| menu-final | 13 | 0 | 0 | Tooltip, sémantique, menu, navigation et changement de langue |
| menu-regression | 68 | 0 | 0 | Accueil, illustration et pages publiques |

**123 scénarios distincts réussis en validation finale ; 0 échec final ; 0 ignoré.** Les 167 passages des quatre exécutions finales comprennent des répétitions et ne sont pas 167 tests distincts.

Suites finales : home_hero_locale_test (13), public_menu_locale_test (13), home_screen_test (31), home_launch_layout_test (18), home_marketplace_copy_test (12), public_launch_copy_contract_test (12), public_launch_pages_test (24).

Les erreurs intermédiaires sont conservées séparément dans CHECKPOINT_I18N_001.md et CHECKPOINT_I18N_002.md : première préparation du test Semantics, patch partiellement appliqué à cause de l'ancre CRLF, mauvais nom de package/import relatif, et recherche d'un élément non encore matérialisé dans une liste à 200 %. Aucun de ces échecs n'a été transformé rétroactivement en réussite. Les assertions pertinentes ont été conservées ; les tests ont été corrigés avant la validation finale.

Navigation testée dans le périmètre des routes et données fictives : ouverture/fermeture du tiroir, Contact et retour, FAQ desktop, changement FR/EN/ES, accès public/invité. Pas de nouvelle validation de GPS, paiement ou calcul financier.

## 5. Qualité et compilation

- Flutter analyze ciblé illustration : 4 fichiers, aucune issue, code 0.
- Flutter analyze ciblé menu final : 5 fichiers, aucune issue, code 0, preuve menu-quality.txt/.exit. Le premier menu-analyze avait signalé hasFlag déprécié ; trace conservée, assertion migrée vers flagsCollection.
- Dart format : 4 puis 5 fichiers contrôlés, 0 changement, code 0.
- git diff --check : réussi avant chaque commit ; dernier contrôle documentaire conservé dans FINAL_VERIFICATION.json.
- Flutter 3.47.1 / Dart 3.13.1 confirmés depuis le SDK installé.

Build exécuté sans résolution Pub, dans un dossier neuf :
```powershell
flutter --no-version-check build web --no-pub --output=artifacts/corrections-1-3M-U-20261012-a61b905e/web-build
```
Environnement du processus : FLUTTER_SUPPRESS_ANALYTICS=true, DART_SUPPRESS_ANALYTICS=true, CI=true ; FLUTTER_STORAGE_BASE_URL et PUB_HOSTED_URL pointés vers http://127.0.0.1:1/disabled. Prévol du cache SDK, compilateurs et font-subset effectué, aucune installation/résolution de dépendances. Ces variables ne constituent pas un pare-feu OS.

Résultat : **code 0, Web compilé, dry-run Wasm réussi** ; aucun serveur ou navigateur applicatif lancé. Le message avertissant de la source Flutter loopback configurée n'est pas une preuve de téléchargement. Avertissement exact toujours présent :
```text
Expected to find fonts for (MaterialIcons, packages/cupertino_icons/CupertinoIcons), but found (MaterialIcons).
```
La phrase complète et le journal sont conservés dans web-build.txt ; manifeste et empreintes des sorties dans BUILD_QUALIFICATION.json. Pas de validation d'exécution Wasm, Chrome, Safari/iOS ou d'icône Cupertino à l'écran. Build et dépendances ne sont donc pas déclarés sans avertissement.

## 6. Isolation, intégrité et preuves

Mocks Auth/SharedPreferences, aucun Firebase initialisé, transport mémoire et refus des clients HTTP réels dans le harnais ; aucune carte lancée, zéro tuile/événement réseau inattendu dans les tests ciblés. Aucun backend, API métier réelle, paiement, GPS ou notification. Ce périmètre simulé n'est pas une preuve de confinement réseau de l'OS. **1.3L reste BLOQUÉ ET REPORTÉ.**

Sur les 3072 fichiers préexistants inventoriés : 3067 empreintes inchangées ; seuls 5 fichiers préexistants autorisés ont changé. Aucun fichier préexistant disparu ou modifié hors périmètre. Les nouveaux fichiers sont identifiés par les manifests des commits.

Diff vide sur functions/, firestore.rules, lib/backend/, live_tracking_map.dart, lib/screens/delivery/, pubspec.yaml et pubspec.lock. Aucun changement de prix, commission, Stripe, snapshot, ledger ou règles serveur. Aucun secret ajouté détecté dans les fichiers sélectionnés ; vérification de motifs et revue du diff, pas une certification exhaustive de tout l'historique.

Preuves : CHECKPOINT_I18N_001.md, CHECKPOINT_I18N_002.md, HERO_EVIDENCE.json, MENU_EVIDENCE.json, IMAGE_EDIT.json, résumés JSON des exécutions, logs qualité, BUILD_INVENTORY.json, BUILD_PREFLIGHT.json, BUILD_QUALIFICATION.json, INTEGRITY_QUALITY.json et FINAL_VERIFICATION.json. Les manifests Git listent chaque fichier sélectionné et son SHA256. Journaux volumineux, base64 de transfert, caches, build Web et captures intermédiaires exclus des commits, conservés localement.

## 7. Fichiers produit et tests sauvegardés

- assets/home/hero_neutral.png — nouvelle illustration EN/ES.
- lib/screens/home/home_screen.dart — sélection réactive et description accessible.
- lib/l10n/home_copy.dart — descriptions et tooltips FR/EN/ES.
- lib/widgets/app_shell.dart — bouton de navigation localisé.
- test/home/home_hero_locale_test.dart — tests permanents de l'illustration.
- test/home/public_menu_locale_test.dart — tests permanents du menu.
- test/helpers/public_render_test_helpers.dart — polices locales et captures de widgets/overlay.
- test/home/home_screen_test.dart — sélecteur du tooltip français corrigé, contrôle invité conservé.
- docs/audit/REGISTRE_BOGUES_MOVIK.md — deux fermetures justifiées, blocage build et historique conservé.
- Preuves essentielles dans le présent dossier ; listes exactes HERO_COMMIT_FILES.json, MENU_COMMIT_FILES.json et FINAL_COMMIT_FILES.json.

## 8. Commits locaux et registre

| Commit | Objet |
|---|---|
| a3efb1e808f0a82d5b81e00c6f40287677d27d03 | fix(i18n): use neutral hero illustration for English and Spanish |
| cbbaf266df2fccad1da71c7f58bafbae87aea091 | fix(i18n): localize public navigation menu tooltip |
| HEAD documentaire enregistré dans FINAL_GIT_RESULT.json | docs(audit): record lot U results and CupertinoIcons blocker ; aucune fermeture BUILD |

27 fiches conservées. **P0 0 / P1 0 / P2 6 ouverts** après recalcul. P3, historiques, prérequis pilote et problèmes reportés conservés.

P2 encore ouverts : P2-BUILD-001, P2-L-01, GAP-M-05, GAP-M-06, GAP-S-02, GAP-S-04. Aucun travail commencé sur les cinq autres P2. Les dossiers GPS fermés restent fermés dans leurs périmètres antérieurs, sans prétention de déploiement.

## 9. Prochaine action unique

Décider d'autoriser l'obtention contrôlée de la dépendance officielle cupertino_icons compatible, absente du cache local, puis son intégration minimale et la validation build/icônes dans une étape distincte. Aucun téléchargement n'a été réalisé dans ce lot ; ne pas fermer P2-BUILD-001 avant preuve de résolution et de rendu des usages concernés.

**Arrêt au checkpoint du lot. Aucun push, merge ou déploiement.**
