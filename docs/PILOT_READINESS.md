# MOVI-K — PILOT READINESS (Phase 7, Bloc AC)

**Statut du document** : dernier bloc de la Phase 7 QA. Objectif unique : répondre honnêtement
à *« Qu'est-ce qui est prêt pour un pilote réel, et qu'est-ce qui doit être configuré/décidé en
Phase 8 ? »*. Ce document n'est PAS une nouvelle phase de développement — aucune ligne de code
n'est modifiée pour produire ce document ; il ne fait que consolider et qualifier honnêtement
l'état déjà prouvé par Phase 2 → Phase 7 (Blocs A → AB).

**Statuts autorisés** (aucun autre statut n'est utilisé dans ce document) :
- `READY` — prouvé par du code + des tests dans ce repo, fonctionnellement complet pour un
  pilote contrôlé.
- `PHASE 8 REQUIRED` — dépend d'une configuration externe (compte tiers, clés de production,
  infrastructure Console GCP/Firebase/Stripe) qui ne peut pas être créée depuis ce repo.
- `PRODUCT DECISION REQUIRED` — un comportement ambigu existe et nécessite un choix produit
  explicite avant correction (pas un bug de code manquant).
- `LEGAL / FOUNDER DECISION REQUIRED` — dépend d'une décision légale/politique/business qui
  n'est pas du ressort de l'ingénierie.

**Règle absolue de ce document : pas de faux READY.** Un statut READY signifie que le
comportement est prouvé par du code + des tests réels dans ce repo, PAS une supposition.

---

## AC-1 — READINESS MATRIX

### CLIENT

| Fonction | Statut | Preuve | Action avant pilote |
|---|---|---|---|
| Signup / Login | READY | `test/auth/` (Firebase Auth + claims), `AuthScreen` testé Bloc L/AB (i18n, tap targets, contraste) | Aucune — fonctionnel de bout en bout en émulateur/test |
| Création mission (quote → confirmation) | READY | `DeliveryRequestFlowScreen`, `calculateDeliveryQuote`/`createDeliveryRequest` (Bloc B/N/O), erreurs génériques non techniques (AB-3, `058a76c`) | Aucune |
| Quote (tarification) | READY | `calculateDeliveryQuote.ts` testé (Bloc B, N, T), validation runtime des champs (Bloc O) | Aucune |
| Paiement (flux applicatif) | PHASE 8 REQUIRED | `StripeProvider`/`FirebaseFinanceRepository` codés et testés en émulateur (idempotence Bloc O, réconciliation Bloc Z/AA) ; **aucune clé Stripe live, aucun webhook production configuré** | Voir AC-2 — Stripe live keys + webhook production |
| Searching driver / Assignment | READY | `dispatchMissionToDrivers.ts` (Bloc Y — observabilité comblée GAP-Y-01), assignation automatique confirmée (AB-1 : libellé landing corrigé pour refléter ce comportement réel) | Aucune |
| Tracking (GPS chauffeur → client) | READY (émulateur/widget) — PHASE 8 REQUIRED (device réel) | `LiveTrackingMap`/`watchDriverLocation()` (Bloc H — durcissement GPS), fonctionnel en test | Voir AC-3 — validation GPS sur téléphone réel obligatoire avant pilote |
| Notifications (in-app) | READY | `NotificationBell`, `notification_repository`, i18n `notif_*` complet (Bloc I/K) | Aucune |
| Notifications (push mobile FCM/APNs) | PHASE 8 REQUIRED | Documenté DEFERRED en Bloc I (I-7) : **aucune dépendance `firebase_messaging` dans le projet** — non construit, pas un bug | Voir AC-2 — FCM/APNs réels |
| Completion (mission terminée) | READY | `_CompletedMissionView`, finance summary testé (AB-8, BUG-AB-08-01 corrigé) | Aucune |
| Rating / Review | READY | AB-10 (`c657368`) — implémentation complète 1-5 étoiles + commentaire, Semantics accessible (AB-9), i18n FR/EN/ES (6/6 + tests dédiés) | Aucune |

### DRIVER

