# MOVI-K — DISASTER RECOVERY (Phase 7, Bloc AA)

Ce document couvre AA-1 → AA-9. Aucun engagement commercial (RPO/RTO) n'est
inventé, aucune action destructive n'a été exécutée sur une ressource réelle
— tout ce qui est marqué `EXTERNAL CONFIGURATION REQUIRED`/`DECISION
REQUIRED BEFORE PRODUCTION` reste explicitement une décision Phase 8.

## AA-1 — Critical Data Map

| Donnée | Criticité | Reconstructible ? | Source de vérité | Récupération |
|---|---|---|---|---|
| `users/{uid}` (profils) | Moyenne | Partiellement (Firebase Auth reste la source d'identité — email/uid) | Firestore + Firebase Auth | Recréation manuelle du profil Firestore possible depuis Auth si le document est perdu (perte d'historique de préférences uniquement) |
| `driver_profiles/{id}` | Élevée | Non (statut d'approbation, historique de missions complétées, vérifications) | Firestore uniquement | Aucune reconstruction automatique — perte = ré-onboarding complet requis |
| `delivery_requests/{id}` | Élevée | Non (contenu métier unique par mission) | Firestore uniquement | Aucune reconstruction — perte = perte de l'historique de la mission |
| `financial_snapshots/{id}` | **Très élevée** | Non (montant gelé au moment de la livraison, dépend de `pricing_versions` au moment T) | Firestore uniquement, **immuable une fois `confirmed`** | Aucune reconstruction fiable après coup — priorité maximale de sauvegarde |
| `transaction_ledger/{id}` | **Très élevée** (priorité maximale) | Non — livre comptable append-only, aucune fonction de ré-génération | Firestore uniquement | Aucune reconstruction — c'est la source de vérité comptable elle-même |
| `payments/{id}` | **Très élevée** (priorité maximale) | Partiellement — Stripe conserve sa propre trace des PaymentIntents/Charges (source externe indépendante), mais le lien `mission_id ↔ payment_id` n'existe que côté Movi-K | Firestore + Stripe (partiel) | Réconciliable via `runReconciliation()` en comparant Firestore ↔ Stripe (AA-4) |
| `driver_payouts/{id}` | **Très élevée** | Partiellement (Stripe Connect conserve la trace du transfert lui-même) | Firestore + Stripe Connect (partiel) | Idem — réconciliable, jamais reconstructible à l'identique côté métadonnées Movi-K (`financial_snapshot_ids`, etc.) |
| `refunds/{id}` | Élevée | Partiellement (Stripe conserve la trace du refund lui-même) | Firestore + Stripe (partiel) | Réconciliable |
| `disputes/{id}` | Élevée | Partiellement (Stripe conserve la trace du litige) | Firestore + Stripe (partiel) | Réconciliable |
| `audit_logs/{id}` | Élevée (preuve d'imputabilité) | Non | Firestore uniquement | Aucune reconstruction — perte = perte de traçabilité historique |
| `system_config/runtime_flags` | Faible en donnée, **critique en conséquence** (voir AA-5) | Oui — 4 booléens, reconstructible à l'identique (fail-safe déjà codé : absence = tout à `false`, jamais une valeur dangereuse par défaut) | Code (`runtimeFlags.ts`) + Firestore | Reconstruction triviale (bootstrap automatique déjà implémenté, Bloc X) |
| `pricing_configs/active` + `pricing_versions/{id}` | Élevée | Reconstructible SI la configuration métier (tarifs) est documentée ailleurs (ex. tableur produit) — sinon perdue | Firestore uniquement (pas de source externe) | Aucune reconstruction automatique — absence => `failedPrecondition` (fail-safe, aucune mission créée avec un tarif erroné, voir AA-5) |
| `payout_policy_configs/default` | Élevée | Idem pricing — dépend d'une doc externe au produit | Firestore uniquement | Idem |
| `tax_configs/{jurisdiction}` | Élevée (obligation fiscale) | Reconstructible SI les taux légaux sont redocumentés depuis la source officielle (gouvernementale) | Firestore uniquement | Idem — absence => échec explicite, jamais un taux à 0% par défaut (voir `taxEngine.ts`) |
| `driver_documents/{id}` (métadonnées) + Storage `driver_documents/{driverId}/*` | Très élevée (conformité réglementaire) | Non (pièces originales du chauffeur) | Firestore + Storage | Aucune reconstruction — perte = re-demande de documents au chauffeur (`requestDriverDocuments.ts`) |
| Storage `delivery_proofs/{missionId}/*` | Élevée (preuve légale) | Non | Storage uniquement | Aucune reconstruction — perte = perte de la preuve de livraison |

**Priorité maximale confirmée** : `transaction_ledger` (aucune trace
externe, aucune reconstruction possible) + `financial_snapshots` confirmés
(montant gelé) + `payments`/`driver_payouts`/`refunds`/`disputes`
(partiellement réconciliables via Stripe, mais les métadonnées métier
Movi-K elles-mêmes ne le sont pas).

## AA-2 — Backups : état honnête

**Rien n'est déclaré comme actif sans preuve.**

### Déjà protégé (aujourd'hui, sans configuration externe supplémentaire)

| Élément | Protection réelle |
|---|---|
| Code source (Functions, Flutter, Security Rules, docs) | Git (`Solexiai/mecano-mobile`), historique complet, multiples PRs mergées — protection réelle et déjà active |
| Secrets Stripe (`STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`) | Google Cloud Secret Manager (`defineSecret`, `functions/src/lib/secrets.ts`) — jamais commités, gérés par l'infrastructure GCP native (Secret Manager a sa propre durabilité/versioning, indépendante d'un "backup Movi-K" explicite) |
| Données de paiement/refund/dispute/payout côté Stripe | Stripe conserve sa propre trace des objets qu'il a créés (PaymentIntent, Charge, Refund, Transfer, Dispute) — **source externe indépendante de Firestore**, exploitable pour réconciliation même si Firestore est perdu |
| Firestore Security Rules / Storage Rules | Versionnées dans Git (`firestore.rules`, `storage.rules`) — redéployables depuis le dernier commit connu bon |

### Nécessite Phase 8 — `EXTERNAL CONFIGURATION REQUIRED`

| Élément | Constat honnête |
|---|---|
| **Firestore scheduled backups / PITR (Point-In-Time Recovery)** | **Aucune preuve dans ce repo qu'une exportation planifiée Firestore ou un PITR soit activé** sur le projet `movik-connect-prod` — ceci se configure exclusivement dans la console GCP (`gcloud firestore export` planifié, ou activation PITR), jamais via du code applicatif. **Ne pas supposer que cela existe.** |
| **Storage backup/recovery** (documents chauffeur, preuves de livraison) | Aucune règle de versioning/lifecycle Cloud Storage n'est configurée dans ce repo (`storage.rules` ne gère que les permissions d'accès, pas la durabilité/versioning des objets). Nécessite configuration GCS (Object Versioning, ou export périodique) côté console. |
| **Secrets/configuration externe** | Le contenu réel des secrets (valeurs Stripe) n'est backupé nulle part dans ce repo par conception (sécurité) — leur récupération dépend entièrement de Google Secret Manager et du compte Stripe Movi-K lui-même (hors du périmètre technique de ce repo). |
| **Monitoring alert destinations** | Aucune destination d'alerte externe (email/Slack/PagerDuty) n'est configurée — voir Bloc Y (Y-6), reporté à Phase 8. |

