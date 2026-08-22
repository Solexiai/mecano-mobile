# Phase 6 — Plan officiel Blocs R → V (Movi-K, directive 38 points)

> **Statut au moment de la rédaction** : Bloc P ✅ FERMÉ (commit `1276264`),
> Bloc Q ✅ FERMÉ (commit `53685ab`). `HEAD == origin/main`, working tree
> clean. Ce document fige la définition officielle des blocs R à V afin
> qu'elle ne soit jamais perdue lors d'une compaction de contexte ou d'un
> changement de session. **Aucune redemande de portée ne doit être faite —
> ce fichier est la source de vérité.**
>
> Exécution : R → S → T → U → V, en mode autonome, sans validation
> utilisateur intermédiaire, sans nouvel audit général au démarrage de
> chaque bloc (sauf le Bloc T qui EST explicitement l'audit sécurité, et le
> Bloc U qui EST explicitement la validation globale).

---

## BLOC R — E2E REFUND APRÈS PAYOUT

**Objectif** : prouver le comportement financier lorsque le chauffeur a
DÉJÀ été payé et qu'un remboursement client arrive ensuite.

### Scénario E2E réel (Cloud Functions réelles uniquement)

```text
payment authorized
→ payment captured
→ mission completed
→ driver earnings enregistrés
→ payout chauffeur créé
→ hold expiré
→ payout processing
→ payout paid
→ refund client après payout
→ provider refund succeeded
→ payout historique reste PAID
→ aucune modification rétroactive
→ compensation financière créée
→ ledger append-only
→ mission_financial_balance recalculé
→ reconciliation cohérente
```

### Assertions obligatoires

- payout historique reste `paid`
- `paid_at` reste inchangé
- `provider_payout_id` reste inchangé
- montant du payout historique reste inchangé
- aucune entrée ledger historique modifiée/supprimée
- refund crée de nouvelles écritures compensatoires
- `customer_refunded` est exact
- `driver_paid` historique reste exact
- `outstanding_driver_balance` (ou mécanisme de compensation équivalent)
  reflète correctement la situation
- `mission_financial_balance` reste cohérent
- reconciliation ne laisse pas d'anomalie non expliquée

### Règle impérative

**Ne jamais récupérer automatiquement l'argent du chauffeur juste pour
faire passer le test.** Si la politique métier ne prévoit pas encore une
récupération automatique :
- comptabiliser la créance/compensation
- garder l'historique intact
- ne pas inventer une règle commerciale

### Couverture minimale de tests

- refund partiel après payout
- refund complet après payout si l'architecture le permet
- double refund interdit/idempotent
- aucun double ledger

### Clôture

Quand tout est vert : déclarer **BLOC R : ✅ FERMÉ**, commit + push, puis
continuer directement S.

---

## BLOC S — E2E DISPUTE / CHARGEBACK

**Objectif** : tester le cycle complet d'une dispute Stripe/chargeback, via
un E2E utilisant les vrais webhooks signés déjà développés.

### Scénario

```text
payment captured
→ webhook charge.dispute.created
→ dispute opened
→ audit financier
→ impact ledger/balance selon architecture
→ webhook dispute updated
→ under_review
→ won OU lost
→ closed
→ éventuelle reversal
→ mission_financial_balance cohérente
→ reconciliation cohérente
```

### Couverture minimale de tests

- dispute opened
- under_review
- won
- lost
- closed
- reversed si réellement supporté
- event webhook dupliqué
- event invalide/signature invalide déjà couverte ailleurs, mais aucune
  régression

### Assertions

- une seule dispute métier créée par provider event
- pas de double ledger
- pas de double compensation
- `provider_event_id` traité une seule fois
- audit `dispute_opened/updated/closed`
- balance cohérente
- reconciliation cohérente

### Règle impérative

Ne pas modifier artificiellement les statuts Firestore si les
orchestrations/webhooks existent déjà — passer par les vrais chemins de
code (webhook réel signé → orchestration réelle).

### Clôture

Quand tout est vert : déclarer **BLOC S : ✅ FERMÉ**, commit + push, puis
continuer T.

---

## BLOC T — SECURITY RULES GLOBAL PHASE 6

Dernier audit global des règles de sécurité de toute la Phase 6.

### Collections au minimum

- `payments`
- `refunds`
- `driver_payouts`
- `disputes`
- `provider_webhook_events`
- `reconciliation_reports`
- `payment_profiles`
- `idempotency_keys`
- `tax_configs`
- `payout_policy_configs`
- `mission_financial_balance`
- `transaction_ledger`
- `financial_snapshots`
- audit logs financiers

### Rôles à tester

unauthenticated, customer, driver, analyst, admin, super_admin.

### Principe

**DENY BY DEFAULT.**

### Customer

Peut lire uniquement ses données autorisées. Ne peut JAMAIS directement :
modifier payment status, créer fake payment success, modifier refund,
modifier payout, modifier commission, modifier tip, modifier bonus,
modifier financial snapshot, modifier tax snapshot, modifier ledger,
modifier mission financial balance, écrire reconciliation reports, écrire
provider webhook events, écrire idempotency keys.

### Driver

Peut lire ses propres gains/payouts autorisés. Ne peut JAMAIS directement
modifier : payout amount, payout status, provider payout id, payment,
refund, commission, tip, bonus, ledger, taxes, snapshot, reconciliation.

### Analyst/Admin/Super Admin

