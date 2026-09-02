# Movi-K — Architecture de paiement (Phase 6)

Ce document fixe les décisions d'architecture financière retenues pour Movi-K,
conformément à l'exigence de la Phase 6 : « Ne jamais inventer une capacité
Stripe. Documenter `selected_payment_architecture`, `reason_for_selection`,
`money_flow`, `refund_flow`, `chargeback_flow`, `payout_flow` ».

Toutes les affirmations ci-dessous sont vérifiées dans la documentation
officielle Stripe (docs.stripe.com) au moment de la rédaction (voir sources
citées). Aucune capacité n'est supposée.

## 1. selected_payment_architecture

- **Fournisseur** : Stripe Connect.
- **Type de compte connecté chauffeur** : Express account (Accounts v1 API).
  - Justification du choix v1/Express plutôt que v2 : Stripe indique
    explicitement que le guide "Design an integration" (v1) s'adresse aux
    plateformes Connect EXISTANTES, et recommande l'API Accounts v2
    uniquement pour les NOUVEAUX intégrateurs
    (docs.stripe.com/connect/design-an-integration : *"This guide only
    applies to existing Connect platforms that use the Accounts v1 API. If
    you're a new Connect user, use the Accounts v2 API instead."*).
    Movi-K étant un nouvel intégrateur, **Accounts v2** est donc le choix
    aligné avec la doc actuelle — mais le SDK Node `stripe` (v22.5.0) expose
    les deux API. Le connecteur `StripeProvider` sera écrit pour utiliser
    l'API v2 `Accounts` (`stripe.v2.core.accounts.create/...`) pour la
    création des comptes chauffeur, avec un tableau de compatibilité
    documenté ci-dessous (§8) — **point explicitement signalé comme
    nécessitant une vérification finale au moment du branchement réel de la
    clé secrète** (aucune clé Stripe n'existe encore dans Secret Manager,
    donc aucun appel réel n'a encore été fait à l'API v2 en environnement
    Movi-K).
  - Dashboard fourni aux chauffeurs : **Express Dashboard** (accès limité,
    marque Movi-K visible, onboarding hébergé par Stripe) — pas de Stripe
    Dashboard complet (les chauffeurs n'ont pas besoin de clés API/webhooks).
- **Modèle marketplace / type de charge** : **Destination charges**
  (`PaymentIntent` créé sur le compte PLATEFORME, avec
  `transfer_data[destination] = <compte chauffeur>` et
  `application_fee_amount = commission Movi-K`).
  - Justification : Stripe recommande explicitement ce modèle pour
    *"a branded service that uses independent contractors, such as a
    rideshare app"* (docs.stripe.com/connect/charges) — description qui
    correspond exactement au modèle Movi-K (marketplace + chauffeurs
    indépendants). Alternative écartée : *direct charges* (le client
    transigerait directement avec le chauffeur, incompatible avec
    l'exigence Movi-K de rester le vendeur officiel / responsable
    contractuel vis-à-vis du client) ; *separate charges and transfers*
    (charge et transfert totalement décorrélés, complexité additionnelle
    non justifiée pour une charge à 1 seul chauffeur bénéficiaire par
    mission).
- **Capture** : `capture_method: 'manual'` sur le PaymentIntent
  (autorisation puis capture explicite), compatible avec `transfer_data`
  (confirmé docs.stripe.com/payments/capture-later — la capture manuelle
  n'est pas incompatible avec les paramètres Connect).
- **Responsabilité du solde négatif (negative balance liability)** :
  Stripe est responsable par défaut pour un compte Express
  (docs.stripe.com/connect/risk-management/best-practices : *"We advise
  that new platforms have Stripe take responsibility for negative balances
  on connected accounts"*). Ce choix est retenu comme point de départ.
  Debit négatif automatique (`debit_negative_balances`) : disponible pour
  comptes au Canada — décision de l'activer ou non signalée comme point à
  valider avec Daniel (impact contractuel sur les chauffeurs, §9).

## 2. reason_for_selection

1. Correspondance directe avec le cas d'usage documenté par Stripe
   ("rideshare app" / marketplace à contractants indépendants).
2. Permet à Movi-K de rester le facturé officiel auprès du client
   (charge sur le compte plateforme), ce qui simplifie la génération de
   reçus/factures Movi-K (point 24) et la gestion des remboursements
   (le remboursement se fait par défaut sur le solde PLATEFORME, pas sur
   le compte chauffeur — voir §4).
3. La capture manuelle permet de respecter l'exigence explicite du point 5
   (« autorisation → mission → montant final confirmé → capture ») sans
   prélever le client avant confirmation du montant final.
4. Le compte Express minimise l'effort d'onboarding chauffeur (formulaire
   hébergé Stripe, KYC pris en charge par Stripe) — aligné avec le principe
   MODE AUTONOME (minimiser les développements d'écrans KYC maison).

## 3. money_flow

```
Client (carte)
  → PaymentIntent créé sur le compte PLATEFORME Movi-K
    (capture_method=manual, transfer_data.destination=<compte chauffeur>,
     application_fee_amount=<commission Movi-K + frais de service>)
  → Autorisation (requires_capture)
  → [mission exécutée, preuve de livraison, montant final confirmé]
  → Capture (le montant capturé peut être ≤ montant autorisé)
  → Stripe répartit automatiquement au moment de la capture :
       - solde compte chauffeur += (montant capturé − application_fee_amount)
       - solde compte plateforme += application_fee_amount
  → Payout chauffeur : virement Stripe → compte bancaire du chauffeur,
    déclenché après la période de sécurité Movi-K (payout_hold_period,
    §"Driver payout" du code), via un payout Stripe Connect explicite
    (pas de payout automatique quotidien — schedule manuel/contrôlé par
    Movi-K, voir docs.stripe.com/connect/manage-payout-schedule).
```

## 4. refund_flow

- Remboursement standard (`refund.create`) sur un `PaymentIntent` de type
  destination charge : débite par défaut le **solde de la PLATEFORME**, pas
  celui du compte chauffeur (docs.stripe.com/connect/destination-charges).
- Si Movi-K souhaite également récupérer la part déjà transférée au
  chauffeur : `reverse_transfer=true` (tire les fonds du compte chauffeur).
  `refund_application_fee=true` (requiert `reverse_transfer=true`) permet
  de rembourser également la commission Movi-K perçue.
- **Politique Movi-K retenue par défaut (configurable, non figée en dur)** :
  - Remboursement AVANT payout chauffeur (chauffeur pas encore payé) :
    `reverse_transfer=true` + `refund_application_fee=true` — le
    chauffeur ne reçoit jamais la part correspondant à un montant remboursé.
  - Remboursement APRÈS payout chauffeur (cas §"refund après payout") :
    `reverse_transfer=false` par défaut (le virement déjà versé au
    chauffeur n'est pas automatiquement récupéré) — une entrée compensatoire
    `driver_negative_balance` / `platform_loss` est créée dans le ledger
    (jamais de modification rétroactive du payout déjà versé). La
    récupération effective auprès du chauffeur (ex: compensation sur un
    payout futur) reste une **décision commerciale/contractuelle non
    automatisée** — signalée au rapport final comme point nécessitant
    validation.

## 5. chargeback_flow (disputes)

- Un chargeback sur une destination charge débite systématiquement le
  **solde de la plateforme** (jamais directement le compte chauffeur) —
  docs.stripe.com/connect/charges : *"If you're using Express or Custom
  legacy account types, your platform is responsible for disputes and
  fraud."*
- Cycle de vie standard Stripe (docs.stripe.com/disputes/how-disputes-work) :
  `warning_needs_response` (inquiry, Amex/Discover uniquement) →
  `needs_response` (dispute formelle) → `under_review` (preuve soumise) →
  `won` | `lost` (final, sauf rare "late win").
- Mission Movi-K : `dispute` Firestore lié au `payment_id` et au
  `mission_id` ; preuve de livraison Phase 5 (`proof_of_delivery_url`)
  automatiquement rattachée comme pièce justificative potentielle. Aucune
  soumission automatique de preuve à Stripe dans cette phase (nécessiterait
  l'API Disputes `evidence.submit`, hors scope Phase 6 — laissé pour action
  manuelle admin, le dossier contient toutes les données nécessaires).
- Récupération éventuelle auprès du chauffeur après un chargeback perdu :
  **non automatisée** — signalée au rapport final (§9) comme point
  nécessitant une politique contractuelle validée avant toute automatisation.

## 6. payout_flow

- `driver_payouts` (existant) étendu avec `payout_hold_period_hours` /
  `payout_eligible_at` — configurables via `payout_policy_configs`
  (nouvelle collection, admin-only), jamais une constante hardcodée.
- Statuts : `pending → eligible → scheduled → processing → paid` ; branches
  d'échec `failed`, `held`, et `reversed` (voir §6 du cahier des charges).
- Le virement réel passe par un `Transfer` déjà effectué implicitement à la
  capture (Connect gère automatiquement l'attribution du solde au compte
  connecté) ; le **payout** (mouvement du solde Stripe du compte connecté
  vers son compte bancaire externe) est déclenché explicitement par Movi-K
  via l'API Payouts (schedule `manual`), jamais le schedule automatique
  quotidien par défaut, pour garder le contrôle du délai de sécurité.

## 7. Aucune capacité inventée — sources consultées

- docs.stripe.com/connect/charges
- docs.stripe.com/connect/destination-charges
- docs.stripe.com/connect/express-accounts
- docs.stripe.com/payments/capture-later
- docs.stripe.com/connect/webhooks
- docs.stripe.com/connect/account-capabilities
- docs.stripe.com/connect/risk-management/best-practices
- docs.stripe.com/connect/design-an-integration
- docs.stripe.com/connect/interactive-platform-guide
- docs.stripe.com/disputes/how-disputes-work

## 8. Points explicitement laissés ouverts / à revalider au branchement réel

- Choix final Accounts v1 (Express, legacy) vs Accounts v2 pour la création
  des comptes chauffeur : le code est écrit derrière l'abstraction
  `PaymentProvider`/`StripeProvider` de façon à isoler cette décision dans
  UNE SEULE fonction (`createDriverAccount`) ; elle pourra être ajustée sans
  impact sur le reste de l'architecture (idempotence, ledger, payouts,
  refunds) qui ne dépend pas de la version d'API de comptes utilisée.
- Activation de `debit_negative_balances` : non activée par défaut, à
  décider avec Daniel.
- Soumission de preuve de dispute automatisée à Stripe : hors scope Phase 6.

## 9. Actions externes requises de Daniel

1. Créer un compte Stripe réel (dashboard.stripe.com), compléter le profil
   plateforme Connect (`Platform profile`), activer les capacités
   nécessaires pour le Canada/Québec.
2. Fournir la clé secrète API (`sk_live_...` ou `sk_test_...` pour la
   phase de test) — sera stockée UNIQUEMENT dans Secret Manager
   (`STRIPE_SECRET_KEY`), jamais dans Flutter/GitHub/logs.
3. Une fois un webhook endpoint configuré dans le Dashboard Stripe, fournir
   le secret de signature (`whsec_...`) — stocké comme
   `STRIPE_WEBHOOK_SECRET` dans Secret Manager.
4. Décision commerciale requise (voir rapport final Phase 6) : politique de
   remboursement de pourboire, récupération après chargeback, activation du
   débit automatique des soldes négatifs, taux de TPS/TVQ applicables.

Tant que ces clés ne sont pas fournies, `StripeProvider` reste **non
opérationnel** par construction : toute tentative d'utilisation sans
`STRIPE_SECRET_KEY` configuré échoue explicitement (voir
`functions/src/payment/stripeProvider.ts`), jamais de simulation silencieuse
de paiement réussi.

## 10. Audit branchement Stripe LIVE (Phase 8B) — référence de vérité

Cette section documente l'audit exhaustif du code réel effectué AVANT toute
demande de secrets LIVE à Daniel (projet `movik-connect-prod`). Aucune
architecture existante n'a été refaite — uniquement 2 bugs de configuration
Cloud Functions v2 corrigés (voir 10.4).

### 10.1 Cloud Function webhook

- **Nom** : `processStripeWebhook` (`functions/src/functions/processStripeWebhook.ts`).
- **Type** : `onRequest` (v2, HTTPS publique, PAS `onCall`).
- **Région** : aucun `region()`/`setGlobalOptions()` n'est déclaré nulle part
  dans `functions/src/` → région par défaut Cloud Functions v2/v1 =
  **`us-central1`**. À confirmer une seule fois par une lecture
  `firebase functions:list` après le premier déploiement (jamais supposée
  au-delà de ce défaut documenté par Firebase).
- **URL publique LIVE** (format Cloud Functions v2 / Cloud Run) :
  `https://us-central1-movik-connect-prod.cloudfunctions.net/processStripeWebhook`
  — c'est CETTE URL qui doit être saisie comme endpoint dans le Dashboard
  Stripe (mode LIVE), identique en forme à l'endpoint TEST (seul le Secret
  Manager change, jamais l'URL).

### 10.2 Événements Stripe strictement nécessaires

Liste exhaustive extraite du `switch` réel de `processStripeWebhook.ts` (tout
autre type d'évènement est accusé réception 200 et ignoré, sans effet) :

- `payment_intent.succeeded`
- `payment_intent.payment_failed`
- `charge.refund.updated`
- `refund.updated`
- `payout.paid`
- `payout.failed`
- `charge.dispute.created`
- `charge.dispute.updated`
- `charge.dispute.closed`
- `account.updated` (Connected Accounts — synchronise `stripe_charges_enabled`/
  `stripe_payouts_enabled` sur `driver_profiles/{driverId}`)

### 10.3 Stripe Connect

- **Type de compte** : Express (`stripe.accounts.create({ type: "express", ... })`,
  `stripeProvider.ts::createDriverAccount`).
- **GAP FERMÉ (Bloc 8B LIVE, "DERNIER CHECK AVANT SECRETS")** : les URLs de
  retour/refresh étaient codées en dur sur `https://movik.ca/...`. Vérif
  réseau réelle (`curl -sv https://movik.ca`) : échec de handshake TLS
  (`SSL routines::ssl/tls alert handshake failure`) et `curl http://movik.ca`
  → `error code: 1001` — **ce domaine ne sert PAS l'app Movi-K
  actuellement**. Le domaine RÉELLEMENT en ligne, vérifié (`curl -sI` → HTTP
  200, `<title>movik_connect</title>`), est
  `https://mecano-mobile-delta.vercel.app`.
- **Correctif appliqué** :
  - `functions/src/lib/appConfig.ts` (nouveau) déclare `APP_PUBLIC_BASE_URL`
    via `defineString` (NON un secret — c'est une URL publique) avec pour
    valeur par défaut le domaine Vercel ci-dessus.
  - `stripeProvider.ts::createDriverAccount` utilise maintenant
    `getDriverStripeReturnUrl()`/`getDriverStripeRefreshUrl()` (au lieu des
    chaînes en dur) → **Return URL final** :
    `https://mecano-mobile-delta.vercel.app/fr/chauffeur/onboarding/complete` ;
    **Refresh URL final** :
    `https://mecano-mobile-delta.vercel.app/fr/chauffeur/onboarding/refresh`.
  - Si Daniel branche plus tard un domaine public final différent (ex.
    `movik.ca` une fois correctement configuré), il suffit de définir le
    paramètre `APP_PUBLIC_BASE_URL` côté Firebase (Console > Functions >
    Configuration des paramètres, ou `.env.movik-connect-prod`) — AUCUNE
    modification de code requise.
  - Nouvelles routes Flutter (FR/EN/ES) ajoutées dans
    `lib/router/app_router.dart`, gérées par
    `DriverStripeOnboardingReturnScreen` (nouveau fichier) : couvrent (a)
    retour onboarding complété, (b) refresh/retry, (c) relecture de l'état
    Connect (réutilise le `watchDriverProfile` stream existant, aucune
    logique dupliquée), (d) retour propre vers l'onglet Profil du chauffeur
    (`ProviderDashboardShell` accepte maintenant `initialTabIndex`, défaut
    `0` inchangé pour tout appelant existant).
  - Tests ajoutés : `test/driver/driver_stripe_onboarding_return_screen_test.dart`
    (12 tests, couvrant les 3 nouvelles routes FR/EN/ES, les 2 modes, la
    relecture d'état, et la navigation vers l'onglet Profil) — tous verts,
    aucune régression sur les suites existantes
    (`app_router_invalid_routes_test.dart`,
    `provider_dashboard_shell_status_gate_test.dart`,
    `provider_stripe_connect_section_test.dart`).

### 10.4 Bugs de configuration corrigés dans cet audit (BUG LIVE-01/02)

Deux Cloud Functions appellent réellement Stripe via
`payment/paymentOrchestration.ts` mais NE déclaraient PAS `secrets: [...]`
dans leurs options v2 — en Cloud Functions v2, un secret Secret Manager
n'est injecté dans le runtime QUE si la fonction le déclare explicitement.
Sans ce correctif, `STRIPE_SECRET_KEY`/`STRIPE_WEBHOOK_SECRET` auraient été
absents à l'exécution même correctement configurés dans Secret Manager,
provoquant un échec SILENCIEUX ("fournisseur non configuré") de toute
opération réelle :

- **BUG LIVE-01** : `refundPayment.ts` (callable, appelle
  `refundPaymentOrchestration` → `provider.refundPayment()`) — corrigé,
  déclare maintenant `{ secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET] }`.
- **BUG LIVE-02** : `processScheduledDriverPayouts.ts` (cron horaire, appelle
  `submitDriverPayout` → `provider.createDriverPayout()`) — corrigé, déclare
  maintenant `{ schedule: "every 60 minutes", secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET] }`.

Tests unitaires (109/109) + intégration ciblée (`refundPayment.test.ts` 15/15,
`e2eFinancialLifecycle`/`submitDriverPayoutFailure`/`financialConcurrency`
6/6) re-passés après correctif, aucune régression (ces tests utilisent
`setPaymentProviderForTesting()` en émulateur, indépendant des secrets réels
— la correction ne change donc que le comportement PRODUCTION, jamais le
comportement testé en émulateur).

Fonctions confirmées SANS besoin de secret Stripe (aucun appel
`getPaymentProvider()`/Stripe direct) : `updateDisputeStatus.ts` (délègue à
`disputeOrchestration.ts`, qui ne fait jamais d'appel réseau Stripe — un
litige est déjà un fait acquis côté Stripe au moment du webhook),
`reverseDriverPayout.ts` (compensation comptable pure, documente
explicitement qu'aucun appel provider n'existe côté Stripe pour annuler un
payout déjà `PAID`).

### 10.5 Cartographie exacte des secrets par fonction

| Fonction | `STRIPE_SECRET_KEY` | `STRIPE_WEBHOOK_SECRET` | Résultat de l'audit |
|---|---|---|---|
| `processStripeWebhook` | ✅ | ✅ | déjà correct |
| `createDriverStripeAccount` | ✅ | ✅ (non utilisé en pratique — `createDriverAccount()` ne vérifie aucune signature ; déclaré par prudence/symétrie historique, non corrigé ce tour car sans impact fonctionnel ni risque) | déjà correct (surdéclaration bénigne) |
| `acceptDelivery` | ✅ | ✅ | déjà correct |
| `completeDelivery` | ✅ | ✅ | déjà correct |
| `attachCustomerPaymentMethod` | ✅ | ✅ | déjà correct |
| `createCustomerPaymentProfile` | ✅ | ✅ | déjà correct |
| `runReconciliationNow` / `runDailyReconciliation` | ✅ | ✅ | déjà correct |
| `refundPayment` | ✅ (corrigé ce tour) | ✅ (corrigé ce tour) | **BUG LIVE-01 corrigé** |
| `processScheduledDriverPayouts` | ✅ (corrigé ce tour) | ✅ (corrigé ce tour) | **BUG LIVE-02 corrigé** |
| `updateDisputeStatus` | — (n'appelle jamais Stripe) | — | correct par conception |
| `reverseDriverPayout` | — (n'appelle jamais Stripe) | — | correct par conception |

### 10.6 Surface API Stripe réellement utilisée (analyse Restricted Key)

Ressources/méthodes Stripe SDK effectivement appelées dans
`stripeProvider.ts` (liste exhaustive, grep confirmé) :

- `customers.create`
- `paymentMethods.attach`
- `paymentIntents.create` / `.confirm` / `.capture` / `.cancel` / `.retrieve` / `.list`
- `refunds.create` / `.retrieve` / `.list`
- `payouts.create` / `.retrieve` / `.list`
- `accounts.create`
- `accountLinks.create`
- `webhooks.constructEvent` (vérification de signature — ne consomme pas la
  clé secrète API, uniquement `STRIPE_WEBHOOK_SECRET`)

Toutes ces ressources correspondent à des permissions granulaires standard
d'une **Restricted API Key** Stripe. Stripe recommande explicitement une
Restricted Key quand le périmètre peut être scopé
(docs.stripe.com/keys/restricted-api-keys) — c'est le cas ici : AUCUNE
méthode utilisée ne requiert un accès non-scopable (pas de gestion de
compte plateforme globale, pas de Radar rules, pas de Billing/Tax API, pas
de Terminal). **Recommandation confirmée : Restricted Key LIVE**, pas la
clé secrète complète `sk_live_...`.

#### 10.6.1 LISTE FINALE EXHAUSTIVE des permissions (vérification "DERNIER CHECK")

Vérification ciblée par re-lecture du code réel (`attachCustomerPaymentMethod.ts`
→ `getPaymentProvider().attachPaymentMethod()` → `stripeProvider.ts` ligne 77
`this.stripe.paymentMethods.attach(...)`) + grep exhaustif de
`this.stripe.transfers|balance|externalAccounts|external_accounts|topups`
(0 match, confirmé) :

| Ressource Dashboard Stripe | Permission | Requis | Preuve code |
|---|---|---|---|
| Customers | **Write** | OUI | `customers.create` (`createCustomerPaymentProfile.ts`) |
| **Payment Methods** | **Write** | **OUI** (absent de la 1ère liste — corrigé ici) | `paymentMethods.attach` (`attachCustomerPaymentMethod.ts` → `stripeProvider.ts:77`) |
| Payment Intents | Write | OUI | `.create/.confirm/.capture/.cancel/.retrieve/.list` |
| Charges | Read | OUI (implicite, lecture de `charge.dispute.*`/`charge.refund.updated` via webhook, pas d'appel API direct côté serveur) | `processStripeWebhook.ts` (événements) |
| Refunds | Write | OUI | `refunds.create/.retrieve/.list` |
| Payouts | Write | OUI | `payouts.create/.retrieve/.list` (avec `{stripeAccount}`) |
| Connected accounts (Accounts) | Write | OUI | `accounts.create` |
| Account Links | Write | OUI | `accountLinks.create` |
| **Transfers** | — | **NON** | 0 appel `stripe.transfers.*` dans tout le code — le mouvement de fonds passe exclusivement par `transfer_data.destination` sur `paymentIntents.create()` (destination charges, docs.stripe.com/connect/destination-charges), jamais par un appel `/v1/transfers` séparé |
| **Balance** | — | **NON** | 0 appel `stripe.balance.*` |
| **External Accounts** | — | **NON** | 0 appel `externalAccounts`/`external_accounts` (Stripe gère l'ajout du RIB du chauffeur dans le flow d'onboarding hébergé lui-même, jamais via l'API Movi-K) |
| **Connected accounts (accès Connect)** | Case "Connected accounts" cochée | OUI | requis dès qu'on appelle `payouts.create(..., {stripeAccount: id})` "as the connected account" (docs.stripe.com/connect/authentication) |
| Webhooks | (n/a — `STRIPE_WEBHOOK_SECRET`, pas la clé API) | — | `webhooks.constructEvent` ne consomme pas la clé secrète API |

**Note d'honnêteté épistémique** : cette liste est déduite du code source
réel (grep + lecture complète), pas d'une supposition. Le mapping exact
"nom technique API → libellé Dashboard Restricted Key" doit être confirmé
visuellement par Daniel au moment de créer la clé (les libellés Dashboard
peuvent différer légèrement de la documentation `stripe-apps/reference/permissions`
utilisée ici pour le raisonnement). Si un appel échoue en mode LIVE malgré
cette liste, le Dashboard Stripe > Developers > API keys > cette clé >
"Voir les logs de requêtes" indique exactement quelle permission manquante
a causé le refus — c'est la méthode de vérification faisant autorité
recommandée par Stripe elle-même, à utiliser en TEST avant tout premier
transfert réel.

### 10.7 Webhook — statut de déploiement et événements Connect (DERNIER CHECK)

- **Endpoint exact** : `https://us-central1-movik-connect-prod.cloudfunctions.net/processStripeWebhook`
- **Région réelle** : `us-central1` (défaut Cloud Functions v2, confirmé par
  absence de `region()`/`setGlobalOptions()` dans tout `functions/src/`).
- **Actuellement déployé : NON VÉRIFIABLE depuis ce sandbox.** Ce sandbox
  n'a aucun accès Firebase CLI authentifié ni console GCP pour le projet
  réel `movik-connect-prod` (pas de `firebase` CLI installé/connecté, pas de
  `GOOGLE_APPLICATION_CREDENTIALS`). Le code est **CODE READY** (build+lint
  OK, la fonction est exportée dans `index.ts`) mais je ne peux pas
  transformer cela en une affirmation "DEPLOYED"/"VERIFIED LIVE" sans
  vérification externe réelle (règle de non-fabrication déjà appliquée dans
  les tours précédents). **Action Daniel** : confirmer via
  `firebase functions:list --project movik-connect-prod` (ou Firebase
  Console > Functions) que `processStripeWebhook` apparaît bien dans la
  liste déployée, AVANT de créer l'endpoint webhook LIVE dans le Dashboard
  Stripe.
- **`account.updated` doit être configuré comme événement Connected
  Account** dans le Dashboard Stripe (case "Listen to events on Connected
  accounts" ou équivalent lors de la création de l'endpoint webhook LIVE) —
  c'est le seul des 10 événements qui concerne un compte CONNECTÉ (le
  chauffeur), pas le compte plateforme.
- **Les 9 autres événements sont des événements PLATEFORME** (pas Connect) :
  dans l'architecture "destination charges" utilisée ici
  (`transfer_data.destination` sur `PaymentIntent`), Stripe débite les
  paiements, remboursements, litiges et frais sur le compte PLATEFORME, pas
  sur le compte connecté (docs.stripe.com/connect/destination-charges,
  "For destination charges... Stripe debits dispute amounts and fees from
  your platform account") — donc `payment_intent.*`, `charge.refund.updated`,
  `refund.updated`, `payout.*` (payout du solde du compte connecté mais
  l'événement webhook lui-même, dans ce flow, est écouté côté plateforme via
  l'endpoint unique), `charge.dispute.*` doivent rester des événements
  plateforme standard (pas cochés "Connected accounts").

### 10.8 Kill switches — statut production réel (DERNIER CHECK, honnêteté requise)

- **Comportement CODE (déjà vérifié, inchangé)** : `runtimeFlags.ts` retourne
  `false` en fail-closed pour `payments_enabled`/`driver_payouts_enabled` si
  le document `system_config/runtime_flags` (ou le champ) est absent/invalide
  — comportement CODE READY, testé.
- **Nuance BOOTSTRAP (déjà identifiée)** : si un admin a DÉJÀ appelé
  `updateRuntimeFlags` au moins une fois (même par le passé, pour un autre
  flag), le document existe et les 4 flags ont été initialisés à `true` au
  premier appel avant patch — donc l'état réel dépend de CE QUI A DÉJÀ ÉTÉ
  ÉCRIT en production, pas seulement du défaut fail-closed.
- **NON VÉRIFIABLE depuis ce sandbox** : aucun accès Firestore/console au
  projet réel `movik-connect-prod`. Je ne peux pas affirmer la valeur réelle
  actuelle de ces deux flags en production sans fabrication.
- **Action Daniel (OBLIGATOIRE avant toute clé LIVE)** : ouvrir Firebase
  Console > Firestore > `movik-connect-prod` > collection `system_config` >
  document `runtime_flags`, et confirmer/forcer explicitement :
  `payments_enabled: false` et `driver_payouts_enabled: false` (créer le
  document avec ces valeurs s'il n'existe pas encore). Ne PAS se reposer
  uniquement sur le fail-closed du code pour cette phase de configuration.

### 10.9 BLOQUEUR WEBHOOK PRODUCTION (Bloc 8B LIVE) — architecture à 2 endpoints

**Origine du bloqueur** : Daniel a vérifié personnellement Firebase Console
> `movik-connect-prod` > Functions et **confirmé que `processStripeWebhook`
N'EXISTE PAS** dans les Functions déployées. Ceci transforme la mise en
garde "NON VÉRIFIABLE" du §10.7 en **BLOCAGE CONFIRMÉ**. Avant toute
correction, la question posée était : Stripe exige-t-il UN seul endpoint
webhook capable de recevoir à la fois les 9 événements plateforme et
`account.updated` (Connect), ou DEUX endpoints distincts ?

**Réponse confirmée (docs.stripe.com/connect/webhooks, crawl réel)** :
chaque endpoint webhook Stripe est scopé **exclusivement** à "Your account"
(événements PLATEFORME, paramètre API `connect: false`) OU "Connected
accounts" (événements sur un compte CONNECTÉ, `connect: true`) — c'est un
scope PAR ENDPOINT, jamais par type d'événement à l'intérieur d'un même
endpoint. Comme Movi-K a besoin des deux (9 événements plateforme +
`account.updated` en Connect), **2 endpoints webhook distincts sont
requis**, chacun avec son propre secret de signature `whsec_...` (jamais
partagé, même s'ils appartiennent au même compte Stripe).

**Architecture implémentée** (`functions/src/functions/processStripeWebhook.ts`) :

- `dispatchStripeEvent(event, sourceFunctionName)` — logique métier
  100% PARTAGÉE, inchangée dans son contenu (switch/case par type
  d'événement), désormais paramétrée par `sourceFunctionName` pour que
  chaque `writeAuditLog()` interne reflète l'endpoint HTTP réel qui a reçu
  la requête (bug découvert et corrigé pendant cette session : ces appels
  hardcodaient auparavant littéralement `"processStripeWebhook"`, y compris
  pour `account.updated` qui transitera TOUJOURS par l'endpoint Connect en
  production — voir ci-dessous).
- `buildStripeWebhookHandler(sourceFunctionName, getWebhookSecretValue)` —
  fabrique le handler `onRequest` complet (vérification de signature,
  idempotence `provider_webhook_events/{event.id}`, dispatch, audit,
  observabilité) ; SEULE différence entre les deux endpoints exportés :
  quel secret sert à vérifier la signature et quel nom est journalisé
  comme `sourceFunction`.
- `StripeProvider.constructVerifiedEvent(rawBody, signatureHeader, secretOverride?)`
  accepte désormais un secret explicite par appel (retombe sur l'ancien
  `this.webhookSecret` legacy si omis, pour compatibilité).
- Deux exports Cloud Functions v2 (`functions/src/index.ts`) :

  ```typescript
  export const processStripeWebhook = onRequest(
    { secrets: [STRIPE_SECRET_KEY, STRIPE_PLATFORM_WEBHOOK_SECRET] },
    buildStripeWebhookHandler("processStripeWebhook", () => STRIPE_PLATFORM_WEBHOOK_SECRET.value())
  );

  export const processStripeConnectWebhook = onRequest(
    { secrets: [STRIPE_SECRET_KEY, STRIPE_CONNECT_WEBHOOK_SECRET] },
    buildStripeWebhookHandler("processStripeConnectWebhook", () => STRIPE_CONNECT_WEBHOOK_SECRET.value())
  );
  ```

- **Aucune duplication de logique métier** : les deux endpoints appellent
  le même `dispatchStripeEvent()` et partagent le même registre
  d'idempotence `provider_webhook_events/{event.id}` (l'ID d'événement
  Stripe est unique tous endpoints confondus, aucun risque de collision).

**Secrets Secret Manager requis (`functions/src/lib/secrets.ts`)** :

| Nom du secret | Consommé par | Remplace |
|---|---|---|
| `STRIPE_PLATFORM_WEBHOOK_SECRET` | `processStripeWebhook` (endpoint "Your account") | — nouveau |
| `STRIPE_CONNECT_WEBHOOK_SECRET` | `processStripeConnectWebhook` (endpoint "Connected accounts") | — nouveau |
| `STRIPE_WEBHOOK_SECRET` | conservé `@deprecated`, legacy, aucun des deux endpoints réels ne l'utilise plus pour la vérification de signature | ancien nom unique, insuffisant pour 2 endpoints |

Aucun secret n'est ni committé dans Git, ni écrit en dur, ni exposé côté
Flutter — inchangé par rapport aux règles déjà en vigueur (point 30 du
cahier des charges).

**URLs des deux endpoints LIVE** (format Cloud Functions v2, région
`us-central1` confirmée par défaut — voir §10.1) :

- Webhook plateforme : `https://us-central1-movik-connect-prod.cloudfunctions.net/processStripeWebhook`
- Webhook Connect : `https://us-central1-movik-connect-prod.cloudfunctions.net/processStripeConnectWebhook`

**Pourquoi rien n'est actuellement déployé (cause racine confirmée)** :
absence totale de pipeline CI/CD — `ls -la .github` confirme qu'aucun
répertoire `.github/workflows/` n'existe dans ce dépôt, et `find . -iname
"*.yml" -o -iname "*.yaml"` ne retourne que `analysis_options.yaml`/
`pubspec.yaml` (Flutter), aucun fichier de workflow. `functions/package.json`
définit `"deploy": "firebase deploy --only functions"` comme un script
**manuel**, jamais déclenché automatiquement par un merge/push GitHub. Ceci
explique pourquoi `processStripeWebhook` — et très probablement TOUTES les
autres Cloud Functions du projet — n'a jamais été réellement poussée vers
`movik-connect-prod` : le déploiement a toujours nécessité une exécution
manuelle avec des identifiants Firebase CLI réels, jamais disponibles dans
ce sandbox, et apparemment jamais exécutée par personne côté production
avant la découverte de ce bloqueur.

**Restricted Key et `payouts.create` — recherche complémentaire** :
`docs.stripe.com/keys/restricted-api-keys` confirme littéralement : *"If you
use Connect, you can also select the permission to allow for this key when
accessing connected accounts"* — ceci confirme qu'un accès Connect
("Connected accounts") est une dimension de permission **séparée** de la
grille Read/Write/None par ressource (Payouts, Customers, etc.), nécessaire
en plus de "Payouts: Write" pour que `payouts.create(..., {stripeAccount:
acct_...})` fonctionne (voir aussi §10.6.1). Le libellé Dashboard exact de
ce bascule n'a pas pu être confirmé mot pour mot dans la documentation
officielle malgré plusieurs recherches ciblées ; son existence est en
revanche certaine. **Conclusion honnête : "À CONFIRMER", pas "OUI"** — la
méthode de vérification faisant autorité, recommandée par Stripe
elle-même, est de créer la clé en mode **TEST**, effectuer un
`payouts.create` réel vers un compte connecté TEST, et consulter Dashboard
Stripe > Developers > API keys > cette clé > "Voir les logs de requêtes" en
cas d'erreur 403 pour identifier précisément la permission manquante, AVANT
de répliquer la même configuration en LIVE.

**Bug corrigé pendant cette implémentation** : les appels `writeAuditLog()`
internes à `dispatchStripeEvent()` (branches `payment_intent.*`,
`charge.refund.updated`/`refund.updated`, `payout.*`, `account.updated`)
journalisaient auparavant un `sourceFunction: "processStripeWebhook"`
littéral et figé, quel que soit l'endpoint réel ayant reçu la requête —
ceci aurait rendu les journaux d'audit de `account.updated` (qui transite
TOUJOURS par `processStripeConnectWebhook` en production) trompeurs pour
toute investigation de traçabilité future. Corrigé en propageant
`sourceFunctionName` depuis le handler appelant jusqu'à chaque
`writeAuditLog()` interne. Couvert par un test d'intégration dédié
(`processStripeWebhook.test.ts`, assertion sur
`audit_logs.source_function == "processStripeConnectWebhook"`).

**Tests** : 24/24 tests d'intégration `processStripeWebhook.test.ts` verts
(incluant 2 nouveaux tests : rejet croisé secret Connect utilisé sur
l'endpoint plateforme et vice-versa, "secrets non interchangeables") ;
3/3 `e2eDisputeChargebackLifecycle.test.ts` verts (endpoint plateforme
uniquement, adapté pour fixer `STRIPE_PLATFORM_WEBHOOK_SECRET` en variable
d'environnement de test) ; 109/109 tests unitaires inchangés.