**Conclusion AA-2** : la seule sauvegarde réellement active aujourd'hui est
le code source (Git). **Les données Firestore/Storage n'ont aucune
sauvegarde automatisée confirmée** — c'est le risque le plus important
identifié dans ce bloc, à traiter en priorité en Phase 8 avant toute mise
en production à volume significatif.

## AA-3 — Incident Runbook

Procédure concrète, réutilisant les kill switches Bloc X et le moteur de
réconciliation Bloc G :

1. **Détecter l'incident** — via les signaux Bloc Y (`docs/MONITORING_RUNBOOK.md`) : logs structurés `severity=ERROR`, `reconciliation_anomaly_detected`, alerte Phase 8 une fois branchée.
2. **Classifier la SEV** — voir AA-7 (SEV-1/2/3).
3. **Activer les kill switches nécessaires** — via `updateRuntimeFlags` (admin-only) : `payments_enabled: false` pour stopper toute nouvelle exposition financière, `accept_new_delivery_requests: false`/`allow_driver_acceptance: false` si le problème touche le cycle de mission. **Ne bloque jamais** les refunds/disputes/compensations/corrections déjà en cours (garantie déjà prouvée par `runtimeFlags.test.ts` sections D/E/G).
4. **Empêcher une nouvelle exposition financière** — confirmé par l'étape 3 (kill switch `payments_enabled`/`driver_payouts_enabled`).
5. **Préserver l'état actuel** — NE RIEN modifier manuellement dans Firestore pendant l'investigation (aucune correction ad hoc sur `transaction_ledger`/`financial_snapshots`/`payments` — voir AA-4, règle absolue).
6. **Identifier la fenêtre d'impact** — déterminer `periodStartMillis`/`periodEndMillis` à partir des logs/timestamps de l'incident.
7. **Comparer Firestore/provider** — exécuter `runReconciliationNow` (callable admin) sur la fenêtre identifiée — réutilise le moteur existant, ne modifie rien.
8. **Restaurer/réconcilier** — voir AA-4 : jamais une modification directe, toujours une nouvelle entrée compensatrice si une correction financière est nécessaire.
9. **Lancer les tests** — rejouer la suite Jest pertinente (unit + integration ciblée) avant toute réactivation, pour confirmer qu'aucune régression n'accompagne le correctif appliqué.
10. **Réactiver progressivement** — remettre les kill switches à `true` un par un (`updateRuntimeFlags`), en commençant par le moins risqué (ex. `accept_new_delivery_requests` avant `payments_enabled`), en observant les logs entre chaque étape.
11. **Surveiller** — suivre les logs structurés Bloc Y pendant les heures suivant la réactivation, avant de considérer l'incident clos.