Respecter exactement les permissions existantes. Ne pas élargir les droits
juste pour faire passer les tests. Les écritures financières sensibles
doivent rester : Cloud Functions / Admin SDK uniquement.

### Storage Rules à inclure

Validation globale des preuves de livraison :
- chauffeur assigné upload autorisé
- autre chauffeur refusé
- client upload refusé
- unauthenticated refusé
- type MIME invalide refusé
- taille excessive refusée selon règle
- client propriétaire lecture autorisée
- autre client refusé
- immutabilité selon règles existantes

### Clôture

Quand tout est vert : déclarer **BLOC T : ✅ FERMÉ**, commit + push, puis
continuer U.

---

## BLOC U — VALIDATION GLOBALE PHASE 6

**Objectif** : validation complète de TOUTE la Phase 6.

### Exécuter réellement

```text
npx tsc --noEmit
npm run lint
npm run test:unit
npm run test:integration
flutter analyze
flutter test
```

### Confirmer les suites spécifiques

Payment, Refund, Payout, Webhooks Stripe, Disputes, Taxes, Mission
Financial Balance, Reconciliation, Audit financier, Observabilité,
Concurrence, Founding Drivers, Security Rules, Storage Rules, E2E P, E2E Q,
E2E R, E2E S.

### Storage flaky historique

Des échecs intermittents ont déjà été observés dans `storageRules.test.ts`
(disparus lors d'autres runs). Au Bloc U :
- relancer la suite Storage plusieurs fois
- ne pas ignorer un test rouge
- distinguer vrai bug vs instabilité Emulator
- corriger si bug réel
- documenter précisément si environnemental (pas de simple « probablement
  flaky »)

### UI / Flutter

Vérifier aussi : UI finance client, UI finance chauffeur, UI finance admin,
FR, EN, ES, loading, empty, error, responsive, aucun RenderFlex overflow
critique, aucune chaîne Phase 6 importante hardcodée.

### Secrets / Production safety

Vérifier qu'aucun secret n'est commité : Stripe secret key, webhook signing
secret, token, Firebase credentials, Authorization header, card data, CVC,
`.env` sensible. Vérifier aussi que `FakePaymentProvider` n'est PAS
sélectionné par défaut en production.

### Régressions

Si une suite révèle un vrai bug dans un bloc déjà fermé : corriger
uniquement le bug. Ajouter un test anti-régression si utile. Ne rouvrir/
reconstruire tout le bloc que si absolument nécessaire.

### Clôture

Quand tout est vert : déclarer **BLOC U : ✅ FERMÉ**, commit + push si
corrections, puis continuer V.

---

## BLOC V — CLÔTURE GIT ET PHASE 6

Dernière vérification.

```text
git status
git diff
git log -1
```

Vérifier :
- aucun fichier temporaire
- aucun fichier WIP inutile
- aucun `debugDumpApp()`
- aucun test `skip` ajouté pour masquer un échec
- aucun mock de test utilisé en production
- aucun secret
- aucune modification non commitée
- documentation cohérente

Formatter uniquement les fichiers réellement modifiés. Jamais de format
global.

Puis : commit final Phase 6 si nécessaire, push `origin/main`, vérifier
`HEAD == origin/main` et working tree clean.

---

## Définition de fin de Phase 6

Ne déclarer la Phase 6 terminée que si TOUT ce qui suit est vérifié :

```text
Payment lifecycle ✅
Authorization ✅
Capture ✅

Commission variable ✅
Founding Drivers ✅
100 % tip chauffeur ✅

Payout ✅
Hold configurable ✅
Payout idempotent ✅
Payout reversal ✅

Refund complet ✅
Refund partiel ✅
Refund post-payout ✅

Disputes / chargebacks ✅
Stripe webhooks signés ✅
Webhooks idempotents ✅

Taxes configurables ✅
Tax snapshot immuable ✅

Mission financial balance ✅
Ledger append-only ✅
Reconciliation ✅
Audit financier ✅
Observabilité ✅

UI client ✅
UI chauffeur ✅
UI admin ✅

FR/EN/ES ✅
Concurrency tests ✅
Security Rules ✅
Storage Rules ✅

E2E principal P ✅
E2E refund Q ✅
E2E refund post-payout R ✅
E2E dispute S ✅

Validation globale U ✅
GitHub synchronisé ✅
```

## Rapport final attendu (uniquement à la toute fin)

```text
# PHASE 6 : ✅ TERMINÉE

## EN CLAIR
### Movi-K sait maintenant
- ...

### Tests
- unitaires : X/X
- intégration : X/X
- Flutter : X/X
- Security Rules : X/X
- Storage Rules : X/X
- concurrence : PASS
- Founding Drivers : PASS
- E2E P : PASS
- E2E Q : PASS
- E2E R : PASS
- E2E S : PASS
- reconciliation : PASS

### Git
- commit final : <hash>
- HEAD == origin/main
- working tree clean

### Action requise de Daniel
- aucune (ou seulement une action externe réellement indispensable)

### Prochaine phase
Phase 7 — QA globale / durcissement préproduction
```

## Règle de continuité

Ce fichier (`docs/PHASE6_R_TO_V_PLAN.md`) est la référence permanente pour
R → S → T → U → V. Il ne doit plus jamais être redemandé à l'utilisateur ;
en cas de compaction de contexte ou nouvelle session, relire ce fichier
avant toute reprise de travail sur ces blocs.
