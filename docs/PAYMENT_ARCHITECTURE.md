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
