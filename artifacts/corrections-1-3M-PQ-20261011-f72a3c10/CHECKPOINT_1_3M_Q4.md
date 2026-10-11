# CHECKPOINT MOVI-K — 1.3M-Q4 — P2-FORM-004

11 octobre 2026. Cause : conversion numérique correcte mais affichage brut de double via toString/interpolation ; 190 cm montrait 74.8031496062992 in. La reproduction initiale totalise 3 réussites et 17 échecs : 16 échecs de présentation reproduisant le défaut et 1 erreur du jeu de données du test inconnu (map inférée Map<String,Object> refusant null), non un bogue produit.

Cette donnée de test est devenue Map<String,dynamic> ; le contrôle inconnu a été exécuté avant correction du produit et a réussi (Q4-before-fixture, 1/0/0). La mesure visuelle repère le véritable RenderEditable parmi les RenderObjects ; aucune assertion supprimée ou affaiblie. Le test initial complet et ses erreurs restent archivés dans Q4-test-initial.dart.txt et Q4-before.jsonl.

Correction : helper local _dimensionText de présentation, deux décimales au plus avec zéros finaux retirés et séparateur FR/ES virgule, EN point. Si cet arrondi masquerait une quantité non nulle par zéro, représentation courte à trois chiffres significatifs ; aucune restriction métier nouvelle. Inconnu reste inconnu. Utilisé seulement dans longueur/largeur/hauteur du formulaire et résumé de confirmation ; poids, calcul de conversion, validateurs, BookingDraft, charge utile et serveur inchangés.

20 tests ciblés : FR/EN/ES × 375×812, 430×932, 1440×900 et 375×812 avec texte 200 %, conversion aller/retour, largeur réelle du champ ; trois résumés de confirmation 200 % avec devis simulé inchangé ; charge utile envoyée conservant 190*(1/2.54) plutôt que 74.8 ; reconstruction sans perte ; saisie décimale conservée ; valeur inconnue ; petite valeur non nulle.

32 non-régressions : Q4-regression = 13 contrôles du label unité, 4 reprise brouillon, 11 autocomplete/adresses et 2 double soumission/interruption préparation ; Q4-confirmation = 2 tests N navigation/reconstruction et charge utile/double appel. Les anciens tests utilisant testWidgets ont été exécutés via copies enveloppées de refus réseau, assertions inchangées. Aucune suite GPS inutilement répétée pour ce changement local.

Commandes : run-Q4-before.ps1 ; run-Q4-before-fixture.ps1 ; run-Q4-after.ps1 ; run-Q4-regression.ps1. Flutter --no-version-check test --no-pub --dart-define=no_default_http_client=true --reporter=json --concurrency=1 avec sélection explicite ; analyse ciblée, Dart format et git diff --check réussis.

Isolation : vrais widgets, BookingTestAuth/TestBookingApi/MemoryBookingStorage ou stub de session, FakeAddressAutocompleteProvider, transport mémoire et refus HTTP ; pas de clés ni d’API externes, aucune mission/paiement réel. Montant de devis fictif 123.45 CAD non utilisé comme preuve financière serveur. Les chiffres stockés et transmis ne changent pas ; aucun tarif/commission/taxe/Stripe/snapshot/ledger modifié.

Limites : vérification widget/contraintes, sans capture Chrome, GPS physique ni production ; BookingLoadSummary de snapshot serveur hors modification. Test autonome 1.3L bloqué/reporté. Le lot P/Q est prêt au bilan après commit local autorisé ; aucune autre correction commencée.

## Résultats et Git

Base : 1aa7b8a8bad130e83a5ef819aa3cf5883980ff8c ; branche fix/gps-client-history-scope-20261009.

- Q4-before : 3 réussis, 17 échoués, 0 ignorés.
- Q4-before-fixture : 1 réussis, 0 échoués, 0 ignorés.
- Q4-after : 20 réussis, 0 échoués, 0 ignorés.
- Q4-regression : 30 réussis, 0 échoués, 0 ignorés.
- Q4-confirmation : 2 réussis, 0 échoués, 0 ignorés.

Résultat final distinct : 52 réussis, 0 échec, 0 ignoré. Analyse ciblée, format et git diff --check : 0. Registre : P0 0, P1 2, P2 10 ouverts, 27 fiches. Fermeture limitée P2-FORM-004 autorisée et appliquée. Aucun autre problème fermé.

Sélection exacte du commit local :

- `lib/screens/delivery/delivery_request_flow_screen.dart`
- `test/customer/delivery_dimension_display_test.dart`
- `docs/audit/REGISTRE_BOGUES_MOVIK.md`
- `artifacts/corrections-1-3M-PQ-20261011-f72a3c10/CHECKPOINT_1_3M_Q4.md`
- `artifacts/corrections-1-3M-PQ-20261011-f72a3c10/VALIDATION_1_3M_Q4.json`

Journaux complets conservés dans le même dossier et exclus du commit, ainsi que copies temporaires, caches, builds et scripts de diagnostic. Empreintes et résultats dans VALIDATION_1_3M_Q4.json. Aucun changement financier ou serveur.