| Fonction | Statut | Preuve | Action avant pilote |
|---|---|---|---|
| Onboarding (formulaire + soumission) | READY | `DriverOnboardingScreen`, texte brut backend éliminé (AB-4, `b42cb6e`) | Aucune |
| Documents (upload permis/assurance) | READY (émulateur/widget) — PHASE 8 REQUIRED (device réel) | `driver_onboarding_document_upload_test.dart`, Storage rules (Bloc P), tap target corrigé (BUG-AB-09-01) | Voir AC-3 — upload réel caméra/galerie sur device |
| Analyst review | READY | Security Rules `driver_documents` (Bloc P), flux de revue documenté | Aucune |
| Approval / Rejection / Suspension | READY | `test/driver/driver_status_screen_test.dart` — 7/7 statuts réels testés (registrationIncomplete, pendingReview, documentsRequired, approved, rejected, suspended, inactive) | Aucune |
| Online / Offline | READY | Switch avec Tooltip accessible (BUG-007, Bloc L), gate dashboard (`provider_dashboard_shell_status_gate_test.dart`) | Aucune |
| Mission offers / Accept | READY | `ProviderJobsTab`, testé fonctionnellement (`provider_jobs_tab_test.dart` — succès/erreurs/double-tap) + mobile 320-360px (AB-8, cette session) | Aucune |
| GPS (localisation chauffeur) | READY (émulateur/widget) — PHASE 8 REQUIRED (device réel) | Bloc H (durcissement), aucune preuve sur device physique réel (background, écran verrouillé, perte réseau) | Voir AC-3 — obligatoire avant pilote |
| Pickup / In-transit | READY | `driver_active_mission_status_gaps_test.dart`, transitions de statut testées | Aucune |
| Proof of delivery | READY (émulateur/widget) — PHASE 8 REQUIRED (device réel caméra) | `driver_active_mission_proof_upload_test.dart`, Storage rules immuables (Bloc P) | Voir AC-3 — caméra réelle sur device |
| Completion | READY | Transition `completed`, testée bout-en-bout (finance, rating déclenché) | Aucune |
| Earnings | READY | `provider_earnings_tab.dart`, dates localisées (Bloc K2) | Aucune |
| Payout | PHASE 8 REQUIRED | `driver_payouts_enabled` kill switch + logique de calcul testées (Bloc X, Bloc O) ; **aucun payout Stripe Connect réel jamais exécuté** (pas de compte Connect production) | Voir AC-2 — Stripe Connect onboarding + payouts réels |

### ADMIN

| Fonction | Statut | Preuve | Action avant pilote |
|---|---|---|---|
| Pending drivers (liste) | READY | `admin_drivers_list_screen.dart`, i18n testé (K5), dates localisées (K2) | Aucune |
| Document review | READY | Security Rules `driver_documents` (analyst/admin read), flux de revue par statut | Aucune |
| Approve / Reject / Request docs | READY | Cloud Functions dédiées testées (Bloc B/C historique), transitions de statut couvertes (`driver_status_screen_test.dart`) | Aucune |
| Missions (vue admin) | READY | `admin_dashboard_shell.dart`, i18n rendu réel testé (`k5_residual_screens_locale_render_test.dart`) | Aucune |
| Finance (vue admin) | READY | `admin_finance_ui_test.dart`, `AdminFinanceShell` testé i18n 3 langues (Bloc M) | Aucune |
| Refunds | READY | `refundPayment` idempotent (Bloc O), E2E validé (Bloc Q — "E2E refund validé partiel + total") | Aucune |
| Disputes | READY | `dispute_info_test.dart`, modèle + UI présents | Aucune |
| Reconciliation | READY | `reconciliationEngine.ts` testé (Bloc Z/AA — `disasterRecovery.test.ts` 3/3 PASS), staleness webhook détectée | Aucune |
| Audit (traçabilité admin) | READY | Toute modification runtime flags / statuts / finance auditée avec old/new values (Bloc X) | Aucune |
| Kill switches | READY | 4 kill switches MVP (Bloc X) : `accept_new_delivery_requests`, `allow_driver_acceptance`, `payments_enabled`, `driver_payouts_enabled` — fail-closed, admin-only, audité | Voir AC-2 — X-13 bootstrap Phase 8 (confirmer explicitement les 4 valeurs en prod avant lancement) |
| Monitoring (interne, logs structurés) | READY | `docs/MONITORING_RUNBOOK.md` — logs structurés `logFinancialSuccess`/`logFinancialFailure` (Bloc Y) | Voir AC-2 — destinations d'alerte externes (Slack/PagerDuty/email) non branchées |

