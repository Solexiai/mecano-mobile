# Revue publique Movi-K — 6 octobre 2026

Branche : `audit/public-launch-granby`, base de reprise `c7b86b0`. Aucune fusion dans main et aucun déploiement de production pendant cette revue.

## État et corrections

Worktree existant : `C:\Users\Utilisateur\mecano-mobile-launch-review`. Mise à jour de `715550a` à `c7b86b0` par avance rapide. Les dix fichiers non suivis antérieurs (captures et scripts locaux) ont été préservés. Aucun changement applicatif non committé avant cette reprise.

- `test/public/public_launch_pages_test.dart` (c7b86b0) : applique réellement l’échelle du texte 200 % au test QR et vérifie sa valeur.
- `lib/screens/delivery/delivery_request_flow_screen.dart` : la catégorie de l’accueil est affichée dans sa langue et conservée depuis le brouillon. Une catégorie générale telle que « Meubles » ne crée plus silencieusement un objet « Autre objet » ; le visiteur précise lui-même les objets. Les catégories détaillées du formulaire gardent leur comportement.
- `test/home/home_screen_test.dart` : assertions sur « Meubles », absence d’objet générique inventé et conservation de la catégorie et de la description après connexion.
- Scripts de capture et serveur SPA local dans `scripts/*public_review_20261006*`. Observations et captures dans `artifacts/review-20261006/`.

## Vérifications

- Relance finale `flutter analyze` : aucune anomalie (8,3 s). Cinq fichiers ciblés : **58 tests réussis** (32 s). Suite complète `flutter test` : **646 tests réussis** (3 min 09 s).
- Build final `flutter build web --release --dart-define=USE_FIREBASE_EMULATORS=true` : **réussi** (108,4 s de compilation). Utilise explicitement `demo-movik-test`, pas les données de production.
- Premier passage avant la correction de catégorie : analyse sans anomalie, 58 tests ciblés réussis et build Web réussi (112,4 s).
- Avertissement non bloquant : famille CupertinoIcons attendue mais non incluse ; aucune dépendance modifiée pour masquer cet avertissement.
- Capture navigateur finale après correction : **36 visites, 25 captures**, dont 24 accueil/Granby (FR/EN/ES × 320/390/768/1280 px) et le formulaire invité avec catégorie « Meubles ». Aucune erreur JavaScript. Deux appels `getBookingConfiguration` refusés, car les émulateurs ne sont pas actifs. Les assertions navigateur confirment la catégorie et l’absence d’objet générique inventé.
- Accueil et page Granby inspectés visuellement ; pages publiques et politiques chargées directement. **11 liens publics cliqués en français sur desktop**, avec vérification de la destination : devis, chauffeur, connexion, FAQ, Tarifs, Sécurité, Contact, Comment ça marche et trois politiques. **Six cartes de catégorie cliquées**, avec vérification du paramètre de catégorie. Preuves : `link-validation.json`, `category-validation.json`.
- Les illustrations existantes gardent du texte français même en EN/ES. La revue linguistique des textes d’interface ne traduit pas ces images.
- Texte 200 % : tests Flutter accueil FR/EN/ES sur 320 px et page QR ; captures navigateur à échelle normale.

## Preview et limites

- Preview locale : `http://127.0.0.1:8092/fr`, QR `http://127.0.0.1:8092/fr/granby`. Serveur concurrent et routes SPA ; bannière Firebase Emulator visible.
- Preview Vercel existante : https://mecano-mobile-git-audit-public-090e24-solexis-projects-4c019079.vercel.app/fr/granby . Protégée ; API 403 pour le scope du projet. Pas de preuve visuelle sur cette preview et aucune protection désactivée.
- Reprise invité → connexion et devis côté serveur validés avec doubles de test / CI émulateurs. Aucun compte connecté, devis officiel réel, mission ni transaction réelle pendant cette recette visuelle.
- GA4 : PR #47 ouverte/non fusionnée lors de la vérification. Aucun identifiant Firebase écrasé.
- Aucun calcul tarifaire, Stripe, snapshot ni règle serveur modifié pendant cette reprise. Les modifications financières/serveur déjà présentes dans 715550a restent dans la branche et nécessitent leur propre revue. Ne pas interpréter le succès des tests comme preuve d’activation Stripe live.

## Décisions restantes

Fournir un canal de contact officiel fonctionnel, autoriser l’accès à la preview, fournir un environnement de recette avec capacités/véhicules/zone/politiques approuvés et compte client, puis vérifier le paiement et la concordance devis = mission = snapshot = cents Stripe. Décision GA4 et approbation des changements serveur antérieurs encore requises.

**QR pas prêt à être distribué au public : canal de contact manquant.** Cible recommandée après validation et publication approuvée : https://movi-k.com/fr/granby . Aucune publication en production autorisée par cette revue.

## Sources

- CI Flutter de c7b86b0 (646 tests, analyse et build réussis) : https://github.com/Solexiai/mecano-mobile/actions/runs/37499286321
- CI Firebase (228 tests unitaires, 618 tests d’intégration sur émulateurs réussis) : https://github.com/Solexiai/mecano-mobile/actions/runs/37499286293
- PR de revue en brouillon : https://github.com/Solexiai/mecano-mobile/pull/51
- Preuves locales : sorties Desktop Commander du 6 octobre 2026 et `browser-validation.json`.
