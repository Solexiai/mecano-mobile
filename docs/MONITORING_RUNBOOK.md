# MOVI-K — MONITORING / ALERTS RUNBOOK (Phase 7, Bloc Y)

Ce document couvre Y-1 → Y-6. Il ne remplace pas `docs/PHASE7_QA_MATRIX.md`
(preuves de tests) : il documente la **stratégie d'observabilité et
d'alerting** production, à partir de l'infrastructure déjà construite en
Phase 6 (`functions/src/lib/observability.ts`, `functions/src/lib/audit.ts`).

Aucune donnée sensible n'est jamais journalisée (voir Y-2) : le module
`observability.ts` sanitize récursivement toute métadonnée (clés/valeurs
ressemblant à un secret, token, mot de passe, clé API Stripe, etc. →
`[REDACTED]`), et tous les correctifs de ce bloc ne transmettent que des
identifiants métier (`mission_id`, `error_code`, compteurs), jamais de PII.

## Y-1 — Matrice courte : incident → signal → alerte → statut

| # | Incident critique | Signal/log existant | Alerte possible (Y-5) | Statut |
|---|---|---|---|---|
| 1 | Création mission échouée | `createDeliveryRequest` lève une `HttpsError` typée (`invalid-argument`/`failed-precondition`/`permission-denied`) — capturée nativement par Cloud Functions (Cloud Logging, sévérité ERROR, stack trace) | MEDIUM si isolé, HIGH si taux d'erreur massif | **COUVERT** (natif) |
| 2 | Dispatch échoué (aucun chauffeur trouvé) | **GAP → CORRIGÉ ce tour** : `dispatchMissionToDrivers.ts` journalise désormais `logFinancialFailure("dispatch_no_driver_available", ...)` avec `mission_id`, `error_code`, `candidatesScanned`, `zonePrefix` | MEDIUM si isolé (comportement métier normal — élargissement de zone), HIGH si répétition massive sur une zone/période | **CORRIGÉ** |
| 3 | Paiement échoué (autorisation/capture) | `paymentOrchestration.ts` — 19 sites `logFinancialSuccess`/`logFinancialFailure` (autorisation, capture, échec carte, etc.) | CRITICAL si généralisé, MEDIUM si isolé (carte refusée = normal) | **COUVERT** (Phase 6) |
| 4 | Payout échoué | `calculateDriverPayout.ts` + `paymentOrchestration.ts` (`submitDriverPayout`) — logs succès/échec + `audit_logs` | CRITICAL si généralisé/montant incorrect, MEDIUM si isolé (retry auto via `driver_payouts_enabled`) | **COUVERT** (Phase 6) |
| 5 | Refund échoué | `refundPayment.ts` (callable, audit + `logFinancialSuccess("refund_requested", ...)`) + orchestration (succès/échec) | CRITICAL si incohérence financière, MEDIUM si isolé | **COUVERT** (Phase 6) |
| 6 | Webhook Stripe échoué/non traité | `processStripeWebhook.ts` — logs succès/échec par type d'évènement (payment/refund/payout/dispute) | HIGH si erreurs continues sur le même endpoint | **COUVERT** (Phase 6) |
| 7 | Dispute/chargeback | `disputeOrchestration.ts` — logs sur création/mise à jour de dispute + `audit_logs` | CRITICAL (impact financier direct) | **COUVERT** (Phase 6) |
| 8 | Reconciliation anomaly | `reconciliationEngine.ts` journalise explicitement `logFinancialFailure("reconciliation_anomaly_detected", ...)` avec `anomalyCount`/`anomalyTypes` | HIGH (déclenche investigation), CRITICAL si volume élevé | **COUVERT** (Phase 6) |
| 9 | Tracking backend (position GPS) | `recordTrackingPoint` — échecs de précondition (`profil introuvable`) levés en `HttpsError` (log natif) ; écriture historique silencieusement ignorée seulement si aucune mission active réelle (comportement voulu, pas une erreur) | MEDIUM si taux d'échec `HttpsError` élevé | **COUVERT** (comportement défensif volontaire + erreurs réelles déjà loguées nativement) |
| 10 | Notification client manquée | **GAP → CORRIGÉ ce tour** : `onMissionStatusChangeNotifyCustomer.ts` journalise désormais `logFinancialSuccess`/`logFinancialFailure("mission_notification_created", ...)` autour de l'écriture Firestore, sans jamais faire échouer le trigger | MEDIUM (dégradé, non bloquant pour la mission) | **CORRIGÉ** |
| 11 | Kill switch modifié | `updateRuntimeFlags.ts` → `writeAuditLogInTransaction` (acteur, rôle, old/new values, `changedKeys`, `wasBootstrapped`, timestamp serveur) — preuve permanente : `runtimeFlags.test.ts` section I (29/29 PASS) | HIGH (toute modification de kill switch doit être revue) | **COUVERT** (Bloc X) |
| 12 | Action admin privilégiée | ~29 Cloud Functions admin (`approveDriver`, `rejectDriver`, `suspendDriver`, `refundPayment`, `updateDisputeStatus`, `setUserRole`, etc.) utilisent `requireAdminOrAbove` + `writeAuditLog`/`writeAuditLogInTransaction` | HIGH pour actions sensibles (`setUserRole`, `refundPayment`) | **COUVERT** (Phase 6/7 existant) |

