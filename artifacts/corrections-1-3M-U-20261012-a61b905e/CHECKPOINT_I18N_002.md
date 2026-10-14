# CHECKPOINT MOVI-K — 1.3M-U — P2-I18N-002

12 octobre 2026, America/Toronto. Branche fix/gps-client-history-scope-20261009.
Parent vérifié : a3efb1e808f0a82d5b81e00c6f40287677d27d03. Index vide et état suivi propre au départ de cette sous-étape.

## Cause et correction

lib/widgets/app_shell.dart laissait AppBar fabriquer le DrawerButton. La racine lib/main.dart n'installe pas de localisation Material globale ; la localisation du formulaire est limitée à ce formulaire. Le DrawerButton du SDK lit MaterialLocalizations.openAppDrawerTooltip, donc l'anglais par défaut sur l'accueil FR/ES.

Correction limitée : IconButton de navigation explicite en mode tiroir, même icône menu et même Scaffold.openDrawer, tooltip traduit avec HomeCopy.open_navigation_menu. FR « Ouvrir le menu de navigation », EN « Open navigation menu », ES « Abrir el menú de navegación ». Aucun tooltip vide. Aucun changement de route, de rôle, de drawer ou de politique d'accès. Desktop conserve ses liens et n'affiche pas de bouton de tiroir.

Le test historique d'absence du lien Administration invité utilise désormais le libellé français correct, sans supprimer l'assertion. Nouveau test permanent public_menu_locale_test.dart : vrais HomeScreen/AppShell/Tooltip/Drawer, tailles logiques vérifiées, sémantique bouton/action tap, infobulle affichée après appui long, ouverture/fermeture, défilement puis Contact, retour, navigation FAQ desktop et changement FR/EN/ES par le sélecteur.

## Exécutions

Commande : flutter --no-version-check test --no-pub --dart-define=no_default_http_client=true --concurrency=1 --reporter=json <fichiers>.

| Exécution | Réussis | Échoués | Ignorés | Interprétation |
|---|---:|---:|---:|---|
| menu-before | 0 | 0 | 0 | 1 erreur de chargement/compilation : mauvais nom de package dans le nouveau test. Aucun scénario exécuté. |
| menu-reproduction | 0 | 13 | 0 | 7 attentes de langue échouées ; 6 échecs du test dus à l'identité de type de l'import relatif LocaleProvider. |
| menu-reproduction-final | 6 | 7 | 0 | Imports corrigés, produit inchangé : manque du tooltip FR/ES et du changement de langue démontré. |
| menu-after | 11 | 2 | 0 | Correction produit appliquée ; deux tests FR/ES à 200 % recherchaient Contact avant sa matérialisation dans ListView. |
| menu-final | 13 | 0 | 0 | Défilement réel jusqu'à Contact ; aucune assertion retirée. |
| menu-regression | 68 | 0 | 0 | home_screen_test (31), home_hero_locale_test (13), public_launch_pages_test (24). |

81 scénarios distincts dans la validation finale de cette fiche. Ne pas additionner les répétitions ni les tests déjà comptés dans la première fiche pour obtenir un total du lot.

Analyse initiale : une utilisation dépréciée de SemanticsData.hasFlag dans le nouveau test. Remplacée par flagsCollection.isButton ; analyse finale 5 fichiers : aucune issue. Format et git diff --check réussis.

## Rendu et isolation

FR/EN/ES : 375×812, 430×932, 1440×900, 375×812 à 200 %. Les trois scénarios desktop testent l'absence normale de tiroir et la navigation FAQ. Neuf PNG mobile/200 % dans menu-final/, obtenus à partir de la couche du vrai RenderView incluant l'overlay Tooltip, examinés. Infobulles lisibles, complètes, sans débordement ; retour à la ligne normal FR/ES à 200 %. Comme toute infobulle, l'overlay recouvre temporairement une partie du contenu et disparaît à la fermeture.

Les captures menu-verified/ initiales ne contenaient pas l'overlay et ne sont pas retenues comme preuve de l'infobulle. Le helper de capture ajoute une fonction dédiée au RenderView, sans changement de widget produit. Bannière debug et police Ahem de certains boutons sont des limites du rendu de test, pas une validation Chrome. Les images non nécessaires au contrôle du tooltip ne sont pas toutes préchargées dans ces captures.

Auth fictive, aucun Firebase initialisé, préférences mémoire, refus de clients HTTP réels et client mémoire sans transport externe, zéro tuile/événement réseau inattendu. Aucun backend, carte, paiement ou notification. 1.3L reste BLOQUÉ ET REPORTÉ ; aucun confinement OS ni appareil physique nouvellement validé.

## Fermeture et sauvegarde

P2-I18N-002 : FERMÉ — PÉRIMÈTRE LOCAL/SIMULÉ VALIDÉ — NON DÉPLOYÉ.
27 fiches conservées ; P0 0 / P1 0 / P2 6.

Fichiers : lib/widgets/app_shell.dart ; lib/l10n/home_copy.dart ; test/home/home_screen_test.dart ; test/home/public_menu_locale_test.dart ; test/helpers/public_render_test_helpers.dart ; docs/audit/REGISTRE_BOGUES_MOVIK.md.
Preuves essentielles : ce rapport, MENU_EVIDENCE.json, MENU_COMMIT_FILES.json, résumés de toutes les exécutions, analyse/format, trois captures d'infobulle FR/EN/ES 375×812. Journaux bruts et autres captures conservés localement, exclus du commit. HERO_COMMIT_RESULT.json conserve le HEAD de la première sauvegarde.

Aucun fichier GPS/financier/serveur modifié. Prochaine anomalie : P2-BUILD-001, à qualifier avant tout changement de dépendance.
