# MOVI-K — PRIVACY / DATA RETENTION (Phase 7, Bloc Z)

Ce document couvre Z-1 → Z-8. Il cartographie les données réelles du repo
(collections Firestore + espaces Storage confirmés par lecture de code), sans
inventer de durée légale. Toute durée non actuellement codée/décidée est
explicitement marquée `POLICY / LEGAL DECISION REQUIRED — PHASE 8`.

## Z-1 — Inventaire des données

Colonnes : **Donnée → Emplacement → Sensibilité → Raison métier → Suppression
possible → Conservation potentielle → Décision externe requise**

### Client

| Donnée | Emplacement | Sensibilité | Raison métier | Suppression possible | Conservation potentielle | Décision externe |
|---|---|---|---|---|---|---|
| Profil (nom, rôle) | `users/{uid}` | Moyenne (identifiant nominatif) | Identification compte, affichage nom sur mission | Oui (anonymisable — voir Z-4) | Historique lié à des missions/factures peut nécessiter le nom pour les enregistrements financiers déjà émis | `POLICY / LEGAL DECISION REQUIRED — PHASE 8` (durée post-suppression) |
| Email | Firebase Auth + `users/{uid}` (dénormalisé si présent) | Élevée (PII) | Connexion, notifications | Oui via suppression du compte Auth | Aucune conservation nécessaire une fois le compte supprimé, sauf trace facturation légale | `POLICY / LEGAL DECISION REQUIRED — PHASE 8` |
| Téléphone (si présent) | `users/{uid}` | Élevée (PII) | Contact chauffeur/client | Oui | Aucune conservation nécessaire hors litige actif | `POLICY / LEGAL DECISION REQUIRED — PHASE 8` |
| Adresses pickup/dropoff | `delivery_requests/{id}.pickup_address` / `.dropoff_address`, sous-collection `stops` | Élevée (PII géographique) | Exécution de la mission, preuve du service rendu | **Non recommandé de supprimer isolément** — l'adresse fait partie de l'enregistrement de mission facturé (justificatif financier) | Conservation liée à la conservation de la mission/finance (voir Finance ci-dessous) | `POLICY / LEGAL DECISION REQUIRED — PHASE 8` (durée) |
| Missions (historique) | `delivery_requests/{id}` + sous-collections `stops`, `tracking_events` | Moyenne-Élevée | Historique de service, preuve de transaction | Anonymisation possible du champ `customer_display_name`/coordonnées après suppression du compte ; la mission elle-même reste liée au ledger (voir Z-4/Z-5) | Oui — nécessaire tant que le ledger/finance associé existe | `POLICY / LEGAL DECISION REQUIRED — PHASE 8` |
| Notifications | `users/{uid}/notifications/{id}` (sous-collection, voir `onMissionStatusChangeNotifyCustomer.ts`) | Faible-Moyenne | UX (statut mission) | Oui, techniquement supprimable sans impact finance/audit | Aucune nécessité de conservation longue | Aucune — purge technique possible dès Phase 7/8 |

### Chauffeur

