# MOVI-K — CHECKPOINT GAP-M-05 — CONSERVATION PARESSEUSE DES ONGLETS
Date : 2026-10-13, heure locale Québec.

## Verdict
**FERMÉ — PÉRIMÈTRE FLUTTER WIDGET LOCAL VALIDÉ — NON DÉPLOYÉ.**

## Git et périmètre
- Dépôt existant : Solexiai/mecano-mobile.
- Worktree : `C:\Users\Utilisateur\movik-gps-history-fix-20261009`.
- Branche : `fix/gps-client-history-scope-20261009`.
- HEAD de départ : `1ca48576abcdc4e74ba4a1f995768fe61c1f4018`.
- Prévol : aucun changement Git suivi, index vide ; branche release `release/live-backend-granby-20261006` non modifiée.
- Aucun push GitHub, merge ni déploiement. Aucun accès Firebase Production, aucun paiement.

## Reproduction statique et cause
`ProviderDashboardShell` construisait les quatre widgets d'onglet dans un tableau puis ne montait que `tabs[_index]`. Changer d'onglet retirait le précédent de l'arbre de widgets et détruisait son State, y compris ses flux Firestore propres. Le registre Phase7 évoquait un `IndexedStack` simple tenté puis annulé, car il montait aussi les onglets jamais visités et pouvait déclencher des flux de finance/profil prématurés.

## Correction locale ciblée
- `lib/screens/dashboard/provider/provider_dashboard_shell.dart` : conserve les quatre positions d'onglet sous un `IndexedStack` stable.
- Chaque position n'est construite comme vrai onglet **qu'à sa première visite**, selon les indicateurs `_visitedTabs`; auparavant, elle ne contient qu'un `SizedBox.shrink()`.
- Une fois un onglet visité, il reste monté hors écran : ses State et ses abonnements subsistent au retour, sans répéter inutilement les abonnements de `ProviderJobsTab`.
- La sélection desktop `NavigationRail` et mobile `BottomNavigationBar` utilise la même méthode, sans modification des routes.
- `Row` + `Expanded` reste le parent de la pile dans les deux modes : un redimensionnement mobile↔desktop préserve les State dans le parcours local testé.
- L'ouverture via `initialTabIndex: 3` monte uniquement Profil et n'initialise pas les flux Missions tant que cet onglet n'a pas été visité. L'identité du chauffeur déclenche la remise à zéro de l'historique de visites de la pile.
- Aucun changement aux onglets métier internes, calculs, tarifs, commissions, Stripe, notifications, Firestore rules, snapshots ou ledger.

## Tests et preuves
- `dart analyze --fatal-infos` ciblé sur le shell et le test modifiés : zéro anomalie.
- `flutter test --no-pub --dart-define=no_default_http_client=true` : **49 tests réussis sur 49**, cinq suites :
  - `test/driver/provider_dashboard_shell_status_gate_test.dart` : 9/9, dont trois nouveaux tests GAP-M-05 (mobile 430px, desktop 1200px, démarrage direct Profil).
  - `test/driver/provider_jobs_tab_test.dart` : 11/11, parcours missions, acceptation, concurrence locale, erreurs et petits écrans.
  - `test/driver/provider_stripe_connect_section_test.dart` : 10/10, états de compte simulés et localisations.
  - `test/finance/provider_payouts_section_test.dart` : 8/8, état des versements et affichage de montants depuis les fixtures.
  - `test/accessibility/critical_accessibility_test.dart` : 11/11, vérifications d'accessibilité ciblées.
- Les tests de lazy mounting vérifient l'absence réelle des éléments Flutter jamais visités (y compris avec `skipOffstage:false`), la conservation du mois de Calendrier et qu'aucun deuxième appel `watchAvailableMissionsForDriver` ou `watchActiveMissionForDriver` n'apparaît au changement/retour d'onglet. Les tests vérifient l'abonnement au profil de chauffeur déjà mémoïsé.
- Le fake d'authentification du test n'a pas un objet `FirebaseAuth.user` complet ; le test de démarrage direct Profil utilise un `pump` borné car l'écran affiche le spinner prévu pour cet état de fixture. Première tentative `pumpAndSettle` expirée pour cette raison ; assertion corrigée sans modifier le code métier.
- Les tests vérifient la pile et les flux simulés, pas des statistiques facturées Firestore en production ni des données saisies dans une vraie session de chauffeur.

## Limites et suivi
- Un onglet **déjà visité reste monté et conserve ses abonnements actifs même lorsqu'il est masqué**. Cela élimine les réabonnements inutiles, mais des onglets parcourus accumulent des abonnements persistants. Les onglets jamais visités ne sont pas démarrés d'avance. Mesurer le coût et la fraîcheur Firestore lors de la recette pilote.
- La conservation de l'état vaut pendant la vie du widget `ProviderDashboardShell`, pas après destruction complète de la route, fermeture d'application ou déconnexion.
- Aucun navigateur Chrome/Safari, appareil physique ou déploiement réel validé. La suite GPS/tuiles réseau 1.3L reste BLOQUÉE/REPORTÉE.
- D'autres P3/prérequis du pilote subsistent indépendamment du registre P0/P1/P2 actif.

## Registre
27 fiches conservées ; **26 fermées localement, 1 P2 restant** dans le registre courant : `P2-L-01` (contraste des badges warning).
P0=0, P1=0 (selon le périmètre enregistré), P2=1. Aucune déclaration de GO production.