---

## AC-2 — PHASE 8 REQUIRED (items externes déjà connus, vérifiés honnêtement)

| Item | Statut | Preuve / justification |
|---|---|---|
| Stripe / Stripe Connect — clés live, webhook production, onboarding Connect, vrais paiements, vrais payouts | **PHASE 8 REQUIRED** | Code + tests émulateur complets (idempotence Bloc O, réconciliation Bloc AA) ; `functions/src/lib/secrets.ts` référence `STRIPE_SECRET_KEY`/`STRIPE_WEBHOOK_SECRET` via Secret Manager (jamais commités) — mais **aucune valeur réelle n'est configurée dans ce repo par conception**. Aucun paiement/payout réel n'a jamais été exécuté. |
| App Check — enforcement production | **PHASE 8 REQUIRED** | Confirmé absent (GAP-Q2-01, Bloc Q2) : SDK `firebase_app_check` présent en dépendance mais **0 activation client, 0 `enforceAppCheck` sur les 31 Cloud Functions `onCall`, 0 référence `request.app` dans les règles**. Nécessite Play Integrity/App Attest/reCAPTCHA — configuration externe hors du périmètre de développement. |
| Push notifications — FCM/APNs réels | **PHASE 8 REQUIRED** | Documenté DEFERRED (I-7, Bloc I) : aucune dépendance `firebase_messaging` dans le projet. Non construit. |
| GPS réel (vrais téléphones, background, écran verrouillé, perte/reprise réseau) | **PHASE 8 REQUIRED** | Bloc H a durci la logique GPS en émulateur/widget test ; **aucune validation sur device physique réel** n'a jamais été faite dans ce repo (impossible en sandbox). Voir AC-3. |
| Backups Firestore/Storage | **PHASE 8 REQUIRED** | Confirmé absent (AA-2, Bloc AA) : **aucune preuve qu'un export planifié Firestore ou un PITR soit activé** sur `movik-connect-prod` ; aucune règle de versioning/lifecycle Cloud Storage configurée. Configuration exclusivement Console GCP, hors de ce repo. Risque Phase 8 le plus important identifié. |
| Monitoring externe (destinations d'alerte) | **PHASE 8 REQUIRED** | `docs/MONITORING_RUNBOOK.md` documente le mécanisme de logs structurés (interne, READY) mais explicitement note que la notification externe (email/Slack/PagerDuty) reste à brancher — décision produit sur le canal, configuration externe. |
| Runtime flags — bootstrap production | **PHASE 8 REQUIRED** (procédure prête, exécution non faite) | Procédure complète documentée (X-13, Bloc X) : 11 étapes explicites pour bootstrapper/confirmer les 4 kill switches en production. Le code est fail-closed par défaut (READY) — mais la confirmation explicite en environnement `movik-connect-prod` n'a pas été exécutée (ne peut pas l'être depuis ce repo). |
| Privacy / data retention — durées finales | **LEGAL / FOUNDER DECISION REQUIRED** | `docs/DATA_RETENTION.md` (Bloc Z) marque explicitement chaque ligne d'inventaire de données `POLICY / LEGAL DECISION REQUIRED — PHASE 8` (durées de conservation post-suppression, documents chauffeur réglementés, etc.) — aucune durée n'est inventée. |
| RPO / RTO | **FOUNDER / OPERATIONS DECISION REQUIRED** | `docs/DISASTER_RECOVERY.md` (AA-8) : `RPO/RTO TARGETS — DECISION REQUIRED BEFORE PRODUCTION`, explicitement non inventé. Dépend directement de l'activation des backups (item ci-dessus). |
| Orphan Storage cleanup | **PHASE 8 REQUIRED** | `docs/DATA_RETENTION.md` (Z-6) : `DEFERRED NON-BLOCKING → Phase 8`, algorithme de nettoyage déjà recommandé dans le document mais non implémenté. |
| `calculateDeliveryQuote` — rate limiting | **PHASE 8 REQUIRED** | GAP-Q2-01 (Bloc Q2) : aucune limite de fréquence sur cette fonction callable. Impact évalué FAIBLE (coût Firestore négligeable, aucun appel provider externe coûteux, `requireSignedIn()` déjà une barrière anti-abuse) mais classé explicitement DEFERRED → Phase 8, pas construit ce tour. |
| GAP-S-04 — chauffeur suspendu pendant mission active | **PRODUCT DECISION REQUIRED** | Bloc S : `suspendDriver.ts` met à jour `driver_profiles.status = suspended`, mais `completePickup.ts`/`completeDelivery.ts` ne revérifient QUE `mission.status` + `driver_id` — un chauffeur suspendu en cours de mission PEUT continuer jusqu'à completion. Non corrigé par choix : interrompre une livraison en cours pourrait créer un colis orphelin (potentiellement pire pour le client). Nécessite une décision produit explicite. Si validé bug : correctif = ajouter vérification `driver_profiles.status === 'approved'` dans `completePickup.ts`/`completeDelivery.ts`. |

