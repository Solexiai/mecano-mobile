# Isolation — 1.3M-S
Date : 11 octobre 2026. HEAD de départ : da3f1d459c3205e55aec3f1d972aab45b4fa7423.

Les tests utilisent le vrai DeliveryRequestFlowScreen et les formatteurs de présentation.
BookingTestAuth (backendConfigured=false), MemoryBookingStorage et TestBookingApi remplacent l'authentification, le stockage et tous les appels métier. QuoteApi restreint explicitement la liste des opérations fictives. Aucune app Firebase n'est initialisée. Coordonnées et identifiants sont ceux des fixtures existantes, fictifs.

Les nouveaux widgets utilisent offlineWidgetTest/withOfflineTransport : HttpOverrides refuse la création de HttpClient et le client package:http mémoire ne délègue à aucun socket. Le flag no_default_http_client=true désactive le transport par défaut. Les assertions exigent zéro tentative inattendue, zéro demande de tuile et Firebase.apps vide. Aucun widget carte n'est créé. Les fixtures ne contiennent aucune photo à charger depuis Storage.

Les sept suites de non-régression ont été examinées : API de réservation fictive, Auth fictive, stockage de test ; l'autocomplétion injecte FakeAddressAutocompleteProvider. Les dimensions utilisent le transport mémoire existant. Les tests de confirmation renvoient ready=true dans la doublure et ne lancent pas d'URL Stripe. Aucun lien externe n'est cliqué ; aucun appel à un provider de paiement.

Cela prouve l'isolation des dépendances et chemins exercés, pas un confinement réseau du système d'exploitation. Le test autonome des tuiles 1.3L reste BLOQUÉ ET REPORTÉ. Aucun émulateur, navigateur, GPS physique, Stripe Sandbox/LIVE, API Google ou Firebase Production n'a été lancé pour cette étape.

Dépendance intl 0.20.3 déjà présente localement : flutter pub get --offline --no-example. Le lock ne change que transitive → direct main, sans version ni empreinte modifiée. Le libellé générique « Downloading packages... » du journal Pub apparaît aussi en mode offline ; aucune commande de téléchargement en ligne n'a été exécutée.
