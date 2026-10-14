# Isolation — étape 1.3M-O — 11 octobre 2026

Le nom du dossier conserve le préfixe 20261010 demandé ; exécution effective le 11 octobre 2026 (America/Toronto).

- Vrais CustomerTrackingScreen, DeliveryRequestFlowScreen et LiveTrackingMap ; MissionStreams/gps.Locations/TestBookingApi/MemoryBookingStorage/BookingTestAuth injectés, aucun widget produit remplacé par une maquette.
- BackendBootstrap.isConfigured=false et Firebase.apps vide contrôlés. Aucun Firebase.initializeApp, émulateur, backend réel ou clé ajouté.
- gps_offline_transport.dart existant réutilisé : http.Client = MemoryOnlyClient, tuiles retournées depuis le PNG mémoire TileProvider.transparentImage. Les URI OSM ne servent que de clés de simulation ; aucun socket/DNS/IOClient n’est appelé par ce transport. Autres chemins refusés et comptabilisés ; assertions réseau conservées.
- --dart-define=no_default_http_client=true ; tentative de création HttpClient dart:io interdite dans la zone. Le binding Flutter remplace aussi son transport HTTP de test. Ces protections et l’inspection des chemins sont propres aux suites exécutées : aucun confinement réseau Windows global n’est revendiqué.
- Les suites historiques sont importées sans modification dans offline_regression_test.dart, sous le harnais mémoire. Auth et repositories fictifs ; vues financières sans backend configuré, notation via repository fictif. Aucun lien externe, image de preuve distante, carte réelle, adresse Google, GPS physique, notification, Stripe ou paiement.
- --no-pub et --no-version-check ; analytics désactivées et CI=true. Aucune installation.
- Le test autonome de tuiles 1.3L reste BLOQUÉ ET REPORTÉ. Ces tests widget ne constituent ni une validation de transport Internet, ni des captures Chrome, ni une validation de production.

Complément final : le premier wrapper n’a pas propagé http.runWithClient au corps des anciens testWidgets. Trois tests ont été refusés par no_default_http_client (16 réussis / 3 échoués), sans client réseau créé. Le lanceur final utilise deux copies temporaires (ownership/listener) remplaçant uniquement testWidgets par offlineWidgetTest et ajoutant son import. regression-adaptation.json prouve la conservation exacte du reste du texte et des assertions ; tests originaux inchangés. Les suites sont regroupées séparément pour isoler leurs hooks. Résultat final : 19 réussis, 0 échec, 0 ignoré. Aucun affaiblissement des gardes réseau.