## AA-4 — Financial Recovery

Réutilisation stricte des mécanismes existants — **aucun nouveau mécanisme
de "réparation" créé**.

| Scénario | Mécanisme existant réutilisé |
|---|---|
| **Paiement provider réussi / réponse perdue** (timeout réseau après capture Stripe réussie) | `idempotency.ts` (`buildIdempotencyKey`/`acquireIdempotencyLockInTransaction`) — un retry avec la même clé déterministe ne ré-exécute jamais l'effet financier ; + `runReconciliation()` détecte `payment_missing_in_movik`/`payment_amount_mismatch` si l'écriture Firestore elle-même a été perdue malgré la capture Stripe réussie |
| **Payout provider réussi / Firestore incomplet** | `runReconciliation()` détecte `payout_missing`/`payout_amount_mismatch` — **jamais un second payout aveugle** : la primitive d'idempotence (`submitDriverPayout`, clé déterministe par snapshot) empêche techniquement un double versement pour la même clé ; toute correction identifiée passe par une investigation admin puis, si nécessaire, `reverseDriverPayout` (compensation, jamais une modification rétroactive) |
| **Refund provider effectué / ledger incomplet** | Détecté par `runReconciliation()` (`refund_missing_in_ledger`) ; correction = **nouvelle entrée de ledger compensatrice** créée via les primitives existantes (`createLedgerEntry`/`refundPayment`), jamais une édition du ledger existant |
| **Webhook manqué** | `processStripeWebhook.ts` + `provider_webhook_events` (statut `received`/`processed`/`failed`) — un webhook manqué reste `received` au-delà du seuil de 15 min, détecté par `runReconciliation()` (`webhook_unprocessed`, **prouvé par le DR exercise AA-9** ci-dessous) ; le traitement idempotent (`processing_status`) permet un replay sûr sans double effet |
| **Dispute/chargeback** | `disputeOrchestration.ts` (orchestration existante, Bloc Y confirmé couvert) — le cycle de vie de la dispute (created/under_review/won/lost/closed) et l'entrée ledger `CHARGEBACK_FEE`/`CHARGEBACK_WON` associée suivent le mécanisme déjà en place, jamais modifié |

### Règle absolue (rappelée, non négociable)

> **NE JAMAIS MODIFIER DIRECTEMENT UNE ENTRÉE LEDGER HISTORIQUE IMMUTABLE
> POUR "RÉPARER".** Toute correction financière → **nouvelle entrée
> compensatrice**. Confirmé structurellement : aucune fonction du repo
> n'expose de `.update()`/`.delete()` sur `transaction_ledger` (grep
> vérifié, Bloc Z Z-5) — cette règle est déjà appliquée par construction,
> pas seulement documentée.

## AA-5 — Config Recovery

| Config | Comportement en cas de perte/absence |
|---|---|
| `system_config/runtime_flags` | **Fail closed** — `resolveRuntimeFlag()` retourne `enabled: false` pour tout flag si le document est absent, un champ est absent, ou le type est invalide (`reason: document_missing`/`field_missing`/`field_invalid_type`) — **prouvé par le DR exercise AA-9 ci-dessous ET par `runtimeFlags.test.ts` section A** (déjà existant, Bloc X, non modifié). Une perte de config ne permet donc **jamais** une opération risquée par défaut. |
| `pricing_configs/active` / `pricing_versions/{id}` | Échec explicite (`failedPrecondition("Aucune configuration tarifaire active")`) dans `calculateDeliveryQuote.ts` — aucune mission n'est créée avec un tarif absent/incorrect ; fail-safe déjà en place, confirmé par lecture de code (Bloc AA, ce tour) |
| `payout_policy_configs/default` | `calculateDriverPayout.ts` lit ce document (jamais hardcodé, voir commentaire du fichier) — une absence provoquerait un échec similaire (à vérifier explicitement en Phase 8 si un scénario de perte totale de cette config n'a pas de test dédié aujourd'hui — **point de vigilance non-bloquant**, pas un gap prouvé ce tour) |
| `tax_configs/{jurisdiction}` | `taxEngine.ts` — un taux absent ne doit jamais défaut à 0% silencieusement (principe déjà documenté dans le code, Bloc E du projet) |

