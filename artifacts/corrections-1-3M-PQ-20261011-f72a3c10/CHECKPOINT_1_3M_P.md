# CHECKPOINT MOVI-K — 1.3M-P — R-K-04

Date : 11 octobre 2026, America/Toronto.

Défaut reproduit dans le vrai LiveTrackingMap : centre Montréal constant lorsque les flux ne fournissent aucun point ni adresse. 4 tests réussis/11 échoués initialement, puis 15 ciblés réussis. Correction limitée : pas de carte sans repère exploitable ; priorité position fraîche/adresses/dernière position compatible/historique valide. Les coordonnées finies dans les bornes géographiques sont conservées, y compris 0/0 explicitement fourni. Aucun nouveau centre Granby, pas de géocodage, pas de marqueur ancien actif.

Le modèle MissionAddress existant convertit des coordonnées JSON absentes en 0 ; leur provenance ne peut pas être reconstruite par la carte. Le correctif n'invente pas une politique de rejet de 0/0 et ne modifie pas le contrat de désérialisation. Les cas sans adresse, adresses hors bornes/non finies et données GPS incompatibles sont validés.

Les tests reproduisent l'absence de FlutterMap/TileLayer et l'absence de requêtes de tuiles quand aucun repère n'existe ; FR/EN/ES sur widget 375×812. Pas de capture Chrome ni de validation terrain. Une ancienne position compatible et un historique restent affichables comme données connues, sans devenir une position active.

Non-régression : 132 tests identité/fraîcheur/erreurs/suivi client ; 6 tests du vrai écran chauffeur avec Geolocator et repositories fictifs. Deux assertions historiques supposant une couche de marqueurs vide ont été renforcées en absence totale de FlutterMap dans ce nouvel état. Les autres assertions sont conservées. Le test chauffeur est exécuté depuis une copie temporaire sous offlineWidgetTest ; original inchangé.

Isolation : gps_offline_transport.dart, MemoryOnlyClient, no_default_http_client=true, HttpClient refusé, backend non configuré, aucune initialisation Firebase. Les tuiles sont des PNG mémoire ; aucun service réel, GPS physique, paiement ou notification. 1.3L reste BLOQUÉ ET REPORTÉ.

Commandes exactes : run-P-before.ps1, run-P-after.ps1, run-P-regression.ps1, run-P-driver.ps1. Flutter --no-version-check test --no-pub --dart-define=no_default_http_client=true --reporter=json --concurrency=1 ; analytics désactivées. Analyse sur les quatre Dart modifiés, format et git diff --check.

Critères de fermeture satisfaits pour le rendu widget simulé ; absence de carte arbitraire prouvée par l'arbre rendu et les tests. Aucun assouplissement GPS/Firestore, aucun changement serveur ou financier. Prochaine étape autorisée : P2-FORM-001.

## Résultats et Git

Base : 2e8424420bfbc8479a41e80a96c4e51238e0db80 ; branche fix/gps-client-history-scope-20261009.

- P-before : 4 réussis, 11 échoués, 0 ignorés.
- P-after : 15 réussis, 0 échoués, 0 ignorés.
- P-regression : 132 réussis, 0 échoués, 0 ignorés.
- P-driver : 6 réussis, 0 échoués, 0 ignorés.

Résultat final distinct : 153 réussis, 0 échec, 0 ignoré. Analyse ciblée, format et git diff --check : 0. Registre : P0 0, P1 2, P2 14 ouverts, 27 fiches. Fermeture limitée R-K-04 autorisée et appliquée. Aucun autre problème fermé.

Sélection exacte du commit local :

- `lib/widgets/live_tracking_map.dart`
- `test/customer/live_tracking_center_test.dart`
- `test/customer/live_tracking_identity_test.dart`
- `test/customer/customer_tracking_presentation_test.dart`
- `docs/audit/REGISTRE_BOGUES_MOVIK.md`
- `artifacts/corrections-1-3M-PQ-20261011-f72a3c10/CHECKPOINT_1_3M_P.md`
- `artifacts/corrections-1-3M-PQ-20261011-f72a3c10/VALIDATION_1_3M_P.json`

Journaux complets conservés dans le même dossier et exclus du commit, ainsi que copies temporaires, caches, builds et scripts de diagnostic. Empreintes et résultats dans VALIDATION_1_3M_P.json. Aucun changement financier ou serveur.
