# CHECKPOINT MOVI-K — 1.3M-R — P1-HOME-001

Date : 11 octobre 2026. Branche fix/gps-client-history-scope-20261009. HEAD avant commit : 5649bbbe14a6500a81cc53d1728a112663a0a92e. Index initial vide ; aucun changement produit préexistant. Les cinq commits P/Q sont présents, de 5e9c60c59a31ac72b5cb196715643922afd9bc8c à 5649bbbe14a6500a81cc53d1728a112663a0a92e.

## Diagnostic et preuves

Le défaut historique du hero desktop a été corrigé par d563be2 puis les textes/parcours publics harmonisés par 49e865c. Aucun diff des sources et ressources publiques sélectionnées entre release 77c3c615 et HEAD actuel. Le hero actif desktop utilise Row/Column et un bloc de réassurance sous le contenu, sans Positioned. Le chemin ancien _HeroRight.desktop n’est pas appelé par ce rendu. Les cartes des quatre étapes ont une hauteur minimale, pas une hauteur maximale bloquante. La demande « En 3 étapes » correspond à un ancien état : le composant réel présente quatre étapes et elles ont toutes été testées.

Le rapport 1.3B du 8 octobre et cinq PNG ont été relus/examinés aujourd’hui : desktop 00/01/02, mobile 375 00 et 430 00. Les fichiers, dimensions et SHA-256 exacts figurent dans HISTORICAL_AND_SOURCES.json. Le rapport historique décrit 21 captures et six navigations CTA ; ces nombres sont historiques, non de nouvelles captures. Aucun chevauchement des zones examinées. hero_clean.png examiné : illustration commerciale générique, aucun engagement de délai/couverture ; texte français incorporé, P2-I18N-001 inchangé.

## Validation actuelle

Commande finale compatible CI : flutter --no-version-check test --no-pub --reporter=json --concurrency=1 test/home/home_screen_test.dart test/home/home_launch_layout_test.dart.

Résultat final : **49 réussis, 0 échoué, 0 ignoré** (31 tests existants + 18 nouveaux). Les 18 nouveaux sont 15 combinaisons de géométrie (FR/EN/ES × 375×812, 430×932, 1440×900, 375×812 texte200%, 430×932 texte200%) et trois routes chauffeur. Rectangles hero/boutons/réassurance et sections disjoints, quatre cartes distinctes, textes hero/étapes non tronqués, défilement jusqu’au bas et absence d’exception. Tests existants : CTA vers vrai formulaire, catégorie et brouillon conservés, connexion simulée/reprise, langues, menu, contact. La destination chauffeur est une route sentinelle dans ce harnais : validation du chemin, pas de l’inscription complète.

Exécutions intermédiaires conservées : home-tests 49/0/0 puis home-layout-final 18/0/0. Elles ne s’ajoutent pas au total distinct final. La première analyse a signalé deux usages dépréciés Finder.description dans le nouveau diagnostic de test ; corrigés sans toucher aux assertions. Analyse finale de cinq fichiers : 0 anomalie. Dart format : 0 changement. git diff --check : réussi.

## Isolation et limites

Authentification backendConfigured:false, SharedPreferences fictifs, API de réservation TestBookingApi explicitement injectée pour la dernière exécution ; aucune application Firebase initialisée (assertions), aucune opération de paiement/mission. Harnais HTTP mémoire existant : création HttpClient refusée, package:http sans transport par défaut, aucun appel externe délégué. Compteur final : in_memory=0 et unexpected=0 pour chaque suite. Ce n’est pas un confinement système : 1.3L demeure bloqué et reporté. Les premières exécutions ont été faites sans Firebase initialisé ; l’injection TestBookingApi a été rendue explicite avant validation finale.

Aucun code produit modifié. Aucun test Chrome actuel, build Web, émulateur, GPS terrain, Firebase réel, disponibilité chauffeur, zone live ni paiement validé. Les PNG sont des preuves Chrome historiques du code public identique, distinctes des tests widget actuels.

## Décision et sauvegarde

P1-HOME-001 : **FERMÉ — PÉRIMÈTRE LOCAL VALIDÉ — NON DÉPLOYÉ**. Critères satisfaits pour le chevauchement local aux formats testés. Registre unique : 27 fiches, P0 0 / P1 1 / P2 10. P1-COPY-001 et les dix P2 restent ouverts à ce point. Fichiers de commit explicitement sélectionnés dans VALIDATION_HOME.json ; aucun cache/build/fichier personnel/secret/journal volumineux inclus. Sauvegarde locale autorisée ; aucun push/merge/déploiement. Prochaine action dans le lot : terminer la vérification P1-COPY-001.

Revalidation finale compatible avec la commande CI sans dart-define obligatoire : home-ci-final, 49/0/0, analyse home-ci-quality sans anomalie, format home-ci-format réussi. Le transport refusant les accès HTTP et le client mémoire sont installés par chaque offlineWidgetTest ; aucun changement du helper GPS partagé. La première tentative de sauvegarde a été stoppée par git diff --cached --check sur les espaces de console recopiés dans QUALITY_HOME.md : copie nettoyée, journal brut conservé, aucun commit lors de cet arrêt.
