# Photo-assisted booking: implementation checkpoint

Date: 2026-10-15. Branch: feature/photo-assisted-booking-20261015.
Base: 197855b77063fdade69193f883a712e89dcdac74. Local changes only; no deployment.

## Approved product direction
Ordinary objects can have unknown dimensions and weight. No invented measurements or automatic heavy/bulky surcharge for null values. Other configured charges remain unchanged. Special objects require targeted details before quote. The server selects the vehicle and calculates the price before the driver accepts or refuses. Vehicles for this new offering are pickup_truck, cargo_van and cube_truck; historical vehicle data is not rewritten.

## Implemented server contract
- Explicit load.intake_mode = photo_assisted. Legacy loads omit the field and preserve their normalization and strict geometric fit.
- Each ordinary photo item requires identification_confirmed = true, special_handling = false and at least one photo path. Unknown values remain null. Categories are the existing object catalog, not invented vehicle types.
- system_config/booking_capacity.photo_intake must be explicitly enabled and versioned. Each object category needs a server-approved category_vehicle_categories mapping. No production mapping or fallback is supplied.
- recommend() checks all items against the configured mapping and uses the existing capacity rank to select a common category. Passenger cars are excluded. Known size/weight, service, equipment and handler incompatibilities remain refusals.
- New BookingSnapshot fields: vehicle_assessment = driver_photo_review and photo_policy_version. This means eligibility for driver review, NOT verified physical fit.
- calculateDeliveryQuote uses the existing server pricing engine and cannot accept a client override of this selected category. No rates, taxes, commissions, money rounding or payment orchestration change.
- findCompatibleVehicle uses the same snapshot eligibility for dispatchMissionToDrivers, bookingJourney, acceptDelivery and adminAssignDelivery. Assignment still reads actual verified vehicle documents within the existing transaction.
- Existing quote integrity includes the new metadata, photo references and normalized load. Changing these invalidates the locked quote; no integrity bypass is added.

## Deployment gate: not ready to activate
config/photo_intake.template.json is a disabled nested configuration template only. It is NOT a replacement for booking_capacity and must not be uploaded as a whole config. Production was not inspected or modified in this intervention.

Before enabling:
1. Implement the client photo intake, explicit object confirmation and special-item questions. Preserve drafts, guest-to-account handoff and unknown values. Existing BookingDraft.load does not yet emit intake_mode.
2. Select and configure an image-analysis provider server-side; budget, privacy and failure behavior still need configuration. No AI API is called or implemented here. AI estimates must remain separate from confirmed measurements; do not feed estimates silently into financial handling flags.
3. Define approved category-to-vehicle mappings and verified capacities using pilot requirements. No category-to-vehicle defaults are invented here.
4. Show driver_photo_review honestly in client and driver summaries; a driver must see the photo and unknown values before accepting. The existing summary is not yet adapted or visually validated for this mode.
5. Validate photo availability and authorized access end to end, not just a syntactically owned path. reviewBooking currently validates ownership by path prefix, not image content/existence.
6. Run isolated quote -> mission -> offer -> acceptance integration tests with this new mode, including cents and ownership checks. Unit tests below do not replace that validation.

Special/unknown objects remain review_required in this first ordinary-object contract. The tailored special-object flow is not implemented. A sofa label is a customer declaration, not proof that image analysis recognized a sofa.

## Evidence and limits
artifacts/photo-assisted-20261015-contract/ contains failing before runs, passing after runs, source backups, test configuration and checkpoint hashes. Latest suite: 115 passed, 0 failed, 0 skipped, seven suites. Tests include real pure booking/pricing/integrity functions and the real repository selection function with mocked Admin database. No emulator, real mission, payment, image recognition, Chrome or physical vehicle was tested.

The Node guard refuses non-loopback destinations and child processes; it is not OS-level confinement. No cartographic transport is involved. Standalone tile test 1.3L remains blocked/deferred.

No existing audit issue is closed by this new feature checkpoint. All historical records are preserved.

## Mise à jour interface — 2026-10-15
Cette section actualise les points 1 et 4 ci-dessus, conservés comme historique du checkpoint serveur.
Le mode photo est maintenant implémenté dans le vrai formulaire Flutter, derrière ENABLE_PHOTO_INTAKE (false par défaut), avec ajout de photo, catégorie confirmée manuellement et dimensions/poids facultatifs pour les objets ordinaires. BookingDraft.load conserve intake_mode. Aucune reconnaissance IA n'est encore branchée.
BookingLoadSummary présente les photos et l'avertissement driver_photo_review dans les consommateurs existants, dont la liste d'offres chauffeur. Une capacité physique n'est jamais déclarée vérifiée sur la seule photo.
150 tests Flutter simulés réussis, zéro échec/ignoré : preuves dans artifacts/photo-assisted-20261015-ui/. Analyse ciblée de dix fichiers sans problème.
Limites restantes : connexion requise avant téléversement; pas encore de photo invitée persistée avant connexion; questionnaire et devis des objets spéciaux incomplets; fournisseur IA et mapping serveur approuvé manquants; accès réel aux photos et parcours devis/mission/offre/acceptation à valider en intégration isolée.
Les tests responsive FR/EN/ES utilisent les vrais widgets et une image locale de test, pas Chrome, pas une reconnaissance d'objet. Aucun build Web ni test appareil physique dans cette intervention.
Aucune activation, aucun commit, push ou déploiement. Les garde-fous serveur et la configuration désactivée restent en place.

