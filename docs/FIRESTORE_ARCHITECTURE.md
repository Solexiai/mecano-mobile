# Movi-K — Architecture Firestore (Étape 8)

Ce document décrit le schéma Firestore complet de Movi-K. Il sert de contrat
entre le frontend Flutter (`lib/backend/models/`, `lib/finance/models/`), les
Security Rules (`firestore.rules`), les Indexes (`firestore.indexes.json`) et
les Cloud Functions (`functions/`).

## Principes directeurs

1. **Firestore n'est pas une base SQL.** On dénormalise délibérément les
   champs consultés fréquemment (ex: `customer_display_name` recopié dans
   `delivery_requests`) afin d'éviter les lectures croisées coûteuses dans le
   dispatch et les listes. On ne dénormalise **jamais** une donnée financière
   confirmée — celles-ci vivent uniquement dans `financial_snapshots` /
   `transaction_ledger`, en lecture seule côté client.
2. **Deny by default.** Aucune collection n'est lisible/écrivable sans règle
   explicite (voir `firestore.rules`).
3. **Écritures sensibles = Cloud Functions uniquement.** Toute collection
   marquée « 🔒 Cloud Functions only » n'accepte aucune écriture cliente,
   même pour son propriétaire apparent (ex: un chauffeur ne peut pas
   s'auto-approuver).
4. **Rôles = Firebase Auth Custom Claims**, jamais un champ Firestore
   modifiable par le client (voir section Rôles ci-dessous).
5. **Immutabilité financière.** `financial_snapshots` (après confirmation) et
   `transaction_ledger` (toute entrée confirmée) ne sont jamais modifiés ni
   supprimés — uniquement complétés par des entrées compensatoires.
6. **GPS à deux vitesses** : position courante (document unique, écriture
   fréquente et bon marché) vs. historique de tracking (sous-collection,
   rétention configurable).

---

## Vue d'ensemble des collections

| # | Collection | Racine/Sous-collection | Rôle |
|---|---|---|---|
| 1 | `users` | racine | Identité + rôle métier de base (miroir des custom claims) |
| 2 | `driver_profiles` | racine (`{uid}`) | Statut d'onboarding/approbation chauffeur |
| 3 | `driver_documents` | racine | Documents chauffeur (métadonnées Storage) |
| 4 | `driver_vehicles` | racine | Véhicules déclarés par un chauffeur |
| 5 | `driver_locations` | racine (`{driverId}`) | Position GPS **actuelle** (1 doc/chauffeur) |
| 6 | `driver_locations/{driverId}/history` | sous-collection | Historique GPS (rétention configurable) |
| 7 | `delivery_requests` | racine | **Document mission** — état condensé, lecture rapide |
| 8 | `delivery_requests/{id}/stops` | sous-collection | Arrêts multiples (pickup + destinations) |
| 9 | `delivery_offers` | racine | Offres de dispatch poussées à des chauffeurs candidats |
| 10 | `delivery_requests/{id}/tracking_events` | sous-collection | Événements de suivi (arrivée, POD, etc.) |
| 11 | `delivery_quotes` | racine | Devis temporaires avant création de mission |
| 12 | `pricing_configs` | racine (singleton logique) | Pointeur vers la `pricing_version` **active** |
| 13 | `pricing_versions` | racine | Grilles tarifaires versionnées, immuables une fois publiées |
| 14 | `driver_pricing_profiles` | racine | Taux de commission résolu courant par chauffeur (cache dénormalisé) |
| 15 | `driver_promotions` | racine | Promotions de commission spécifiques à un chauffeur |
| 16 | `founding_driver_programs` | racine | Config + liste des qualifications Founding Driver |
| 17 | `financial_snapshots` | racine | 🔒 Contrat financier figé par mission |
| 18 | `transaction_ledger` | racine | 🔒 Grand livre append-only |
| 19 | `payments` | racine | 🔒 Paiements clients (état, provider-agnostic) |
| 20 | `driver_payouts` | racine | 🔒 Versements aux chauffeurs |
| 21 | `ratings` | racine | Évaluations client ↔ chauffeur |
| 22 | `notifications` | racine (`/users/{uid}/notifications` en sous-coll.) | Notifications utilisateur |
| 23 | `admin_reviews` | racine | File d'attente + décisions analyste/admin |
| 24 | `audit_logs` | racine | 🔒 Trace immuable de toute action sensible |

**Changement proposé par rapport à la liste initiale** : j'ai transformé
`delivery_stops`, `delivery_tracking` en **sous-collections** de
`delivery_requests/{id}` plutôt qu'en collections racine. Raison : ces
données n'ont de sens que rattachées à une mission précise, sont toujours
lues *avec* la mission (jamais interrogées globalement), et Firestore
facture/indexe plus efficacement des sous-collections pour ce pattern d'accès
1-mission → N-arrêts / N-événements. Cela réduit aussi le risque de fuite de
données (les Security Rules héritent naturellement du contexte du document
parent). J'ai gardé `delivery_offers` et `delivery_quotes` en collections
racine car elles sont interrogées **transversalement** (« toutes les offres
pour ce chauffeur », tous statuts de missions confondus) — un pattern que les
sous-collections gèrent mal sans requêtes collection-group coûteuses.

---

## 1. `users/{uid}`

**Rôle** : identité de base + miroir en lecture des rôles (custom claims).

| Champ | Type | Oblig. | Description |
|---|---|---|---|
| `uid` | string | ✅ | = Firebase Auth UID (aussi l'ID du doc) |
| `email` | string | ✅ | |
| `phone` | string? | ❌ | |
| `full_name` | string | ✅ | |
| `profile_photo_url` | string? | ❌ | URL Storage publique (avatar, non sensible) |
| `roles` | array\<string\> | ✅ | **Miroir en lecture uniquement** des custom claims. Voir section Rôles. |
| `created_at` | timestamp | ✅ | |
| `is_disabled` | bool | ✅ (default false) | Compte désactivé par un admin |
| `email_verified` | bool | ✅ (default false) | Miroir Firebase Auth |

**Références** : aucune (racine de l'identité).
**Lecture** : l'utilisateur lui-même (son propre doc) ; `analyst/admin/super_admin` peuvent lire n'importe quel `users/{uid}` pour le support/la modération.
**Écriture** : l'utilisateur peut modifier `full_name`, `phone`, `profile_photo_url` sur son propre document. **`roles` est 🔒 Cloud Functions only** (ex: `setUserRole()` appelée par un `super_admin`, qui met à jour Firebase Auth custom claims PUIS ce champ miroir dans la même opération serveur).
**Immuable** : `uid`, `created_at`.
**Rétention** : conservé indéfiniment (obligations légales/comptables) ; anonymisation possible sur demande RGPD-like via Cloud Function dédiée (hors scope immédiat).

---

## 2. `driver_profiles/{uid}`

**Rôle** : état d'onboarding et d'approbation d'un chauffeur. Le champ le
plus consulté par le dispatch.

| Champ | Type | Oblig. | Description |
|---|---|---|---|
| `uid` | string | ✅ | = `users/{uid}` |
| `full_name` | string | ✅ | Dénormalisé depuis `users` pour éviter une jointure au dispatch |
| `city` | string | ✅ | |
| `status` | string (`DriverStatus`) | ✅ | `registration_incomplete\|pending_review\|documents_required\|approved\|rejected\|suspended\|inactive` |
| `service_radius_km` | number | ✅ | |
| `accepted_vehicle_categories` | array\<string\> | ✅ | Valeurs `VehicleCategory` — **utilisé par le dispatch** |
| `accepted_item_category_keys` | array\<string\> | ✅ | clés i18n `cat_*` |
| `rating` | number | ✅ (default 0) | Moyenne dénormalisée (recalculée par Cloud Function à chaque nouvelle `rating`) |
| `completed_missions` | number | ✅ (default 0) | Compteur dénormalisé |
| `created_at` | timestamp | ✅ | |
| `approved_at` | timestamp? | ❌ | |
| `approved_by_user_id` | string? | ❌ | uid de l'analyste/admin |
| `rejection_reason` | string? | ❌ | |
| `identity_verified` | bool | ✅ (default false) | |
| `vehicle_verified` | bool | ✅ (default false) | |
| `online_status` | string (`DriverOnlineStatus`) | ✅ (default `offline`) | `offline\|online\|on_mission` — **utilisé par le dispatch** |
| `current_geohash` | string? | ❌ | Geohash (précision ~1km) recopié depuis `driver_locations/{uid}` pour permettre une requête de zone *sans* lire la collection GPS. Mis à jour par la même Cloud Function qui écrit la position. |
| `documents_all_valid` | bool | ✅ (default false) | Dénormalisé : `true` seulement si tous les `driver_documents` requis sont `approved` et non expirés. Recalculé par Cloud Function à chaque changement de statut de document. **Utilisé par le dispatch pour éviter de lire `driver_documents` à chaque recherche.** |

**Références** : `uid` → `users/{uid}`.
**Lecture** : le chauffeur lui-même (son propre doc) ; `analyst/admin/super_admin` (tous) ; clients : lecture **partielle** autorisée uniquement via une vue publique dénormalisée dans la mission assignée (jamais un accès direct à `driver_profiles/{autreUid}` pour un client — voir Security Rules).
**Écriture** :
- Le chauffeur peut écrire lui-même : `city`, `service_radius_km`, `accepted_vehicle_categories`, `accepted_item_category_keys` (déclaratif, non sensible), et `online_status` (**uniquement** s'il est `approved` — sinon rejeté par les rules).
- 🔒 **Cloud Functions only** : `status`, `approved_at`, `approved_by_user_id`, `rejection_reason`, `identity_verified`, `vehicle_verified`, `rating`, `completed_missions`, `documents_all_valid`, `current_geohash`.
**Immuable** : `uid`, `created_at`.
**Rétention** : conservé indéfiniment tant que le compte existe.

---

## 3. `driver_documents/{id}`

**Rôle** : métadonnées d'un document (le fichier vit dans Firebase Storage).

| Champ | Type | Oblig. | Description |
|---|---|---|---|
| `driver_id` | string | ✅ | → `driver_profiles/{driver_id}` |
| `type` | string (`DriverDocumentType`) | ✅ | `drivers_licence\|vehicle_registration\|insurance\|identity\|vehicle_photo\|other` |
| `status` | string (`DriverDocumentStatus`) | ✅ | `missing\|uploaded\|pending_review\|approved\|rejected\|expired\|replacement_required` |
| `storage_bucket_path` | string | ✅ | Chemin Storage, jamais une URL publique permanente |
| `uploaded_at` | timestamp | ✅ | |
| `reviewed_at` | timestamp? | ❌ | |
| `reviewed_by_user_id` | string? | ❌ | |
| `rejection_reason` | string? | ❌ | |
| `expires_at` | timestamp? | ❌ | Pour permis/assurance |

**Index requis** : `driver_id` + `status` (liste des documents en attente d'un chauffeur) ; `status` + `expires_at` (job de détection des documents expirants, voir étape 10).
**Lecture** : le chauffeur propriétaire (`driver_id == uid`) ; `analyst/admin/super_admin`.
**Écriture** : le chauffeur peut **créer** un document en `status=uploaded` (après upload Storage réussi) mais 🔒 **ne peut jamais lui-même passer `status` à `approved`/`rejected`** — c'est réservé aux Cloud Functions déclenchées par un analyste. Le chauffeur peut ré-uploader (nouveau doc) si `replacement_required`.
**Immuable** : `storage_bucket_path`, `uploaded_at`, `type`, `driver_id` (un changement de type = nouveau document).
**Rétention** : les documents rejetés/remplacés sont conservés 24 mois pour audit (Storage lifecycle rule), puis purgés automatiquement ; les documents `approved` en cours de validité sont conservés tant que le compte chauffeur existe.

---

## 4. `driver_vehicles/{id}`

| Champ | Type | Oblig. | Description |
|---|---|---|---|
| `driver_id` | string | ✅ | |
| `category` | string (`VehicleCategory`) | ✅ | |
| `make_model` | string | ✅ | |
| `year` | number | ✅ | |
| `plate` | string | ✅ | |
| `max_payload_kg` | number? | ❌ | |
| `is_verified` | bool | ✅ (default false) | |
| `created_at` | timestamp | ✅ | |

**Lecture** : chauffeur propriétaire ; analyst/admin/super_admin.
**Écriture** : le chauffeur peut créer/modifier ses propres véhicules (champs déclaratifs) ; 🔒 `is_verified` est Cloud Functions only (validé en même temps que les documents véhicule).
**Immuable** : `driver_id`, `created_at`.

---

## 5. `driver_locations/{driverId}` — position **actuelle**

**Rôle** : la donnée GPS la plus chaude de tout le système — écrite très
fréquemment (chauffeur en mission), lue rarement (un client à la fois, sur sa
mission active). **1 seul document par chauffeur**, toujours écrasé (jamais
d'historique ici).

| Champ | Type | Oblig. | Description |
|---|---|---|---|
| `driver_id` | string | ✅ | = ID du document |
| `latitude` | number | ✅ | |
| `longitude` | number | ✅ | |
| `accuracy` | number? | ❌ | |
| `heading` | number? | ❌ | |
| `speed` | number? | ❌ | |
| `updated_at` | timestamp | ✅ | |
| `active_delivery_id` | string? | ❌ | Mission active en cours (sert de clé d'autorisation de lecture) |

**Lecture** :
- Le chauffeur lui-même.
- Un client **uniquement si** `active_delivery_id` correspond à une mission dans `delivery_requests` dont `customer_id == request.auth.uid` **et** `driver_id == resource.id` (vérifié via `get()` dans les Security Rules — voir étape 9).
- `analyst/admin/super_admin` (supervision).
**Écriture** : le chauffeur lui-même, à une cadence raisonnable (throttlée côté client : 5-15s en mission active, ex. 60s+ hors mission) — **jamais** par le client d'une mission ni par une Cloud Function tierce.
**Immuable** : aucun champ (document volatile par nature).
**Rétention** : aucune (toujours écrasé) — c'est l'historique séparé ci-dessous qui gère la rétention.

## 5bis. `driver_locations/{driverId}/history/{eventId}` — historique GPS

**Rôle** : trace de trajet, uniquement **quand une mission active le
nécessite** (ex: preuve de trajet, litige, dashboard analytique) — pas un
enregistrement permanent de chaque déplacement du chauffeur.

| Champ | Type | Oblig. | Description |
|---|---|---|---|
| `delivery_id` | string | ✅ | Mission pour laquelle ce point a été enregistré |
| `latitude` | number | ✅ | |
| `longitude` | number | ✅ | |
| `recorded_at` | timestamp | ✅ | |

**Écriture** : 🔒 Cloud Function (`recordTrackingPoint()`, appelée par le
client chauffeur mais qui n'écrit que si une mission active existe réellement
— pas un `.add()` direct côté client) — évite qu'un chauffeur alimente un
historique sans mission réelle, et permet d'appliquer la politique de
rétention côté serveur.
**Lecture** : chauffeur propriétaire ; client de la mission concernée ;
analyst/admin/super_admin.
**Rétention** : **configurable**, valeur par défaut proposée = 30 jours après
`completed_at` de la mission (purge automatique via Cloud Function planifiée
`cleanupExpiredTrackingHistory`, cron quotidien). Au-delà, si nécessaire pour
litige, un export peut être archivé hors Firestore (Cloud Storage / BigQuery)
avant purge.

---

## 6. `delivery_requests/{id}` — **document mission (condensé)**

**Rôle** : LE document consulté pour connaître l'état d'une mission en une
seule lecture. Toutes les informations "vue d'ensemble" sont dénormalisées
ici ; les détails lourds (arrêts multiples, événements de tracking) vivent en
sous-collections.

| Champ | Type | Oblig. | Description |
|---|---|---|---|
| `customer_id` | string | ✅ | |
| `customer_display_name` | string | ✅ | Dénormalisé (évite une lecture `users` dans les listes chauffeur) |
| `driver_id` | string? | ❌ | 🔒 écrit uniquement par `acceptDelivery()` |
| `driver_display_name` | string? | ❌ | Dénormalisé après assignation |
| `status` | string (`MissionStatus`) | ✅ | Machine à états complète (voir `enums.dart`) |
| `item_category_key` | string | ✅ | clé i18n `cat_*` |
| `description` | string | ✅ | |
| `required_vehicle_category` | string (`VehicleCategory`) | ✅ | **utilisé par le dispatch** |
| `pickup_address` | map `{line1, city, postal_code, lat, lng}` | ✅ | Dénormalisé (pas besoin de lire `stops`) |
| `dropoff_address` | map `{line1, city, postal_code, lat, lng}` | ✅ | Adresse de la **dernière** destination (résumé) — le détail multi-arrêts est dans la sous-collection `stops` |
| `distance_km` | number | ✅ | |
| `estimated_duration_minutes` | number | ✅ | |
| `pricing_version` | string | ✅ | Référence figée dès le devis — **jamais recalculée rétroactivement** |
| `driver_offer_amount` | number | ✅ (0 avant assignation) | Copié depuis le `financial_snapshot` dès sa création — lecture rapide sans dépendance |
| `customer_total` | number | ✅ (0 avant devis) | idem |
| `payment_status` | string (`PaymentStatus`) | ✅ (default `pending`) | Dénormalisé depuis `payments` |
| `active_quote_id` | string? | ❌ | |
| `active_financial_snapshot_id` | string? | ❌ | |
| `created_at` | timestamp | ✅ | |
| `accepted_at` | timestamp? | ❌ | 🔒 écrit uniquement par `acceptDelivery()` |
| `completed_at` | timestamp? | ❌ | |
| `cancelled_at` | timestamp? | ❌ | |
| `cancellation_reason` | string? | ❌ | |
| `dispatch_zone_geohash` | string | ✅ | Geohash du pickup (précision ~1-5km) — **utilisé par le dispatch** pour filtrer par zone sans scanner toutes les missions |

**Index requis** : voir étape 10 (`customer_id`+`created_at`, `driver_id`+`status`, `status`+`dispatch_zone_geohash`+`required_vehicle_category`).
**Lecture** : `customer_id == uid` ; `driver_id == uid` (une fois assigné) ; chauffeurs `approved` peuvent lire les missions `status in [searching_driver, offered]` de leur zone/catégorie (liste filtrée, jamais un scan complet — voir Security Rules + Indexes) ; analyst/admin/super_admin.
**Écriture** :
- Le client peut créer une mission (via `createDeliveryRequest()`, 🔒 Cloud Function — pas un `.add()` direct, pour garantir la cohérence devis→mission) et modifier certains champs **avant assignation** uniquement (ex: `description`, adresse) tant que `status == draft`.
- 🔒 **Cloud Functions only** : `driver_id`, `status`, `accepted_at`, `driver_offer_amount`, `customer_total`, `payment_status`, `active_financial_snapshot_id`, `completed_at`.
- **Aucune écriture cliente n'est permise une fois `driver_id` non nul**, sauf `cancellation_reason` par le client (annulation, transition contrôlée par règle explicite).
**Immuable** : `customer_id`, `created_at`, `pricing_version` (une fois fixé).
**Rétention** : conservé indéfiniment (historique client/chauffeur + obligations comptables).

## 6bis. `delivery_requests/{id}/stops/{stopId}` — arrêts détaillés

| Champ | Type | Oblig. | Description |
|---|---|---|---|
| `sequence` | number | ✅ | Ordre (0 = pickup) |
| `type` | string | ✅ | `pickup\|dropoff` |
| `address` | map | ✅ | |
| `contact_instructions` | string? | ❌ | |
| `access_details` | string? | ❌ | |
| `completed_at` | timestamp? | ❌ | 🔒 Cloud Function (`completePickup`/`completeDelivery`) |

**Lecture/Écriture** : hérite du parent (client/chauffeur assignés,
analyst/admin) ; `completed_at` est 🔒 Cloud Functions only.

## 6ter. `delivery_requests/{id}/tracking_events/{eventId}` — événements

| Champ | Type | Oblig. | Description |
|---|---|---|---|
| `event_type` | string | ✅ | `driver_assigned\|arrived_pickup\|picked_up\|arrived_dropoff\|delivered\|proof_of_delivery_uploaded\|...` |
| `occurred_at` | timestamp | ✅ | |
| `metadata` | map | ❌ | ex: URL photo de preuve de livraison |

**Écriture** : 🔒 Cloud Functions only (toujours généré par une transition de
statut serveur, jamais par une écriture cliente directe) — garantit que
l'historique reflète fidèlement la machine à états serveur.

---

## 7. `delivery_offers/{id}` — dispatch

**Rôle** : offre poussée à un chauffeur candidat pendant la recherche (avant
acceptation atomique). Collection racine (interrogée transversalement par
chauffeur, tous statuts de mission confondus).

| Champ | Type | Oblig. | Description |
|---|---|---|---|
| `mission_id` | string | ✅ | → `delivery_requests/{mission_id}` |
| `driver_id` | string | ✅ | |
| `offered_at` | timestamp | ✅ | |
| `expires_at` | timestamp | ✅ | |
| `status` | string | ✅ | `pending\|accepted\|expired\|declined\|superseded` |

**Index requis** : `driver_id` + `status` + `expires_at` (offres actives d'un chauffeur).
**Lecture** : le chauffeur destinataire (`driver_id == uid`) ; analyst/admin.
**Écriture** : 🔒 Cloud Functions only en création/mise à jour de `status`
(le passage à `accepted` déclenche/résulte de `acceptDelivery()` ; les autres
chauffeurs voient leur offre passer à `superseded` par la même transaction).
**Rétention** : purge automatique 7 jours après expiration (Cloud Function planifiée) — donnée volatile de dispatch, aucune valeur archivistique au-delà du support client court terme.

---

## 8. `delivery_quotes/{id}`

| Champ | Type | Oblig. | Description |
|---|---|---|---|
| `mission_id` | string | ✅ | Peut référencer un brouillon avant création formelle |
| `pricing_version` | string | ✅ | |
| `customer_total` | number | ✅ | |
| `created_at` | timestamp | ✅ | |
| `expires_at` | timestamp | ✅ | |
| `is_consumed` | bool | ✅ (default false) | `true` une fois qu'une mission a été créée à partir de ce devis |

**Lecture** : le client qui a demandé le devis.
**Écriture** : 🔒 Cloud Functions only (`calculateDeliveryQuote()`).
**Immuable** : tous les champs après création (un devis n'est jamais modifié, seulement consommé ou expiré).
**Rétention** : purge 48h après expiration si `is_consumed == false` (Cloud Function planifiée).

---

## 9. `pricing_configs/{singleton}` — pointeur de configuration active

**Rôle** : un document unique (ID fixe `"active"`) qui pointe vers la
`pricing_version` actuellement en vigueur, évitant une requête `orderBy` sur
`pricing_versions` à chaque devis.

| Champ | Type | Oblig. | Description |
|---|---|---|---|
| `active_pricing_version` | string | ✅ | → `pricing_versions/{active_pricing_version}` |
| `updated_at` | timestamp | ✅ | |
| `updated_by_user_id` | string | ✅ | |

**Lecture** : tous les utilisateurs authentifiés (nécessaire pour afficher un devis).
**Écriture** : 🔒 Cloud Functions only (`updatePricingConfiguration()`, admin/super_admin uniquement).

## 10. `pricing_versions/{pricingVersion}`

**Rôle** : grille tarifaire complète et versionnée — structure exacte de
`PricingConfig` (voir `lib/finance/models/pricing_config.dart`).

| Champ | Type | Oblig. |
|---|---|---|
| `pricing_version` | string | ✅ |
| `is_active` | bool | ✅ |
| `effective_from` | timestamp | ✅ |
| `vehicle_rules` | array\<map\> | ✅ |
| `handling_fees` | map | ✅ |
| `waiting_fee` | map | ✅ |
| `additional_stop_fee` | map | ✅ |
| `surcharges` | array\<map\> | ✅ |
| `customer_service_fee` | map | ✅ |
| `commission` | map | ✅ |
| `tip_policy` | map | ✅ |
| `quote_config` | map | ✅ |
| `tax_rate` | number | ✅ |

**Lecture** : tous les utilisateurs authentifiés.
**Écriture** : 🔒 Cloud Functions only. **Une version publiée n'est jamais modifiée** — `updatePricingConfiguration()` crée toujours un nouveau document `pricing_versions/{nouvelle_version}` puis met à jour `pricing_configs/active`.
**Immuable** : intégralement, une fois `is_active` passé à `true` au moins une fois.
**Rétention** : conservé indéfiniment (une mission historique doit pouvoir résoudre sa `pricing_version` pour toujours).

## 11. `driver_pricing_profiles/{driverId}`

**Rôle** : cache dénormalisé du taux de commission effectif courant d'un
chauffeur (résultat du `CommissionResolver`), pour éviter de recalculer la
hiérarchie Founding Driver/promo/standard à chaque écran.

| Champ | Type | Oblig. | Description |
|---|---|---|---|
| `driver_id` | string | ✅ | |
| `resolved_commission_rate` | number | ✅ | |
| `resolved_program` | string (`CommissionProgramType`) | ✅ | |
| `resolved_reason` | string | ✅ | ex: `founding_driver_promotional_period` |
| `last_resolved_at` | timestamp | ✅ | |

**Lecture** : le chauffeur lui-même ; analyst/admin.
**Écriture** : 🔒 Cloud Functions only, recalculé à chaque événement pertinent (qualification Founding Driver, promotion activée/expirée, changement de config standard).
**Note importante** : ce document est un **cache d'affichage**, jamais la source de vérité utilisée pour un calcul financier réel — `calculateDriverPayout()` et `createFinancialSnapshot()` **rejouent** systématiquement le `CommissionResolver` au moment de l'exécution, avec les données à jour (`founding_driver_programs`, `driver_promotions`, `pricing_versions`), pour éviter tout écart entre l'affichage et le calcul réel.

## 12. `driver_promotions/{id}`

| Champ | Type | Oblig. | Description |
|---|---|---|---|
| `driver_id` | string | ✅ | |
| `promotional_commission_rate` | number | ✅ | |
| `starts_at` | timestamp | ✅ | |
| `ends_at` | timestamp | ✅ | |
| `is_active` | bool | ✅ | |
| `created_by_user_id` | string | ✅ | |
| `reason` | string? | ❌ | |

**Index requis** : `driver_id` + `is_active` + `ends_at` (promotions actives d'un chauffeur ; job de détection des promotions expirées).
**Lecture** : chauffeur concerné ; analyst/admin.
**Écriture** : 🔒 Cloud Functions only (`applyDriverPromotion()`, admin/super_admin).
**Immuable** : `driver_id`, `promotional_commission_rate`, `starts_at`, `created_by_user_id` une fois créé — seul `is_active` peut être forcé à `false` (révocation anticipée) via Cloud Function, jamais modifié directement.

## 13. `founding_driver_programs/{programId}`

**Rôle** : config globale du programme + qualifications individuelles en
sous-collection (pattern 1 config → N chauffeurs qualifiés).

| Champ | Type | Oblig. | Description |
|---|---|---|---|
| `program_id` | string | ✅ | |
| `is_active` | bool | ✅ | |
| `total_slots` | number | ✅ | |
| `slots_taken` | number | ✅ | 🔒 incrémenté uniquement par `qualifyFoundingDriver()` |
| `promotional_commission_rate` | number | ✅ | |
| `promotional_duration_months` | number | ✅ | |
| `preferred_commission_rate` | number | ✅ | |
| `program_opens_at` | timestamp? | ❌ | |
| `program_closes_at` | timestamp? | ❌ | |

### `founding_driver_programs/{programId}/qualifications/{driverId}`

| Champ | Type | Oblig. | Description |
|---|---|---|---|
| `driver_id` | string | ✅ | |
| `status` | string (`FoundingDriverStatus`) | ✅ | `candidate\|qualified\|suspended\|revoked\|expired` |
| `qualified_at` | timestamp | ✅ | |
| `promotional_period_ends_at` | timestamp | ✅ | |
| `suspension_reason` | string? | ❌ | |
| `revocation_reason` | string? | ❌ | |
| `status_changed_at` | timestamp? | ❌ | |
| `status_changed_by_user_id` | string? | ❌ | |

**Lecture** : le chauffeur concerné (sa propre qualification) ; config globale lisible par tous les chauffeurs (pour afficher "places restantes") ; analyst/admin (tout).
**Écriture** : 🔒 Cloud Functions only (`qualifyFoundingDriver()`, `revokeFoundingDriverStatus()`) — **jamais** un chauffeur ne peut se qualifier ou modifier son propre statut.
**Immuable** : `driver_id`, `qualified_at`, `promotional_period_ends_at` une fois `qualified` (une révocation change `status`, pas les dates historiques).

---

## 14. `financial_snapshots/{id}` 🔒 IMMUABLE

**Rôle** : contrat financier figé d'une mission — voir
`lib/finance/models/financial_snapshot.dart` pour la liste exhaustive des
champs (`mission_base_value`, `driver_gross_earnings`, `driver_offer_amount`,
`commission_rate`, `commission_program`, `platform_commission_amount`,
`customer_service_fee`, `driver_bonus`, `tip_amount`,
`driver_net_mission_earnings`, `driver_total_payout`, `customer_total`,
`platform_gross_revenue`, `contribution_margin`, etc.)

**Index requis** : `mission_id` (unique par mission), `driver_id`+`created_at` (historique gains chauffeur), `status`+`created_at` (dashboard financier).
**Lecture** : `customer_id` de la mission ; `driver_id` de la mission ; analyst/admin/super_admin.
**Écriture** : 🔒 **Cloud Functions only, sans exception.** `createFinancialSnapshot()` crée le document en `status=pending`, puis le passe à `confirmed` (jamais l'inverse). **Aucun champ n'est modifiable après `status=confirmed`** — appliqué à la fois par la Security Rule (`resource.data.status == 'confirmed' ⇒ deny update/delete`) et par la logique serveur.
**Correction** : toute erreur détectée après confirmation se traite exclusivement par une nouvelle entrée dans `transaction_ledger` référençant ce snapshot — jamais par une modification du snapshot lui-même.
**Rétention** : conservé indéfiniment (obligations comptables/fiscales).

---

## 15. `transaction_ledger/{id}` 🔒 APPEND-ONLY

**Rôle** : grand livre comptable — voir `lib/finance/models/transaction_ledger.dart`.

| Champ clé | Type | Description |
|---|---|---|
| `mission_id` / `transaction_id` | string? | |
| `type` | string (`LedgerEntryType`) | `customer_charge\|platform_commission\|driver_earning\|driver_tip\|refund\|driver_payout\|...` |
| `amount` | number | |
| `direction` | string (`LedgerDirection`) | `credit\|debit` |
| `party` | string (`LedgerParty`) | `customer\|driver\|platform` |
| `status` | string (`LedgerEntryStatus`) | `pending\|confirmed\|reversed\|compensated` |
| `reference_id` | string? | Si entrée compensatoire, référence l'entrée corrigée |
| `created_by` | string | Identifiant de la Cloud Function/process serveur (jamais un uid client) |

**Index requis** : `mission_id`+`created_at` ; `party`+`created_at` (filtré par utilisateur via règle, pas par requête globale) ; `status`+`type`+`created_at` (dashboards).
**Lecture** : chaque partie voit **uniquement** les entrées où elle est concernée (`party == 'customer' && mission.customer_id == uid`, ou `party == 'driver' && mission.driver_id == uid`), résolu via règle avec `get()` sur la mission référencée ; analyst/admin/super_admin voient tout.
**Écriture** : 🔒 **Cloud Functions only.** Aucune règle Firestore n'autorise jamais `create`/`update`/`delete` par un client, quel que soit son rôle (même un `super_admin` agit via une Cloud Function pour garder la trace `created_by`/`audit_logs`).
**Correction** : `status=reversed` sur l'entrée fautive + nouvelle entrée `status=confirmed` avec `reference_id` pointant vers l'originale — jamais de update destructif.
**Rétention** : conservé indéfiniment (obligation comptable légale).

---

## 16. `payments/{id}` 🔒

| Champ | Type | Oblig. | Description |
|---|---|---|---|
| `customer_id` | string | ✅ | |
| `mission_id` | string | ✅ | |
| `provider_payment_id` | string? | ❌ | ID côté fournisseur (Stripe ou autre — jamais de détail de carte stocké ici) |
| `amount` | number | ✅ | |
| `currency` | string | ✅ (default `CAD`) | |
| `status` | string (`PaymentStatus`) | ✅ | `pending\|authorized\|captured\|failed\|refunded\|partially_refunded\|disputed` |
| `created_at` | timestamp | ✅ | |
| `updated_at` | timestamp | ✅ | |

**Lecture** : `customer_id` propriétaire ; analyst/admin/super_admin.
**Écriture** : 🔒 Cloud Functions only (`PaymentProvider` implémentation serveur — voir `lib/backend/payment/payment_provider.dart`). Le webhook du fournisseur de paiement met à jour ce document via une Cloud Function HTTP dédiée, jamais via une écriture cliente.
**Immuable** : `customer_id`, `mission_id`, `amount`, `currency`, `created_at`. `status` suit une machine à états stricte appliquée côté serveur.
**Rétention** : indéfinie (obligations comptables/anti-fraude).

## 17. `driver_payouts/{id}` 🔒

| Champ | Type | Oblig. | Description |
|---|---|---|---|
| `driver_id` | string | ✅ | |
| `financial_snapshot_ids` | array\<string\> | ✅ | Missions incluses dans ce versement (peut être un lot) |
| `amount` | number | ✅ | |
| `currency` | string | ✅ | |
| `status` | string | ✅ | `pending\|processing\|paid\|failed` |
| `provider_payout_id` | string? | ❌ | |
| `created_at` | timestamp | ✅ | |
| `paid_at` | timestamp? | ❌ | |

**Lecture** : `driver_id` propriétaire ; analyst/admin/super_admin.
**Écriture** : 🔒 Cloud Functions only (`calculateDriverPayout()`).
**Rétention** : indéfinie.

---

## 18. `ratings/{id}`

| Champ | Type | Oblig. | Description |
|---|---|---|---|
| `mission_id` | string | ✅ | |
| `rater_id` | string | ✅ | |
| `rated_user_id` | string | ✅ | |
| `rater_role` | string | ✅ | `customer\|driver` |
| `stars` | number (1-5) | ✅ | |
| `comment` | string? | ❌ | |
| `created_at` | timestamp | ✅ | |

**Index requis** : `rated_user_id`+`created_at` (profil chauffeur/client).
**Lecture** : publique parmi utilisateurs authentifiés (nécessaire pour afficher le profil chauffeur) ; commentaires modérables par analyst/admin.
**Écriture** : le client/chauffeur concerné peut créer **une seule** note par mission dont il est partie (règle vérifie qu'aucune note du même `rater_id`+`mission_id` n'existe déjà, et que la mission est bien `completed`). 🔒 La mise à jour du champ dénormalisé `driver_profiles.rating` se fait par Cloud Function (trigger `onCreate`), jamais par le client.
**Immuable** : tout, une fois créé (pas de modification a posteriori — seule la suppression par un admin en cas d'abus est permise).

---

## 19. `notifications/{uid}/items/{notificationId}` (sous-collection de `users`)

**Changement proposé** : sous-collection de `users/{uid}` plutôt que
collection racine `notifications` — accès toujours scoping par utilisateur,
jamais de requête transversale, donc le pattern sous-collection est idéal et
simplifie les Security Rules (`request.auth.uid == uid` suffit).

| Champ | Type | Oblig. | Description |
|---|---|---|---|
| `type` | string | ✅ | ex: `mission_accepted`, `document_rejected` |
| `title` | string | ✅ | |
| `body` | string | ✅ | |
| `is_read` | bool | ✅ (default false) | |
| `created_at` | timestamp | ✅ | |
| `related_mission_id` | string? | ❌ | |

**Lecture/Écriture(`is_read`)** : l'utilisateur propriétaire uniquement.
**Création** : 🔒 Cloud Functions only.
**Rétention** : purge automatique après 90 jours (Cloud Function planifiée).

---

## 20. `admin_reviews/{id}`

**Rôle** : file d'attente et trace des décisions du portail analyste (au-delà
de l'approbation chauffeur qui a son propre statut sur `driver_profiles`) —
ex: signalement, litige, revue de document isolé.

| Champ | Type | Oblig. | Description |
|---|---|---|---|
| `subject_type` | string | ✅ | `driver_document\|dispute\|report` |
| `subject_id` | string | ✅ | |
| `status` | string | ✅ | `open\|in_review\|resolved` |
| `assigned_to_user_id` | string? | ❌ | |
| `decision` | string? | ❌ | |
| `created_at` | timestamp | ✅ | |
| `resolved_at` | timestamp? | ❌ | |

**Lecture/Écriture** : analyst/admin/super_admin uniquement.

---

## 21. `audit_logs/{id}` 🔒 IMMUABLE

Voir `lib/backend/models/audit_log.dart`. `actor_user_id`, `actor_role`,
`action`, `target_id`, `metadata`, `created_at`.

**Lecture** : admin/super_admin uniquement (un analyste ne voit pas les logs
d'audit des autres analystes/admins — seulement ses propres actions, si
nécessaire, via un filtre applicatif).
**Écriture** : 🔒 Cloud Functions only — **chaque** Cloud Function sensible
(`approveDriver`, `updatePricingConfiguration`, etc.) écrit une entrée
d'audit dans la même transaction/exécution serveur que son action principale.
**Immuable** : intégralement, aucune modification/suppression jamais permise.
**Rétention** : indéfinie (exigence de conformité).

---

## Rôles — Firebase Auth Custom Claims

`PlatformRole` (`customer|driver|mechanic|analyst|admin|super_admin`) est
géré exclusivement via **Firebase Auth Custom Claims**, jamais comme un champ
Firestore librement modifiable :

1. Une Cloud Function protégée `setUserRole()` (appelable seulement par un
   `super_admin`, vérifié via `context.auth.token.role == 'super_admin'`)
   appelle `admin.auth().setCustomUserClaims(uid, { role, roles })`.
2. La même fonction met à jour, dans la même exécution, le champ miroir
   `users/{uid}.roles` (pour affichage/requêtes Firestore uniquement — jamais
   utilisé pour une décision d'autorisation côté Security Rules).
3. **Les Security Rules et les Cloud Functions n'utilisent JAMAIS
   `users/{uid}.roles` pour autoriser une action** — elles lisent
   exclusivement `request.auth.token.role` (les custom claims, injectés dans
   le JWT au moment du login/refresh). Ainsi, même si un client parvenait à
   modifier son propre document `users/{uid}` (ce que les rules interdisent
   déjà), cela n'aurait **aucun effet** sur ses permissions réelles.
4. Le client doit forcer `getIdTokenResult(forceRefresh: true)` après tout
   changement de rôle pour rafraîchir son JWT (les claims ne se propagent pas
   instantanément sur un token déjà émis).

Cette approche répond directement à l'exigence : *« les permissions élevées
ne doivent pas être décidées par un simple champ modifiable par le client »*.

---

## Dispatch — comment on évite un scan complet

Pour trouver les chauffeurs éligibles à une mission, le dispatch (dans
`calculateDeliveryQuote()`/`createDeliveryRequest()`/logique d'offre) exécute
une requête composite sur `driver_profiles`, jamais un scan :

```
driver_profiles
  where status == 'approved'
  where online_status == 'online'
  where accepted_vehicle_categories array-contains <catégorie requise>
  where documents_all_valid == true
  where current_geohash >= <prefix>  and current_geohash < <prefix>\uf8ff   (requête de plage sur geohash)
  order by current_geohash
```

Cela nécessite un **index composite** (voir étape 10) et repose sur le champ
dénormalisé `current_geohash` (maintenu par la Cloud Function qui reçoit les
mises à jour de position), évitant de croiser `driver_locations` à chaque
recherche de dispatch.

---

## Résumé des collections 🔒 « Cloud Functions only »

`financial_snapshots` (write) · `transaction_ledger` (write) · `payments`
(write) · `driver_payouts` (write) · `audit_logs` (write) ·
`pricing_versions` (write) · `pricing_configs` (write) ·
`founding_driver_programs/*/qualifications` (write) · `driver_promotions`
(write) · `driver_profiles.status/approved_*/rejection_reason/rating/
completed_missions/documents_all_valid/current_geohash` (champs spécifiques)
· `driver_documents.status` (champ spécifique) · `delivery_requests.driver_id/
status/accepted_at/driver_offer_amount/customer_total/payment_status`
(champs spécifiques) · `delivery_offers` (write) · `delivery_quotes` (write)
· `users.roles` (champ spécifique) · `notifications/*/items` (create) ·
`promo_codes` (write).

---

## Addendum (Étape 12) — `promo_codes/{code}` et `customer_discount`

Ajouté lors de la rédaction des tests unitaires du moteur financier (test
« customer promotion »). Le champ `customer_discount` de `FinancialSnapshot`
(section 14) existait déjà dans le modèle mais n'était jusqu'ici jamais
calculé par aucun moteur — cet addendum documente le mécanisme complet.

| Champ | Type | Oblig. | Description |
|---|---|---|---|
| `code` | string | ✅ | = ID du document (ex: `BIENVENUE10`) |
| `discount_mode` | string | ✅ | `fixed_amount` \| `percentage` |
| `discount_value` | number | ✅ | Montant $ ou fraction (0.10 = 10%) selon `discount_mode` |
| `max_discount_amount` | number? | ❌ | Plafond $ de la remise (utile surtout en mode `percentage`) |
| `is_active` | bool | ✅ | |
| `starts_at` | timestamp? | ❌ | |
| `ends_at` | timestamp? | ❌ | |

**Écriture** : 🔒 Cloud Functions only / console admin — non exposé par une
Cloud Function callable dédiée dans cette étape (création de codes hors
scope de l'étape 11 ; les tests de l'étape 12 créent les documents
directement via l'Admin SDK de l'émulateur).

**Flux** : le client envoie uniquement un `promoCode` (chaîne) à
`calculateDeliveryQuote()`. Le MONTANT de la remise est résolu
EXCLUSIVEMENT côté serveur (lecture de `promo_codes/{code}`, vérification
`is_active`/fenêtre de validité, calcul borné par `max_discount_amount`) —
un montant envoyé directement par le client dans la requête est
structurellement impossible à exploiter puisque `CalculateDeliveryQuoteRequest`
ne contient aucun champ de montant, uniquement `promoCode: string`. Le
montant résolu est ensuite dénormalisé sur la mission
(`delivery_requests.customer_discount_amount`) pour que `acceptDelivery()`
et `createFinancialSnapshot()` recalculent avec EXACTEMENT la même remise
que celle affichée au client dans son devis.