---

## AC-3 — PHYSICAL DEVICE PLAN

**Rappel critique** : tout ce qui suit n'a été validé qu'en émulateur Firebase et/ou widget test
Flutter (`flutter test`, aucun rendu réel sur écran physique). **Aucun de ces points n'est
marqué READY** — ils exigent une validation sur appareils réels avant tout pilote, quel que soit
le niveau de couverture logicielle atteint en Phase 7.

### Client (device réel requis)

| Point à tester | Pourquoi ce n'est pas déjà prouvé |
|---|---|
| Android réel (pas seulement émulateur widget test) | `flutter test` s'exécute en environnement de test Flutter (pas un vrai rendu Android/iOS) |
| Connectivité Wi-Fi / données mobiles réelles, transition entre les deux | Bloc G (offline/retry) teste la logique de retry en simulant des exceptions réseau, pas une vraie coupure radio |
| Notifications push réelles | N/A tant que FCM/APNs n'est pas intégré (voir AC-2) |
| Tracking GPS côté client (recevoir la position chauffeur en temps réel) | `watchDriverLocation()` testé avec des flux Firestore simulés, jamais avec un vrai flux GPS chauffeur en mouvement |
| Comportement background/foreground de l'app pendant une livraison en cours | Aucun test Flutter ne peut simuler le vrai cycle de vie Android/iOS background |

### Driver (device réel requis)

| Point à tester | Pourquoi ce n'est pas déjà prouvé |
|---|---|
| GPS réel (précision, dérive, tunnels/zones mortes) | Bloc H durcit la LOGIQUE de traitement des positions, pas la qualité du signal GPS réel |
| Permissions runtime (localisation "toujours"/"en utilisant l'app", caméra, stockage) | Les dialogues de permission natifs OS ne sont pas simulables en widget test |
| GPS en arrière-plan (app minimisée pendant une livraison) | Nécessite configuration native Android (foreground service)/iOS (background modes) non vérifiable par `flutter test` |
| Écran verrouillé pendant le tracking | Comportement OS natif, hors de portée des tests Flutter |
| Caméra réelle pour preuve de livraison (qualité photo, permissions, orientation) | `driver_active_mission_proof_upload_test.dart` simule un fichier déjà sélectionné, ne teste jamais le vrai flux caméra |
| Perte réseau puis reprise en plein trajet (upload de position/preuve en attente) | Bloc G simule des exceptions, pas une vraie coupure radio prolongée sur le terrain |
| Consommation batterie sur une session de livraison complète (GPS actif en continu) | Aucun test logiciel ne peut mesurer un impact batterie réel |

**Ne jamais marquer un de ces points comme déjà validé sur la seule base d'émulateur/widget
test.**

---

## AC-4 — PILOT STRATEGY

Un pilote contrôlé doit rester volontairement petit et réversible :

- **Zone géographique** : une seule zone urbaine restreinte (ex. un seul quartier/secteur de
  livraison) — **FOUNDER / OPERATIONS DECISION** (pas de zone choisie dans ce document).
- **Chauffeurs pilotes** : un petit groupe fermé, onboardés manuellement, connus individuellement
  de l'équipe (pas d'ouverture publique de l'onboarding chauffeur pendant le pilote) —
  **FOUNDER / OPERATIONS DECISION** pour le nombre exact.
- **Clients pilotes** : accès contrôlé (invitation, liste fermée, ou zone géographique limitante)
  — **FOUNDER / OPERATIONS DECISION** pour le nombre exact et le mécanisme d'accès.
- **Volume** : faible volume intentionnel (quelques missions/jour au démarrage), afin de pouvoir
  investiguer manuellement chaque incident financier ou opérationnel sans automatisation de
  masse — **FOUNDER / OPERATIONS DECISION** pour le seuil exact.