**Reconstruction** : `system_config/runtime_flags` se reconstruit
automatiquement au premier appel admin (`ensureRuntimeFlagsBootstrapped()`,
Bloc X, X-13) — pas d'action manuelle nécessaire au-delà du premier appel
`updateRuntimeFlags`. Les configs pricing/payout/tax nécessitent une
re-saisie manuelle via les callables admin dédiés
(`updatePricingConfiguration`, `updatePayoutPolicyConfiguration`, etc.) à
partir d'une source externe au code (tableur produit/taux légaux) — **pas
de mécanisme de sauvegarde/restauration automatique de leur CONTENU
métier** (seule la structure/fail-safe est garantie par le code).

## AA-6 — Deployment Rollback

Procédure simple, sans nouvelle infrastructure CI/CD (aucune n'existe dans
ce repo — confirmé, `find .github` = vide) :

1. **Identifier le dernier commit Git connu bon** — `git log --oneline` sur
   `main`, repérer le dernier tag/merge PR validé (ex. `fce2641` = fin Bloc
   X, `7060189` = fin Bloc Y, etc.).
2. **Activer les kill switches si nécessaire** — si le mauvais déploiement a
   introduit un risque financier actif (voir AA-3).
3. **Rollback/redéployer la version précédente** — `git checkout
   <bon-commit>` (ou `git revert` du commit fautif) puis redéployer via
   `firebase deploy --only functions` (Functions) et/ou `flutter build` +
   republication (client) selon la plateforme touchée. `firebase.json`
   confirme déjà un `predeploy` (`lint` + `build`) qui bloque un déploiement
   cassé avant même l'upload.
4. **Validation ciblée** — rejouer au minimum la suite Jest ciblée sur les
   fonctions touchées par le rollback (pas nécessairement toute la suite
   556 tests si le rollback est localisé), puis `flutter test`/`flutter
   analyze` si le client a été redéployé.
5. **Réouverture progressive** — même logique que AA-3, étape 10.

Même logique pour le client (Flutter/mobile ou web) : identifier la
dernière version publiée stable, revenir à cette version via le store/la
plateforme de distribution concernée, republier depuis le commit Git
correspondant.

## AA-7 — Incident Severity

