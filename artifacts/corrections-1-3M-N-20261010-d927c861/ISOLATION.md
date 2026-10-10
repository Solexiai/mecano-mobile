# Isolation — 1.3M-N

Tests locaux Flutter widget uniquement. Aucun émulateur démarré.

- `DeliveryRequestFlowScreen` réel, `ConfirmationApi extends TestBookingApi`, liste fermée des opérations fictives. Les appels `startBookingCardSetup` sont interceptés : réponse mémoire `ready` ou exception contrôlée, jamais URL Stripe ouverte.
- `MemoryBookingStorage`, `BookingTestAuth(backendConfigured: false)` et faux utilisateur ; `Firebase.apps` doit rester vide. Aucun `Firebase.initializeApp` exécuté par le harnais.
- Aucun clic sur les liens externes conditions/confidentialité, aucun upload/photo, aucune recherche d’adresse, aucune carte ou géolocalisation. Reprise d’adresses fictives déjà structurées.
- `--no-pub`, `--no-version-check`, CI, suppression analytics. `--dart-define=no_default_http_client=true` interdit le client HTTP par défaut de package:http ; contrôle exécuté. Flutter TestWidgetsBinding neutralise le transport HTTP dart:io des widgets ; un contrôle HttpOverrides complète cette restriction. Les appels natifs métier sont évités par injections et inspection des chemins exécutés.
- Aucun confinement réseau global/processus Windows n’est revendiqué. Ces preuves portent sur les dépendances et chemins des tests ciblés. Le test autonome cartographique 1.3L reste BLOQUÉ ET REPORTÉ.
- Les tests ne prouvent aucune carte réellement enregistrée, autorisation, capture, calcul serveur officiel ou mission réelle. Le montant 123.45 est une fixture, sans transaction.