| Donnée | Emplacement | Sensibilité | Raison métier | Suppression possible | Conservation potentielle | Décision externe |
|---|---|---|---|---|---|---|
| Profil (nom, véhicule, statut) | `driver_profiles/{id}` | Moyenne | Identification, dispatch, affichage | Anonymisable après fermeture de compte | Historique commissions/payouts nécessite un lien stable vers le chauffeur (voir Finance) | `POLICY / LEGAL DECISION REQUIRED — PHASE 8` |
| Coordonnées (email/téléphone) | Firebase Auth + `driver_profiles/{id}` | Élevée (PII) | Contact, vérification identité | Oui via suppression Auth | Aucune conservation nécessaire hors litige actif | `POLICY / LEGAL DECISION REQUIRED — PHASE 8` |
| Permis de conduire, assurance, immatriculation, pièce d'identité, photo véhicule | `driver_documents/{id}` (métadonnées Firestore) + `driver_documents/{driverId}/{fileName}` (fichier Storage, **immuable en écriture** — `storage.rules` interdit `update`/`delete`, seul un nouveau fichier peut remplacer via un nouveau document Firestore) | **Très élevée** (pièces d'identité, données réglementées) | Vérification légale d'aptitude à conduire/livrer, conformité juridictionnelle | Techniquement supprimable (le fichier Storage n'est protégé QUE par les règles, pas par une contrainte applicative d'immutabilité physique) — **mais aucune fonction de suppression n'existe aujourd'hui dans le repo** | Conservation probable requise pour audit/litige/conformité juridictionnelle (durée non codée) | `RETENTION POLICY DECISION REQUIRED — PHASE 8` (voir Z-3) |
| Documents juridictionnels (permis municipal, etc. si applicable) | `driver_documents/{id}` (même mécanisme que ci-dessus, type générique) | Très élevée | Conformité réglementaire locale | Idem ci-dessus | Idem ci-dessus | `RETENTION POLICY DECISION REQUIRED — PHASE 8` |
| Statut/review analyste (`approved`/`rejected`/`suspended`, `rejection_reason`, `suspension_reason`) | `driver_profiles/{id}` | Moyenne (peut contenir un motif sensible) | Traçabilité décision métier | Le motif texte est potentiellement supprimable/anonymisable après un délai | La DÉCISION elle-même (approved/rejected + date) a une valeur d'audit | `POLICY / LEGAL DECISION REQUIRED — PHASE 8` |

### Mission