## Mise à jour raccordement IA — 2026-10-15
L'adaptateur OpenAI Responses et la callable analyzeBookingPhoto sont désormais implémentés et reliés au bouton du formulaire. Ils produisent des suggestions de catégorie/description, jamais des mesures vérifiées ni un devis. Le résultat exige une action du client et sa confirmation.
Cette mise à jour remplace le constat « aucun code IA » des checkpoints précédents, sans transformer leurs tests en appels réels. Aucun fournisseur n'a été appelé : clé, modèle, quotas approuvés, déploiement de recette et évaluation de reconnaissance restent nécessaires.
Instructions : docs/PHOTO_AI_SETUP.md. Preuves : artifacts/photo-ai-20261015-1705/. Les autres limites (invité, objets spéciaux, mapping véhicule, intégration de bout en bout) demeurent.

## Mise à jour parcours complet — 2026-10-15, 19 h UTC
Cette section remplace les limites d'implémentation devenues obsolètes ci-dessus; les preuves historiques restent conservées.

Implémenté et exécuté localement :
- Objet courant confirmé, photo privée, poids/dimensions inconnus conservés à null; suggestion IA distincte de la confirmation client.
- Objet spécial : dimensions client et consignes de manutention requises avant recommandation serveur; poids inconnu permis. Les mesures approximatives restent signalées comme telles au chauffeur.
- Vérification des références exactes par propriétaire/brouillon/objet/emplacement et des métadonnées Storage avant devis photo. Photo absente, étrangère ou invalide : refus. Aucun nouveau contrôle Storage pour le parcours historique.
- Parcours immédiat et programmé : analyse fictive, devis réel du code serveur, création idempotente, offre, notification interne et sélection du véhicule validé, acceptation avec fournisseur de paiement fictif.
- Refus chauffeur via declineDeliveryOffer : transaction limitée aux offres de ce chauffeur; ne modifie ni mission ni données financières. Interface réelle avec attente, prévention de répétition, erreur et reprise.
- Les données financières simulées prouvent la concordance exacte devis → mission → snapshot → montant en cents transmis au fournisseur fictif. Aucun essai Stripe n'est réalisé.

Preuves : artifacts/photo-journey-20261015-150639-1611abe5/. Dernières séries : 168 tests unitaires serveur, 7 intégrations photo, 21 intégrations refus/assignation/réservation et 86 tests Flutter, tous réussis, aucun ignoré. Les échecs initiaux et le test d'attente mal adapté à une animation sont conservés séparément. Analyse Flutter ciblée : aucun problème. TypeScript noEmit et lint serveur : réussis.

Activation toujours bloquée :
- Lecture seule du 15 octobre : system_config/booking_capacity, booking_policy, service_zones et photo_analysis absents de movik-connect-prod.
- Le compte chauffeur pilote est approuvé/en ligne, mais la requête driver_vehicles par driver_id ne retourne aucun document. Le profil ne fournit pas de lien véhicule ni de capacités; une ancienne approbation vehicle_verified ne constitue pas une fiche de capacité exploitable.
- Il faut fournir les capacités réellement vérifiées, le mapping catégories/véhicules, les seuils de manutention existants approuvés, la zone et les conditions commerciales. Aucune valeur n'a été inventée ou écrite en production.
- L'IA reste désactivée tant que configuration, secret lié à la fonction déployée et quotas ne sont pas activés. Secret et essai fournisseur antérieur ne prouvent pas l'intégration Firebase en production.
- Photos invitées : connexion toujours requise avant téléversement. Auth, Storage réel, notifications Web et essai sur navigateur/téléphone restent à valider.
- Les offres expirent selon le délai existant de 45 secondes. Une relance générale après expiration/refus de tous les chauffeurs n'est pas ajoutée; sa gestion opérationnelle reste à vérifier.
- Le test autonome de tuiles 1.3L demeure bloqué et reporté. Aucun service cartographique n'est appelé ici.

Ne pas déployer un build local dépourvu des paramètres de production Maps/FCM. Ne pas charger les templates désactivés comme une configuration commerciale complète.
Aucun tarif, commission, taxe, ledger, orchestrateur de paiement, règle Firestore/Storage ou correctif GPS n'a été modifié. Aucun commit, push, déploiement ni écriture cloud dans cette intervention.