- **Monitoring renforcé** : surveillance manuelle rapprochée pendant toute la durée du pilote
  (logs structurés déjà READY, voir AC-1 Admin/Monitoring) — augmenter la fréquence de review
  humaine des logs `logFinancialFailure` pendant le pilote.
- **Kill switches prêts** : les 4 kill switches (Bloc X) doivent être confirmés opérationnels
  (bootstrap X-13 exécuté, voir AC-2) et une personne d'astreinte doit savoir les activer en
  moins de 5 minutes en cas d'incident.

**Aucun chiffre exact (taille de zone, nombre de chauffeurs/clients, seuil de volume) n'est fixé
dans ce document — ce sont des décisions FOUNDER/OPERATIONS, pas des paramètres techniques.**

---

## AC-5 — GO / NO-GO CHECKLIST

Le GO pilote exige la conjonction de TOUS les points suivants. Tout item non encore configuré
est classé **PHASE 8 REQUIRED**, et n'est PAS un bug logiciel de Phase 7.

| Critère GO | Statut actuel | Action requise |
|---|---|---|
| P0 logiciel = 0 | ✅ Confirmé (tous blocs A→AB) | Aucune |
| P1 logiciel = 0 | ✅ Confirmé (tous blocs A→AB) | Aucune |
| Tests critiques verts (`flutter analyze` 0 issue, `flutter test` 531/531, Jest unit 109/109, Jest intégration 559/559) | ✅ Confirmé | Aucune |
| Stripe réel validé (clés live) | ❌ PHASE 8 REQUIRED | Configurer Secret Manager production + valider un paiement test réel en mode live restreint |
| Paiement réel testé | ❌ PHASE 8 REQUIRED | Dépend du point ci-dessus |
| Payout réel testé | ❌ PHASE 8 REQUIRED | Stripe Connect onboarding réel + premier payout test réel |
| Push réel testé | ❌ PHASE 8 REQUIRED | Intégrer FCM/APNs (actuellement absent, voir AC-2) puis tester sur device |
| GPS réel testé | ❌ PHASE 8 REQUIRED | Voir AC-3 — tests sur device physique obligatoires |
| Backup activé | ❌ PHASE 8 REQUIRED | Activer export Firestore planifié et/ou PITR + versioning Storage (Console GCP) |
| Monitoring externe configuré | ❌ PHASE 8 REQUIRED | Brancher une destination d'alerte réelle (email/Slack/PagerDuty) sur les logs structurés déjà READY |
| Runtime flags configurés | ⚠️ Procédure prête, exécution non faite | Exécuter la procédure X-13 (11 étapes) en environnement `movik-connect-prod` |
| Admin prod configuré | ⚠️ Non vérifié dans ce repo | Confirmer les comptes admin/super_admin réels en production (claims Firebase Auth) |
| Policies requises prêtes | ❌ LEGAL/FOUNDER DECISION REQUIRED | Voir AC-6 |
| Kill switches vérifiés | ⚠️ Code READY, confirmation prod non faite | Même action que "Runtime flags configurés" ci-dessus |
| Runbook incident disponible | ✅ `docs/MONITORING_RUNBOOK.md` + `docs/DISASTER_RECOVERY.md` (11 étapes) | Aucune |

**Conclusion honnête** : le logiciel (code + tests) est prêt (P0=0, P1=0, suite complète verte).
Le GO pilote reste bloqué par des items **PHASE 8 REQUIRED** externes (Stripe live, App Check,
push, GPS device réel, backups, monitoring externe, runtime flags bootstrap prod) et des
décisions **LEGAL/FOUNDER** (policies, RPO/RTO, zone/volume pilote) — aucun de ces blocages
n'est un bug de Phase 7.

---

## AC-6 — LEGAL / POLICY

Documents identifiés comme nécessaires avant un pilote réel avec de vrais utilisateurs
(paiements, données personnelles, géolocalisation) :

