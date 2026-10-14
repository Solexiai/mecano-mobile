# Prévalidation d'isolation — 1.3M-C — 9 octobre 2026

Périmètre : tests de contrat Flutter/Dart locaux. Aucun test autonome de transport 1.3L, aucune capture Chrome, aucun confinement OS revendiqué.

## Chaîne inspectée avant montage de la carte

- LiveTrackingMap utilise TileLayer sans fournisseur personnalisé (lib/widgets/live_tracking_map.dart:126–131).
- flutter_map 7.0.2 : TileLayer construit NetworkTileProvider (tile_layer.dart:258).
- NetworkTileProvider utilise RetryClient(Client()) (network_tile_provider.dart:39).
- MapNetworkImageProvider ne lit les images que via le client fourni, readBytes (network_image_provider.dart:91–96).
- http 1.5.0 : Client() choisit zoneClient avant createClient (client.dart:39).
- io_client.dart:14–20 : no_default_http_client=true fait échouer createClient avant toute construction IOClient.
- offline_transport.dart fournit un BaseClient en mémoire, sans socket, DNS, délégation ni client réseau. Les seules URL acceptées sont les clés synthétiques de tuiles attendues. Il retourne le PNG transparent embarqué de TileProvider, pas une tuile obtenue par Internet.
- Tout autre URL/méthode est refusé et fait échouer la suite. HttpOverrides refuse aussi la création de dart:io HttpClient. Le test préalable vérifie le choix du transport et les refus (résultat à consulter dans isolation-test.jsonl).

Les sources locales des dépendances et leurs SHA256 sont conservés dans transport-sources.json. Ce n'est donc pas une conclusion tirée de zéro requête observée. Les chemins de chargement du composant et leur remplacement ont été examinés.

## Autres services

- FirebaseLocationRepository réel reçoit explicitement deux objets Fake (Firestore et Functions). Le spy contrôle l'ordre des appels et refuse toute opération non prévue. Aucun Firebase.initializeApp, aucune requête native ou émulateur.
- Cartes/écrans : BackendLocator utilise les overrides avant ses constructeurs Firebase ; statut initial notConfigured. Les tests ciblés vérifient ce statut. MissionRepository/LocationRepository sont fictifs, auth backendConfigured=false.
- Écran chauffeur : GeolocatorPlatform est remplacé par FakeGeolocatorPlatform déjà présent. Aucune localisation physique ; les rapports vont au faux repository.
- Les suites existantes conservées importent les mêmes fakes. Les tests de statut cliquent uniquement sur les actions de transition simulées, jamais sur Google Maps, caméra ni téléversement.
- Aucun main de l'application, bootstrap Firebase, carte Web/Chrome, notification, paiement, Secret Manager ou fonction serveur.
- Flutter est exécuté avec --no-pub et --no-version-check ; dépendances déjà présentes, variables de suppression d'analytique limitées au processus. Aucun outil installé ou émulateur démarré.

## Limites

Les interdictions sont démontrées pour les chemins actifs des tests examinés, pas pour un processus arbitraire utilisant des sockets brutes, un sous-processus malveillant ou un navigateur. Le transport fictif ne constitue pas une carte réelle et aucun aspect visuel de tuiles n'est validé. Le vrai LiveTrackingMap et les vrais écrans sont montés ; aucune copie de leur logique ne remplace le produit. La preuve recherchée porte sur les arguments, les abonnements, le filtrage, le tri et la non-régression des consommateurs.

1.3L reste BLOQUÉ ET REPORTÉ faute de confinement complet du processus exigé à cette étape. GPS terrain, réseau réel, production et rendu Chrome restent NON TESTÉS.

## Correction du harnais préalable (aucun changement produit)

Le premier contrôle a échoué avant montage de carte : la zone installée pendant l'enregistrement des tests n'est pas héritée lors de leur exécution (StateError no_default_http_client). Le garde-fou a fonctionné : aucune connexion et aucune image demandée. Résultat conservé dans isolation-test.jsonl : 0 réussi, 1 erreur, 0 ignoré.

La version suivante place withOfflineTransport autour du corps de chaque test, y compris les callbacks widget. Les copies temporaires des quatre suites existantes ne changent que les imports, le nom de main et l'enveloppe testWidgets. L'inversion de ces transformations reconstruit exactement les originaux (quatre bodiesUnchanged=true, SHA256 conservés). Aucune assertion retirée, aucun composant produit remplacé. Les wrappers existing_* initiaux ne sont pas exécutés.

L'analyse du nouveau harnais retourne 14 avertissements et aucun diagnostic error : 5 annotations sealed des objets SDK simulés, 9 visibleForTesting dus au dossier artifacts hors test/ racine. Ils restent visibles, non supprimés. Ce résultat n'est pas présenté comme une analyse sans avertissement ; l'analyse du produit est distincte.

Résultats définitifs : précontrôle v3 1/1, contrat 7/7, consommateurs 20/20, zéro ignoré dans ces exécutions. La version v2 avait une erreur de compilation du nouveau callback Future<void> (pas de test exécuté), corrigée uniquement en rendant le callback de la sonde async. Les deux essais infructueux restent conservés. La carte a réellement utilisé le transport mémoire : 120 chargements locaux dans les tests de contrat, puis 24/24/24/0 dans les quatre suites consommateurs ; zéro demande inattendue. Il ne s'agit pas de requêtes Internet. Le test préalable démontre le refus de createClient et de HttpClient, et le choix de MemoryOnlyClient. Aucune exception des composants ou teardown n'est restée dans les exécutions finales.