**Bilan** : 10/12 items déjà couverts par l'infrastructure Phase 6 (aucune
reconstruction nécessaire, conformément à la consigne « ne reconstruis pas la
finance »). 2 GAPS réels trouvés et corrigés ce tour (dispatch échoué,
notification manquée) — voir Y-2 pour le détail des correctifs.

## Y-2 — Logs structurés : vérification et correctifs

**Schéma structuré existant** (`buildFinancialLogEntry`, `observability.ts`) :

```
{ correlation_id, operation, result: "success"|"failure", duration_ms,
  mission_id?, payment_id?, refund_id?, payout_id?, dispute_id?,
  provider_event_id?, error_code?, message?, metadata? }
```

Ce schéma satisfait déjà l'exigence Y-2 (function/action = `operation`,
mission ID, IDs finance, résultat, erreur). Le `correlation_id` est propagé
si fourni, sinon généré (UUID) — permet de corréler plusieurs logs d'une
même opération métier.

**Garanties anti-fuite (déjà en place, revérifiées ce tour)** — `sanitizeMetadata()` :
- Clés interdites (regex, insensible à la casse) : `secret`, `apikey`/`api_key`,
  `authorization`, `token`, `access_token`, `refresh_token`, `password`,
  `credential`, `private_key`, `admin_key`, `service_account`, `card_number`,
  `cvc`, etc. → valeur entière retirée (`[REDACTED]`), pas de fuite partielle.
- Valeurs interdites (pattern structurel, même sous une clé au nom innocent) :
  clé secrète Stripe (`sk_live_`/`sk_test_`), clé restreinte (`rk_*`), webhook
  signing secret (`whsec_*`), en-tête `Authorization: Bearer ...` complet.
- Aucune mutation de l'entrée d'origine (copie).

**Deux vrais GAPS corrigés ce tour** (aucun autre gap trouvé après revue des
Functions critiques listées en Y-1) :

1. **`dispatchMissionToDrivers.ts`** — le cas « aucun chauffeur éligible »
   retournait silencieusement (`return;`) sans aucun signal. Ajout de
   `logFinancialFailure("dispatch_no_driver_available", ..., "no_eligible_driver_in_zone", { missionId }, { metadata: { candidatesScanned, zonePrefix } })`
   avant le `return`, et `logFinancialSuccess("dispatch_offers_created", ...)`
   **après** le `batch.commit()` réussi (jamais annoncer un succès avant
   persistance réelle). Comportement métier inchangé (jamais d'exception
   levée — c'est un comportement normal, pas une erreur système).
2. **`onMissionStatusChangeNotifyCustomer.ts`** — l'écriture Firestore de la
   notification n'était protégée par aucun try/catch : un échec d'écriture
   (timeout, quota, règle) aurait été totalement invisible. Ajout d'un
   try/catch avec `logFinancialSuccess`/`logFinancialFailure("mission_notification_created", ...)`,
   sans jamais propager l'exception (le trigger s'exécute après la
   transition de statut métier, déjà réussie — une notification manquée ne
   doit jamais faire échouer le trigger). Confirmé sans régression : aucun
   test existant n'attend un rejet de ce trigger (grep `rejects`/`toThrow` = 0
   résultat), et les 2 suites régression passent (16/16 PASS).

**Aucune donnée sensible journalisée** — les 2 correctifs ne transmettent
que `mission_id` (identifiant métier), `error_code`, et des compteurs/types
non sensibles (`candidatesScanned`, `notificationType`). Jamais de
coordonnées GPS brutes, jamais de `customer_id`/adresse/contenu de
notification.

## Y-3 — Finance : signaux exploitables (réutilisation Phase 6, aucune reconstruction)

| Cas | Signal | Fichier |
|---|---|---|
| Authorization failure | `logFinancialFailure` | `paymentOrchestration.ts` |
| Capture failure | `logFinancialFailure` | `paymentOrchestration.ts` |
| Payout failure | `logFinancialFailure` + `audit_logs` | `calculateDriverPayout.ts`, `paymentOrchestration.ts` |
| Refund failure | `logFinancialFailure` + `audit_logs` | `refundPayment.ts`, `paymentOrchestration.ts` |
| Dispute/chargeback | `logFinancialSuccess`/`Failure` + `audit_logs` | `disputeOrchestration.ts`, `processStripeWebhook.ts` |
| Webhook non traité | `logFinancialFailure` par type d'évènement | `processStripeWebhook.ts` |
| Reconciliation anomaly | `logFinancialFailure("reconciliation_anomaly_detected", ...)` avec `anomalyCount`/`anomalyTypes` | `reconciliationEngine.ts` |

