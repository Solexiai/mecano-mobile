# CHECKPOINT MOVI-K — RÉSERVATION IMMÉDIATE / PROGRAMMÉE

Date : 14 octobre 2026, America/Toronto.
Worktree : C:\Users\Utilisateur\movik-gps-history-fix-20261009
Branche : fix/booking-timing-20261014
HEAD de départ : 0780c0efa75023dc1f012eed319bedc31b2ccbe5.
La branche de correction GPS existante et les autres worktrees sont préservés.

## Résultat

Le choix « Dès maintenant / Programmée » est implémenté et validé localement. La chaîne devis → demande → offre chauffeur → notification interne fonctionne avec les vrais handlers et des dépendances fictives dans Firestore Emulator.

**La réservation réelle sur movi-k.com reste bloquée par des prérequis de configuration. Aucun changement de production n'a été effectué dans cette intervention.**

Les captures utilisateur montrent le message « La réservation est indisponible » à l'étape Mon prix ; elles ne prouvent pas l'enregistrement d'une mission. L'absence de réception par un chauffeur dans cet essai ne démontre donc pas un défaut du déclencheur d'assignation.

## État constaté en production, lecture seule

Preuve datée du 14 octobre 2026 à 18:32:42Z, projet movik-connect-prod :

- accept_new_delivery_requests : false.
- allow_driver_acceptance : false.
- payments_enabled : false.
- driver_payouts_enabled : false.
- Documents system_config/booking_policy, booking_capacity et service_zones absents.

À 18:53:48Z : huit documents driver_vehicles examinés ; aucun is_verified=true, aucune verified_capacity, aucune capacité non expirée. La preuve conservée contient uniquement les nombres, sans coordonnées personnelles.

Sources : PRODUCTION_CONFIGURATION_READONLY.json, VEHICLE_READINESS.json ; contrats dans functions/src/lib/bookingServer.ts. Le modèle approuvé ne peut être remplacé par les valeurs fictives des tests.

## Correction

1. Choix explicite immédiat/programmé en FR/EN/ES.
2. Mode immédiat : aucune date artificiellement créée ; date programmée retirée.
3. Mode programmé : date/heure réelle exigée, souhait soumis à l'acceptation du chauffeur.
4. Changement de mode : devis et consentement invalidés par le mécanisme existant ; objets et coordonnées conservés.
5. Brouillon et reconstruction du widget conservent le choix.
6. Résumés client/chauffeur indiquent honnêtement « selon la disponibilité du chauffeur ».
7. Contrat serveur normalise le mode, rejette les valeurs inconnues et les combinaisons contradictoires. Les anciens payloads sans timing_mode restent inchangés.
8. Les contrôles de politique, de zone, de capacité et de paiement ne sont pas contournés.

Le dispatch existant commence lors de la création d'une mission éligible. Le choix programmé exprime une date souhaitée : aucun nouveau moteur de réservation différée, aucune garantie de créneau ni d'arrivée immédiate n'a été ajouté.

## Tests exécutés

| Exécution | Réussis | Échoués | Ignorés | Portée |
| --- | ---: | ---: | ---: | --- |
| Reproduction Flutter avant correction | 1 | 17 | 0 | Vrai formulaire et brouillon |
| Reproduction unité serveur avant correction | 4 | 7 | 0 | Contrat de mode / date |
| Flutter ciblé après correction | 18 | 0 | 0 | Choix, reprise, invalidation, garde indisponible |
| Flutter parcours et non-régressions combinés | 200 | 0 | 0 | Inclut les 18 ciblés |
| Vérification finale des 18 après alignement des sous-titres EN/ES | 18 | 0 | 0 | Répétition, non additionnée |
| Unité serveur, nouveau contrat + suite booking existante | 34 | 0 | 0 | 11 nouveaux + 23 existants |
| Intégration finale, quatre suites | 23 | 0 | 0 | Devis, création, dispatch, absence de chauffeur |

**257 tests distincts réussis dans les exécutions finales pertinentes.** Les répétitions ne sont pas additionnées. RESULTATS.json conserve les noms et résultats.

Les tests Flutter couvrent FR/EN/ES, 375×812, 430×932, 1440×900 et mobile avec texte à 200 %. Ce sont des tests de vrais widgets, pas des captures Chrome ou des essais de téléphone physique. Aucun nouveau screenshot n'est revendiqué.

Suites d'intégration :
- functions/test/integration/bookingTimingDispatch.test.ts : 4.
- functions/test/integration/bookingJourney.test.ts : 8.
- functions/test/integration/calculateDeliveryQuote.test.ts : 9.
- functions/test/integration/dispatchNoDriverAvailable.test.ts : 2.

Le nouveau test intégré vérifie pour les deux modes la création réelle en émulateur d'une offre unique et d'une notification interne, la bonne mission/chauffeur, l'idempotence de la confirmation, et le refus de réutiliser un devis après changement de mode.

## Échecs de préparation conservés

1. Premier démarrage : « Expected single_project_mode to be set for single_project_mode_error ». Aucun test exécuté.
2. Deuxième tentative : chemin de credentials volontairement absent ; quatre suites ne s'initialisent pas, aucun scénario exécuté.
3. Troisième tentative : 23 échecs lors des écritures de fixtures ; Firestore Emulator Java échoue avec MissingResourceException, bundle JValidationMessages_messages, locale fr_CA. Quatre tentatives de détection du serveur de métadonnées sont refusées par le garde réseau avant toute transmission.
4. Tentative finale : paramètres Java en_US limités au processus, détection de métadonnées désactivée, projet demo-movik-test ; 23/23 réussis, aucune tentative bloquée enregistrée, émulateur dédié arrêté.