| Sévérité | Exemples Movi-K |
|---|---|
| **SEV-1** | Fuite de données (PII/documents d'identité exposés), paiement incorrect massif (montant erroné sur de nombreuses missions), payout incorrect massif, corruption du `transaction_ledger`, compromission auth/admin (accès admin non autorisé) |
| **SEV-2** | Missions indisponibles (dispatch en panne généralisée), paiement fortement dégradé (taux d'échec élevé mais pas total), tracking généralisé défaillant, notification critique dégradée à grande échelle |
| **SEV-3** | Erreur isolée (un utilisateur, une mission), problème UX sans risque financier/sécurité (ex. notification manquée isolée — voir Bloc Y GAP corrigé) |

Classification volontairement simple (3 niveaux), cohérente avec la
politique d'alerte Bloc Y (SEV/CRITICAL ≈ SEV-1, HIGH ≈ SEV-2, MEDIUM ≈
SEV-3) — pas de système de sévérité complexe supplémentaire créé ce tour.

## AA-8 — RPO / RTO

**`RPO/RTO TARGETS — DECISION REQUIRED BEFORE PRODUCTION`**

Aucun engagement commercial de temps de récupération (RTO) ni de perte de
données maximale tolérée (RPO) n'est inventé dans ce document — ces cibles
dépendent de décisions produit/business (budget infrastructure, criticité
perçue par les parties prenantes, contraintes réglementaires locales) qui
n'ont pas été tranchées dans ce projet.

**Recommandations techniques séparées** (à valider par la décision
business ci-dessus, PAS un engagement) :
- Compte tenu de l'absence confirmée de backup Firestore/Storage actif
  (AA-2), le RPO réel actuel serait `illimité` (aucune garantie de
  récupération de données en cas de perte du projet Firestore) — activer
  au minimum un export Firestore planifié quotidien réduirait le RPO
  technique à ~24h, sans configuration supplémentaire.
- Le RTO dépend principalement du temps de reconstruction manuelle des
  configs (pricing/payout/tax — AA-5) et de la disponibilité d'un
  administrateur pour réactiver les kill switches (AA-3) — un exercice DR
  périodique (voir AA-9) permettrait de mesurer un RTO réel plutôt que de
  l'estimer.

## AA-9 — DR Exercise (non destructif, émulateur)

**Implémenté ce tour** : `functions/test/integration/disasterRecovery.test.ts`
— 3 tests, **3/3 PASS** (voir preuve ci-dessous), exécutés exclusivement sur
l'émulateur Firestore (`demo-movik-test`), **aucune donnée de production**.

### Scénario A — Config runtime absente/corrompue → fail closed → restauration

1. Suppression du document `system_config/runtime_flags` (simule une perte
   de config).
2. Vérification : les 4 flags (`accept_new_delivery_requests`,
   `allow_driver_acceptance`, `payments_enabled`,
   `driver_payouts_enabled`) résolvent `enabled: false`,
   `reason: document_missing` — **fail closed prouvé**.
3. Restauration d'une config valide (`seedRuntimeFlags()`).
4. Vérification : effet immédiat au prochain appel — les 4 flags repassent
   à `true` sans délai de propagation (pas de cache).

### Scénario B — Incohérence financière réconciliable (webhook_unprocessed)

1. Seed d'un `provider_webhook_events` reçu il y a 20 minutes, jamais passé
   à `processed` (simule un incident réel de traitement webhook).
2. Exécution de `runReconciliation()` (mécanisme **existant**, non modifié)
   sur une fenêtre couvrant l'évènement.
3. Vérification : l'anomalie `webhook_unprocessed` est détectée,
   `report.status === "anomaly"`.
4. Vérification : le document source `provider_webhook_events` reste
   **inchangé** (`processing_status` toujours `received`,
   `processed_at` toujours `null`) — aucune correction silencieuse.
5. Vérification : **aucune** entrée `transaction_ledger` créée par ce
   mécanisme (comptage avant/après identique).
6. Vérification : une seule écriture produite — le
   `reconciliation_reports/{reportId}` lui-même.

### Preuve d'exécution

```
Test Suites: 1 passed, 1 total
Tests:       3 passed, 3 total
  ✓ config absente : les 4 flags résolvent enabled=false (fail closed, aucune opération risquée permise)
  ✓ restauration de la config -> effet immédiat, aucun flag ne reste bloqué par un cache
  ✓ détecte webhook_unprocessed SANS modifier la source ni créer d'entrée ledger
```

## Phase 8 — External actions identifiées (récapitulatif)

| Action | Référence |
|---|---|
| Activer un export Firestore planifié (ou PITR) | AA-2, AA-8 |
| Activer un backup/versioning Cloud Storage | AA-2 |
| Configurer les destinations d'alerte (email/Slack/GCP Monitoring) | AA-2, Bloc Y (Y-6) |
| Décider des cibles RPO/RTO officielles | AA-8 |
| Décider des durées de rétention légales (données PII, documents chauffeur, logs) | Bloc Z |

## DONE AA

| Critère | Statut |
|---|---|
| Critical data map | ✅ AA-1 |
| Backup state honnête | ✅ AA-2 (aucune sauvegarde Firestore/Storage active confirmée — risque identifié explicitement, pas caché) |
| Runbook incident | ✅ AA-3 (11 étapes, réutilise Bloc X) |
| Financial recovery | ✅ AA-4 (mécanismes existants réutilisés, règle immuable rappelée et vérifiée structurellement) |
| Config recovery | ✅ AA-5 (fail-closed prouvé par test, AA-9) |
| Rollback | ✅ AA-6 (procédure Git simple, sans nouvelle CI/CD) |
| SEV classification | ✅ AA-7 (3 niveaux, exemples Movi-K) |
| RPO/RTO non inventés | ✅ AA-8 (`DECISION REQUIRED BEFORE PRODUCTION` + recommandations séparées) |
| DR exercise/test | ✅ AA-9 — `disasterRecovery.test.ts`, 3/3 PASS, émulateur uniquement, aucune donnée production |
| Phase 8 external actions identifiées | ✅ (tableau récapitulatif ci-dessus) |
| P0 ouverts | ✅ 0 |
| P1 ouverts | ✅ 0 |

**Preuves de non-régression** : `npx tsc --noEmit` (0 erreur), `npm run
lint` (0 warning), `disasterRecovery.test.ts` (3/3 PASS).

# BLOC AA : ✅ FERMÉ
