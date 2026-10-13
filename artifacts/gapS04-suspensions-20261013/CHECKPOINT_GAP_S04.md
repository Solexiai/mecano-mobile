# MOVI-K — CHECKPOINT GAP-S-04 — SUSPENSIONS ORDINAIRE / URGENTE

Date : 13 octobre 2026, America/Toronto.

**Verdict : FERMÉ DANS LE PÉRIMÈTRE TEST LOCAL/ÉMULATEUR — NON DÉPLOYÉ.**
L'autorisation du propriétaire a été reçue pour la politique ordinaire/urgente. Aucun push, merge, déploiement ou modification de la production.

## Référence Git

- Dépôt : Solexiai/mecano-mobile.
- Worktree : `C:\Users\Utilisateur\movik-gps-history-fix-20261009`.
- Branche : `fix/gps-client-history-scope-20261009`.
- HEAD initial : `756efd66a21601e408477f3202410246668a28e4`.
- Branche de lancement `release/live-backend-granby-20261006` vérifiée inchangée.

## Contrat métier adopté

- Suspension **ordinaire** : refus de toute nouvelle mission et profil mis hors ligne. Une mission déjà assignée peut poursuivre ses transitions existantes, conserver son GPS actif seulement sur son lien de mission, et être terminée sans modifier les écritures financières prévues pour le flux normal ; fin de mission ne remet jamais un profil suspendu en ligne.
- Suspension **urgente** : refuse immédiatement completePickup, completeDelivery, updateMissionTrackingStatus et recordTrackingPoint même si la mission était déjà assignée. Aucune annulation de mission, remboursement, capture ou effet comptable nouveau n'est déclenché par l'action de suspension ; intervention admin nécessaire.
- Ancienne suspension sans `suspension_mode` explicite : **urgente par défaut (fail-closed)** ; anciens clients appelant suspendDriver sans mode restent urgents.
- Un administrateur peut promouvoir une suspension `ordinary` existante vers `urgent` sans réactiver ; le retour `urgent -> ordinary` n'est pas autorisé silencieusement. `reactivateDriver` rétablit approved et efface le champ de mode.
- Une suspension n'autorise aucun accès d'un tiers ou d'un chauffeur non assigné.

## Fichiers et fonctionnement

- `functions/src/lib/driverSuspensionPolicy.ts` : modes et vérification transactionnelle de driver_profiles.
- `functions/src/functions/suspendDriver.ts` : niveau facultatif strict (défaut urgent), raison requise, admin ou super_admin, escalade et traçabilité du mode.
- `functions/src/functions/reactivateDriver.ts` : remise à zéro du mode.
- `functions/src/functions/completePickup.ts`, `completeDelivery.ts`, `updateMissionTrackingStatus.ts` : relisent le profil chauffeur dans la transaction, avant toute écriture ; une suspension urgente concomitante force une relecture via les mécanismes de transactions Firestore. Éligibilité selon la mission et le statut.
- `functions/src/functions/recordTrackingPoint.ts` : un chauffeur suspendu ordinairement ne peut transmettre que sur sa mission encore active et liée ; urgent/legacy sont refusés. Les règles d'autorité GPS d'origine sont conservées.
- `functions/src/lib/types.ts` : champ optionnel `suspension_mode` avec valeurs `ordinary` / `urgent`.
- `lib/backend/repositories/driver_repository.dart`, `firebase_driver_repository.dart` : transport explicite du niveau vers la callable.
- `lib/backend/models/driver_profile_v2.dart` : champ sérialisé et désérialisé pour l'interface admin.
- `lib/screens/dashboard/admin/drivers/admin_driver_detail_screen.dart` et `lib/l10n/app_strings.dart` : boutons ordinaire/urgente et bouton d'escalade, textes FR/EN/ES.
- `lib/screens/driver/driver_status_screen.dart` : un profil suspendu ordinairement garde l'accès au tableau de bord pour sa mission, mais n'a aucun bouton de mise en ligne ; suspension urgente et legacy conservent le blocage. Deux tests widget ajoutés.
- Fixtures de tests de repository et des transitions mises à jour uniquement pour l'autorité chauffeur requise.

## Résultats techniques contrôlés

- **10/10 tests ciblés GAP-S-04** sur Firestore/Auth Emulator demo-movik-test, aucun échec.
- **150/150 tests serveur** sur neuf suites ciblées : sécurité admin, GPS, atomicité, completion pickup/delivery, transitions, acceptation concurrente et nouveaux scénarios suspension.
- **33/33 tests Flutter** sur trois suites chauffeur (statut, onboarding/document, Stripe Connect), aucun échec : 31 avant le correctif final de navigation, puis 20 tests réussis sur le nouvel écran de statut, incluant 2 nouveaux scénarios ordinaires/urgents.
- Compilation TypeScript `tsc --noEmit` et ESLint ciblé des sources réussis.
- Dart `analyze --fatal-infos` ciblé des fichiers touchés et fixtures Flutter : 0 anomalie.
- Les tests de missions financières restent sur les fixtures existantes ; aucune utilisation de fournisseur Stripe réel ni capture volontaire dans les nouveaux scénarios.
- Les résultats prouvent les **handlers directs avec des Firestore transactions émulées** et les widgets Flutter, pas une intégration réseau Functions déployée.

## Limites et risques distincts

- Aucun test Chrome/Safari ou sur appareil physique, ni validation des notifications de suspension côté chauffeur en temps réel.
- L'affichage admin des nouveaux boutons est compilé/analysé et les tests Flutter connexes passent ; aucune capture Chrome ni preuve de traduction en navigateur. La navigation depuis le statut ordinaire est testée comme bouton affiché, pas comme parcours de mission complet sur téléphone.
- L'autorisation des clients à lire la localisation après suspension ordinaire dépend également de Firestore Rules et de l'application cliente ; non certifiée par la seule autorisation serveur du report GPS. À vérifier dans une recette GPS séparée avant le pilote.
- Le niveau ordinaire autorise des missions **déjà assignées**, même si le chauffeur n'a pas encore physiquement rejoint le point de collecte ; si une règle future exige un début de déplacement démontré, ce changement métier demandera une décision explicite.
- Aucune bascule de statut, commission, tarif, ledger, snapshot, Stripe ou règles de sécurité Firestore en production.
- Le test des tuiles réseau 1.3L reste BLOQUÉ ET REPORTÉ.

Registre après fermeture locale ciblée : **P0 0 / P1 0 / P2 3 ouverts**, 27 fiches conservées. Les trois P2 restants sont GAP-M-05, GAP-M-06 et P2-L-01.

**Aucun GO de lancement ; aucun push, merge ni déploiement.**