Aucun test n'a été supprimé, ignoré ou affaibli. Aucun paramètre Windows n'a été modifié. Les journaux des tentatives 1–3 sont conservés, pas réécrits en succès.

## Isolation

- Flutter : TestBookingApi, MemoryBookingStorage, BookingTestAuth, transport mémoire existant et no_default_http_client=true.
- Node 20.20.2 local ; Firestore Emulator dédié à demo-movik-test sur 127.0.0.1:8080.
- Garde du processus Jest : sockets, TLS, DNS et fetch refusent les destinations autres que loopback:8080 ; création de processus enfants interdite.
- Profil cloud/APPDATA isolé, aucun credential de production utilisé par les tests.
- Routes : mock existant setupRouteMock.ts.
- Paiements : FakePaymentProvider.
- FCM : sendDeliveryOfferPush simulé explicitement.
- Aucun émulateur Functions, aucune notification réelle, aucune mission réelle et aucun paiement.

Ce garde logiciel ne constitue pas une preuve de confinement réseau du système d'exploitation. Le test autonome de tuiles 1.3L reste BLOQUÉ ET REPORTÉ.

## Commandes et qualité

Commandes Flutter réellement exécutées :
- flutter --no-version-check test --no-pub --dart-define=no_default_http_client=true --concurrency=1 --reporter=json (suites détaillées dans FLUTTER_COMMAND.json et RESULTATS.json).
- flutter --no-version-check analyze --no-pub lib/screens/delivery/delivery_request_flow_screen.dart lib/services/booking/booking_draft.dart lib/widgets/booking_load_summary.dart test/customer/delivery_timing_test.dart.
- dart format --output=none --set-exit-if-changed sur ces quatre fichiers.
- flutter --no-version-check build web --release --no-pub --dart-define=USE_FIREBASE_EMULATORS=true.

TypeScript : tsc --noEmit ; lint : eslint --ext .js,.ts src. Tous réussis. git diff --check réussi.

Jest, via Node20 local : --runInBand --runTestsByPath, quatre suites ci-dessus, avec --require artifacts/booking-timing-20261014/loopback-only.cjs et les variables d'émulateur fictif. Le runner et les journaux locaux documentent les arguments exacts. Ne pas lancer ces suites contre un projet réel.

Le build Web est compilé pour la recette avec USE_FIREBASE_EMULATORS=true. Il n'est pas un artefact de production à publier tel quel.

## Intégrité financière

Aucun moteur tarifaire, commission, taxe, paiement, règle Firestore, snapshot financier ou ledger n'a été modifié. Le seul changement serveur porte sur le mode/date de la demande.

En émulateur, le customer_total_minor du devis est égal à celui de la mission et de son pricing_snapshot. Le changement de choix immédiat/programmé seul ne change ni le total ni la ventilation du devis fictif.

Ces essais ne créent pas de paiement Stripe, ne valident pas un financial_snapshot de paiement ni la concordance Stripe LIVE. L'invariant devis officiel = mission = snapshot financier = montant Stripe en cents reste une obligation ; sa preuve en production n'est pas fournie par ces tests.

## Fichiers proposés pour la sauvegarde locale

Code :
- functions/src/lib/booking.ts
- lib/screens/delivery/delivery_request_flow_screen.dart
- lib/services/booking/booking_draft.dart
- lib/widgets/booking_load_summary.dart

Tests permanents :
- functions/test/unit/bookingTiming.test.ts
- functions/test/integration/bookingTimingDispatch.test.ts
- test/customer/delivery_timing_test.dart

Registre et preuves essentielles :
- docs/audit/REGISTRE_BOGUES_MOVIK.md
- artifacts/booking-timing-20261014/CHECKPOINT_RESERVATION.md
- artifacts/booking-timing-20261014/RESULTATS.json
- artifacts/booking-timing-20261014/INTEGRITE.json
- artifacts/booking-timing-20261014/PRODUCTION_CONFIGURATION_READONLY.json
- artifacts/booking-timing-20261014/VEHICLE_READINESS.json

Les caches, builds, journaux bruts, sauvegardes historiques, scripts temporaires et fichiers non suivis préexistants sont exclus du commit et conservés localement. INTEGRITE.json fixe les empreintes des sources testées.

## Registre et prochaine action

30 fiches : **P0 0 / P1 1 / P2 1 ouverts**. Les 28 dossiers historiques sont préservés.

- P1-BOOKING-CONFIG-01 : BLOQUÉ — configuration métier requise.
- P2-BOOKING-TIMING-01 : VALIDÉ LOCALEMENT — NON FERMÉ — NON DÉPLOYÉ.

Prochaine action unique : compléter les données approuvées de mise en service du pilote, à partir du premier véhicule/chauffeur réellement opérationnel.

Il faut ses capacités mesurées (volume utile, ouverture, charge, équipement/manutention), la zone précise, la politique applicable et les seuils existants approuvés de manutention. Ces seuils peuvent influer sur les frais : ils n'ont pas été inventés. Vérifier ensuite les prérequis du paiement et l'état en ligne du chauffeur avant activation contrôlée.

Un simple passage des drapeaux à true ne résout pas les configurations manquantes. Aucune garantie commerciale ni réservation réelle ne doit être annoncée à ce stade. Aucune fermeture globale du pilote.
