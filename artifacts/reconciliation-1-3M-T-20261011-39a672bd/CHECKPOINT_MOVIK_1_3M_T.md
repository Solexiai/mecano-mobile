# CHECKPOINT MOVI-K — 1.3M-T — P2-COPY-001

Date : 11 octobre 2026, America/Toronto. Verdict : TERMINÉ, périmètre local/simulé uniquement.

## 1. Reprise Git

Worktree : C:\Users\Utilisateur\movik-gps-history-fix-20261009.
Branche : fix/gps-client-history-scope-20261009.
HEAD initial : 18f12ff393d54b5cd32219cc9188f1354a90e1db, commit local P2-G-02 confirmé.
Index initial vide, aucun fichier suivi modifié. Les empreintes de 3 031 fichiers préexistants suivis/non suivis ont été relevées dans GIT_INITIAL.json et comparées avant sauvegarde. Les fichiers non suivis antérieurs sont préservés.
HEAD de sauvegarde : commit contenant ce checkpoint ; la vérification post-commit consigne son identifiant exact dans CHECKPOINT_MOVIK_1_3M_T_FINAL.md.

## 2. Défaut historique et état présent

- Ancienne mention : « Leboncoin, Marketplace, Kijiji, etc. », home_screen.dart ligne 459 dans le parent du commit 49e865c7a91eb0fda8be6fbc5fcc88b1058c3b5f.
- Ce commit du 1er octobre 2026 à 13:11:57 −04:00 remplace le texte codé directement par HomeCopy.marketplace_examples.
- HEAD actuel : lib/screens/home/home_screen.dart:486–488 utilise cette clé ; lib/l10n/home_copy.dart:326–330 fournit « Facebook Marketplace, Kijiji, etc. » en FR/EN/ES.
- Recherche Git insensible à la casse dans lib et web : aucune occurrence de « Leboncoin » ou « le bon coin ». Les mentions documentaires et historiques restent conservées.
- Release lue sans modification : 77c3c61534d1300ddc0eab5585f78b9662a69537. Aucun écart dans les sources publiques comparées (accueil, HomeCopy, pages info, landing livraison, AppShell, web, assets).
- L’image réellement utilisée, assets/home/category_marketplace.png, a été examinée : cartons, sans texte commercial. Son empreinte est conservée.
- Aucune correction produit nécessaire ; aucun partenariat ni promesse commerciale ajouté.

## 3. Preuves historiques conservées

SOURCE_HISTORY.json contient les commits, lignes, empreintes et comparaison release.
Le checkpoint 1.3B du 8 octobre est retrouvé à C:/Users/Utilisateur/mecano-mobile/artifacts/checkpoint-1-3B-20261008-Vm7G5Q/CHECKPOINT_PHASE1_1_3B.md ; SHA-256 actuel identique à celui archivé à l’étape R. Ses lignes 48 et 70 constataient déjà le retrait.
CHECKPOINT_COPY.md de 1.3M-R est référencé avec son empreinte. Ses anciens résultats ne sont pas comptés comme de nouveaux tests.

## 4. Tests exécutés pendant T

| Exécution | Réussis | Échoués | Ignorés |
|---|---:|---:|---:|
| Premier test Marketplace, police Flutter Ahem par défaut | 9 | 3 | 0 |
| Même test avec Roboto local explicitement chargé | 12 | 0 | 0 |
| Accueil existant + géométrie + contrat des textes publics | 61 | 0 | 0 |
| Pages publiques existantes, sélection FR/EN/ES | 3 | 0 | 0 |
| Test Marketplace final après retrait d’un import redondant | 12 | 0 | 0 |

Couverture finale : **76 tests distincts réussis, 0 échec final, 0 ignoré**. Les répétitions des 12 tests ne sont pas additionnées. Les trois échecs initiaux restent archivés.

Les trois échecs initiaux portaient sur didExceedMaxLines du titre Marketplace à 375 px, dans chaque langue. Le SDK local confirme que flutter_tester impose --use-test-fonts (Ahem). Le nouveau test charge les fontes Roboto déjà installées utilisées par le thème Material ; aucune police téléchargée, aucun thème produit remplacé, aucune assertion retirée ou affaiblie. Les mêmes contrôles passent ensuite. Cela ne démontre pas un défaut Chrome. FONT_EVIDENCE.json et INITIAL_FAILURES.json conservent les traces et empreintes.

## 5. Commandes reproductibles

Variables de processus : FLUTTER_SUPPRESS_ANALYTICS=true, DART_SUPPRESS_ANALYTICS=true, CI=true.
SDK existant : C:/Users/Utilisateur/mecano-mobile/.flutter/bin/flutter.bat.

Préfixe commun des tests :
flutter --no-version-check test --no-pub --dart-define=no_default_http_client=true --concurrency=1 --reporter=json

Arguments des exécutions :
- test/home/home_marketplace_copy_test.dart (les trois exécutions distinctes ci-dessus).
- test/home/home_screen_test.dart test/home/home_launch_layout_test.dart test/public/public_launch_copy_contract_test.dart.
- test/public/public_launch_pages_test.dart --plain-name "public launch pages render in".

