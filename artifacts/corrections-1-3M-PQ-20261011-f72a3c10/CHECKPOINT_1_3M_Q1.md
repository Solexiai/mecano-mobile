# CHECKPOINT MOVI-K — 1.3M-Q — P2-FORM-001

11 octobre 2026, America/Toronto.

Reproduction : français/espagnol héritaient des MaterialLocalizations anglaises de l'application. Six cas échoués (sélecteur date, sélecteur heure, résumé pour FR/ES) et trois cas EN réussis. Correction locale au formulaire : Localizations.override avec la langue de la route et les delegates déjà présents dans flutter_localizations. Aucun changement global de main.dart ni dépendance ajoutée. Le résumé réutilise _localizedTime validé en N ; son préfixe devient facultatif. Les appels de confirmation avec préfixe restent identiques.

Neuf tests ciblés finaux réussis : dialogues FR/EN/ES, boutons localisés, annulation sans changer requested_at, résumé et absence de création de mission. 26 tests de confirmation sélectionnés (dates/fuseau Québec, dates absentes, navigation/reconstruction, payload et double callback) réussis. La sélection est explicite dans run-Q1-regression.ps1 ; les autres tests de confirmation ne sont pas présentés comme exécutés.

Commandes : run-Q1-before.ps1, run-Q1-after.ps1, run-Q1-regression.ps1. flutter test --no-pub --no-version-check --dart-define=no_default_http_client=true, reporter JSON. Analyze et format ciblés : 0. Les tests utilisent les vrais widgets avec TestBookingApi/MemoryBookingStorage/BookingTestAuth ; aucune adresse saisie ni recherche fournisseur effectuée. Transport HTTP par défaut désactivé ; pas de Firebase/Stripe/Google/OSM.

Validation limitée au rendu widget simulé (dialogues à 430×932) ; Chrome et téléphone physique non testés. Les dates financières, montants, devis et le contrat serveur ne changent pas. Historique conservé ; fermeture autorisée pour le périmètre simulé. Prochaine anomalie : P2-FORM-002.

## Résultats et Git

Base : 5e9c60c59a31ac72b5cb196715643922afd9bc8c ; branche fix/gps-client-history-scope-20261009.

- Q1-before : 3 réussis, 6 échoués, 0 ignorés.
- Q1-after : 9 réussis, 0 échoués, 0 ignorés.
- Q1-regression : 26 réussis, 0 échoués, 0 ignorés.

Résultat final distinct : 35 réussis, 0 échec, 0 ignoré. Analyse ciblée, format et git diff --check : 0. Registre : P0 0, P1 2, P2 13 ouverts, 27 fiches. Fermeture limitée P2-FORM-001 autorisée et appliquée. Aucun autre problème fermé.

Sélection exacte du commit local :

- `lib/screens/delivery/delivery_request_flow_screen.dart`
- `test/customer/delivery_date_localization_test.dart`
- `docs/audit/REGISTRE_BOGUES_MOVIK.md`
- `artifacts/corrections-1-3M-PQ-20261011-f72a3c10/CHECKPOINT_1_3M_Q1.md`
- `artifacts/corrections-1-3M-PQ-20261011-f72a3c10/VALIDATION_1_3M_Q1.json`

Journaux complets conservés dans le même dossier et exclus du commit, ainsi que copies temporaires, caches, builds et scripts de diagnostic. Empreintes et résultats dans VALIDATION_1_3M_Q1.json. Aucun changement financier ou serveur.