Tous ces signaux existaient déjà avant ce tour (Phase 6) — confirmés par
lecture/grep, aucun changement de code nécessaire.

## Y-4 — Kill switch : traçabilité (référence Bloc X)

`updateRuntimeFlags.ts` écrit un `audit_logs` via `writeAuditLogInTransaction`
contenant : `actor_user_id`, `actor_role`, `action: "update_runtime_flags"`,
`target_id`, et en métadonnées les valeurs **old** et **new** de chaque flag
modifié (`changedKeys`), plus `wasBootstrapped` et un timestamp serveur
(`created_at`). Preuve permanente déjà existante : `runtimeFlags.test.ts`
section I (29/29 PASS, aucune modification nécessaire ce tour).

## Y-5 — Alert Policy (minimale, production)

| Sévérité | Déclencheurs Movi-K | Action attendue |
|---|---|---|
| **SEV/CRITICAL** | Paiements en échec généralisé (taux anormal sur `paymentOrchestration` failures), payouts incorrects (montant/`reverseDriverPayout` en volume), incohérence financière (`reconciliation_anomaly_detected` en volume élevé ou montant important), fuite de sécurité (accès refusé anormal, `permission-denied` en masse), corruption de données critiques (ledger/snapshot) | Investigation immédiate, kill switch si nécessaire (Bloc X), astreinte |
| **HIGH** | `reconciliation_anomaly_detected` isolé, webhook Stripe en erreur continue (même `provider_event_id`/endpoint sur plusieurs évènements consécutifs), missions massivement en échec (`dispatch_no_driver_available` répété sur une zone/période), modification de kill switch (Y-4) | Revue dans la journée, pas nécessairement une astreinte nocturne |
| **MEDIUM** | Incidents isolés/retry-récupérables (échec carte isolé, notification manquée isolée), tracking dégradé (échecs `recordTrackingPoint` ponctuels) | Suivi standard, pas d'astreinte |

Politique volontairement minimale (pas de bureaucratie excessive) — les
seuils numériques précis (ex : « X% d'échecs sur Y minutes ») seront affinés
en Phase 8 une fois les alertes externes réellement branchées (Y-6), à
partir de données réelles de production plutôt que d'hypothèses.

## Y-6 — External alerting : à activer en Phase 8 (EXTERNAL CONFIGURATION)

Rien de ceci n'est créé/activé ce tour (pas de compte externe créé, pas
d'intervention fondateur demandée) :

- **Google Cloud Monitoring** : alerting policies basées sur les métriques de
  log (`log-based metrics`) filtrant sur `severity=ERROR` +
  `jsonPayload.operation` pour les opérations listées en Y-1/Y-5 (ex :
  `reconciliation_anomaly_detected`, `dispatch_no_driver_available` en
  volume). Nécessite accès console GCP du projet `movik-connect-prod`.
- **Firebase Alerts** (Crashlytics/Performance si utilisés côté app mobile,
  hors scope Functions).
- **Notification externe** (email/Slack/PagerDuty/etc.) : brancher les
  alerting policies GCP ci-dessus sur un canal de notification (nécessite
  une décision produit sur le canal — Slack webhook, email d'astreinte,
  etc. — et la création du compte/intégration correspondant).

**Phase 8 — EXTERNAL CONFIGURATION** : créer les alerting policies GCP citées
ci-dessus à partir des `operation`/`error_code` déjà journalisés (aucun
changement de code applicatif nécessaire — l'instrumentation Phase 7 suffit).

## DONE Y

| Critère | Statut |
|---|---|
| Incidents critiques observables | ✅ 12/12 items de la matrice Y-1 COUVERTS (10 déjà existants Phase 6, 2 corrigés ce tour) |
| Finance observable | ✅ Y-3, réutilisation intégrale Phase 6 |
| Logs utiles | ✅ Schéma structuré existant (`correlation_id`, `operation`, IDs métier, résultat, erreur) |
| Aucune donnée sensible loguée | ✅ `sanitizeMetadata()` vérifié + correctifs ne transmettent que `mission_id`/`error_code`/compteurs |
| Kill switches auditables | ✅ Y-4, preuve permanente `runtimeFlags.test.ts` section I |
| Plan d'alertes production | ✅ Y-5 (SEV/CRITICAL, HIGH, MEDIUM) + Y-6 (liste Phase 8) |
| P0 ouverts | ✅ 0 |
| P1 ouverts | ✅ 0 |

**Preuves de non-régression** : `npx tsc --noEmit` (0 erreur), `npm run lint`
(0 warning), `dispatchNoDriverAvailable.test.ts` +
`onMissionStatusChangeNotifyCustomer.test.ts` (16/16 PASS avec les nouveaux
logs visibles), suite d'intégration complète 555/556 PASS (1 échec
`processStripeWebhook.test.ts` confirmé flaky/pré-existant — race de
concurrence non-déterministe sur un test `Promise.allSettled`, **18/18 PASS
en isolation**, sans rapport avec les fichiers modifiés ce tour), Jest unit
109/109 PASS.

# BLOC Y : ✅ FERMÉ