Les autres tests de public_launch_pages_test.dart sont exclus par sélection, pas annoncés réussis ni ignorés. Les synthèses JSON donnent les noms exacts et les SHA-256 des journaux bruts conservés localement.

## 6. FR/EN/ES, formats et navigation

Nouveau test permanent : vrais HomeScreen et DeliveryRequestFlowScreen, harnais existant, trois langues × 375×812, 430×932, 1440×900, 375×812 texte 200 %.
Assertions : exemple Marketplace exact ; absence de l’ancienne mention dans les RichText rendus et toutes les entrées HomeCopy ; texte de pré-lancement/Granby maintenu ; titre et sous-texte de la carte sans troncature ; aucune exception Flutter.
Clic réel sur la catégorie : destination /{locale}/livraison/demande?category=cat_marketplace, paramètre transmis au vrai formulaire, aucune création de mission simulée demandée.
Les tests existants couvrent les CTA devis/chauffeur, les catégories, la reprise invitée, la géométrie sans chevauchement et les textes prudents. Les destinations du harnais accueil restent distinctes des routes réellement montées par AppRouter dans les tests publics.
Trois tests publics montent huit routes réelles par langue ; les douze tests de contrat parcourent accueil, fonctionnement, FAQ dépliée, Granby, chauffeur et tarifs.

## 7. Isolation

Auth backendConfigured:false, Firebase.apps vide vérifié avant/après, SharedPreferences fictif, TestBookingApi pour les appels du formulaire dans le harnais accueil.
Transport existant offlineWidgetTest/withOfflineTransport : HttpClient interdit, package:http routé vers un client mémoire sans délégation. Les cinq synthèses de transport finales rapportent zéro tuile et zéro demande inattendue.
Aucun lien externe cliqué, aucune demande d’adresse ou devis réel, aucune mission ou transaction créée. Polices lues depuis le cache local du SDK.
Ces garanties concernent les dépendances des widgets testés ; elles ne prouvent pas un confinement réseau de tout Windows. Le test autonome 1.3L reste BLOQUÉ ET REPORTÉ.

## 8. Qualité et intégrité

Analyse Flutter ciblée sur huit fichiers : aucune anomalie lors de l’exécution finale.
L’analyse initiale avait signalé un import dart:typed_data inutile dans le nouveau test ; seul cet import a été retiré. Trace conservée, pas de correction produit.
Dart format --output=none --set-exit-if-changed sur le nouveau test : aucun changement.
git diff --check et contrôle de l’index avant commit : code 0.
Empreintes : aucune modification d’un fichier préexistant sauf le registre maître. Aucun fichier produit, GPS, financier, règle Firestore ou fonction serveur modifié.
Contrôle des fichiers sélectionnés : aucun secret détecté, aucun cache/build/journal volumineux ni fichier personnel. Aucun hook Git actif trouvé.

## 9. Fermeture et registre

P2-COPY-001 : **FERMÉ — PÉRIMÈTRE LOCAL/SIMULÉ VALIDÉ — NON DÉPLOYÉ**, suivant l’autorisation explicite de cette étape.
Correction historique présente, non-régressions ciblées concluantes, routes préservées, preuves et limites conservées.
Registre unique : docs/audit/REGISTRE_BOGUES_MOVIK.md. Ancien état « VALIDÉ — HISTORIQUE, NON FERMÉ » conservé dans l’historique.
Décompte recalculé sur les 27 fiches : **P0 0 / P1 0 / P2 8**. Aucun autre statut changé. P3 et prérequis du pilote préservés.

## 10. Fichiers et sauvegarde

Fichiers de travail : nouveau test test/home/home_marketplace_copy_test.dart ; registre maître ; preuves essentielles listées exactement dans VALIDATION.json.
La sélection comprend ce checkpoint, SOURCE_HISTORY.json, FONT_EVIDENCE.json, INITIAL_FAILURES.json, les cinq synthèses d’exécution et VALIDATION.json.
Exclusions : GIT_INITIAL.json volumineux, journaux bruts, scripts intermédiaires, copies initiales du nouveau test, caches/builds, toutes les preuves antérieures non suivies. Les exclusions restent sur disque.
Commit local autorisé : test(public): preserve marketplace copy and close P2-COPY-001.
Aucun push, merge, déploiement ou accès à la production.

## 11. Limites et prochaine séquence

Validation widget locale, sans nouvelle capture Chrome, appareil physique, build Web ou revue de production. Aucune disponibilité réelle de chauffeur ni préparation au lancement commercial déduite.
La présence de textes intégrés en français dans l’illustration EN/ES reste P2-I18N-001 ; aucune fermeture de cette fiche.
Les huit P2 restants sont : P2-I18N-001, P2-I18N-002, P2-BUILD-001, P2-L-01, GAP-M-05, GAP-M-06, GAP-S-02 et GAP-S-04.
Prochaine séquence proposée, non commencée : P2-I18N-001, qualifier l’illustration française de l’accueil EN/ES à partir des ressources existantes.