| Document | Statut | Référence |
|---|---|---|
| Terms of Service (client) | **LEGAL / FOUNDER REVIEW REQUIRED** | Non trouvé dans ce repo — nécessite rédaction/validation juridique |
| Privacy Policy | **LEGAL / FOUNDER REVIEW REQUIRED** | `docs/DATA_RETENTION.md` fournit l'inventaire technique des données (base factuelle pour rédiger la policy) mais n'est PAS lui-même une Privacy Policy publiable |
| Driver terms (conditions chauffeur/partenaire) | **LEGAL / FOUNDER REVIEW REQUIRED** | Non trouvé dans ce repo |
| Payment / refund policy | **LEGAL / FOUNDER REVIEW REQUIRED** | Logique technique de refund READY (Bloc O/Q), mais la POLICY commerciale (délais, conditions d'éligibilité communiquées au client) n'est pas rédigée dans ce repo |
| Location / GPS consent | **LEGAL / FOUNDER REVIEW REQUIRED** | Permissions techniques Android/iOS gérées au niveau OS (à valider AC-3), mais le texte de consentement/disclosure utilisateur n'existe pas dans ce repo |
| Document handling (permis, assurance, pièces d'identité chauffeur) | **LEGAL / FOUNDER REVIEW REQUIRED** | `docs/DATA_RETENTION.md` marque explicitement ces données `RETENTION POLICY DECISION REQUIRED — PHASE 8` |
| Retention policy (durées) | **LEGAL / FOUNDER DECISION REQUIRED** | Voir AC-2 — chaque ligne d'inventaire `docs/DATA_RETENTION.md` est marquée en attente de décision |
| Account deletion / data request process | **LEGAL / FOUNDER REVIEW REQUIRED** | Mécanisme technique de suppression de compte Firebase Auth existe (suppression native) mais le PROCESSUS de demande utilisateur (formulaire, délai de traitement, confirmation) n'est pas documenté/construit |

**Aucun de ces documents n'est rédigé dans ce repo — ce sont des livrables LEGAL/FOUNDER, hors du
périmètre d'ingénierie de la Phase 7.**

---

## AC-7 — OPERATIONAL ACCOUNTS

Comptes/accès nécessaires pour opérer le pilote. **Aucun credential fictif n'est créé dans ce
document** — cette section liste uniquement les comptes à provisionner, sans valeur.

| Compte / Service | Nécessaire pour | Statut |
|---|---|---|
| Firebase / GCP (projet `movik-connect-prod`) | Hébergement Firestore/Auth/Storage/Functions | Projet référencé tout au long de Phase 7 (`movik-connect-prod`) — accès admin/IAM production à confirmer par le founder |
| Stripe | Paiements clients | Non configuré (voir AC-2) — compte Stripe live à créer/activer |
| Stripe Connect | Payouts chauffeurs | Non configuré (voir AC-2) — onboarding Connect plateforme à compléter |
| FCM / APNs | Push notifications | Non intégré au projet (voir AC-2) — comptes développeur Apple/Google Push à provisionner en Phase 8 |
| Admin / Super Admin (production) | Opérer le dashboard admin, revoir documents, gérer kill switches | Mécanisme de claims READY (code) — comptes réels de production à créer et vérifier (procédure X-13) |
| Support email | Point de contact pilote (voir AC-8) | Non défini dans ce repo — à décider par le founder |
| Monitoring / destinations d'alerte | Recevoir les alertes de `logFinancialFailure`/incidents | Non branché (voir AC-2) — compte Slack/PagerDuty/email d'astreinte à provisionner |

---

## AC-8 — SUPPORT PILOT

Flux de support réutilisant intégralement les mécanismes déjà construits en Bloc Y (Monitoring)
et Bloc AA (Disaster Recovery) — aucun nouveau mécanisme technique créé pour ce document :

1. **Utilisateur signale un problème** (client ou chauffeur, via le canal support à définir —
   voir AC-7, support email non encore défini).
2. **Récupérer le mission ID** concerné (identifiant `delivery_requests/{id}`, visible côté
   client/chauffeur dans l'app, et côté admin via `admin_dashboard_shell.dart`).
3. **Investigation admin** : consulter la mission dans `AdminFinanceShell`/vue mission admin,
   consulter les logs structurés (`logFinancialSuccess`/`logFinancialFailure`, Bloc Y) associés à
   ce mission ID.
4. **Audit** : consulter la trace d'audit (old/new values) si la mission a traversé un
   changement de statut, un runtime flag, ou une action admin (Bloc X).
5. **Refund / dispute si nécessaire** : utiliser `refundPayment` (idempotent, Bloc O) ou le flux
   `dispute_info` existant — jamais de modification manuelle directe du ledger (règle absolue
   réaffirmée en Bloc AA : "jamais modifier une entrée ledger").
6. **Escalation SEV si nécessaire** : appliquer la classification SEV-1/2/3 déjà définie dans
   `docs/DISASTER_RECOVERY.md` (AA-7) avec des exemples Movi-K concrets, et suivre le runbook
   incident 11 étapes (AA-3) si l'incident dépasse le cadre d'un ticket support isolé.

**Ce flux réutilise Y/AA sans duplication** — aucun nouveau code, aucune nouvelle Cloud Function
créée pour le support pilote.

---

## AC-9 — RELEASE CHECKLIST (Phase 8)

Checklist consolidée de tout ce qui doit être fait AVANT le lancement du pilote réel, dans
l'ordre logique de dépendance :

1. **Code** — ✅ déjà prêt (Phase 2 → Phase 7, P0=0, P1=0, tests verts).
2. **Environment** — confirmer la configuration `movik-connect-prod` (projet Firebase/GCP réel,
   pas un projet de test/staging).
3. **Secrets** — provisionner `STRIPE_SECRET_KEY`/`STRIPE_WEBHOOK_SECRET` réels dans Secret
   Manager production (jamais commités, voir `functions/src/lib/secrets.ts`).
4. **Firebase** — vérifier les Security Rules déployées correspondent exactement à celles
   testées (Bloc P/Q), activer les index Firestore requis (`docs/FIRESTORE_INDEXES.md`).
5. **Stripe** — activer le mode live, configurer le webhook production (endpoint +
   `STRIPE_WEBHOOK_SECRET`), compléter l'onboarding Stripe Connect plateforme.
6. **App Check** — activer côté client (`FirebaseAppCheck.instance.activate()`) et configurer
   l'enforcement Console (recommandé : mode "monitor only" avant enforcement dur, voir Bloc Q2).
7. **Notifications** — intégrer `firebase_messaging`, configurer FCM (Android) et APNs (iOS).
8. **GPS réel** — exécuter le plan AC-3 sur au moins un device Android et un device iOS réels.
9. **Backups** — activer export Firestore planifié et/ou PITR, activer versioning/lifecycle
   Cloud Storage (Console GCP).
10. **Monitoring** — brancher une destination d'alerte externe réelle sur les logs structurés
    déjà en place (`docs/MONITORING_RUNBOOK.md`).
11. **Policies** — finaliser et publier ToS, Privacy Policy, driver terms, payment/refund policy,
    GPS consent (voir AC-6) — décision LEGAL/FOUNDER.
12. **Admin prod** — créer/vérifier les comptes admin/super_admin réels, exécuter la procédure
    de bootstrap runtime flags (X-13, 11 étapes).
13. **Runtime flags** — confirmer explicitement les 4 valeurs en production (voir X-13).
14. **Physical-device QA** — exécuter intégralement le plan AC-3 (client + chauffeur, device
    réel) avant d'ouvrir l'accès à de vrais utilisateurs pilotes.
15. **Pilot users** — définir la zone, le nombre de chauffeurs/clients pilotes, le mécanisme
    d'accès (décision FOUNDER/OPERATIONS, voir AC-4).
16. **Smoke tests** — exécuter un parcours complet réel (signup → quote → mission → paiement
    réel restreint → tracking → completion → rating → payout réel restreint) sur l'environnement
    de production avec des comptes de test internes, AVANT d'ouvrir aux pilotes externes.
17. **GO / NO-GO** — revalider la checklist AC-5 dans son intégralité.
18. **Lancement pilote** — ouverture contrôlée selon la stratégie AC-4.

---

## DONE AC

| Critère de clôture | Statut |
|---|---|
| Readiness matrix complète (CLIENT/DRIVER/ADMIN) | ✅ AC-1 |
| External blockers identifiés | ✅ AC-2 |
| Physical-device plan | ✅ AC-3 |
| GO/NO-GO checklist | ✅ AC-5 |
| Legal/policy checklist | ✅ AC-6 |
| Operational accounts | ✅ AC-7 |
| Support flow | ✅ AC-8 |
| Release checklist | ✅ AC-9 |
| Aucun P0/P1 logiciel connu laissé ouvert | ✅ Confirmé (P0=0, P1=0, Bloc AB fermé) |

# BLOC AC : ✅ FERMÉ
