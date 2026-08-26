# Movi-K — Justification des index Firestore (Étape 10)

Chaque index de `firestore.indexes.json` correspond à une requête réelle
identifiée dans l'architecture (étape 8) ou les Cloud Functions (étape 11).
Aucun index n'est créé « par précaution » — les requêtes simples sur un seul
champ (`where('driver_id', isEqualTo: ...)`) n'ont pas besoin d'index composite
et ne figurent pas ici (index automatique Firestore).

| # | Collection | Champs (ordre) | Requête utilisatrice | Contexte |
|---|---|---|---|---|
| 1 | `driver_profiles` | `status`, `online_status`, `documents_all_valid`, `current_geohash` | **Dispatch** : trouver les chauffeurs `approved` + `online` + documents valides, triés/filtrés par geohash de zone, puis filtrés en mémoire par `accepted_vehicle_categories array-contains`. | `createDeliveryRequest()` / logique de dispatch (Cloud Function `dispatchMissionToDrivers`) |
| 2 | `driver_documents` | `driver_id`, `status` | Portail analyste : « documents en attente de ce chauffeur » ; écran chauffeur : « quels documents me manquent ». | `DriverRepository.getDriverDocuments()`, portail analyste |
| 3 | `driver_documents` | `status`, `expires_at` | Job planifié de **détection des documents expirants** (ex: permis qui expire dans 30 jours) → notification chauffeur + passage à `expired`. | Cloud Function planifiée `detectExpiringDocuments` (cron quotidien) |
| 4 | `delivery_requests` | `customer_id`, `created_at` desc | **Historique client** : liste des missions d'un client, plus récentes en premier. | `MissionRepository.watchCustomerMissions()` |
| 5 | `delivery_requests` | `driver_id`, `status`, `created_at` desc | **Historique chauffeur** filtré par statut (ex: missions actives vs. complétées). | Écran "Mes missions" chauffeur |
| 6 | `delivery_requests` | `status`, `required_vehicle_category`, `dispatch_zone_geohash` | **Dispatch** : missions `searching_driver`/`offered` d'une catégorie de véhicule donnée, dans une zone donnée — évite un scan de toutes les missions. | Cloud Function de dispatch, écran chauffeur "missions disponibles" |
| 7 | `delivery_requests` | `status`, `created_at` desc | **Dashboard admin** : missions par statut (ex: toutes les `disputed`), triées par date. | Portail analyste/admin, dashboard économique |
| 8 | `delivery_offers` | `driver_id`, `status`, `expires_at` | **Offres actives d'un chauffeur** : celles encore `pending` et non expirées, pour l'écran de notification chauffeur. | `MissionRepository.watchOffersForDriver()` |
| 9 | `driver_promotions` | `driver_id`, `is_active`, `ends_at` | Résolution de la promotion active d'un chauffeur donné (CommissionResolver, côté serveur). | `calculateDriverPayout()`, `createFinancialSnapshot()` |
| 10 | `driver_promotions` | `is_active`, `ends_at` | Job planifié de **détection des promotions expirées** → passage automatique à `is_active=false`. | Cloud Function planifiée `expireDriverPromotions` |
| 11 | `qualifications` (collection group, sous `founding_driver_programs/*/qualifications`) | `status`, `promotional_period_ends_at` | Détection des chauffeurs Founding Driver dont la **période promotionnelle vient de se terminer** (transition promo → taux préférentiel), tous programmes confondus. | Cloud Function planifiée `transitionFoundingDriverPeriods` |
| 12 | `financial_snapshots` | `driver_id`, `created_at` desc | **Historique de gains** d'un chauffeur (écran "Mes revenus"). | `FinanceRepository` (lecture chauffeur) |
| 13 | `financial_snapshots` | `status`, `created_at` desc | **Dashboard financier admin** : snapshots confirmés récents, calcul de marge de contribution agrégée. | Portail admin, dashboard économique |
| 14 | `transaction_ledger` | `mission_id`, `created_at` desc | Détail comptable complet d'une mission (toutes les entrées liées), affiché en support client/litige. | `FinanceRepository.watchLedgerEntriesForMission()` |
| 15 | `transaction_ledger` | `status`, `type`, `created_at` desc | **Dashboard financier** : agrégation par type d'entrée (commission, tips, refunds) sur une période. | Portail admin, reporting |
| 16 | `driver_payouts` | `driver_id`, `created_at` desc | Historique des versements d'un chauffeur. | Écran chauffeur "Mes paiements" |
| 17 | `ratings` | `rated_user_id`, `created_at` desc | Notes reçues par un chauffeur/client, triées récentes en premier (affichage profil). | Écran profil public chauffeur |
| 18 | `admin_reviews` | `status`, `created_at` desc | File d'attente analyste : dossiers `open`/`in_review` les plus anciens en premier (ou récents, selon tri UI). | Portail analyste |
| 19 | `audit_logs` | `action`, `created_at` desc | Recherche d'audit par type d'action (ex: tous les `approveDriver` récents) pour investigation admin. | Portail admin (recherche d'audit) |
| 20 | `history` (collection group, sous `driver_locations/*/history`) | `recorded_at` asc | Job planifié de **purge GPS** : trouve tous les points historiques antérieurs à la fenêtre de rétention (30 jours), tous chauffeurs confondus, en une seule requête. | Cloud Function planifiée `cleanupExpiredTrackingHistory` |

> **Correctif Bloc N (Phase 7)** : cet index #20 était documenté ici depuis l'étape 10
> mais **absent** du fichier `firestore.indexes.json` réellement déployé (confirmé par
> énumération programmatique — seulement 20 entrées existaient, la dernière étant
> `audit_logs`, aucune `history`). `cleanupExpiredTrackingHistory` (cron quotidien
> 02:00 America/Toronto) aurait échoué avec `FAILED_PRECONDITION` en production dès
> sa première exécution contre un vrai Firestore. **Corrigé** : l'entrée a été ajoutée
> à `firestore.indexes.json` (validée comme JSON syntaxiquement correct) — la
> documentation et le fichier réel sont maintenant synchronisés.

## Requêtes volontairement NON indexées (évitées par design)

- **Aucune requête `orderBy` combinée à un `where` sur un champ non indexé
  ci-dessus** n'est utilisée dans l'architecture — conformément à la règle
  « éviter les erreurs d'index manquant / éviter la sur-normalisation ».
- Le filtre `accepted_vehicle_categories array-contains <catégorie>` dans le
  dispatch (index #1) ne peut pas être combiné à d'autres `where` d'égalité
  au-delà d'un array-contains + un range Firestore standard — il est donc
  appliqué **en mémoire côté Cloud Function** après la requête indexée
  (le lot de chauffeurs déjà filtrés par statut/zone reste petit, de l'ordre
  de quelques dizaines à quelques centaines de documents, jamais un scan de
  toute la table).
- Les collections `notifications`, `admin_reviews` (lecture simple par
  utilisateur) n'ont pas besoin d'index composite au-delà de ceux listés.

## Note Bloc N — index #4 potentiellement sur-provisionné (P3, documenté)

L'implémentation actuelle de `MissionRepository.watchCustomerMissions()`
(`lib/backend/repositories/firebase_mission_repository.dart`) utilise
volontairement une requête **simple** (`where('customer_id', isEqualTo: ...)`
seul, tri par date fait **en mémoire** côté client) — voir le commentaire du
fichier, qui référence explicitement cette convention (cohérence avec
`FirebaseDriverRepository.watchDriversByStatus()`). Aucun `.orderBy()` n'est
donc réellement exécuté contre Firestore pour cette requête, et confirmé par
grep qu'aucune Cloud Function ne combine `customer_id` + `orderBy` non plus.
L'index #4 (`delivery_requests(customer_id, created_at desc)`) n'est donc
actuellement consommé par **aucune requête réelle** — il reste inoffensif
(un index composite non utilisé ne casse rien, coûte seulement un peu
d'espace de stockage/écriture) mais la ligne #4 ci-dessus est à lire comme
« conçu pour, mais pas actuellement utilisé par l'implémentation présente ».
Conservé tel quel (P3, non-bloquant) : le supprimer référencerait un futur
retour à un tri serveur sans bénéfice MVP démontré ; le garder ne coûte rien
d'important. À réévaluer si `watchCustomerMissions()` passe un jour à un
`.orderBy()` serveur (ex: pagination volumineuse).
