# CHECKPOINT MOVI-K — 1.3M-Q3 — P2-FORM-003

11 octobre 2026. Cause reproduite : _invalidateAddress ne sauvegardait que l’invalidation d’une ancienne adresse résolue ; _restore ne relisait que formatted_address. Aucun texte inachevé n’était conservé. Avant : 2 tests réussis, 10 échoués (valeur null au lieu de la saisie, perte lors de reconstruction et absence dans la sauvegarde simulée).

Correction limitée au vrai formulaire : _addressText privilégie l’adresse résolue puis le texte brut ; chaque modification de texte est sauvegardée immédiatement via le brouillon existant, avec invalidation existante de l’adresse et du devis. Les champs pickup_text/dropoff_text sont des données de brouillon, jamais des stops ni des coordonnées. Aucun nouveau géocodage automatique au rétablissement. Aucune politique de validation d’adresse modifiée.

Contrat serveur inspecté, non modifié : functions/src/functions/bookingJourney.ts saveBookingDraft accepte déjà l’objet de brouillon, borné à 50 000 caractères, avec ownerUid/revision ; les métadonnées de saisie empruntent ce même contrat. BookingDraft.load et stops restent inchangés ; _confirm recrée un petit brouillon reçu et efface ainsi les données personnelles, y compris ces champs. Pas de nouvelle collection ni règle.

Après : 12 tests ciblés FR/EN/ES, pickup/dropoff, reconstruction immédiate avant debounce, texte vidé, invalidation du devis, priorité de l’adresse résolue historique, vraie sélection via fournisseur fictif, sauvegarde simulée et séparation/handoff des comptes. 17 non-régressions : 11 tests delivery_address_autocomplete_test et 6 tests reprise/disponibilité existants, exécutés dans des copies enveloppées pour refus réseau, assertions inchangées.

Isolation : BookingTestAuth, TestBookingApi, MemoryBookingStorage et stub de session ; FakeAddressAutocompleteProvider via override, restauré en teardown ; HttpOverrides et no_default_http_client=true, transport mémoire. Aucun appel Google Places/Routes, Firebase, Stripe ou carte réelle. Données intégralement fictives.

Commandes : run-Q3-before.ps1, run-Q3-after.ps1, run-Q3-regression.ps1 ; flutter test --no-pub --dart-define=no_default_http_client=true --reporter=json --concurrency=1 ; analyse ciblée flow/nouveau test, Dart format, git diff --check. Échecs initiaux conservés dans Q3-before.jsonl/summary. Empreintes après validation archivées.

Limites : reconstruction du widget et sérialisation du brouillon simulées, pas rafraîchissement Chrome réel ni synchronisation Firebase réelle. 1.3L reste bloqué/reporté. Aucun fichier serveur/financier/GPS modifié. Prochaine anomalie : P2-FORM-004, présentation des conversions.

## Résultats et Git

Base : afb803c35ee20106441908f06a15f53bbb2c33a6 ; branche fix/gps-client-history-scope-20261009.

- Q3-before : 2 réussis, 10 échoués, 0 ignorés.
- Q3-after : 12 réussis, 0 échoués, 0 ignorés.
- Q3-regression : 17 réussis, 0 échoués, 0 ignorés.

Résultat final distinct : 29 réussis, 0 échec, 0 ignoré. Analyse ciblée, format et git diff --check : 0. Registre : P0 0, P1 2, P2 11 ouverts, 27 fiches. Fermeture limitée P2-FORM-003 autorisée et appliquée. Aucun autre problème fermé.

Sélection exacte du commit local :

- `lib/screens/delivery/delivery_request_flow_screen.dart`
- `test/customer/delivery_address_draft_text_test.dart`
- `docs/audit/REGISTRE_BOGUES_MOVIK.md`
- `artifacts/corrections-1-3M-PQ-20261011-f72a3c10/CHECKPOINT_1_3M_Q3.md`
- `artifacts/corrections-1-3M-PQ-20261011-f72a3c10/VALIDATION_1_3M_Q3.json`

Journaux complets conservés dans le même dossier et exclus du commit, ainsi que copies temporaires, caches, builds et scripts de diagnostic. Empreintes et résultats dans VALIDATION_1_3M_Q3.json. Aucun changement financier ou serveur.