| Donnée | Emplacement | Sensibilité | Raison métier | Suppression possible | Conservation potentielle | Décision externe |
|---|---|---|---|---|---|---|
| Pickup/dropoff, timestamps de cycle de vie | `delivery_requests/{id}` | Élevée (PII géographique + horodatage comportemental) | Preuve d'exécution du service, base du calcul financier | Non recommandé isolément (lié au ledger) | Oui, tant que le ledger associé existe | `POLICY / LEGAL DECISION REQUIRED — PHASE 8` |
| Tracking GPS (position courante + historique) | `driver_locations/{driverId}` (position courante) + `driver_locations/{driverId}/history/{eventId}` (historique) | **Très élevée** (géolocalisation) | Suivi temps réel client, preuve d'exécution du trajet | **Historique** : purge automatique déjà en place (voir Z-2). **Position courante** : écrasée à chaque appel, `active_delivery_id` remis à `null` par `completeDelivery.ts` (désactive le tracking en fin de mission) | Position courante non conservée au-delà du besoin opérationnel ; historique conservé 30 jours (config technique actuelle, voir Z-2) | Aucune — mécanisme déjà automatisé, durée = `CURRENT TECHNICAL CONFIGURATION` |
| Preuve de livraison (photo) | `delivery_proofs/{missionId}/{fileName}` (Storage, immuable — `allow update/delete: if false`) + `proof_of_delivery_url` dénormalisé sur la mission | Élevée (image, potentiellement identifiante) | Preuve légale de livraison, résolution de litige | **Non supprimable par design actuel** (immutabilité volontaire — "preuve légale") | Conservation nécessaire tant que la mission/litige potentiel existe | `POLICY / LEGAL DECISION REQUIRED — PHASE 8` (durée max de conservation d'une preuve) |
| Metadata proof/recipient (`tracking_events` sous-collection) | `delivery_requests/{id}/tracking_events/{id}` | Moyenne | Timeline/historique de la mission | Lié à la mission — pas de suppression isolée prévue | Idem mission | `POLICY / LEGAL DECISION REQUIRED — PHASE 8` |

### Finance

| Donnée | Emplacement | Sensibilité | Raison métier | Suppression possible | Conservation potentielle | Décision externe |
|---|---|---|---|---|---|---|
| Payments | `payments/{id}` | Élevée (données financières, jamais de PAN/CVC — voir Bloc Y `sanitizeMetadata`) | Preuve de transaction, capture/autorisation Stripe | **NON — jamais supprimable** (nécessaire à la comptabilité/réconciliation/litige) | Conservation obligatoire tant que l'activité existe | `POLICY / LEGAL DECISION REQUIRED — PHASE 8` (durée légale de conservation comptable, hors scope code) |
| Payouts | `driver_payouts/{id}` | Élevée | Preuve de versement chauffeur | **NON — jamais supprimable** | Idem | `POLICY / LEGAL DECISION REQUIRED — PHASE 8` |
| Refunds | `refunds/{id}` | Élevée | Preuve de remboursement | **NON — jamais supprimable** | Idem | `POLICY / LEGAL DECISION REQUIRED — PHASE 8` |
| Disputes | `disputes/{id}` | Élevée | Litige/chargeback Stripe | **NON — jamais supprimable** | Idem | `POLICY / LEGAL DECISION REQUIRED — PHASE 8` |
| Ledger (`transaction_ledger`) | `transaction_ledger/{id}` | Très élevée | **Append-only par conception** (voir Bloc AA, AA-4) — livre comptable immuable | **NON — jamais** (aucune fonction de suppression/mise à jour n'existe ; conçu explicitement immuable) | Conservation permanente par conception actuelle | `POLICY / LEGAL DECISION REQUIRED — PHASE 8` (durée légale, hors scope technique) |
| Financial snapshots | `financial_snapshots/{id}` | Très élevée | Gel du montant exact facturé à la confirmation de livraison, **immuable une fois `confirmed`** (`completeDelivery.ts`) | **NON une fois confirmé** | Conservation permanente par conception actuelle | `POLICY / LEGAL DECISION REQUIRED — PHASE 8` |
| Reconciliation reports | `reconciliation_reports/{id}` | Moyenne-Élevée | Preuve d'audit de cohérence financière | Techniquement supprimable (rapport dérivé, pas une source de vérité primaire) mais non recommandé pour la traçabilité | Conservation recommandée pour audit | `POLICY / LEGAL DECISION REQUIRED — PHASE 8` |

### Système

| Donnée | Emplacement | Sensibilité | Raison métier | Suppression possible | Conservation potentielle | Décision externe |
|---|---|---|---|---|---|---|
| Audit logs | `audit_logs/{id}` | Moyenne-Élevée (traçabilité actions sensibles, acteur+cible) | Preuve d'imputabilité (qui a fait quoi, quand) — Bloc Y/X | **NON recommandé** (même logique que le ledger : la valeur de l'audit dépend de son immutabilité) | Conservation recommandée pour toute la durée d'exploitation | `POLICY / LEGAL DECISION REQUIRED — PHASE 8` |
| Notifications (client/chauffeur) | `users/{uid}/notifications/{id}` | Faible | UX | Oui, purge technique possible sans impact finance/audit | Aucune | Aucune |
| Runtime flags | `system_config/runtime_flags` (document unique) | Faible (config, pas de PII) | Kill switches Bloc X | Non applicable (config vivante, pas une donnée personnelle) | N/A | Aucune |
| Logs techniques (Cloud Logging) | Hors Firestore — infrastructure GCP | Variable (voir Z-7) | Observabilité (Bloc Y) | Géré par la rétention Cloud Logging (config GCP, pas le code applicatif) | Voir Z-7 | `Phase 8 — GCP/Firebase retention configuration` |

## Z-2 — GPS / Tracking retention

**Mécanisme déjà existant** (Bloc N, non réaudité en détail conformément à
la consigne) : `functions/src/functions/cleanupExpiredTrackingHistory.ts` —
Cloud Function planifiée (`onSchedule`, cron quotidien `02:00
America/Toronto`), purge par lots (`BATCH_LIMIT=400`, boucle jusqu'à 20
itérations) tout document de `driver_locations/{driverId}/history/{eventId}`
dont `recorded_at < now - RETENTION_DAYS` (`RETENTION_DAYS = 30`).

**Preuves demandées par Z-2** (référencées, pas ré-auditées) :

| Preuve | Élément de preuve |
|---|---|
| Données expirées supprimées | Requête `collectionGroup("history").where("recorded_at", "<", cutoff).limit(400)` + `batch.delete()` sur tous les documents retournés — supprime bien tout document strictement antérieur au cutoff |
| Données dans la fenêtre conservées | La clause `where("recorded_at", "<", cutoff)` exclut par construction tout document `>= cutoff` — non parcouru, non supprimé |
| Mission/client/chauffeur non concernés par erreur | La requête cible exclusivement la sous-collection `history` (`collectionGroup`) — ne touche jamais `driver_locations/{driverId}` (document parent, position courante), `delivery_requests`, `users`, ou tout autre document parent |
| Cleanup ne touche pas la position active | Le document parent `driver_locations/{driverId}` (contenant `latitude`/`longitude`/`active_delivery_id` courants) n'est jamais dans le scope de la requête `collectionGroup("history")` — structurellement impossible de le supprimer via ce job |
| Audit/log approprié | `writeAuditLog({ action: "cleanupExpiredTrackingHistory", metadata: { totalDeleted, retentionDays } })` si `totalDeleted > 0` — déjà en place |
| Index requis | Index `collectionGroup` sur `history(recorded_at)` — documenté dans `docs/FIRESTORE_INDEXES.md` (Bloc N-7, déjà ajouté, gap corrigé lors du Bloc N précédent) |

**Classification de la durée** : `RETENTION_DAYS = 30` est une **CURRENT
TECHNICAL CONFIGURATION** (constante codée dans
`cleanupExpiredTrackingHistory.ts`), **PAS une obligation légale
définitive** — aucune source juridique n'est établie dans ce projet fixant
cette durée. Une décision produit/légale future pourrait ajuster cette
constante sans changement d'architecture.

## Z-3 — Driver documents : ce qui est réellement supprimable

Flux réels examinés (`approveDriver.ts`, `rejectDriver.ts`, `suspendDriver.ts`,
`requestDriverDocuments.ts`, `validateDriverDocument.ts`,
`detectExpiringDocuments.ts` + `storage.rules`) :

1. **Techniquement supprimable aujourd'hui** : RIEN automatiquement. Le
   fichier Storage `driver_documents/{driverId}/{fileName}` est protégé par
   `allow update: if false; allow delete: if false;` (immuable dès l'upload).
   Aucune Cloud Function du repo n'appelle `file.delete()` sur ce chemin.
   Une suppression physique nécessiterait une nouvelle fonction dédiée,
   inexistante actuellement.
2. **Remplacement** : un chauffeur ne peut PAS écraser un fichier existant
   (`resource == null` requis pour `create`) — un remplacement passe
   obligatoirement par un **nouveau nom de fichier** + un **nouveau document
   Firestore** `driver_documents/{id}` avec `status: uploaded`
   (`validateDriverDocument.ts` recalcule ensuite `documents_all_valid`
   côté `driver_profiles`). L'ancien fichier/document reste en place, non
   écrasé.
3. **Ce qui reste après rejet** (`rejectDriver.ts`) : le document
   `driver_profiles/{id}` passe à `status: REJECTED` avec
   `rejection_reason` — **aucun document `driver_documents/{id}` ni fichier
   Storage n'est supprimé ou modifié** par ce flux. Les pièces déjà
   uploadées restent intactes.
4. **Ce qui reste après fermeture de compte** : aucun workflow de fermeture
   de compte chauffeur avec suppression de documents n'existe dans le repo
   (voir Z-4) — par défaut, tout reste en place indéfiniment.
5. **Conservation pour litige/audit** : les pièces d'identité/permis/
   assurance/immatriculation sont exactement le type de donnée qui peut être
   requise en cas de litige (accident, fraude, contrôle réglementaire) —
   une suppression immédiate après rejet/fermeture serait risquée sans
   décision légale explicite.

**Conclusion Z-3** : `RETENTION POLICY DECISION REQUIRED — PHASE 8` — la
distinction entre « techniquement supprimable » (aujourd'hui : rien, car
aucune fonction de suppression n'existe) et « doit être supprimé après X
jours » (une politique métier/légale non définie dans ce projet) est
confirmée. **Aucune suppression automatique n'est implémentée ce tour**,
conformément à la consigne (« ne supprime rien automatiquement simplement
parce qu'un chauffeur est rejeté »).

## Z-4 — Account deletion : stratégie technique

**État actuel confirmé** : **aucun workflow technique de suppression de
compte n'existe dans le repo** (recherche `deleteAccount`/`deleteUser`/
`accountDeletion` = 0 résultat dans `functions/src`). Ce tour définit donc
une **stratégie minimale claire**, sans l'implémenter en fonction complète
(hors scope Phase 7 — pas de nouvelle Cloud Function de suppression créée
ce tour, car cela nécessiterait des décisions Z-1/Z-3 encore ouvertes
`POLICY/LEGAL DECISION REQUIRED`).

### Données supprimables / anonymisables (candidates)

- Préférences utilisateur non critiques (si elles existent côté app —
  aucune trouvée dans les collections serveur actuelles au-delà du profil).
- Champs de profil non requis pour l'historique financier :
  `customer_display_name`/`driver profile display fields` → remplaçables
  par un placeholder anonymisé (ex. `"Utilisateur supprimé"`), PAS une
  suppression du document entier tant qu'une mission/ledger y référence
  l'UID.
- Tokens push/notification (si stockés — non trouvés dans les collections
  actuelles, probablement gérés côté client/FCM uniquement).
- Notifications (`users/{uid}/notifications/{id}`) — purge technique
  possible sans impact finance/audit (voir Z-1, Système).
- Compte Firebase Auth lui-même (email/téléphone) — supprimable via
  `admin.auth().deleteUser(uid)`, ce qui retire l'accès mais NE DOIT PAS
  supprimer les documents Firestore liés au ledger/finance.

### Données à NE JAMAIS détruire à l'aveugle

- `transaction_ledger/*` (append-only par conception).
- `payments/*`, `driver_payouts/*`, `refunds/*`, `disputes/*`.
- `financial_snapshots/*` (immuable une fois `confirmed`).
- `audit_logs/*`.
- Preuves liées à un litige potentiel (`delivery_proofs/*`, documents
  chauffeur tant qu'un litige n'est pas clos — voir Z-3).

### Stratégie recommandée (à implémenter en Phase 8 une fois les décisions
Z-1/Z-3 tranchées) : **delete/anonymize user-facing personal data, préserver
les enregistrements financiers/historiques**

1. Supprimer le compte Firebase Auth (email/téléphone/mot de passe) —
   révoque l'accès immédiatement.
2. Anonymiser (PAS supprimer) les champs PII directement lisibles sur
   `users/{uid}` / `driver_profiles/{uid}` référencés par des missions
   existantes (nom affiché, coordonnées) — remplacer par un placeholder
   stable, conserver le document (l'UID reste la clé étrangère du ledger).
3. Purger sans risque : `notifications` (sous-collection de l'utilisateur).
4. **NE JAMAIS** supprimer en cascade `delivery_requests`, `payments`,
   `transaction_ledger`, `financial_snapshots`, `audit_logs`,
   `driver_documents` référencés par cet UID — ces documents restent, avec
   l'UID comme référence opaque après anonymisation du profil.
5. Documents chauffeur (permis, assurance, etc.) : rester en place (voir
   Z-3), sauf décision légale explicite Phase 8 imposant une suppression
   après un délai précis.

**Aucun delete cascade dangereux n'est proposé ni implémenté** — la
stratégie ci-dessus est délibérément conservatrice (anonymisation plutôt que
destruction) tant que la politique légale n'est pas tranchée.

## Z-5 — Financial safety : invariants (aucun workflow de suppression implémenté ce tour)

**Confirmation** : aucun workflow `account deletion` n'existe en Phase 7 —
donc aucun risque actuel de suppression accidentelle des enregistrements
financiers via ce chemin (le risque n'existe pas encore techniquement).

**Invariants que Phase 8 DEVRA respecter** lors de l'implémentation d'un
futur workflow de suppression de compte :

| Invariant | Preuve structurelle actuelle |
|---|---|
| Le ledger ne doit jamais être modifié/supprimé par un flux de suppression de compte | `transaction_ledger` n'a aucune fonction d'update/delete dans tout le repo (grep confirmé : seules des créations `tx.set()`/`db.collection("transaction_ledger").doc()` existent, jamais de `.update()`/`.delete()`) |
| Les payouts/refunds/disputes historiques doivent rester intacts | Idem — aucune fonction de suppression sur ces collections dans le repo actuel |
| Les financial snapshots confirmés sont déjà protégés contre toute modification | `completeDelivery.ts` : `if (snapshot.status === "confirmed") throw failedPrecondition(...)` — protection déjà en place au niveau applicatif, avant même un futur flux de suppression |
| La réconciliation ne doit jamais être invalidée par une suppression de profil | `reconciliationEngine.ts` compare des IDs (`payment_id`, `payout_id`, etc.) — tant que ces documents financiers restent en place (Z-4), la réconciliation reste valide même si le profil utilisateur est anonymisé |

**Conclusion Z-5** : aucun test supplémentaire n'est nécessaire ce tour (le
risque n'existe pas tant qu'aucun code de suppression de compte n'est
écrit) — mais les invariants ci-dessus sont **documentés explicitement**
pour contraindre toute implémentation Phase 8 (« ne jamais construire un
delete cascade sur ces collections »).

## Z-6 — Orphan files (P-7, repris)

**Rappel du gap connu** (déjà documenté en Bloc P, `docs/PHASE7_QA_MATRIX.md`
P-7) : `completeDelivery.ts` — le client uploade la preuve de livraison
directement via le SDK Storage (`delivery_proofs/{missionId}/{fileName}`,
gouverné par `storage.rules`, indépendant de Firestore) PUIS appelle
`completeDelivery(missionId, proofOfDeliveryUrl)`. Si l'étape Firestore
échoue (contention, statut déjà terminal, snapshot déjà confirmé), le
fichier Storage déjà uploadé n'est référencé par aucun document Firestore
→ orphelin potentiel.

**Évaluation d'une solution sûre maintenant** :

Un cleanup scheduled nécessiterait de :
1. Lister les fichiers sous `delivery_proofs/{missionId}/*` (nécessite
   `admin.storage().bucket().getFiles({ prefix: "delivery_proofs/" })` —
   opération potentiellement coûteuse à l'échelle, doit être paginée).
2. Pour chacun, vérifier si `delivery_requests/{missionId}.proof_of_delivery_url`
   référence bien ce fichier.
3. Si NON référencé **ET** que le fichier a dépassé une période de grâce
   (ex. 24-48h, pour ne jamais supprimer un fichier tout juste uploadé dont
   l'appel `completeDelivery` est simplement en vol/retry) → candidat à la
   suppression.
4. Journaliser (audit) chaque suppression avec l'identité du fichier et la
   preuve d'absence de référence.

**Décision de ce tour** : **NE PAS implémenter ce cleanup maintenant.**
Justification :
- Le gap est déjà classé `DEFERRED NON-BLOCKING` en Bloc P avec analyse de
  fréquence détaillée (fenêtre de contention étroite, aucune fuite de
  sécurité — le fichier orphelin reste protégé par les mêmes règles Storage
  que les fichiers valides).
- L'implémentation sûre nécessite un listing Storage paginé + une logique
  de grâce period non triviale — risque de complexité/bugs disproportionné
  par rapport à l'impact réel (coût de stockage négligeable, aucune fuite).
- Respecte la consigne explicite : « NE PAS supprimer immédiatement, NE PAS
  supprimer un fichier uniquement parce qu'une lecture Firestore temporaire
  échoue » — une implémentation précipitée sous contrainte de temps risque
  de violer cette règle plus sûrement qu'un report documenté.

**`DEFERRED NON-BLOCKING → Phase 8`** avec l'algorithme recommandé
ci-dessus (listing paginé + vérification de référence + grace period ≥
24-48h + suppression uniquement après preuve d'orphelin + audit log par
suppression). Aucune régression introduite : le comportement actuel
(fichier orphelin rare, non exploitable, coût négligeable) est inchangé.

## Z-7 — Logs / retention (référence Bloc Y)

Référence directe à `docs/MONITORING_RUNBOOK.md` (Y-2) : le module
`sanitizeMetadata()` de `lib/observability.ts` garantit déjà qu'aucun log
structuré ne contient :
- secrets/tokens/clés API/mots de passe/credentials (clés interdites +
  patterns de valeurs Stripe/Bearer) ;
- aucun document d'identité complet (les logs financiers ne transmettent
  que des identifiants métier — `mission_id`, `payment_id`, etc. — jamais
  le contenu d'un document chauffeur) ;
- aucun payload bancaire (aucune Function ne journalise de numéro de
  carte/CVC — `card_number`/`cvc` sont explicitement dans
  `FORBIDDEN_KEY_PATTERNS`).

**Durée de rétention Cloud Logging** : non configurée dans le code de ce
repo (c'est un paramètre de configuration GCP, pas applicatif) —
`Phase 8 — GCP/Firebase retention configuration` (définir la durée de
rétention des logs dans Google Cloud Logging pour le projet
`movik-connect-prod`, actuellement la valeur par défaut GCP s'applique tant
que non configurée explicitement).

## Z-8 — Privacy access boundaries (sanity, référence Blocs P/Q)

Vérification légère (pas de ré-audit complet des Security Rules,
conformément à la consigne) — confirmée par référence aux preuves déjà
établies en Blocs P/Q/V :

| Vérification | Preuve de référence |
|---|---|
| Client A ne lit pas client B | `securityRules.test.ts` (Bloc V, L827 — cross-customer refusé) |
| Chauffeur A ne lit pas documents chauffeur B | `storage.rules` — `driver_documents/{driverId}/{fileName}` : `allow read: if uid() == driverId \|\| isAnalystOrAbove()` — un autre chauffeur (`uid() != driverId`, pas analyst+) est explicitement exclu |
| Preuve de mission privée non accessible cross-user | `storage.rules` — `delivery_proofs/{missionId}/{fileName}` : lecture limitée au `customer_id`/`driver_id` de LA mission (lookup Firestore) ou analyst+ ; confirmé Bloc P (P-6, `storageRules.test.ts` 19/19 PASS) |
| Admin/analyst uniquement selon rôle prévu | `isAnalystOrAbove()`/`requireAdminOrAbove()` — hiérarchie de rôles déjà testée (`adminPrivilegedActions.test.ts`, Bloc V) |

**Conclusion Z-8** : sanity confirmée par référence aux preuves existantes,
aucune Security Rule modifiée ce tour.

## DONE Z

| Critère | Statut |
|---|---|
| Inventory complet | ✅ Z-1 (Client/Chauffeur/Mission/Finance/Système) |
| GPS retention | ✅ Z-2 (mécanisme existant prouvé par référence, 30 jours = `CURRENT TECHNICAL CONFIGURATION`) |
| Driver docs strategy | ✅ Z-3 (rien n'est techniquement supprimable aujourd'hui ; remplacement ≠ suppression ; `RETENTION POLICY DECISION REQUIRED — PHASE 8`) |
| Account deletion strategy | ✅ Z-4 (aucun workflow existant ; stratégie minimale anonymize-not-destroy documentée pour Phase 8) |
| Finance protégée contre delete destructif | ✅ Z-5 (invariants documentés ; aucun risque actuel car aucun workflow de suppression n'existe) |
| Logs/privacy | ✅ Z-7 (référence Bloc Y, garanties `sanitizeMetadata` confirmées) |
| Orphan files traités ou deferred avec plan précis | ✅ Z-6 (`DEFERRED NON-BLOCKING → Phase 8` avec algorithme recommandé) |
| Décisions policy/légal séparées du code | ✅ Toutes les durées non codées sont marquées `POLICY/LEGAL DECISION REQUIRED — PHASE 8`, jamais inventées |
| P0 ouverts | ✅ 0 |
| P1 ouverts | ✅ 0 |

**Aucun code applicatif modifié dans ce bloc** — Z est un bloc de
cartographie/stratégie/documentation, pas de correctif de code (aucun GAP
RÉEL nécessitant un correctif immédiat n'a été trouvé : les mécanismes
existants — GPS retention, immutabilité Storage/ledger/snapshots — sont
déjà corrects par conception).

# BLOC Z : ✅ FERMÉ
