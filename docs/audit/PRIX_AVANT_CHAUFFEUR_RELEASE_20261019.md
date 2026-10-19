# Prix avant affectation chauffeur — publication ciblée du 19 octobre 2026

## Décision et périmètre
Le propriétaire demande que le client obtienne le prix officiel avant la connexion ou l'affectation d'un chauffeur. Il autorise ensuite explicitement le push ciblé, la publication coordonnée Firebase/Vercel et le contrôle d'un devis réel, sans fusion dans main, activation des paiements ni création de mission réelle.

Branche de publication : fix/quote-before-driver-release-20261019. Base : 10179e0e181c6373d3173177b5a0fa297da87b17. Le worktree feature/booking-terms-20261018 et ses modifications sont conservés séparément.

## Correctif
Le parcours price_before_assignment calcule le prix avec le moteur serveur, l'itinéraire officiel, les taxes et la version tarifaire active. Il ne consulte ni les véhicules/chauffeurs ni booking_capacity pour chiffrer une demande. Les données de l'objet, la propriété des photos, les adresses et la zone restent validées. La tarification doit être identique pour les trois catégories pilote ; sinon un refus tarifaire explicite est conservé.

Le contexte pre_assignment est inclus dans l'empreinte du nouveau devis. Les snapshots et devis antérieurs ne sont pas réécrits. La suppression déjà approuvée du supplément lourd est conservée. Aucun moteur tarifaire, taux, commission, pourboire, taxe, ledger ou fournisseur Stripe n'est modifié.

La création et l'affectation manuelle de tests restent limitées aux rôles et comptes de test déjà autorisés côté serveur. Une demande préalable n'est pas une réservation commerciale et ne peut pas devenir un paiement par un changement de mode client. Le dispatch automatique ignore ces demandes : aucune offre automatique à un chauffeur.

## Isolation
Les changements de conditions de réservation, reçus, routeur et autres travaux non publiés du chantier parallèle sont exclus. Les sources frontend déjà présentes dans le dernier bundle public sont conservées d'après leurs empreintes archivées ; leur sauvegarde Git n'est pas un nouveau développement de ce correctif. Aucun fichier de credentials ou configuration locale Vercel/Firebase n'est ajouté au commit.

## Vérifications
Avant publication, la lecture Firebase du 19 octobre à 14:21 UTC confirme MOVIK-PILOT-20261016-001, trois catégories avec départ 20 CAD, 1,50 CAD/km, 0,30 CAD/min et minimum 25 CAD, frais volumineux nuls. Les quatre interrupteurs opérationnels sont false. Aucune configuration n'est modifiée.

Le premier lot isolé réussit 162 tests serveur et 168 tests Flutter, sans échec ni test ignoré. Les tests exécutent le vrai code avec services externes simulés : ils ne prouvent pas un devis LIVE. TypeScript et Flutter analyze sont verts. Les derniers contrôles du build configuré, publication et navigateur sont consignés séparément dans artifacts/quote-release-20261019-1420, dans le worktree d'origine.

## Fonctions à publier ensemble
getBookingConfiguration, getBookingQuote, calculateDeliveryQuote, createDeliveryRequest, adminAssignDelivery, acceptDelivery, onMissionCreatedDispatch, onMissionReopenedDispatch, onDriverBecameAvailableDispatch.

Aucun déploiement de règles Firestore/Storage, aucune modification des flags, aucun test de mission ou paiement réel. La publication ne constitue pas l'ouverture commerciale du service.
