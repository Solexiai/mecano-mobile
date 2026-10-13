# MOVI-K — CHECKPOINT GAP-M-06 — LECTURES FIRESTORE BORNÉES
Date : 2026-10-13, America/Toronto

## Verdict
FERMÉ — PÉRIMÈTRE CODE FLUTTER / TESTS WIDGET LOCAUX VALIDÉ — NON DÉPLOYÉ.
Ce verdict n'est PAS une mesure du coût réel Firestore en production et n'atteste PAS d'une recette sur de vraies collections chargées.

## Prérequis et sécurité
- Dépôt : Solexiai/mecano-mobile.
- Worktree : C:\Users\Utilisateur\movik-gps-history-fix-20261009.
- Branche : fix/gps-client-history-scope-20261009.
- HEAD initial : d92527efdd8d3d8616b1e9927c7648a541b5a171.
- Aucun push, merge, déploiement, modification Stripe/Firebase Production, tarifs, commissions, snapshots, ledger ou règles Firestore.

## Cause initiale
- FirebaseNotificationRepository.watchNotifications() : écoute Firestore sur la totalité des notifications d'un utilisateur, sans .limit().
- FirebaseDriverRepository.watchDriversByStatus() : écoute tous les profils, filtrés ou non, sans .limit() ; les alias migrés étaient écartés seulement APRÈS le chargement.
- Le chargement de tous les résultats d'un coup avait un risque de coût et de charge client sans qu'un coût réel excessif ait été mesuré.

## Correctif local
1. Les deux flux acceptent un paramètre nommé `limit`, par défaut 50, validé positif. Chaque abonnement s'appuie sur une requête Firestore munie de .limit(limit). Les notifications utilisent un index simple créé_at descending ; l'ordre le plus récent d'abord ne nécessite pas de nouvel index composite. Les chauffeurs utilisent l'ordre stable documentId, plus filtre de statut si demandé ; les éléments déjà chargés sont triés localement par dernière modification comme avant.
2. L'interface notifications utilise une fenêtre initiale de 50, puis le bouton localisé FR/EN/ES « Afficher plus » demande 100, 150, etc. Elle conserve le comportement des liens mission, des compteurs et des erreurs du flux. Le même incrément existe pour la liste administrative des chauffeurs et se réinitialise au changement de filtre. Le bouton « Réessayer » renouvelle l'abonnement après erreur.
3. Les alias chauffeurs migrés sont filtrés APRÈS requête. La nouvelle classe FirestoreDriverWindow conserve le nombre de documents bruts reçus, évitant de masquer « Afficher plus » lorsque la page contient uniquement des profils migrés ; le dossier valide suivant reste accessible.
4. Les fenêtres augmentent volontairement à la demande (ce n'est PAS une pagination par curseur). Chaque requête reste bornée, mais charger un historique très volumineux requiert des fenêtres croissantes et des lectures répétées ; on ne revendique pas des coûts constants par page. Aucun document n'est supprimé.
5. Les interfaces et fakes de tests ont reçu seulement le paramètre compatible `{int limit = 50}`, sans changer les routes ni les actions métier.

## Tests
- Dart analyze --fatal-infos : aucune anomalie dans les sources et tests ciblés.
- Lot widget ciblé : 11/11 réussis (chargement 50→100, profils migrés, changement filtre, reprise après erreur et notifications live).
- Non-régression Flutter sans tests GPS réseau : **63/63 réussis** sur huit fichiers (notifications, navigation, erreurs d'écriture, onboarding et statut chauffeurs, Stripe Connect simulé, accessibilité).
- Responsive ciblé Notifications U-6.5 : **2/2 réussis** aux largeurs 320 et 360 pixels.
- La tentative de suite responsive complète avec `--dart-define=no_default_http_client=true` a subi des échecs sur les widgets de tuiles GPS externes (création HTTP interdite par le harnais). Ce résultat n'est pas masqué : test GPS 1.3L déjà BLOQUÉ ET REPORTÉ, indépendamment de GAP-M-06. Aucun succès de toute la suite responsive globale n'est revendiqué.
- Aucune requête Firestore réelle ni émulateur Firebase testé par ces tests widget/fakes : le caractère borné des appels .limit est établi par le code Flutter analysé, pas par les compteurs de lectures facturées.

## Limites distinctes
- watchUnreadCount reste un listener historique sur les notifications non lues. markAllAsRead effectue également une lecture indépendante ; ni l'un ni l'autre n'est corrigé ou présenté comme borné ici. Une future optimisation demanderait une conception qui préserve le compteur en temps réel et le marquage global sans pertes.
- Notifications historiques sans le champ created_at ne sont pas incluses par orderBy('created_at'); les créateurs actuels contrôlés renseignent ce champ. Migration de données legacy non auditée sur Firebase réel.
- Le tri du répertoire chauffeur par dernière modification s'effectue à l'intérieur de la fenêtre actuellement chargée, pas globalement sur toute la collection comme avant ; l'accès aux documents suivants reste possible via « Afficher plus ». Les index/volumes réels ne sont pas vérifiés.
- Les P3, l'audit de l'accessibilité général, l'intégration GPS 1.3L et les essais navigateur/appareil restent hors périmètre.

## Registre
27 fiches au total, 25 fermées dans leur périmètre déclaré ; P0 0 / P1 0 / P2 2 ouverts : GAP-M-05 et P2-L-01.
GAP-M-06 fermé uniquement pour les deux abonnements ciblés et leur accès progressif aux résultats. Aucun GO lancement.
