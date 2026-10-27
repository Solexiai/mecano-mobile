# Movi-K — Ce qui reste à faire avant le lancement

**Date :** 27 octobre 2026
**Base analysée :** `main` au commit `bbfbcad` (feat(analytics): connect GA4 web stream, PR #91)
**Périmètre :** code Flutter (`lib/`, 60 696 lignes, 229 fichiers), Cloud Functions TypeScript (`functions/src`, 22 147 lignes, 73 exports), règles Firestore/Storage, index, CI, scripts de build, et l'intégralité de `docs/` (33 fichiers, 14 386 lignes).
**Méthode :** lecture complète des documents pour reprendre l'état déclaré et les décisions prises, puis six revues parallèles du code (sécurité ; paiements, dispatch et configuration ; écrans client, public et i18n ; écrans chauffeur et admin ; qualité et dette technique ; synthèse documentaire). `npm ci`, `npm run lint`, `npm run build` et `npm run test:unit` ont été exécutés dans `functions/` : **lint et build verts, 713 tests unitaires / 53 suites, 0 échec**. Aucun fichier du dépôt n'a été modifié en dehors du présent rapport.

**Limites de cette analyse :**
- Le site en ligne (`movi-k.com`, `www.movi-k.com`, prévisualisations Vercel) n'était **pas joignable** depuis l'environnement d'analyse (résolution DNS bloquée). Le « site » a été analysé à partir de `web/index.html`, du routeur Flutter, des écrans et du script de build Vercel. Les pages réellement servies n'ont pas été vues.
- Flutter n'est pas installé dans l'environnement : `flutter analyze`, `flutter test` (675 tests déclarés) et `flutter build web` n'ont pas été exécutés. La revue des écrans est statique.
- L'état réel de `movik-connect-prod` (fonctions et règles déployées, valeurs de `system_config/*`, secrets, sauvegardes, App Check, comptes admin) n'est pas vérifiable depuis le dépôt. Les docs sont la seule source ; le dernier état cité date du 20 octobre 2026.

Tout ce qui n'a pu être vérifié est marqué **non vérifié**.

---

## Résumé exécutif

**Verdict : NO-GO pour un paiement réel aujourd'hui, et le logiciel n'est pas « prêt sauf configuration ».** Les docs (PILOT_READINESS 8L, registre de bogues) concluent déjà à un NO-GO pour cause de dépendances externes. Cette analyse ajoute des **défauts logiciels bloquants** que les docs ne connaissent pas, principalement dans la chaîne d'argent :

1. **N'importe quel client peut se rembourser intégralement** par appel direct de `refundPayment`, après livraison et après versement du chauffeur (SEC-01).
2. **Les versements chauffeurs n'existent pas en pratique** : `calculateDriverPayout` n'est appelé par aucun écran ni aucun cron ; les onglets « Versements » resteront vides et la rétention de 72 h documentée est inopérante (DRV-09). Si on l'appelait, le payout échouerait probablement car les comptes Express sont créés avec le versement automatique quotidien Stripe (PAY-04).
3. **Aucune interface de remboursement ni de litige côté admin** : les onglets sont en lecture seule (ADM-01). Aucune interface pour les quatre interrupteurs d'urgence (ADM-02).
4. **Capture refusée après livraison = perte sèche** : paiement en état terminal `FAILED`, mission `completed`, chauffeur payé quand même (PAY-03). **Autorisation Stripe posée à l'acceptation** sans surveillance de l'expiration de 7 jours pour les réservations planifiées (PAY-08).
5. **Les taxes TPS/TVQ ne sont pas configurées** et la grille pilote active provient d'un script à `tax_rate: 0` ; aucun numéro d'enregistrement fiscal n'apparaît dans l'app ni sur les reçus (PAY-07).
6. **Textes légaux** : la seule fonction qui publie `system_config/booking_policy` publie la version « ESSAI, sans argent réel » ; les textes de repli affichés dans l'app sont des brouillons « en révision » contredisant la FAQ et la page Tarifs sur les frais d'annulation ; la politique de confidentialité ne satisfait pas la Loi 25 ; GA4 est chargé sans consentement (PAY-12, LEG-01 à LEG-04).
7. **Compte « démo » codé en dur** : un compte dont le courriel est `demo.client.160926@movi-k.com` crée des missions sans paiement et sans interrupteurs ; si ce compte n'existe pas en prod, n'importe qui peut le créer (SEC-02).
8. **Mission bloquée pour toujours en `offered`** si aucun chauffeur n'accepte en 45 s et que `system_config/driver_scheduling` est absent, ce qui est l'état de prod du 20 octobre (DISP-01). Le client n'est jamais notifié d'une recherche infructueuse ni d'un échec de paiement (DISP-02).
9. **Runtime Node 20 en production** d'après les docs, à migrer **avant le 30 octobre 2026**, soit dans trois jours ; `package.json` est déjà sur Node 22, il faut redéployer (non vérifié).
10. **Pas de mot de passe oublié**, pas de page 404 brandée, mécanique mobile encore accessible par URL sur des données démo, pas de suppression de compte en libre-service.

**Ce qui est solide** et n'a pas à être refait : architecture Stripe Connect (destination charges, capture manuelle), idempotence et transactions Firestore, signature des webhooks, refus par défaut des règles, rôles par custom claims, interrupteurs fail-closed en lecture, FCM réel avec nettoyage des jetons, parcours de réservation photo complet, agenda chauffeur, 713 tests unitaires et 776 tests d'intégration verts.

**Effort total estimé pour atteindre un pilote payant restreint** (blocs A à D ci-dessous, hors décisions et rédactions juridiques) : environ **18 à 25 jours-personne** de développement, plus 4 à 6 jours de recette sur appareils réels et en sandbox Stripe.

---

## Légende

- **Gravité** : **Bloquant** = empêche un paiement réel sûr ou expose à une perte ou un risque légal immédiat ; **Important** = à corriger avant d'ouvrir à de vrais utilisateurs ; **Souhaitable** = après le pilote.
- **Effort** : heures (h) ou jours-personne (j) de développement, tests inclus, hors décisions externes.
- Les identifiants (SEC-, PAY-, DISP-, CLI-, DRV-, ADM-, LEG-, I18N-, UX-, TECH-) sont propres à ce rapport.

---

## 1. Ce qui bloque un vrai paiement

### 1.1 Stripe

| # | Gravité | Constat | Où | Effort |
|---|---|---|---|---|
| PAY-01 | Bloquant | **Bascule test → live casse tous les profils existants.** `payment_profiles/{uid}` et `driver_profiles.stripe_connected_account_id` portent `stripe_environment: test`. Avec une clé live, `bookingCardSetup` refuse (« appartient à un autre environnement »), `createDriverStripeAccount` réutilise un `acct_` test et échoue, `submitDriverPayout` échoue. Aucune recréation automatique. | `functions/src/functions/bookingCardSetup.ts:44`, `createDriverStripeAccount.ts:36-55` | 0,5 j + runbook |
| PAY-04 | Bloquant | **Comptes Express créés sans `settings.payouts.schedule.interval: "manual"`.** Stripe verse donc automatiquement le solde du chauffeur chaque jour ; quand `processScheduledDriverPayouts` tente `payouts.create` après 72 à 336 h, le solde est déjà parti → `insufficient_funds` → payout FAILED alors que le chauffeur a été payé. La rétention documentée (PAYMENT_ARCHITECTURE §3/§6) n'existe pas. Très probable, à confirmer en sandbox. | `functions/src/payment/stripeProvider.ts:347-357` | 0,5 j + sandbox |
| PAY-05 | Bloquant | **`payout.paid` / `payout.failed` jamais appliqués.** Les payouts sont créés sur le compte connecté ; leurs événements arrivent sur l'endpoint « Connected accounts », pas sur l'endpoint plateforme comme le dit la doc. Le code marque PAID dès que `payouts.create` répond (statut Stripe réel : `pending`) et ne passe jamais à FAILED sur un échec bancaire. | `processStripeWebhook.ts:275-318`, `paymentOrchestration.ts` (`submitDriverPayout`) | 1 j |
| PAY-06 | Bloquant | **Réconciliation des payouts : faux positifs systématiques.** `payouts.retrieve(id)` sans `stripeAccount` ne voit pas un payout de compte connecté → anomalie critique `PAYOUT_MISSING` pour chaque payout réussi ; `listProviderPayouts` liste les payouts de Movi-K vers sa banque, pas ceux des chauffeurs. | `stripeProvider.ts:427-434, 487-494, 286-312` | 0,5 j + sandbox |
| PAY-03 | Bloquant | **Capture refusée après livraison** : `payments` passe en `FAILED` (terminal, aucune transition de sortie), la mission reste `completed`, le snapshot est `confirmed`, et `calculateDriverPayout` n'exclut pas ces snapshots → chauffeur payé sans encaissement. Aucune alerte, aucun écran admin. Même chose pour les frais (`chargeMissionFee`). | `paymentOrchestration.ts` (≈631-800), `paymentStateMachine.ts:37`, `completeDelivery.ts:72`, `missionFeeOrchestration.ts:159-179` | 1 à 2 j |
| PAY-02 | Bloquant | **Pourboire jamais prélevé** : `recordTip` écrit une entrée de registre sans PaymentIntent ; le payout ne l'inclut pas ; le solde dû au chauffeur gonfle indéfiniment et la réconciliation signale `TIP_MISMATCH`. Le client Flutter n'appelle pas cette fonction : la retirer de `index.ts` est le correctif le plus simple. | `functions/src/functions/recordTip.ts:44-108`, `calculateDriverPayout.ts:93-108` | 0,5 j (retrait) / 3 j (vrai pourboire) |
| PAY-07 | Bloquant | **Taxes et reçus.** Sans `tax_configs/QC_GST_current` et `QC_QST_current`, le devis retombe sur `pricing_version.tax_rate`, qui vaut **0** dans la grille créée par `bootstrap_test_pricing.js` (et dont dérive la grille pilote active `MOVIK-PILOT-20261016-001`). Aucun numéro TPS/TVQ/NEQ nulle part dans `lib/` ni `functions/src`. Le reçu client est l'URL du reçu hébergé Stripe, non itemisé. Aucun envoi de courriel dans le code. | `functions/src/lib/taxEngine.ts:16`, `calculateDeliveryQuote.ts:283-290`, `functions/scripts/bootstrap_test_pricing.js`, `getPaymentReceipt.ts:59`, `bookingReceipt.ts` | config 1 h ; reçu conforme 1 à 2 j |
| PAY-08 | Important | **Expiration de l'autorisation (≈7 jours)** : autorisation posée à l'acceptation, `authorization_expires_at` toujours `null`, aucun cron de surveillance ; `booking_hours.days_ahead` admet jusqu'à 14 jours et `driver_scheduling.max_advance_minutes` est sans borne. Une acceptation à J-10 → capture refusée à la livraison → PAY-03. | `stripeProvider.ts:162`, `acceptDelivery.ts`, `lib/bookingHours.ts` | 1 à 2 j |
| PAY-11 | Important | **Timeout réseau à la capture traité comme un refus** : toute exception → `FAILED` alors que la carte peut avoir été débitée ; le webhook `payment_intent.succeeded` n'est qu'un audit. Détecté seulement par la réconciliation quotidienne. | `stripeProvider.ts:209-219`, `processStripeWebhook.ts:155-203` | 0,5 j |
| PAY-10 | Important | **Autorisation non libérée** si l'appel Stripe échoue lors de l'annulation (`onMissionEndedClearTracking` sans retry, aucun cron ne reprend les `AUTHORIZED` de missions annulées). | `onMissionEndedClearTracking.ts`, `recoverCancelledPendingPayments.ts` | 0,5 j |
| PAY-13 | Important | Webhook `charge.dispute.created` sur une charge inconnue → 500 en boucle pendant 3 jours. | `processStripeWebhook.ts:329` | 1 h |
| PAY-14 | Important | `accounts.create` sans clé d'idempotence → comptes Express orphelins en cas d'échec d'écriture. | `stripeProvider.ts:347-357` | 15 min |
| PAY-16 | Souhaitable | `paymentIntents.confirm` sans `off_session: true` : une carte exigeant 3DS tomberait en `payment_failed`. À tester en sandbox (carte `4000 0027 6000 3184`). | `stripeProvider.ts:148` | 0,5 j |
| PAY-17 | Souhaitable | Crons de réconciliation et de payouts en UTC (les autres sont en `America/Toronto`). | `runReconciliation.ts`, `processScheduledDriverPayouts.ts` | 15 min |

**Secrets et paramètres à provisionner** (Secret Manager, `firebase functions:secrets:set`) : `STRIPE_SECRET_KEY` (clé restreinte recommandée : Customers W, Payment Methods W, Payment Intents W, Checkout Sessions W, Charges R, Refunds W, Payouts W, Accounts W, Account Links W, accès comptes connectés), `STRIPE_PLATFORM_WEBHOOK_SECRET`, `STRIPE_CONNECT_WEBHOOK_SECRET`, et `STRIPE_WEBHOOK_SECRET` (legacy, encore déclaré par 14 fonctions : doit exister avec n'importe quelle valeur sinon le déploiement est bloqué, **non vérifié**). Optionnels : `OPENAI_API_KEY`, `CALENDAR_TOKEN_ENCRYPTION_KEY`, `GOOGLE_CALENDAR_CLIENT_SECRET`, `MICROSOFT_CALENDAR_CLIENT_SECRET`. Paramètre `APP_PUBLIC_BASE_URL` (défaut `https://movi-k.com`, doit être HTTPS et correspondre au domaine réel). Sans clé Stripe, le fournisseur `NotConfiguredPaymentProvider` échoue explicitement : aucun risque de « mock en prod », c'est vérifié.

**Webhooks à créer dans le Dashboard Stripe** : endpoint plateforme `https://us-central1-movik-connect-prod.cloudfunctions.net/processStripeWebhook` abonné à `checkout.session.completed`, `payment_intent.succeeded`, `payment_intent.payment_failed`, `charge.refund.updated`, `refund.updated`, `charge.dispute.created/updated/closed` ; endpoint « Connected accounts » `/processStripeConnectWebhook` abonné à `account.updated` **et `payout.paid`, `payout.failed`** (après correctif PAY-05). PAYMENT_ARCHITECTURE §10.9 rapporte que Daniel a constaté que `processStripeWebhook` **n'était pas déployé** ; aucun document postérieur ne confirme son déploiement (**non vérifié**).

### 1.2 Configuration Firestore requise

| Document | État prod au 20 oct. (docs) | Qui le crée | Si absent | Gravité |
|---|---|---|---|---|
| `system_config/runtime_flags` (4 interrupteurs) | 4 × `false` | `updateRuntimeFlags` (admin, **sans UI**, voir ADM-02) | Fail-closed en lecture. **Mais** PAY-09 : si le document est absent, le premier `updateRuntimeFlags` écrit les clés non fournies à `true` (`RUNTIME_FLAG_BOOTSTRAP_DEFAULTS`), paiements et versements inclus. | Bloquant à corriger (1 h) |
| `system_config/pilot_access` | inconnu | `adminPilotSetup` | Les uid listés **contournent les 4 interrupteurs**, paiements inclus. À vider avant le live. | Important |
| `system_config/booking_policy` | **absent** | `adminPilotSetup publishTrialTerms` publie **uniquement la version d'essai** (« paiements en mode test, sans argent réel ») ; aucune fonction ne publie une version finale (PAY-12) | Réservation et carte refusées | Bloquant (0,5 j de code + textes juridiques) |
| `pricing_configs/active` → `pricing_versions/…` | grille `MOVIK-PILOT-20261016-001` active | `updatePricingConfiguration` (super_admin, UI admin) | Devis impossible | OK, mais `tax_rate` à vérifier (PAY-07) |
| `tax_configs/QC_GST_*`, `QC_QST_*` + alias `_current` | **absents** d'après les docs | `updateTaxConfiguration` (admin, UI admin) : 2 appels (0,05 et 0,09975) | Devis **hors taxes** | Bloquant (1 h après décision comptable) |
| `payout_policy_configs/default` | inconnu | `updatePayoutPolicyConfiguration` | Repli codé 72 / 168 / 336 h | OK |
| `system_config/service_zones` | Granby 40 km appliqué | `adminServiceSettings` | Repli zone de lancement | OK |
| `system_config/booking_hours` | inconnu | `adminServiceSettings` | 9 h-19 h, 60 min, **4 jours**, 7 j/7 | OK ; ne pas dépasser 5 jours tant que PAY-08 n'est pas réglé |
| `system_config/booking_capacity` (mapping objets ↔ véhicules, `photo_intake.enabled`, `require_booking_details`) | **absent** (P1-BOOKING-CONFIG-01) | `adminItemTypes save` pour le mapping ; `photo_intake.enabled` et `require_booking_details` **jamais écrits par une fonction** → manuel | « Ce type d'objet n'est pas offert » ; anciens clients sans description acceptés si `require_booking_details` ≠ true | Bloquant (config métier) |
| `system_config/driver_scheduling` | **absent** | aucune fonction d'écriture → manuel | Dispatch « legacy » 45 s **sans relance** (DISP-01) | Bloquant (voir §4) |
| `system_config/calendar_oauth`, `photo_analysis`, `special_conditions` | absents / inconnu | manuel / `adminSpecialConditions` | Fonctions désactivées ; pas de surcharge ni pause | OK |
| `driver_vehicles.verified_capacity` sur au moins un véhicule réel | 8 véhicules, **0 vérifié** | admin via « Vérifier les capacités » | Aucun véhicule éligible, aucune offre | Bloquant (opérationnel) |
| Comptes `admin` / `super_admin` réels | **non vérifié** | `functions/scripts/bootstrap_super_admins.js` (prod en dur) ; aucune UI d'attribution de rôle staff (ADM-15) | Personne ne peut opérer | Bloquant (procédure) |

### 1.3 Textes légaux affichés

| # | Gravité | Constat | Où | Effort |
|---|---|---|---|---|
| LEG-03 | Bloquant | **Deux politiques d'annulation opposées** : FAQ et Tarifs annoncent « gratuit avant acceptation ou si ramassage > 2 h, sinon 30 $ », le dialogue d'annulation et la section conditions reprennent 30 $, mais la page `/legal/cancellation` de repli dit « Aucun délai gratuit ni frais fixe n'est annoncé » et « Document en révision avant lancement public ». Dès que la politique publiée ne charge pas (erreur, `approved != true`), le client lit les deux. | `lib/screens/legal/legal_screen.dart:246-284, 585-596, 633-644`, `faq_screen.dart:145-147`, `pricing_screen.dart:185-187`, `cancel_mission_button.dart:70-72` | 0,25 j après décision |
| LEG-02 | Bloquant | **Politique de confidentialité de repli non conforme à la Loi 25** : pas de responsable de la protection des renseignements personnels ni de coordonnées, pas de raison sociale/adresse, pas de liste des tiers réels (Stripe, Google Places/Routes, Firebase/Google Cloud, OpenAI pour les photos, Vercel), pas d'hébergement hors Québec, pas de durée chiffrée, rien sur les photos d'intérieur ni la géolocalisation partagée, pas de recours à la CAI. | `legal_screen.dart:438-509` ; OpenAI cité à `delivery_request_flow_screen.dart:901-903` | 1 à 2 j (rédaction juridique) + 0,25 j intégration |
| LEG-01 | Bloquant | **GA4 chargé sans consentement** dès `<head>` (ID `G-M8GKQGV3CN` en dur), aucune bannière, page Cookies qui renvoie au navigateur, politique de confidentialité muette sur Google Analytics. | `web/index.html:23-30`, `legal_screen.dart:374-437` | 1 j (Consent Mode v2 `denied` par défaut + bannière FR/EN/ES) |
| LEG-04 | Important | CGU et Entente fournisseur de repli : pas de raison sociale, NEQ, adresse, TPS/TVQ, droit applicable, tribunal ; rien sur l'assurance des biens transportés ni le plafond de responsabilité ; vocabulaire « fournisseur » alors que tout le site dit « chauffeur ». | `legal_screen.dart:106-245` | 1 à 2 j (juridique) |
| LEG-05 | Important | Documents publiés affichés **en français aux utilisateurs EN/ES** (« Document en français ») et acceptés avec `consent.locale = en` : le client signe ce qu'il n'a pas pu lire. | `lib/services/booking/booking_contract.dart:15-23`, `legal_screen.dart:537-543`, `booking_terms_section.dart:67-73` | 0,5 j + traduction |
| LEG-06 | Important | Pages `dispute`, `accessibility`, `cookies`, `provider-agreement` accessibles par URL, non liées, toutes « en révision / version de travail ». | `legal_screen.dart:272-335`, `app_shell.dart:408-412` | 0,5 j |
| LEG-11 | Souhaitable | `consent: true` envoyé automatiquement à `analyzeBookingPhoto` sans case cochée. | `delivery_request_flow_screen.dart:1017-1024` | 0,25 j |

### 1.4 Interrupteurs et garde-fous

| # | Gravité | Constat | Où | Effort |
|---|---|---|---|---|
| PAY-09 | Bloquant | Bootstrap des interrupteurs **fail-open** : sur document absent, les flags non fournis sont écrits à `true`. | `functions/src/functions/updateRuntimeFlags.ts:51-73`, `lib/runtimeFlags.ts:125-130, 284` | 1 h |
| ADM-02 | Bloquant | **Aucune UI pour les quatre interrupteurs** : en incident, couper les paiements exige la console Firebase. Le Centre de commande n'a que supplément tempête et pause. | `lib/screens/dashboard/admin/**` (aucun appel à `updateRuntimeFlags`) | 0,5 j |
| SEC-02 | Important | Compte démo par courriel codé en dur contourne interrupteurs, pause et paiement (voir §2). | `functions/src/lib/auth.ts:66-72` | 1 à 2 h |
| — | Important | `system_config/pilot_access` contourne les interrupteurs financiers : à vider ou à restreindre aux flags opérationnels avant toute clé live. | `lib/runtimeFlags.ts` (`isRuntimeFlagEnabledFor`) | 1 h |
| — | Bloquant (délai) | **Runtime Node 20 en prod** d'après PILOT_READINESS:46-50 ; retrait annoncé le **30 octobre 2026**. `package.json` est passé à `"node": "22"` le 22 octobre : un redéploiement complet des fonctions est nécessaire et doit être coordonné avec les lots non déployés (voir §8). **Non vérifié**. | `functions/package.json` | 0,5 j de déploiement et recette |

---

## 2. Failles de sécurité restantes (règles Firestore et fonctions)

Déjà documentées et toujours vraies : App Check absent (0 `enforceAppCheck` sur ~80 exports, 0 activation client, 0 `request.app` dans les règles) ; aucune clé Stripe commitée ; webhooks signés avec deux secrets distincts ; interrupteurs fail-closed en lecture ; purge GPS 30 jours ; refus par défaut des règles (`firestore.rules:742-744`, `storage.rules:160-162`) ; rôles exclusivement par custom claims. La mention « aucune limite de fréquence sur le devis » est devenue fausse (quota 60/min/uid), mais reste insuffisante (SEC-07).

| # | Gravité | Constat et scénario | Où | Correctif | Effort |
|---|---|---|---|---|---|
| SEC-01 | **Bloquant** | **Remboursement en libre-service.** `refundPayment` autorise le client propriétaire à rembourser total ou partiel, tout motif, à tout moment après capture, après livraison, après versement. L'UI ne l'expose pas, mais la callable est appelable avec le SDK et un jeton client. Fraude triviale : livraison faite → appel direct → remboursement Stripe réel, chauffeur payé → perte plateforme. | `functions/src/functions/refundPayment.ts:92-96`, `payment/paymentOrchestration.ts:1519-1640` | `requireAdminOrAbove` ; le client passe par une demande traitée par l'admin. Test d'intégration « customer refund refused after completed ». | 2 à 4 h |
| SEC-02 | Important | **Privilège par courriel en dur** `demo.client.160926@movi-k.com` : missions `internal_test` sans Stripe, sans interrupteurs, sans pause ; `email_verified` non exigé. Si le compte n'existe pas en prod, n'importe qui le crée via l'inscription ouverte. | `lib/auth.ts:66-72`, `createDeliveryRequest.ts:78`, `bookingJourney.ts:17` | Custom claim `internal_tester` via `setUserRole` ou liste `pilot_access` ; retirer le courriel. | 1 à 2 h |
| SEC-03 | Important | `recordTip` : montant libre (`1e12`, `NaN`, `Infinity` passent), entrée CONFIRMED sans encaissement (voir PAY-02). | `recordTip.ts:38-40, 67-86` | Retirer l'export. | 1 h |
| SEC-04 | Important | **Preuves photo : URL arbitraire acceptée** (`proofOfPickupUrl` ≤ 2048 car., `proofOfDeliveryUrl` non borné). Le chauffeur peut fournir une image d'un autre colis ou un lien externe affiché au client. | `completePickup.ts:27-29`, `completeDelivery.ts:128-130` | N'accepter qu'un chemin Storage `delivery_proofs/{missionId}/…`, vérifier existence et `contentType`. | 2 à 3 h |
| SEC-05 | Important | **`approveDriver` (rôle analyst) approuve en bloc des documents jamais revus** (statut `uploaded`) et met `identity_verified`/`vehicle_verified`/`documents_all_valid` à `true` depuis n'importe quel statut. Règle `create` de `driver_documents` sans `hasOnly`, sans contrôle de `type` ni de `storage_bucket_path`. | `approveDriver.ts:27-139`, `firestore.rules:190-192` | Exiger `status == approved` par type (via `validateDriverDocument`, qui n'a pas d'UI : ADM-04) ; statut préalable `pending_review` ; liste blanche de champs. | 3 à 4 h |
| SEC-06 | Important | Claim `driver` en libre-service → téléversements Storage 10 Mo illimités sous `driver_documents/{uid}/`, documents/véhicules/présence sans quota. Vecteur de coûts sans App Check. | `registerAsDriver.ts:30-76`, `storage.rules:113-114`, `firestore.rules:190-192, 212-215, 657-663` | Upload conditionné à un document pré-créé ou URL signée comptée ; `email_verified` ; App Check. | 0,5 à 1 j |
| SEC-07 | Important | Anti-abus incomplet : 60 req/min/uid = ~86 000 appels Google Routes/jour/compte ; pas de plafond de missions ouvertes par client (chaque création = dispatch + 15 offres + 15 push) ; chaque passage online d'un chauffeur redispatche jusqu'à 25 missions ; `recordTrackingPoint` sans limite ; codes promo sans `max_uses`. | `appConfig.ts:64-66`, `routingRateLimit.ts:399-422`, `dispatchMissionToDrivers.ts:242-266`, `recordTrackingPoint.ts:34-42`, `firestore.rules:455` | Quota 10/min + 100/jour ; `email_verified` ; max 3 missions ouvertes ; debounce redispatch 60 s ; limites promo. | 1 à 2 j |
| SEC-08 | Important | `ratings` lisible par tout utilisateur connecté (texte libre, `rater_id`, `mission_id`) ; grilles tarifaires, taux de commission et programmes fondateurs lisibles par tout connecté. | `firestore.rules:671-672, 435-443, 606-609, 480-482` | Restreindre ; agrégat de note dénormalisé. | 2 à 3 h |
| SEC-09 | Important | `update` client sur `delivery_requests` en **liste noire** : avant assignation, `customer_id`, `dispatch_zone_geohash`, `created_at`, `proof_*_url`, `description`, champs arbitraires jusqu'à 1 Mo sont modifiables. Idem `users`. | `firestore.rules:317-355, 92-94` | Liste blanche `affectedKeys().hasOnly([...])`. | 2 h + tests |
| SEC-10 | Souhaitable | Validation : lat/lng sans bornes ni `isFinite`, champs texte sans longueur max, `createLedgerEntry` enums libres sans plafond, `targetUid` non typé, 500 webhook renvoyant le message interne. | `recordTrackingPoint.ts:40-42`, `createDeliveryRequest.ts:354, 447-448`, `createLedgerEntry.ts:58-67`, `setUserRole.ts:51-52` | — | 3 à 4 h |
| SEC-11 | Souhaitable | `registerPushToken` : revendication d'un jeton d'un autre utilisateur, jetons illimités. | `registerPushToken.ts:49-73` | Refuser si `existing.user_id !== uid` ; plafond. | 1 à 2 h |
| SEC-12 | Souhaitable | Missions « legacy » (sans `booking_snapshot`) acceptables sans offre par tout chauffeur approuvé connaissant l'ID, tant que `require_booking_details` ≠ true en prod. | `acceptDelivery.ts:175-188` | Exiger toujours une offre vivante hors `internal_test`. | 1 h |
| SEC-13 | Souhaitable | `deleteDriverProfile` efface `driver_internal_notes` (déclarées immuables) par un simple admin ; batch > 500 échouerait. | `deleteDriverProfile.ts:25-119` | Soft-delete, super_admin, pagination. | 2 à 3 h |
| SEC-14 | Souhaitable | Web : aucun en-tête de sécurité (CSP, `frame-ancestors`, HSTS, `Referrer-Policy`) dans `vercel.json` ; `spa_server.py` (dev) force `X-Frame-Options: ALLOWALL`. | `vercel.json`, `spa_server.py:12-14` | `headers` Vercel. | 2 à 3 h |
| SEC-15 | Souhaitable | Pas de `region`, `maxInstances` (sauf `analyzeBookingPhoto`), ni `setGlobalOptions` : `us-central1` par défaut, emballement de coûts possible. Changer de région recrée les URLs. | `functions/src/index.ts` | `setGlobalOptions` ; décision résidence des données. | 1 à 2 h + redéploiement |
| SEC-16 | Souhaitable | Scripts e2e et bootstrap pointant **en dur sur `movik-connect-prod`**, sans `--project` ni confirmation ; rapports e2e avec UIDs/courriels prod commités. | `functions/scripts/*.js`, `e2e_report.json` | Garde `--project` + `--yes` ; projet de test ; retirer les rapports. | 2 h |
| SEC-17 | Souhaitable | `setUserRole` : un super_admin peut retirer le dernier super_admin (lockout) ; chemin de re-liaison par courriel à retirer après migration. | `setUserRole.ts:76-116, 172-229` | — | 1 h |
| SEC-19 | Souhaitable | Données personnelles : adresses exactes et nom du client lisibles par jusqu'à 15 chauffeurs avant acceptation ; `booking_contacts` (téléphones) copiés dans `users/{uid}` lisibles par tout analyste ; position courante des chauffeurs lisible par les analystes hors mission ; aucune purge de `delivery_requests/private` ni `booking_reviews`. | `firestore.rules:286-297`, `createDeliveryRequest.ts:436` | Décision produit + mise à jour de DATA_RETENTION et du consentement. | 2 h |
| SEC-21 | Souhaitable | `profile_photos` : lecture publique, tout `image/*` déclaré accepté (SVG scripté possible). | `storage.rules:69-72, 125-128` | Restreindre à jpeg/png/webp. | 1 h |

---

## 3. Bogues et parcours cassés

Revue statique (Flutter non installé) ; les correspondances callables client ↔ fonctions exportées ont été vérifiées une à une : **aucun nom ni champ ne diverge**. Les écarts sont fonctionnels.

### 3.1 Parcours client

| # | Gravité | Constat | Où | Effort |
|---|---|---|---|---|
| CLI-01 | Bloquant | **Pas de « mot de passe oublié »** : `sendPasswordResetEmail` n'existe nulle part, aucun lien sur l'écran de connexion. Un client qui perd son mot de passe n'a aucune issue. | `lib/providers/firebase_auth_provider.dart:196-250`, `lib/screens/auth/auth_screen.dart:275-309` | 0,5 à 1 j |
| CLI-02 | Bloquant | **Page 404 go_router par défaut, en anglais, hors `AppShell`** ; un test verrouille même ce comportement. | `lib/router/app_router.dart:68-71`, `test/routing/app_router_invalid_routes_test.dart:67` | 0,5 j |
| CLI-05 | Important | **Paiement refusé à l'acceptation : aucun état client.** `paymentStatus` n'est exploité que dans le panneau planifié ; pour une demande « dès que possible », l'autorisation refusée n'est ni montrée ni accompagnée d'une action « mettre la carte à jour ». Aggravé par TECH-04 : le statut serveur `payment_failed` n'existe pas côté Dart et est **affiché comme « Brouillon »**. | `lib/widgets/scheduled_mission_panel.dart:72-109`, `customer_tracking_screen.dart`, `lib/models/enums.dart:347-350` | 1 j |
| CLI-04 | Important | Mission annulée par le chauffeur ou Movi-K : libellé « Annulée » seul, `cancellationReason` jamais affiché, aucune action (refaire, contact). | `customer_tracking_screen.dart:231-250, 534-563` | 0,5 j |
| CLI-07 | Important | **Mécanique mobile encore routée** (`/fr/mecanique-mobile`, `/demande`, `/devenir-mecanicien`, `/inscription`, + EN/ES) : fonctionne sur l'ancien `AuthProvider` Hive, faux profils `DemoDataService.mechanics` (avatars `i.pravatar.cc`), textes FR en dur, « soumission » locale ; l'inscription crée un compte fantôme puis redirige vers un écran verrouillé. Les docs ont décidé « Bientôt disponible », pas « formulaire démo ». | `app_router.dart:115-138, 173-192`, `screens/mechanic/**`, `services/demo_data_service.dart:92-164` | 0,5 à 1 j |
| CLI-08 | Important | Écrans protégés non connectés : `Scaffold` nu sans menu ni langue, bouton « Se connecter » sans `returnTo` → atterrissage sur le tableau de bord, pas sur le suivi demandé. | `customer_dashboard_shell.dart:25-47`, `customer_tracking_screen.dart:77-116`, `router/delivery_request_intent.dart:112-122` | 0,5 j |
| CLI-03 | Important | Déconnexion depuis l'espace client sans navigation : l'utilisateur reste sur `/tableau-de-bord` verrouillé. | `customer_dashboard_shell.dart:95`, `customer_profile_tab.dart:294` | 0,25 j |
| CLI-06 | Important | Rafraîchir `/fr/notifications` connecté construit `AuthScreen` (lecture non réactive de l'auth) ; probable, **non vérifié**. | `app_router.dart:297-304` | 0,25 j |
| CLI-09 | Important | Canal de contact contradictoire : `info@movi-k.com` sur Contact et dans la recherche de chauffeur, « canal officiel pas encore publié » sur `/granby`. | `granby_launch_screen.dart:113-123`, `contact_screen.dart:39,51`, `driver_search_status.dart:95-99` | 0,25 j |
| CLI-10 | Souhaitable | Référence de mission = ID Firestore de 20 caractères. | `delivery_request_flow_screen.dart:1176` | 0,25 j |
| CLI-11 | Souhaitable | Slugs mixtes FR/EN dans les URL (`/en/livraison/suivi/…`, retour vers `/dashboard`). | `customer_tracking_screen.dart:136`, `app_shell.dart:161,213` | 0,5 j |
| CLI-12 | Souhaitable | `/legal/:type` inconnu → Politique de confidentialité au lieu d'un 404. | `legal_screen.dart:425-426` | 0,1 j |
| CLI-14 | Souhaitable | Bascule mode sombre dans le profil alors que l'accueil, le parcours et l'espace client codent des fonds clairs en dur (UX-02). | `customer_profile_tab.dart:259-266` | 0,1 j (retrait) |
| CLI-15 | Souhaitable | Connexion : pas d'« afficher le mot de passe », pas d'`autofillHints`, pas d'acceptation CGU à la création du compte. | `auth_screen.dart:232-248, 278-288` | 0,25 j |

Vérifié conforme : brouillon invité 24 h et reprise connectée, devis figé avec recalcul, Stripe Checkout en mode `setup` dans le même onglet avec bouton de vérification, bandeau clair quand les paiements sont fermés, bouton « demande de test » réservé au compte interne, recherche de chauffeur avec relance et annulation avec aperçu des frais, suivi avec fraîcheur GPS 60 s, écran de livraison terminée avec photos, reçu, récapitulatif imprimable et évaluation.

### 3.2 Parcours chauffeur

| # | Gravité | Constat | Où | Effort |
|---|---|---|---|---|
| DRV-09 | **Bloquant** | **Les versements n'existent pas** : `driver_payouts` n'est créé que par `calculateDriverPayout`, appelé par **personne** (ni écran, ni cron, ni autre fonction). `processScheduledDriverPayouts` et `reverseDriverPayout` n'ont rien à traiter ; « Versements » chauffeur et admin restent vides ; la rétention `payout_policy_configs` est inopérante. Pendant ce temps l'argent arrive sur le compte Express via destination charge et Stripe le verse automatiquement (PAY-04). **Décision requise** : soit afficher les transferts Stripe réels, soit déclencher `calculateDriverPayout` depuis `completeDelivery` ou un cron. | `functions/src/functions/calculateDriverPayout.ts:145-165`, `provider_earnings_tab.dart:209-214` | 1 à 3 j |
| DRV-04 | Important | **Pas de GPS en arrière-plan** : le rapporteur de position est un `Timer` Dart vivant tant que l'écran Mission active est monté ; `ACCESS_BACKGROUND_LOCATION` absent. Le bouton « Ouvrir dans Google Maps » met l'app en arrière-plan → le suivi client se fige. Structurellement certain, non vérifié à l'exécution. | `lib/services/driver_location_reporter.dart`, `driver_active_mission_screen.dart:97-101, 132-189`, `android/app/src/main/AndroidManifest.xml:3-7` | 2 à 4 j (service de premier plan) ; 0,25 j (message « position en pause ») |
| DRV-02 | Important | **Toute erreur d'acceptation est affichée « déjà acceptée par un autre chauffeur »** alors que le serveur distingue « passez en ligne », « hors zone », « confirmez le véhicule », « documents invalides ». Le mapping fin `acceptMission()` du repository est du code mort. | `provider_jobs_tab.dart:254-270, 676-678`, `firebase_mission_repository.dart:274-320` | 0,5 j |
| DRV-03 | Important | `watchMission()` instancié dans `build()` : chaque `setState` recrée le stream → spinner plein écran et réabonnement Firestore à chaque action. Bogue identique corrigé ailleurs (« Bloc C item 3 »). | `driver_active_mission_screen.dart:347-350` | 0,25 j |
| DRV-01 | Important | Reprise d'une inscription incomplète : formulaire vide, nouvel id de véhicule → doublons `driver_vehicles` et 7 nouveaux `driver_documents` à chaque relance. | `driver_status_screen.dart:154-155`, `driver_onboarding_screen.dart:92, 877` | 1 à 2 j |
| DRV-05 | Important | Onglet Profil : lecture seule, « Mes tarifs » et « Support » en « Bientôt », « Avis reçus » texte fixe, statut documents déduit du statut profil, catégories affichées en camelCase (« cargoVan »). | `provider_profile_tab.dart:128-210` | 1,5 j |
| DRV-06 | Important | **Aucune suppression de compte en libre-service** (exigence Apple et Loi 25) ; `deleteDriverProfile` admin ne supprime ni Auth ni `users`. | `deleteDriverProfile.ts:60-80` | 1 à 2 j |
| DRV-08 | Important | Pas de mot de passe oublié côté chauffeur/admin non plus ; `email-already-in-use` → message générique. | `firebase_auth_provider.dart:309-325`, `driver_onboarding_screen.dart:819-831` | 0,5 j (avec CLI-01) |
| DRV-07 | Important | **Dossier `ios/` absent** du dépôt : aucune build iOS possible, permissions et APNs non configurables, alors que les docs testent la photo sur iPhone (via le web). | racine du dépôt | 3 à 5 j hors compte Apple |
| DRV-13 | Souhaitable | `expires_at` des documents jamais saisi → cron `detectExpiringDocuments` inerte ; `validateDriverDocument` sans UI. | `approveDriver.ts:109-116` | 1 j |
| DRV-10 | Souhaitable | Streams dans `build()` (Versements, Profil). | `provider_payouts_section.dart:66-74`, `provider_profile_tab.dart:47` | 0,25 j |
| DRV-11 | Souhaitable | Dates `DateTime.toString()` brutes (« Offre valable jusqu'à 2026-10-27 09:00:00.000 »), montants « 12.50$ ». | `provider_jobs_tab.dart:619, 625`, `scheduled_mission_panel.dart:102`, `driver_active_mission_screen.dart:658` | 0,5 j |
| DRV-12 | Souhaitable | Remplacement de document : MIME forcé `image/jpeg` pour PNG/HEIC. | `driver_status_screen.dart:316-321` | 0,1 j |
| DRV-14 | Souhaitable | Boutons « Actualiser / Réessayer » qui ne font qu'un `setState`. | `driver_stripe_onboarding_return_screen.dart:189-193`, `driver_status_screen.dart:638-645` | 0,1 j |
| DRV-16 | Souhaitable | Push Web silencieusement désactivé sans `FCM_WEB_VAPID_KEY`, aucun retour UI. | `push_notification_service.dart:92, 117, 138` | 0,25 j |

Vérifié conforme : double-tap protégé avec `acceptanceRequestId` persisté, chauffeur en mission ne voit plus les offres, preuve photo obligatoire au ramassage et à la livraison, permissions demandées au bon moment, suspension ordinaire laissant finir la mission, agenda (confirmation de durée, édition par journée) et revue de capacités véhicule conformes aux décisions documentées.

### 3.3 Administration

| # | Gravité | Constat | Où | Effort |
|---|---|---|---|---|
| ADM-01 | **Bloquant** | **Aucune UI de remboursement ni de litige** : `adminRefundPayment()` et `adminUpdateDisputeStatus()` existent dans le repository mais **aucun écran ne les appelle** ; onglets Remboursements/Litiges et fiche paiement en lecture seule. Impossible de rembourser un client ou de clore un litige depuis l'admin. | `firebase_finance_repository.dart:600-612, 728-735`, `admin_finance_refunds_tab.dart`, `admin_finance_disputes_tab.dart` | 1 j |
| ADM-02 | Bloquant | Aucune UI pour les interrupteurs d'urgence (voir §1.4). | — | 0,5 j |
| ADM-15 | Bloquant (procédure) | Aucun écran n'attribue `analyst/admin/super_admin` ; seul `bootstrap_super_admins.js` (prod en dur) le fait. | `admin_user_detail_screen.dart:362-389`, `functions/scripts/bootstrap_super_admins.js` | 0,5 j ou procédure documentée |
| ADM-07 | Important | Un **analyste** voit tout l'admin (Finances, Centre de commande, Pilote, Utilisateurs, assignation) ; le serveur refuse ses actions mais l'UI les propose. | `admin_login_screen.dart:311-315`, `admin_dashboard_shell.dart:246-287` | 0,5 j |
| ADM-06 | Important | Assignation manuelle : l'éligibilité client ignore `online_status`, zone, véhicule vérifié et engagements planifiés exigés par le serveur → échecs après clic. | `admin_mission_assignment_dialog.dart:166-172` | 0,5 j |
| ADM-05 | Important | Missions, dialogue d'assignation et Utilisateurs lisent **des collections entières sans borne** (`snapshots()` sans `where/limit`). | `admin_missions_screen.dart:54-57`, `admin_mission_assignment_dialog.dart:73-76`, `admin_users_screen.dart:46` | 1 j |
| ADM-03 | Important | Promotions et programme Chauffeur fondateur : fonctions sans aucune UI ; la fiche chauffeur n'affiche ni commission résolue ni statut fondateur. | `applyDriverPromotion`, `qualifyFoundingDriver` (0 appelant) | 1,5 j |
| ADM-04 | Important | `verifyDriverServiceBase` (base de dispatch) et `validateDriverDocument` sans UI. | — | 0,5 j chacun |
| ADM-08 | Souhaitable | « Missions terminées » compte `delivered` (statut intermédiaire avant capture). | `getAdminDashboardMetrics.ts:16`, `admin_missions_screen.dart:130-132` | 0,1 j |
| ADM-10 | Souhaitable | Navigation `Navigator.push` au lieu de la route `/admin/chauffeurs/:driverId` (URL non partageable). | `admin_drivers_list_screen.dart:411-415` | 0,25 j |
| ADM-11 | Souhaitable | Fiche paiement charge toute la fenêtre de paiements pour en trouver un ; hors fenêtre → « vide ». | `admin_payment_detail_screen.dart:40-41` | 0,25 j |
| ADM-12 | Souhaitable | Une callable `getAdminDriverActivity` (jusqu'à 500 missions lues) **par ligne** de la liste des chauffeurs. | `admin_drivers_list_screen.dart:495-499` | 0,25 j |
| ADM-14 | Souhaitable | Téléphone : `DataTable` à défilement horizontal (types d'objets, grille tarifaire), bouton de déconnexion flottant superposé à l'AppBar, aucun `textScaler` géré dans l'admin. | `admin_item_types_screen.dart:150-152`, `admin_finance_pricing_tab.dart:1009-1011`, `admin_login_screen.dart:333-345` | 0,5 j |
| ADM-09 | Souhaitable | `AdminFinanceShell.initialSection` ne gère que `disputes`. | `admin_finance_shell.dart:115-117` | 0,1 j |

Fonctions exportées **jamais appelées par un client** (12) : `updateRuntimeFlags`, `applyDriverPromotion`, `qualifyFoundingDriver`, `revokeFoundingDriverStatus`, `verifyDriverServiceBase`, `validateDriverDocument`, `createFinancialSnapshot`, `calculateDriverPayout`, `refundPayment` (wrapper sans écran), `updateDisputeStatus` (idem), `recordTip`, `createCustomerPaymentProfile`/`attachCustomerPaymentMethod` (remplacées par Checkout). Crons sans effet faute de données : `detectExpiringDocuments`, `processScheduledDriverPayouts`, `expireDriverPromotions`, `transitionFoundingDriverPeriods`.

Écrans **sans aucun test** : `AdminDriverDetailScreen` (toutes les actions approve/reject/suspend), `AdminMissionsScreen`, `AdminMissionAssignmentDialog`, `AdminUsersScreen`, `AdminUserDetailScreen`, les 10 onglets de `admin/finance/tabs/` (0 test, dont la grille tarifaire de 1 110 lignes), `customer_dashboard_shell`, `customer_profile_tab`, `driver_search_status`, pages info et landings. Les pages publiques n'ont de smoke-test de rendu qu'en FR.

---

## 4. Fiabilité du dispatch et des paiements

Cycle réel tel que codé : devis figé (`calculateDeliveryQuote`) → carte via Stripe Checkout `mode=setup` → `createDeliveryRequest` (mission `searching_driver`, aucune autorisation) → dispatch par offres de 45 s (ou rounds planifiés si `driver_scheduling` existe) avec push FCM → `acceptDelivery` (transaction d'assignation puis, **hors transaction**, PaymentIntent `capture_method: manual`, `transfer_data.destination`, `application_fee_amount`, montant = max(prix, 30 $)) → statuts de mission → `completeDelivery` (transaction snapshot + ledger puis, hors transaction, capture partielle du prix) → Stripe transfère la part chauffeur sur son compte Express → `calculateDriverPayout` (admin, jamais appelé) → cron payouts → remboursements et litiges par webhooks → réconciliation quotidienne.

| # | Gravité | Constat | Où | Effort |
|---|---|---|---|---|
| DISP-01 | **Bloquant** | **Mission jamais prise = bloquée pour toujours en `offered`.** Sans `system_config/driver_scheduling` (absent en prod le 20 oct.), les offres expirent à 45 s et le seul balayage qui remet en `searching_driver` (`sweepDriverOffers`) **retourne immédiatement si la politique est absente**. `onDriverBecameAvailableDispatch` ne requête que `searching_driver` ; `acceptDelivery` refuse l'offre expirée ; `retryDriverSearch` refuse car `dispatch_state` n'est jamais `no_driver_available`. Client jamais informé. | `functions/src/functions/driverScheduleLifecycle.ts:107-108`, `dispatchMissionToDrivers.ts` (`OFFER_EXPIRY_MS`) | 0,5 j (balayage indépendant de la politique) ou exiger le document en prod |
| DISP-02 | Important | **Aucune notification client** pour « aucun chauffeur trouvé » ni `payment_failed` (absents de `NOTIFICATION_BY_STATUS`), alors que les conditions d'essai promettent « Vous en êtes informé ». | `onMissionStatusChangeNotifyCustomer.ts` | 0,5 j |
| DISP-03 | Important | Candidats limités à 50 (`.limit(50)`) puis filtre geohash en mémoire : au-delà de 50 chauffeurs en ligne, des chauffeurs proches sont ignorés. Acceptable pour Granby. | `dispatchMissionToDrivers.ts` | 0,5 j |
| SEC-07 | Important | Redispatch de jusqu'à 25 missions à chaque passage online (spam d'offres et de push). | `dispatchMissionToDrivers.ts:242-266` | inclus dans SEC-07 |
| PAY-03, 04, 05, 06, 08, 10, 11 | voir §1.1 | Chaîne capture → versement → réconciliation. | — | — |
| P1-DISPATCH-RETRY-01, P1-DRIVER-OFFER-TERMS-01 (docs) | Important | Garde transactionnelle contre les événements dupliqués et affichage du montant chauffeur avant acceptation : « validés localement, non déployés » dans le registre, mais `acceptDelivery` et le dispatch ont été republiés les 16 et 20 oct. sans que le registre dise si ces correctifs y sont. **Non vérifié.** | `docs/audit/REGISTRE_BOGUES_MOVIK.md:56-57, 5028-5040` | 0,5 j de vérification |
| PAY-19 | Souhaitable | `onPaymentAuthorizedAfterMissionCancel` avec `retry: true` rejoue une erreur permanente jusqu'à 7 jours. | — | 0,25 j |

Vérifié solide : course « deux chauffeurs acceptent » couverte par transaction et test de concurrence ; webhooks idempotents (bail 10 min, attente sur doublon, `livemode` vs environnement) ; arrondis en cents centralisés (`lib/money.ts`) ; commission ≤ montant ; hold minimum 30 $ et capture partielle ; frais d'annulation figés sur le paiement ; FCM via `sendEachForMulticast` avec suppression des jetons invalides ; aucun fournisseur simulé possible en prod.

---

## 5. Qualité du code et dette technique

| # | Gravité | Constat (mesuré) | Pourquoi ça coûtera cher | Effort |
|---|---|---|---|---|
| TECH-01 | Important | **Aucun pipeline de déploiement, un seul projet Firebase (`production`), aucun staging.** 3 workflows, 0 `firebase deploy`. 5 scripts ciblent `movik-connect-prod` en dur. | L'état des règles et des 73 fonctions en prod n'est reproductible que depuis le poste de Daniel ; dérive règles déployées ↔ dépôt invérifiable ; un test e2e lancé par erreur pollue la prod. Les docs montrent déjà des publications faites depuis 7 branches différentes « sans fusion dans main ». | 3 à 4 j |
| TECH-02 | Important | **La CI Flutter ne tourne pas sur `main`** (déclencheur `push` sur une vieille branche de travail) ; Vercel déploie tout push sur `main` ; `stripe-sandbox-validation.yml` est mort (`if` sur une branche obsolète) ; aucune couverture ; pas de Dependabot. | Un hotfix poussé sur `main` part en prod sans `flutter analyze` ni les 675 tests. | 1 j |
| TECH-04 | Important | **Enums dupliqués client/serveur sans génération, dérive déjà présente** : `payment_failed` (serveur) absent côté Dart → repli silencieux `MissionStatus.draft` ; 7 types de registre (`chargeback_*`, `driver_payout_reversal`, `promotion_cost`…) affichés « Ajustement chauffeur » ; même `orElse` silencieux sur 8 enums. | Chaque nouvel état serveur = bogue d'affichage invisible aux tests. | 0,5 j (hotfix) + 2 j (génération) |
| TECH-03 | Important | **Couche démo toujours branchée** : 8 boîtes Hive ouvertes au démarrage, `AuthProvider` « lien magique simulé », `DeliveryProvider`/`ReviewProvider` référencés nulle part sauf `main.dart`, `demo_data_service.dart` importé par le flux de réservation réel, routes mécanicien actives, 3 enums legacy. | Démarrage plus lent, confusion « quel AuthProvider ? », dépendances `hive`/`uuid` pour du code mort. | 2 à 3 j |
| TECH-05 | Important | **Moteur de tarification écrit deux fois** (`lib/finance/engines/` 5 moteurs ≈ 550 l. et `pricingEngine.ts` 364 l.), le moteur Dart n'étant utilisé par aucun écran ; `DriverCompensationEngine` a déjà divergé (ignore la part « driverOnly »). | Toute évolution de grille codée et testée deux fois ; divergence d'arrondi entre simulateur et facture. | 2 j |
| TECH-06 | Important | Fichiers « dieu » : `app_strings.dart` 5 411 l., `delivery_request_flow_screen.dart` **3 259 l.** (31 `setState`, appels `cloud_functions` directs), `paymentOrchestration.ts` 1 865 l. (`refundPayment` 347 l.), `driver_onboarding_screen.dart` 1 674, `customer_tracking_screen.dart` 1 664 ; 12 `httpsCallable` et 9 `FirebaseFirestore.instance` directement dans les écrans. | Correctifs sur la réservation dans un fichier de 3 259 l., conflits de merge, PR illisibles. | 5 à 7 j |
| TECH-07 | Important | **Deux systèmes d'i18n** : 1 099 clés `AppStrings` + 4 dictionnaires **et** 761 triplets `tr('fr','en','es')` inline dans 36 fichiers, 40 définitions locales dupliquées de `tr()` ; 261 clés `AppStrings` (24 %) et 27 clés `HomeCopy` jamais référencées. Pas d'ARB ni `gen-l10n`. | Impossible à exporter pour un traducteur ; dérive garantie. | 4 à 5 j |
| TECH-08 | Important | **Aucune capture d'erreurs côté client** (0 `FlutterError.onError`, `runZonedGuarded`, Crashlytics, Sentry) ; 6 `console.*` bruts côté serveur ; aucune alerte Cloud Monitoring définie dans le dépôt. | Le premier signal d'un crash sera un client au téléphone. | 1,5 j |
| TECH-09 | Important | SDK Firebase Flutter **gelés à octobre 2024** (`firebase_core 3.6.0`, `cloud_firestore 5.4.3`, `firebase_auth 5.3.1`…) avec un commentaire « compatibilité Flutter 3.35.4, ne pas mettre à jour » alors que build et CI utilisent **Flutter 3.47.1**. | Correctifs sécurité/compat non reçus ; saut de deux majeures d'un coup. | 2 j + 1 j QA Android |
| TECH-10 | Bloquant pour un lancement store | Android **signé en debug** (`signingConfig = debug`, `// TODO` du template), `applicationId` template, label `movik_connect`, `version: 1.0.0+1` jamais incrémentée, 0 tag git, **pas de `ios/`**. | APK refusé par Google Play ; aucune build iOS ; mises à jour store impossibles sans `versionCode`. | 1 j Android ; 3 à 5 j iOS |
| TECH-11 | Important | Tests : 675 Dart (ratio test/code 0,54) mais **29 écrans (~9 600 l.) sans aucun test**, dont tout `admin/finance/tabs/` ; 14 fichiers TS sans test (`paymentStateMachine.ts`, `previewPricingConfiguration.ts`, `registerPushToken.ts`…) ; `stripeProvider.test.ts` n'a qu'un test ; aucun e2e navigateur automatisé ; 32 fichiers de test ne testent que des chaînes. | Le back-office finance peut casser sans qu'aucun test ne rougisse. | 4 à 6 j |
| TECH-12 | Souhaitable | `npm audit --omit=dev` : **14 vulnérabilités (4 hautes, 10 modérées, 0 critique)**, toutes transitives (`@fastify/busboy`, `@grpc/grpc-js`, `body-parser`, `node-forge`, `qs`, `uuid`) ; `npm audit fix` sans `--force` corrige tout sauf `uuid` (exige `firebase-admin@14`). ESLint 8 en fin de vie, `plugin:@typescript-eslint/recommended` non étendu, `firebase-admin 12.7 → 14.5`, `firebase-functions 6.6 → 7.4`, `stripe 22.5 → 23.0`. | — | 1,5 j |
| TECH-13 | Souhaitable | Commentaires d'historique incrustés : 146 « Bloc » et 95 « Phase N » dans `lib/`, 38 et 113 dans `functions/src` ; 19 % de lignes de commentaires côté serveur ; 109 blocs ≥ 15 lignes. | Références de phase fausses au premier refactor ; lecture doublée pour un nouveau dev. | 1 à 2 j |
| TECH-14 | Souhaitable | `README.md` = template Flutter ; pas de CONTRIBUTING/CODEOWNERS/PR template ; `artifacts/` = **238 fichiers, 13 Mo versionnés** ; `docs/` = 14 386 lignes dont 70 % d'historique de phases. | — | 1 j |
| TECH-15 | Souhaitable | 28 `new HttpsError` hors `errors.ts`, 40 `throw new Error` remontés en `internal` ; côté Dart 149 `catch` non typés dont **84 `catch (_)`** silencieux. | — | 1,5 j |
| TECH-16 | Souhaitable | 0 `deferred` import : les 73 routes (dont 15 927 l. d'admin) sont dans le bundle initial public ; `assets/home/` 3,1 Mo dont `hero_neutral.png` 1,79 Mo et **4 assets orphelins ≈ 920 Ko**. Taille du bundle non mesurable ici. | — | 1 j |
| TECH-17 | Souhaitable | Vercel clone le SDK Flutter à chaque build (tag mutable, SHA non vérifié contrairement à la CI) ; `firebase-tools` 15.28 vs 14.9 entre workflows ; une action non épinglée par SHA. | — | 0,5 j |
| TECH-18 | Souhaitable | 73 fonctions dans un seul `codebase`, sans `region`/`memory`/`maxInstances`. | Temps de déploiement, coûts, résidence des données. | 1 j |
| TECH-19 | Souhaitable | `analysis_options.yaml` = `flutter_lints` sans règle ajoutée ; 391 `dynamic`, 489 casts `as`. Points positifs : 0 `// ignore`, 0 TODO, 0 `print`, cycle de vie des `Timer`/`listen` propre, 106 `runTransaction`. | — | 1 j |

---

## 6. Design, textes et cohérence FR/EN/ES

**Traductions** : les 5 dictionnaires sont **complets dans les 3 langues** (1 099 + 70 + 45 + 32 + 2 clés, 0 manquante) et les 761 triplets inline n'ont aucun argument vide. Les problèmes sont de cohérence et d'architecture, pas de trous.

| # | Gravité | Constat | Où | Effort |
|---|---|---|---|---|
| I18N-01 | Important | **Messages d'erreur d'authentification uniquement en français** affichés tels quels en EN/ES (« Adresse courriel ou mot de passe incorrect. », « Trop de tentatives… »). | `firebase_auth_provider.dart:200, 236, 243, 279-281, 300-334` | 0,25 j |
| I18N-02 | Important | Courriel de vérification forcé en français (`setLanguageCode('fr')`). | `firebase_auth_provider.dart:273` | 0,1 j |
| I18N-06 | Important | **Trois graphies de la marque** : « Movi-K » (119), « Movi-k » (44, dont `app_name`, `auth_welcome`, le titre de `main.dart`, 4 pages légales) et « Movi‑K » avec trait d'union insécable U+2011 (7 fichiers) ; les trois coexistent sur une même page légale. | `app_strings.dart`, `home_copy.dart`, `legal_screen.dart:116, 164`, `main.dart:87` | 0,25 j + test structurel |
| I18N-04 | Important | Registre espagnol mixte : « tú » dans l'accueil et la réservation, « usted » dans ~70 clés affichées au même client (`driver_active_mission_*`, `payout_*`, `provider_*`). | `app_strings.dart` | 0,5 j |
| I18N-05 | Important | Chaînes en dur FR : libellé sémantique « Obtenir un prix pour … » (lecteur d'écran EN/ES), `semanticLabel: 'Photo'`, `'Objet'`, tous les textes des écrans mécanicien, ternaires hors dictionnaire dans `_Trust`/`_Reassurance`. | `home_screen.dart:708, 503-513, 941-951`, `booking_load_summary.dart:317`, `mechanic_*_landing_screen.dart`, `app_shell.dart:31-40` | 0,25 j |
| I18N-03 | Important | Deux systèmes d'i18n (voir TECH-07). | — | 3 à 5 j |
| LEG-07 | Important | Promesses GPS contradictoires : « Suivez votre chauffeur en direct » (Livraison, Sécurité) vs « une carte GPS est prévue… validation en cours » (Comment ça marche). | `delivery_landing_screen.dart:149-157`, `safety_screen.dart:64-77`, `how_it_works_screen.dart:106-118` | 0,1 j |
| LEG-08 | Important | Mesures contradictoires : `HomeCopy.item_note` demande « les mesures de chaque objet emballé » ; FAQ et parcours photo disent « Pas de mesures à prendre ». | `home_copy.dart` (`item_note`), `faq_screen.dart:68-76` | 0,1 j |
| — | Important | Vocabulaire : « chauffeur » (160) domine mais « fournisseur » survit dans 19 clés dont le menu `nav_provider_space` « Espace fournisseur » et 4 pages légales ; « mission » (55) est un jargon interne visible du client (« étapes de la mission », « Mission programmée ») là où le site dit « livraison » (104). | voir `app_strings.dart`, `scheduled_mission_panel.dart` | 0,5 j |
| I18N-07 | Souhaitable | Anglicismes FR : « onboarding » (5 clés Stripe Connect), « pickup » (FAQ). | `app_strings.dart`, `faq_screen.dart:193` | 0,1 j |
| I18N-08 | Souhaitable | Dates formatées à la main de 4 façons (« 23/10/2026 · 14:00 », « ven. 23 oct. », « 14 h 05 », `DateTime.toString()` brut dans « Créneau réservé ») avec commentaires obsolètes « no Material locales ». | `customer_mission_view.dart:85-112`, `scheduled_mission_panel.dart:97-101` | 0,5 j |
| I18N-09 | Souhaitable | Devise : « $ CA », « $ » (sans locale : « 25.00 $ » en FR), « CA$ », « CAD » selon l'écran. | `delivery_request_flow_screen.dart:671-675`, `mission_finance_section.dart:39-45` | 0,25 j |
| I18N-10 | Souhaitable | Drapeaux 🇫🇷 🇬🇧 🇪🇸 pour un public québécois. | `language_selector.dart:207-211` | 0,1 j |
| I18N-11 | Souhaitable | Routes ES/EN incomplètes (inscription chauffeur FR/EN seulement, `legal`, `notifications` sans slug localisé). | `app_router.dart:152-171, 348-359` | 0,5 j |
| LEG-12 | Souhaitable | `web/index.html` : `lang="fr"` fixe, titre et description FR seulement, pas d'`og:image`/`og:url`/`canonical`/`hreflang`, pas de `<noscript>`, `IE=Edge` obsolète ; `manifest.json` force `portrait-primary`. | `web/index.html:2, 7, 15-20`, `web/manifest.json:9` | 0,5 j |
| LEG-10 | Souhaitable | Blogue avec 3 billets « À venir » (dont un sur la mécanique) accessible par `/blogue`, `/blog` ; À propos : badge « Bientôt » sur « Notre histoire » malgré un texte complet. | `blog_screen.dart:29-60`, `about_screen.dart:138-154` | 0,25 j |
| LEG-09 | Souhaitable | Pied de page sans raison sociale, adresse, courriel, ni liens Cookies/Accessibilité. | `app_shell.dart:354-479` | 0,25 j |
| UX-01 | Important | Polices sous 12 px : 9 px (exemples sous les catégories), 11 et 11,5 px (blocs de confiance, bandeau réassurance), 10 px (badge notifications) ; l'enseigne force `TextScaler.noScaling`. | `home_screen.dart:757, 447, 552, 1000, 122`, `notification_bell.dart:59` | 0,25 j |
| UX-02 | Important | **Thème sombre incohérent** : fonds clairs codés en dur (`Colors.white`, `#F9FCFF`, `#EEF8FF`, `#fff1dd`…) et textes `primaryDark` fixes sur l'accueil, les pages info, le parcours, l'onglet Activité, le tiroir ; thème sombre sans `tabBarTheme`/`chipTheme`/`snackBarTheme`. Alternative : retirer la bascule (CLI-14). | `home_screen.dart:397, 594, 604, 791, 875, 963`, `delivery_request_flow_screen.dart:1053, 2829-2830`, `app_theme.dart:144-248` | 2 j ou 0,1 j |
| UX-03 | Important | Contraste des corps de texte 11 à 12,5 px sur fonds teintés (≈3,9:1 estimé) ; **non mesuré outillé**. | `home_screen.dart:960-1003` | 0,25 j |
| UX-04 | Important | Libellés trompeurs : « Conditions et confidentialité » n'ouvre que les CGU ; `/granby` « Voir l'état du contact » alors que Contact fonctionne ; suppression de compte = « écrivez-nous ». | `customer_profile_tab.dart:286-290`, `granby_launch_screen.dart:145-153` | 0,1 j |
| UX-05 | Souhaitable | 320 px : hero bascule à 980 px hors `AppBreakpoints`, cartes catégories serrées, `GridView.count` à ratio fixe (texte coupé à 200 %), `_recap` sans `Flexible`. **Non vérifié** (rendu). | `home_screen.dart:171, 622-624`, `about_screen.dart:181-189`, `delivery_request_flow_screen.dart:2409-2420` | 1 j |
| UX-06 | Souhaitable | Deux bleus primaires (`#0879E8` accueil vs `AppColors.primary #0F2A5C` pages info) ; `GlassCard` et `heroGradient` abandonnés (0 import). | `home_screen.dart`, `app_colors.dart:8`, `widgets/glass_card.dart` | 0,5 j |
| UX-07 | Souhaitable | Accessibilité : `ExpansionTile` FAQ sans `Semantics(header)`, sélecteur de langue sans `tooltip`, menu compte sans libellé texte. | `faq_screen.dart:258-288`, `language_selector.dart:203-227` | 0,1 j |
| UX-08 | Souhaitable | États de chargement/erreur hétérogènes ; pas d'écran hors ligne ni de réessai sur le suivi. | `customer_tracking_screen.dart:138-143` | 0,5 j |
| DRV-17 | Souhaitable | Admin codé FR/EN seulement (`isFrench ? … : …`), « Retour accueil » → `/fr` quelle que soit la langue. Acceptable pour un back-office. | `admin_login_screen.dart:154` | — |

---

## 7. Ce que seul Daniel peut fournir ou décider

### Stripe et finance
1. Compte Stripe réel, profil plateforme Connect, capacités Canada/Québec ; clé restreinte (périmètre §1.1) → `STRIPE_SECRET_KEY`.
2. Deux endpoints webhook (plateforme + comptes connectés) avec leurs événements (§1.1) → `STRIPE_PLATFORM_WEBHOOK_SECRET`, `STRIPE_CONNECT_WEBHOOK_SECRET` ; conserver un `STRIPE_WEBHOOK_SECRET` tant qu'il est déclaré.
3. Décisions commerciales encore ouvertes dans les docs : modèle de versement (quotidien Stripe ou lot Movi-K avec rétention, DRV-09/PAY-04), remboursement du pourboire (ou retrait du pourboire), récupération après chargeback, `debit_negative_balances`, Accounts v1 vs v2.
4. Exécuter le cycle Stripe TEST complet puis un premier paiement et un premier versement LIVE restreints, en comparant devis = mission = snapshot = PaymentIntent en cents. Les docs disent explicitement qu'aucun paiement réel n'a jamais été exécuté.

### Comptable
5. Taux et date d'effet TPS 5 % / TVQ 9,975 %, numéros d'enregistrement, émetteur de la facture (Movi-K ou chauffeur : champ `tax_registration_owner`), forme du reçu, durée légale de conservation comptable. **Aucun comptable n'est mentionné dans les docs.**

### Juriste
6. Rédaction et validation : conditions de réservation (texte paiement + annulation avec la matrice BOOKING_TERMS.md:66-79 : avant assignation, après assignation, après prise en charge, annulation chauffeur/Movi-K, après capture), CGU, politique de confidentialité conforme à la Loi 25 (responsable PRP, tiers nommés dont OpenAI, hébergement hors Québec, durées, recours CAI), conditions chauffeur indépendant, consentement GPS et photos, processus de demande de suppression, bandeau cookies/GA4. Publication des trois langues. **Aucun juriste n'est mentionné dans les docs.**
7. Décisions de rétention : chaque ligne de `DATA_RETENTION.md` est marquée « décision requise » ; les durées annoncées dans `FIRESTORE_ARCHITECTURE.md` (24 mois, 7 jours, 48 h, 90 jours) ne sont pas implémentées.

### Courtier d'assurance
8. Assurance des biens transportés, responsabilité civile plateforme, exigences d'assurance des chauffeurs (le document « assurance » n'est aujourd'hui qu'une pièce téléversée, approuvée en bloc sans revue individuelle : SEC-05). Le site promet des photos « preuve en cas de problème » sans dire ce qui est couvert. **Aucun courtier n'est mentionné dans les docs.**

### Support et opérations
9. Confirmer que `info@movi-k.com` est bien reçu et lu ; retirer « canal à venir » de la page Granby ; désigner la personne d'astreinte capable de couper un interrupteur en moins de 5 minutes (après ADM-02) ; personnel habilité à traiter la file `booking_reviews` (vérifications qui expirent après 7 jours).
10. Zone pilote finale (40 km autour de Granby déjà configurés), nombre de chauffeurs et de clients pilotes, mécanisme d'accès (`pilot_access`), volume journalier.
11. Faire inscrire et **vérifier physiquement au moins un véhicule réel** (mesures, ouverture, charge, échéance) via « Vérifier les capacités » ; renseigner le mapping objets ↔ véhicules et `booking_capacity`.
12. Compte client de recette ordinaire (le compte proposé dans les docs a des rôles driver/super_admin) ; remplacer le courriel démo codé en dur par un claim (SEC-02).

### Infrastructure Firebase/GCP/Web
13. Accès IAM `movik-connect-prod`, création des comptes admin/super_admin réels, exécution de la procédure X-13 et vérification des quatre interrupteurs.
14. Sauvegardes : export Firestore planifié ou PITR, versioning Cloud Storage ; décider RPO/RTO. Les docs qualifient ce point de « risque Phase 8 le plus important ».
15. Alertes : choisir le canal (courriel/Slack) et créer les politiques Cloud Monitoring sur `logFinancialFailure`, erreurs 5xx, webhooks en échec.
16. App Check : reCAPTCHA Enterprise (web) et Play Integrity (Android), mode « monitor » puis enforcement.
17. Push : clé VAPID web (`FCM_WEB_VAPID_KEY` dans Vercel), compte Apple pour APNs si iOS est retenu ; test de réception sur appareils réels.
18. Google Cloud : API Routes activée et facturée, restriction HTTP-referrer de la clé Places (`GOOGLE_MAPS_API_KEY` Vercel) ; budget OpenAI.
19. Redéploiement complet des fonctions sur Node 22 **avant le 30 octobre**.
20. Domaine : confirmer que `www.movi-k.com` sert bien l'app (non joignable depuis cet environnement) et que `APP_PUBLIC_BASE_URL`, les URLs de retour Stripe Connect et le callback OAuth pointent dessus.
21. Décider du sort de la mécanique mobile (routes à retirer ou page « Bientôt » unique) et du GA4 (consentement).
22. Créer un projet Firebase de **test/staging** pour arrêter de recetter en production.

---

## 8. Incohérences entre les documents et le code

- **Branches et déploiements** : PILOT_READINESS cite `main = 6090fed` ; les publications d'octobre ont été faites depuis sept branches (`fix/gps-client-history-scope`, `feature/photo-assisted-booking`, `feature/booking-terms-20261018`, `fix/quote-before-driver-release`, `feat/admin-*`, `feat/customer-loading-help`, `feat/driver-agenda`) « sans fusion dans main ». Aucun document ne décrit ce qui tourne réellement en prod ; le registre marque « non déployé » des correctifs (P1-DISPATCH-RETRY-01, retrait de l'option lourd) alors que les fonctions concernées ont été republiées ensuite.
- **Webhook Stripe** : PILOT_READINESS 8B parle de deux webhooks actifs ; PAYMENT_ARCHITECTURE §10.9 rapporte que `processStripeWebhook` n'existe pas dans les fonctions déployées. Jamais tranché.
- **Push** : AC-1/AC-2 disent « `firebase_messaging` absent, non construit » ; le registre 8D et le code montrent un service FCM complet. Ce qui manque est la configuration et la validation sur appareils, pas le code.
- **Rétention** : FIRESTORE_ARCHITECTURE annonce des durées ; DATA_RETENTION dit qu'aucune n'est décidée ni implémentée (hors GPS 30 jours et brouillons).
- **PAYMENT_ARCHITECTURE** : §1 annonce Accounts v2, le code utilise v1 Express ; §3/§6 annoncent un schedule de payout manuel absent du code ; §9 un seul secret webhook vs §10.9 deux ; §10.2 omet `checkout.session.completed` ; `APP_PUBLIC_BASE_URL` par défaut `mecano-mobile-delta.vercel.app` dans la doc vs `https://movi-k.com` dans le code.
- **FIRESTORE_ARCHITECTURE** : schémas `payments`/`driver_payouts` périmés (noms de champs et statuts) ; une quinzaine de collections réelles absentes (`payment_profiles`, `refunds`, `disputes`, `provider_webhook_events`, `tax_configs`, `booking_*`, `push_tokens`, `system_config/*`).
- **FIRESTORE_INDEXES** : documente 20 index ; le fichier en a 23 + 3 overrides ; les index #1 et #6 « utilisés par le dispatch » ne le sont pas.
- **DISASTER_RECOVERY** AA-5 : « `payout_policy_configs` absent → échec » (faux, repli codé) ; « `tax_configs` absent → jamais 0 % » (faux : repli sur `tax_rate` de la grille, qui vaut 0).
- **MONITORING_RUNBOOK** : chiffres de tests périmés (109 unitaires vs 713 aujourd'hui) ; « payout échoué couvert » vrai pour le log, faux pour l'état.
- **Décompte du registre** : 34 fiches (l.13) vs « 31 fiches » répété dans les addenda des 19-20 oct. ; en-tête « dernière mise à jour 14 octobre » malgré des addenda du 20.
- **Zone et contact** : AC-4 « aucune zone choisie » vs Granby 40 km configuré ; « canal de contact manquant » (sept./6 oct.) vs `info@movi-k.com` approuvé (16 oct.) vs page Granby encore « à venir » dans le code.

---

## 9. Ordre de lancement proposé, bloc par bloc

Chaque bloc se termine par un déploiement coordonné (fonctions + règles + web) et une recette. Les blocs A et B peuvent avancer en parallèle (A = développement, B = Daniel). Rien de ce qui suit n'autorise un paiement réel avant la fin du bloc D.

### Bloc 0 — Cette semaine (avant le 30 octobre)
- Redéployer **toutes** les fonctions sur Node 22 depuis un `main` réconcilié (fusionner les branches publiées, vérifier P1-DISPATCH-RETRY-01 et P1-DRIVER-OFFER-TERMS-01). Vérifier `firebase functions:list` et la présence des deux webhooks. — 0,5 à 1 j + Daniel.
- Confirmer les 4 interrupteurs à `false`, `pilot_access` vide, règles déployées = dépôt. — Daniel, 1 h.

### Bloc A — Fermer la chaîne d'argent (développement, ≈ 6 à 8 j)
1. SEC-01 remboursement admin seulement ; SEC-02 claim testeur à la place du courriel ; SEC-03/PAY-02 retrait de `recordTip` ; PAY-09 bootstrap à `false`. — 1 j.
2. DRV-09 + PAY-04 : décision du modèle de versement, puis `interval: manual` à la création des comptes et déclenchement de `calculateDriverPayout` (ou affichage des transferts). PAY-05 statuts payout par webhook Connect ; PAY-06 `stripeAccount` dans la réconciliation ; PAY-14 idempotence. — 2 à 3 j.
3. PAY-03 : transition `FAILED → CAPTURE_PENDING` admin, exclusion des snapshots non capturés du payout, notification admin ; PAY-11 distinction timeout/refus ; PAY-10 reprise des autorisations de missions annulées ; PAY-13 litige inconnu. — 2 j.
4. PAY-08 : borner `days_ahead` à 5 jours et `max_advance_minutes`, ou cron de ré-autorisation. — 1 j (borne) ou 2 j (cron).
5. PAY-12 : callable `publishBookingPolicy` (super_admin) pour la version finale. — 0,5 j.
6. TECH-04 hotfix : `paymentFailed` et les 7 types de registre côté Dart, plus échec explicite sur valeur inconnue. — 0,5 j.

### Bloc B — Ce que Daniel fournit en parallèle (≈ 2 à 3 semaines calendaires)
- Stripe : compte, clé restreinte, deux webhooks, trois secrets ; décisions §7.3.
- Comptable : taux et numéros TPS/TVQ → `updateTaxConfiguration` (2 appels) ; émetteur de facture.
- Juriste : conditions de réservation, CGU, confidentialité Loi 25, conditions chauffeur, consentement GPS/photos/OpenAI, en FR puis EN/ES.
- Courtier : couverture des biens et exigences chauffeurs.
- Opérations : véhicule réel vérifié, mapping objets ↔ véhicules, `booking_capacity`, `driver_scheduling`, comptes admin, astreinte, confirmation de `info@movi-k.com`.
- Infra : sauvegardes + RPO/RTO, alertes, App Check en mode monitor, VAPID, projet de test.

### Bloc C — Dispatch, admin et parcours critiques (≈ 6 à 8 j)
1. DISP-01 balayage indépendant de la politique ; DISP-02 notifications « aucun chauffeur » et « paiement refusé » ; SEC-07 debounce du redispatch et plafond de missions ouvertes. — 1,5 j.
2. ADM-01 boutons Rembourser et statut de litige ; ADM-02 panneau interrupteurs ; ADM-07 masquage par rôle ; ADM-06 éligibilité d'assignation ; ADM-15 attribution de rôles ou procédure. — 2,5 j.
3. CLI-01/DRV-08 mot de passe oublié ; CLI-02 page 404 ; CLI-05 état « paiement non autorisé » avec mise à jour de carte ; CLI-04 vue annulée ; CLI-07 retrait des routes mécanicien ; CLI-08 `returnTo`. — 3 j.
4. DRV-02 messages d'acceptation réels ; DRV-03/DRV-10 streams mémoïsés ; DRV-04 au minimum le message « position en pause » côté client. — 1 j.

### Bloc D — Sécurité et conformité avant tout utilisateur externe (≈ 4 à 5 j + juridique)
1. SEC-04 preuves = chemins Storage vérifiés ; SEC-05 approbation par document (avec UI `validateDriverDocument`, ADM-04/DRV-13) ; SEC-09 listes blanches `delivery_requests`/`users` ; SEC-08 `ratings` ; SEC-06/SEC-07 quotas et `email_verified`. — 2,5 j.
2. LEG-01 Consent Mode v2 + bannière ; LEG-03 alignement des textes d'annulation ; LEG-02/04/05 intégration des textes juridiques dans les 3 langues et retrait des replis « en révision » ; LEG-06 pages non liées ; SEC-14 en-têtes Vercel. — 2 j + textes.
3. Recette Stripe sandbox complète : carte OK / refusée / 3DS (PAY-16), acceptation, capture, échec de capture, remboursement, litige, payout Connect, `account.updated`, bascule d'environnement (PAY-01 : runbook de purge des profils test). — 2 j.
4. Recette appareils réels (plan AC-3) : GPS, caméra, permissions, push, perte réseau, sur Android ; iOS seulement si `ios/` est créé (TECH-10/DRV-07). — 2 à 3 j.
5. GO/NO-GO : AC-5 revalidée, 4 interrupteurs passés à `true` un par un, smoke test réel avec comptes internes (devis → livraison → capture → versement), puis ouverture à la liste pilote.

### Bloc E — Pendant le pilote (≈ 8 à 10 j)
- TECH-01/TECH-02 : staging, workflow de déploiement, CI sur `main`, drift check des règles ; TECH-08 capture d'erreurs client et alertes ; TECH-10 signature Android et versionnage ; DRV-01 reprise d'inscription ; DRV-05/DRV-06 profil éditable et suppression de compte ; ADM-05 requêtes bornées ; ADM-03 promotions ; I18N-01/02/04/05/06 et vocabulaire ; UX-01/02/03/04 ; TECH-12 `npm audit fix` et montée `firebase-admin@14`.

### Bloc F — Après le pilote (≈ 15 à 20 j)
- TECH-03 retrait de la couche démo et Hive ; TECH-05 un seul moteur de prix ; TECH-06 découpe des fichiers géants ; TECH-07/I18N-03 migration ARB ; TECH-09 montée des SDK Firebase ; TECH-11 couverture et e2e Playwright ; TECH-13/14 nettoyage des commentaires, README, sortie des artefacts ; TECH-16 chargement différé de l'admin et optimisation des images ; DRV-04 GPS de premier plan ; iOS complet si retenu ; SEC-15 région et `maxInstances`.

---

## Annexe — Résultats des commandes et éléments non vérifiés

```
functions/ (Node v22.22.0, firebase-functions 6.6.0, firebase-admin 12.7.0, stripe 22.5.0)
npm ci            OK
npm run lint      OK (0 erreur, 0 avertissement)
npm run build     OK (tsc)
npm run test:unit 53 suites, 713 tests, 713 réussis, 0 échec, 0 ignoré, 40 s
npm audit --omit=dev   14 vulnérabilités (10 modérées, 4 hautes, 0 critique), toutes transitives
git status        propre (node_modules/ et lib/ ignorés)
```

Non exécuté : `flutter analyze`, `flutter test` (675 tests déclarés), `flutter build web`, `npm run test:integration` (776 tests, émulateurs requis), `npm run test:stripe-sandbox`.

Non vérifiable depuis le dépôt : site servi sur `movi-k.com`, fonctions et règles déployées, runtime Node en prod, secrets présents, valeurs de `system_config/*` et de `tax_configs`, existence du compte démo, comptes admin, sauvegardes/PITR, App Check, restriction de la clé Google Maps, protection de branche GitHub, paramètres Vercel, région Firestore.
