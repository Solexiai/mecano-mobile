# CHECKPOINT MOVI-K — 1.3M-U — P2-I18N-001

Date : 12 octobre 2026 (America/Toronto). Branche fix/gps-client-history-scope-20261009.
HEAD initial : 7700931ee7a91b8b9a29c2f91ca3ccdf857e6c29. Index initial vide ; aucun fichier suivi modifié. Inventaire initial complet dans GIT_INITIAL.json (3072 empreintes). Aucun autre worktree modifié.

## Défaut et correction

Les deux branches responsive de lib/screens/home/home_screen.dart utilisaient toujours assets/home/hero_clean.png. Image originale examinée : 524×350, 417088 octets, SHA256 45b11258e45ea649dfa51c070052893427520f0f0212c8462a4b63b64e638365. Le slogan français et « LIVRAISON SIMPLIFIÉE » étaient inscrits dans les pixels. hero_reference_right et tracking_phone examinés : pas de variante neutre équivalente disponible.

Original FR strictement préservé. Nouvelle ressource assets/home/hero_neutral.png pour EN/ES : suppression des textes français et de la flèche du slogan avec l'outil de retouche d'image, sans nouvelle traduction incorporée. Van, chauffeur, mobilier, maison, couleurs, marque Movi-K et proportions conservés visuellement ; retouche générative, pas identité pixel par pixel. 1535×1025, 1791300 octets, SHA256 c687035e45b047a6b9516bf40f672ec05cdd0f9b6a51d9be171bcb11b00726e5. Prompt et provenance : IMAGE_EDIT.json. Aucun remplacement de moindre résolution. Poids augmenté ; coût de chargement réel non mesuré.

Sélection de ressource réactive au LocaleProvider aux deux emplacements. Description accessible localisée avec HomeCopy.hero_scene_label. Aucun changement de texte commercial, de disposition ou de navigation. Le logo officiel indépendant dans l'en-tête demeure inchangé, y compris sa signature de marque.

## Exécutions réellement effectuées

Commande commune : flutter --no-version-check test --no-pub --dart-define=no_default_http_client=true --concurrency=1 --reporter=json <fichiers>.

| Exécution | Réussis | Échoués | Ignorés | Portée |
|---|---:|---:|---:|---|
| hero-before | 0 | 13 | 0 | Première préparation du test ; handles Semantics libérés trop tard. Défaut de test, pas 13 bogues produit. |
| hero-reproduction | 4 | 9 | 0 | Test corrigé, avant correctif produit ; EN/ES chargent hero_clean au lieu de hero_neutral. |
| hero-after | 4 | 9 | 0 | Patch interrompu par ancre CRLF non trouvée, état incomplet, non validé. |
| hero-final | 13 | 0 | 0 | Routage d'assets ; captures initiales insuffisantes (MediaQuery et décodage). |
| hero-verified | 13 | 0 | 0 | Assertions renforcées : taille logique réelle, image décodée et largeur desktop. |
| hero-permanent | 13 | 0 | 0 | État permanent final, après retrait d'un alias de police sans effet. |
| hero-regression | 73 | 0 | 0 | home_screen_test, home_launch_layout_test, home_marketplace_copy_test, public_launch_copy_contract_test. |

Les répétitions ne sont pas additionnées comme tests distincts : 13 ciblés + 73 non-régressions = 86 scénarios distincts réussis en exécution finale. Les échecs et journaux originaux sont conservés. Deux avertissements de style dans le nouveau test au premier analyze ont été corrigés ; analyse finale et format contrôlés séparément.

## Preuves de rendu et isolation

12 PNG réels issus de RenderRepaintBoundary.toImage dans hero-verified/, examinés un par un : FR/EN/ES × 375×812, 430×932, 1440×900 et 375×812 à 200 %. Dimensions contrôlées dans le test et par lecture PNG. Image affichée, aucune inscription française dans le visuel EN/ES, original FR conservé ; pas de chevauchement avec les blocs voisins dans les vues examinées. Les vues mobiles sont défilées jusqu'à l'image ; le contenu agrandi continue normalement hors du viewport vertical.

Harnais permanent : vrais HomeScreen/AppShell/Image/LanguageSelector, services Auth non configurés et SharedPreferences simulé. HttpOverrides refuse les clients HTTP réels, client package:http mémoire uniquement, compilation no_default_http_client=true. Assertions Firebase.apps vide et zéro requête de tuile/imprévue. Aucun lancement de backend ni carte ; aucune connexion métier externe. Ce contrôle ciblé n'est pas une preuve de confinement OS ; 1.3L reste BLOQUÉ ET REPORTÉ.

Polices Roboto et MaterialIcons chargées depuis le SDK local. Certains boutons sans famille explicite restent en Ahem dans flutter_tester : leurs rectangles et routes sont testés, leur typographie plateforme n'est pas validée par ces PNG. Les premiers PNG hero-final/ ne sont pas retenus comme preuves responsive ; les dimensions étaient celles de la surface mais pas toutes celles de MediaQuery. Pas de capture Chrome, de téléphone physique, de production ni de mesure des performances.

## Décision et sauvegarde

P2-I18N-001 : FERMÉ — PÉRIMÈTRE LOCAL/SIMULÉ VALIDÉ — NON DÉPLOYÉ, limité au choix de l'illustration et à sa description accessible.
27 fiches conservées ; P0 0 / P1 0 / P2 7 après cette seule fermeture.

Fichiers produit/tests : assets/home/hero_neutral.png ; lib/screens/home/home_screen.dart ; lib/l10n/home_copy.dart ; test/home/home_hero_locale_test.dart ; test/helpers/public_render_test_helpers.dart ; docs/audit/REGISTRE_BOGUES_MOVIK.md.
Preuves Git essentielles : ce checkpoint, IMAGE_EDIT.json, HERO_EVIDENCE.json, HERO_COMMIT_FILES.json, résumés JSON avant/après et contrôles qualité ciblés. Journaux bruts, captures intermédiaires, base64, scripts de préparation, builds/caches et GIT_INITIAL.json complet restent conservés localement mais exclus du commit.

Aucun GPS, paiement, tarif, commission, snapshot, ledger, règle Firestore ou fonction serveur modifié. Prochaine anomalie autorisée : P2-I18N-002.
