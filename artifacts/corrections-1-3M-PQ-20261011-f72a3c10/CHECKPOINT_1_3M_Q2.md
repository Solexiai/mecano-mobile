# CHECKPOINT MOVI-K — 1.3M-Q2 — P2-FORM-002

11 octobre 2026. Reproduction sur le vrai DeliveryRequestFlowScreen : le RenderParagraph du label Unité de poids dépassait sa limite de lignes dans les 12 combinaisons FR/EN/ES × 375×812, 430×932, 1440×900 et mobile 200 %. Avant : 1 réussite (sélection) et 12 échecs de lisibilité. Après : 13 réussites.

Correction minimale : label Text avec retour à la ligne, au-dessus du Dropdown existant ; largeur, valeurs kg/lb et calculs inchangés. Tests vérifient limites visuelles et conversion conservant dimensions/libellé.

Non-régression : six tests existants (delivery_request_draft_resume_test et booking_service_availability_test), assertions inchangées, exécutés depuis des copies temporaires enveloppées par offlineTests/offlineWidgetTest. Restauration coordonnées/adresses/dimensions, invalidation du devis, séparation comptes, expiration et reprise d’indisponibilité couvertes.

Isolation : TestBookingApi, MemoryBookingStorage ou stockage session stub, BookingTestAuth sans backend ; transport mémoire et HttpOverrides refusant réseau avec no_default_http_client=true. Aucune carte ni service réel. Aucun appel de paiement, mission réelle ou modification serveur/financière. Limite : rendu widget, pas Chrome ni appareil physique. Test autonome 1.3L reste bloqué/reporté.

Commandes réellement exécutées : scripts run-Q2-after.ps1 et run-Q2-regression.ps1 ; flutter --no-version-check test --no-pub --dart-define=no_default_http_client=true --reporter=json --concurrency=1 sur la suite ciblée puis deux copies ; flutter analyze --no-pub sur flow et nouveau test ; dart format --output=none --set-exit-if-changed sur ces deux fichiers ; git diff --check. Logs avant/après et hashes conservés.

Aucun autre worktree modifié. Prochaine anomalie : P2-FORM-003, reprise du texte d’adresse non résolu.

## Résultats et Git

Base : f3af606d1af05def76f1f3bedb8bf51495ff9527 ; branche fix/gps-client-history-scope-20261009.

- Q2-before : 1 réussis, 12 échoués, 0 ignorés.
- Q2-after : 13 réussis, 0 échoués, 0 ignorés.
- Q2-regression : 6 réussis, 0 échoués, 0 ignorés.

Résultat final distinct : 19 réussis, 0 échec, 0 ignoré. Analyse ciblée, format et git diff --check : 0. Registre : P0 0, P1 2, P2 12 ouverts, 27 fiches. Fermeture limitée P2-FORM-002 autorisée et appliquée. Aucun autre problème fermé.

Sélection exacte du commit local :

- `lib/screens/delivery/delivery_request_flow_screen.dart`
- `test/customer/delivery_weight_unit_layout_test.dart`
- `docs/audit/REGISTRE_BOGUES_MOVIK.md`
- `artifacts/corrections-1-3M-PQ-20261011-f72a3c10/CHECKPOINT_1_3M_Q2.md`
- `artifacts/corrections-1-3M-PQ-20261011-f72a3c10/VALIDATION_1_3M_Q2.json`

Journaux complets conservés dans le même dossier et exclus du commit, ainsi que copies temporaires, caches, builds et scripts de diagnostic. Empreintes et résultats dans VALIDATION_1_3M_Q2.json. Aucun changement financier ou serveur.
