# CHECKPOINT MOVI-K — Préparation sans réservation
Date : 16 octobre 2026, America/Toronto. Branche feature/photo-assisted-booking-20261015.
HEAD initial : 197855b77063fdade69193f883a712e89dcdac74. Index initial vide. Nombreux changements préexistants préservés; aucun autre worktree modifié.

## Cause racine
Route /fr/livraison/demande → DeliveryRequestFlowScreen. Le passage Mon prix → Mes coordonnées était offert seulement si quoteValid. Une revue serveur sans devis laissait l'utilisateur dans Mon prix. Le retry ne faisait que rappeler getBookingConfiguration, sans modifier le serveur.
_loadConfiguration absorbait toutes les exceptions et les transformait en policy null. L'API ne renvoyait que la politique, pas les capacités opérationnelles. Il ne s'agissait pas d'un changement de tarif ni d'un cache de devis.
Lecture réelle 19:11 UTC : booking_policy et booking_capacity absents; accept_new_delivery_requests, allow_driver_acceptance, payments_enabled, driver_payouts_enabled false. Appel public getBookingConfiguration HTTP 200, policy null. Aucun flag activé.

## Correction
- Préparation explicite possible sans devis : Mon prix → Mes coordonnées → résumé du brouillon.
- Validation normale des coordonnées conservée; navigation arrière, stockage et restauration conservés.
- Revalidation d'un devis qui échoue ne renvoie plus automatiquement le brouillon à l'étape 2.
- Distinction entre revue refusée/devis indisponible, réservation fermée, paiement indisponible et erreur technique.
- Retry secondaire, déclenché manuellement une fois; aucune boucle automatique ajoutée.
- getBookingConfiguration expose uniquement les capacités de réservation/paiement via le lecteur central resolveRuntimeFlag; aucune mutation.
- Garde UI et garde dans les méthodes de préparation carte/confirmation. Les protections serveur existantes restent autoritaires.
- Montants et distances inchangés; aucun calcul frontend ajouté; pas de devis fictif montré comme officiel.

## Fichiers modifiés par cette intervention
1. lib/screens/delivery/delivery_request_flow_screen.dart
2. functions/src/functions/bookingJourney.ts
3. functions/src/lib/bookingAvailability.ts (nouveau)
4. functions/test/unit/bookingAvailability.test.ts (nouveau)
5. test/helpers/booking_test_harness.dart
6. test/customer/booking_preparation_test.dart (nouveau)
7. test/customer/delivery_contact_validation_test.dart (fixture stabilisée)
8. docs/audit/REGISTRE_BOGUES_MOVIK.md (addendum)
La sélection Git inclut aussi les dépendances photo du formulaire déjà présentes et publiées mais non committées : aucune modification produit nouvelle de ces dépendances pendant cette intervention. Voir commit-files.json. Ne pas assimiler leur sauvegarde à de nouveaux correctifs.

## Tests réellement exécutés
- Reproduction initiale : 12 réussis, 5 échoués, 0 ignoré. Les 5 échecs couvrent la préparation invité/connecté, la confusion technique/disponibilité, le paiement désactivé et le refus du devis.
- Ciblé après : 23 réussis, 0 échoué, 0 ignoré.
- Première non-régression : 176 réussis, 2 échoués (option no_default_http_client manquante). Aucune assertion retirée.
- Non-régression avec option : 200 réussis, 1 échoué. Ancienne fixture de coordonnées générait deux dates d'expiration différentes d'une milliseconde.
- Fix du harnais : même snapshot de devis réutilisé; assertion d'égalité complète conservée. Suite coordonnées : 46 réussis/0 échoué/0 ignoré.
- Nouvelle exécution préparation + erreurs : 21 réussis/0 échoué/0 ignoré.
- Bilan des scénarios distincts, en prenant leur dernière exécution : 201 Flutter réussis, 0 échec restant, 0 ignoré. Ne pas additionner les exécutions recouvrantes.
- Serveur simulé : 7 réussis/0 échoué/0 ignoré; variantes flags, politique absente, erreur Firestore, erreur de politique.
- Flutter analyze intégral final : No issues found. Dart format : 4 fichiers, 0 changement.
- TypeScript noEmit et lint source finaux réussis; première erreur d'import inutilisé corrigée. Le lint initial visait aussi un test hors tsconfig source; le test est compilé par ts-jest, sans modifier la configuration du projet.
- git diff --check réussi.
- Build Web release réussi (117,42 s).
- FR/EN/ES, 375×812, 430×932, 768×1024, 1440×900 et texte 200 % couverts par vrais widgets.

## Preuve navigateur et publication
Chrome réel sur bundle local puis sur movi-k.com; données fictives dans le brouillon invité, pas d'adresses présentées comme validées. Saisie des coordonnées, résumé, retour et rafraîchissement contrôlés. Ne pas présenter ce scénario comme un devis serveur réussi ou une réservation réelle.
Les premières attentes DOM après chargement/rechargement échouaient car les sémantiques Flutter étaient activées trop tôt; captures montrent le formulaire et les coordonnées restaurées. Harnais corrigé pour attendre le placeholder Flutter; aucune modification produit pour masquer cet échec.
Fichiers local-final-result.json, public-final-result.json et PNG associés : preuves finales à consulter. Aucune requête métier autre que getBookingConfiguration pendant le contrôle navigateur; aucune mission, carte, paiement ou notification créée.
Web : dpl_3z1Xs3fbPnhZP6rqiJpDBh5wXwXf, feature draft-preparation-unblocked-v1.
URL : https://mecano-mobile-9ai8qfncz-solexis-projects-4c019079.vercel.app
Bundle SHA256 : 00401a108c56873c5fd69019ea2251e6720f336eee8f2c26b3145033ae2af464
Empreinte contrôlée directement sur movi-k.com et www.
Fonction publiée uniquement : getBookingConfiguration, revision getbookingconfiguration-00002-ziw, ACTIVE, mise à jour 19:19:27 UTC.
Quatre flags relus et strictement inchangés. Aucun déploiement de règles, prix, paiement ou autre fonction par cette intervention.

## Limites et sécurité
- Réservation, paiement et acceptation chauffeur toujours désactivés; devis officiel encore soumis aux configurations de capacité/politique manquantes.
- Ce correctif débloque la préparation, pas les ventes, ni Stripe LIVE.
- Brouillon invité conservé dans l'onglet, durée existante 24 h; fermer l'onglet l'efface. Pas de promesse de conservation interappareil.
- Pas de téléphone physique testé. Tests simulés des chemins disponibles et des payloads, Chrome réel du chemin fermé.
- Source manifest : 304 fichiers comparés; seuls écran et bookingJourney modifiés, plus nouveau helper lecture seule. Finance et GPS inchangés.
- Aucun push, merge ni modification d'autres worktrees. Commit local ciblé après contrôles; reçu Git séparé.
- P1-BOOKING-CONFIG-01 reste ouvert pour le lancement commercial; 31 fiches conservées, P0 0 / P1 1 / P2 2. Test autonome 1.3L toujours reporté.
- Avertissement CLI Node 20 et dépendance Firebase à traiter séparément, aucune installation réalisée.

## Prochaine action
Achever la configuration et la validation commerciale permettant d'obtenir un devis officiel et de réserver, sans inventer de capacités véhicule ni activer les paiements pour contourner un contrôle.
