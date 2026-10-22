# Movi-K — Chauffeur, véhicule et validation pilote
Mise à jour : 16 octobre 2026. Implémentation locale, non déployée.

## Parcours livré dans le code
1. Le chauffeur crée son dossier dans le parcours existant et choisit pick-up, fourgon cargo ou camion cube. Les anciennes catégories ne sont pas supprimées des données historiques.
2. Il fournit les informations, la charge utile déclarée, les photos du véhicule et les documents déjà demandés par Movi-K.
3. Dans Administration → Chauffeurs → Dossier, l'administrateur vérifie les documents et approuve le dossier avec l'action existante.
4. Dans la section Véhicule, « Vérifier les capacités » ouvre une fiche distincte pour chaque véhicule. Saisir des dimensions utiles et d'ouverture mesurées, une charge utile vérifiée, les aides/services disponibles, une date de validité et la justification documentaire.
5. La validation serveur exige le rôle administratif, le bon propriétaire, une identité véhicule inchangée et un dossier approuvé. La date ne peut dépasser celle des documents approuvés. Une simple déclaration du chauffeur n'est pas une capacité validée.
6. Les règles clientes interdisent l'auto-validation et le remplacement de l'identité physique d'un véhicule vérifié. Retirer sa validation administrativement avant de changer ces informations, puis effectuer une nouvelle vérification.
7. Le sélecteur existant de réservation utilise les capacités vérifiées. Les essais intégrés démontrent le chemin photo → devis → offre → notification interne → acceptation pour les trois catégories, en immédiat et programmé, exclusivement en émulateur avec fournisseurs fictifs.

## Frontière administrative / financière
La nouvelle fonction reviewDriverVehicle écrit uniquement driver_vehicles et un audit atomique. Aucun tarif, montant, taxe, commission, snapshot, paiement ni ledger n'est modifié.
La vérification physique ne doit jamais copier les valeurs des fixtures. Pour une caisse ouverte, les limites doivent être réellement autorisées, pas illimitées.
Les comptes multirôles sont contrôlés par les rôles Auth; un analyste ne peut s'auto-valider. L'exception super_admin conserve le contrat administratif existant.

## Prérequis de publication et d'ouverture encore absents
Lecture seule du 16 octobre 2026 à 13:03:28 UTC : system_config/booking_capacity, booking_policy, service_zones, photo_analysis absents; réservations, acceptations, paiements et versements désactivés. Aucun véhicule dans driver_vehicles pour le chauffeur de recette indiqué.
- Contact : fournir le courriel ou le canal officiel à afficher. Aucune adresse personnelle mentionnée pour un compte n'est automatiquement publiée.
- Zone : fournir les municipalités ou la limite précise approuvée de Granby et environs.
- Réservation : capacités et correspondances objets/véhicules approuvées; seuils de manutention existants à fournir sans inventer de frais; conditions d'annulation et de paiement approuvées.
- IA : secret déjà présent selon les preuves précédentes; appel fournisseur antérieur réussi. Proposition de recette existante : gpt-5.6-luna, 10 appels/jour/compte, 20/jour globalement, comptes de recette uniquement. Cette configuration n'est pas encore écrite ni activée.
- Véhicules : Daniel n'a pas à fournir un véhicule personnel. Les chauffeurs inscrivent leurs propres véhicules; l'administration valide leurs capacités réelles. Aucun véhicule fictif ne sera rendu disponible aux vrais clients.
- Publication : déployer les versions serveur/Web compatibles avec les paramètres Maps/FCM de production et un retour arrière. Ne pas publier le build local de validation sans ces paramètres.
- Recette déployée : navigateur, appel callable HTTP, notifications réelles et collecte du moyen de paiement restent à vérifier. Aucun paiement réel autorisé dans les tests locaux.

## Preuves
artifacts/driver-vehicle-rollout-20261015-1648-7b62e3/
Rapport de reprise : CHECKPOINT_CHAUFFEUR_VEHICULE_20261016.md.
Les tests cartographiques autonomes 1.3L restent bloqués/reportés, sans rapport avec ces essais de véhicules.
