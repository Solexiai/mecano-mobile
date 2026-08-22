# PHASE 7 — Bloc A — Matrice QA Produit (version initiale)

Cette matrice est volontairement créée rapidement (conformément à la consigne du Bloc A :
« Ne pas passer une session complète à documenter »). Elle sera enrichie au fil des blocs B-AC
au fur et à mesure que des scénarios sont réellement testés (statut mis à jour en continu).

Colonnes : ID | Rôle | Préconditions | Étapes | Résultat attendu | Test auto existant | Test manquant | Statut | Bug

## Auth / Onboarding

| ID | Rôle | Préconditions | Étapes | Résultat attendu | Test existant | Manquant | Statut | Bug |
|---|---|---|---|---|---|---|---|---|
| AUTH-01 | client | aucune | signup email/password | compte créé, redirection dashboard client | partiel (unit auth Flutter) | E2E signup->login runtime | À TESTER (Bloc E) | - |
| AUTH-02 | tous | compte existant | login | session active, claims corrects | - | E2E | À TESTER (Bloc E) | - |
| AUTH-03 | admin révoqué | admin dont le rôle est rétrogradé | admin tente une action admin après révocation | action refusée immédiatement (claims rafraîchis) | non | oui — critique | À TESTER (Bloc E) | RISQUE IDENTIFIÉ |
| DRV-ONB-01 | driver | signup | profil + véhicule + documents + submit review | passe en pending_review | `submitDriverForReview` (unit/integration existant) | E2E complet | À TESTER (Bloc C) | - |

## Missions (Client)

| ID | Rôle | Préconditions | Étapes | Résultat attendu | Test existant | Manquant | Statut | Bug |
|---|---|---|---|---|---|---|---|---|
| MIS-C-01 | client | payment_profile avec default_payment_method | devis -> création mission -> assignation -> tracking -> completed | mission completed, paiement capturé, historique visible | `e2eDeliveryLifecycle.test.ts` (nominal) | négatifs ci-dessous | PARTIEL (nominal DONE) | - |
| MIS-C-02 | client | aucun chauffeur dispo | createDeliveryRequest puis timeout dispatch | mission reste `searching_driver`, message clair, pas de crash | non trouvé | oui | À TESTER (Bloc B) | - |
| MIS-C-03 | client | devis expiré | createDeliveryRequest avec quoteId expiré | `failed-precondition` | `createDeliveryRequest.test.ts` (couvert) | non | DONE | - |
| MIS-C-04 | client | paiement refusé à l'acceptation | acceptDelivery avec FakePaymentProvider en échec | mission `payment_failed`, désassignée | couvert dans un test paiement ? à vérifier | à confirmer | À VÉRIFIER (Bloc B) | - |
| MIS-C-05 | client | mission assignée (driver_id != null), payment authorized | client annule (`status`->`cancelled`) | **paiement autorisé doit être libéré/annulé (cancelAuthorization)** | NON — `cancelAuthorization` jamais appelé dans `src/` | oui — CRITIQUE | BUG SUSPECTÉ (Bloc B) | **candidat P1** |
| MIS-C-06 | client | session expirée | tente action authentifiée | redirection login, pas de crash | non | oui | À TESTER (Bloc E/F) | - |
| MIS-C-07 | client | non authentifié | accède à un écran mission | redirection/erreur propre | non | oui | À TESTER (Bloc F) | - |
| MIS-C-08 | client | ancienne mission avec données partielles (avant Phase 6, sans timestamps financiers) | ouvre l'historique | pas de crash, defaults sûrs | non | oui | À TESTER (Bloc R) | - |
| MIS-C-09 | client | déconnexion réseau pendant requête | retry | pas de double mission créée | `acceptDeliveryConcurrency.test.ts` couvre double-accept chauffeur, pas retry client | oui côté client | À TESTER (Bloc G) | - |

## Missions (Chauffeur)

| ID | Rôle | Préconditions | Étapes | Résultat attendu | Test existant | Manquant | Statut | Bug |
|---|---|---|---|---|---|---|---|---|
| MIS-D-01 | driver approuvé | mission ouverte | accepte -> pickup -> transit -> dropoff -> completed | earnings crédités, payout éligible | `e2eDeliveryLifecycle.test.ts` | - | DONE | - |
| MIS-D-02 | driver pending_review | tente accepter | refusé | `acceptDeliveryConcurrency.test.ts` | - | DONE | - |
| MIS-D-03 | driver suspendu | tente accepter | refusé | `acceptDeliveryConcurrency.test.ts` | - | DONE | - |
| MIS-D-04 | 2 drivers | même mission, accept simultané | un seul gagne, l'autre reçoit erreur claire | `acceptDeliveryConcurrency.test.ts` (déjà 100% Phase 5/6) | - | DONE | - |
| MIS-D-05 | driver | GPS refusé/désactivé | tente `recordTrackingPoint` | erreur claire, mission reste cohérente | `recordTrackingPoint.test.ts` (à vérifier cas refus) | à confirmer | À VÉRIFIER (Bloc H) | - |
| MIS-D-06 | driver | proof upload échoue (Storage) | completeDelivery sans proof valide | erreur claire, pas de transition fantôme | à vérifier | oui | À TESTER (Bloc C/G) | - |
| MIS-D-07 | driver | payout policy / Stripe account non configuré | payout scheduled | échec explicite, pas de perte de fonds | `reverseDriverPayout.test.ts`, `calculateDriverPayout.test.ts` | cas payout failure complet | À VÉRIFIER (Bloc C) | - |

## Admin / Analyste / Super Admin

| ID | Rôle | Étapes | Résultat attendu | Statut |
|---|---|---|---|---|
| ADM-01 | analyste | review driver, request documents | autorisé | Sécurité déjà auditée Phase 6 (securityRules.test.ts) — DONE (lecture/écriture Firestore) ; reste à tester via Functions (Bloc D) |
| ADM-02 | analyste | tente refund/payout/reconciliation | refusé | Security Rules DONE ; Functions-level à confirmer (Bloc D) |
| ADM-03 | admin | refund/payout/dispute/reconciliation/taxes | autorisé | Security Rules DONE ; Functions-level à confirmer (Bloc D) |
| ADM-04 | super_admin | payout policy update | autorisé | `payoutPolicyConfig.test.ts` (unit) — à confirmer intégration (Bloc D) |

## GPS / Notifications / Responsive / I18N / Sécurité / Performance
Voir blocs dédiés H, I, J, K, Q, M — matrice à enrichir au fur et à mesure des tests réels.

---
**Note méthodologique** : Cette matrice n'est PAS exhaustive à ce stade — elle sert de point de
départ. Elle sera mise à jour à chaque bloc fermé avec les résultats réels (statut, bug ID le
cas échéant). La priorité immédiate est de suivre TEST → FAIL → FIX → RETEST plutôt que
d'étoffer ce tableau de façon théorique.

**Découverte initiale la plus importante (à valider par test réel dans Bloc B)** :
`MIS-C-05` — aucune Cloud Function n'appelle `cancelAuthorization()` du provider de paiement
lorsqu'un client annule une mission déjà assignée (payment_status = `authorized`). Grep exhaustif
sur `functions/src/` confirme zéro appel à `.cancelAuthorization(` en dehors de sa définition
d'interface/implémentation. Ceci doit être confirmé par un test d'intégration réel avant d'être
classé comme bug (voir Bloc B).
