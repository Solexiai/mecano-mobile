# Conditions de réservation — intégration en développement

État au 18 octobre 2026 : intégration locale à valider, non déployée. Aucun texte commercial provisoire n'autorise une réservation. Ce document décrit le raccordement technique et les décisions manquantes ; il ne constitue pas les conditions contractuelles de Movi-K.

## Sources examinées et autorité

| Source | Constat | Portée |
|---|---|---|
| docs/CUSTOMER_JOURNEY_DELIVERY.md | Parcours, revue serveur, setup carte, migration require_booking_details | Cadrage technique existant, pas approbation commerciale |
| lib/screens/legal/legal_screen.dart et routes légales existantes | CG/confidentialité présentes mais non versionnées ; page annulation signale des conditions non approuvées | Ne pas convertir ces pages en contrat approuvé par simple copie |
| config/booking_policy.template.json avant intervention | approved=false, version REQUIRES_APPROVAL, textes vides et URL null | Aucun contrat final fourni |
| artifacts/pricing-approved-20261016-1808/CHECKPOINT_GRILLE_APPROUVEE_20261016.md | Grille MOVIK-PILOT-20261016-001 conservée par le propriétaire | Approbation tarifaire, pas approbation des annulations |
| docs/audit/RETRAIT_OPTION_LOURD_20261017.md ; commit 10179e0 | Retrait du supplément lourd approuvé et poussé, non déployé dans la preuve précédente | Décision conservée, aucun supplément réintroduit |
| functions/src/functions/bookingCardSetup.ts | Stripe Checkout mode setup | Comportement technique : préparer la carte ne prélève pas la prestation |
| functions/src/functions/createDeliveryRequest.ts | Crée une demande searching_driver depuis le devis verrouillé | Ni chauffeur assigné ni créneau confirmé au clic final |
| functions/src/functions/acceptDelivery.ts ; functions/src/payment | Autorisation à l'acceptation chauffeur | Cycle implémenté ; sa présentation contractuelle reste à approuver |
| functions/src/functions/completeDelivery.ts ; functions/src/payment | Capture à la fin de mission | Cycle conservé, aucun nouveau délai ni droit déduit |
| docs/PAYMENT_ARCHITECTURE.md | Historique technique financier | Le code exécuté prime pour décrire le comportement actuel |
| artifacts/booking-terms-20261018-1430/current-policy.json | Lecture cloud du 18 octobre à 14:23:39 UTC : booking_policy absent ; quatre flags opérationnels false | Lecture seule réelle ; aucune écriture cloud effectuée |

Aucune version commerciale finale des trois documents n'a été trouvée dans les sources examinées. `schema_version: 2` est une version de format technique, pas une version de conditions approuvées. Un test avec FakePaymentProvider, un test Stripe ou un champ approved=true n'est pas à lui seul une décision du propriétaire.

## Parcours et informations visibles

Au récapitulatif, les montants proviennent toujours du devis officiel existant. La ventilation, les taxes/frais présents dans ce devis et les services/options du booking_snapshot sont réutilisés. Le résumé des objets, manutention, accès et équipements n'est plus replié à cette étape. Aucun montant ni supplément n'est recalculé par la section contractuelle.

La section Conditions de réservation expose directement payment_text et cancellation_text. Leur texte doit être approuvé et complet : ne pas dissimuler les frais, exceptions ou moments décisifs dans les documents dépliés. Les documents intégraux s'ouvrent dans une fenêtre interne, avec version et source. Le brouillon est sauvegardé avant ouverture. Fermer ou utiliser Échap conserve le parcours. Le lien source HTTPS ouvre un autre onglet ; il ne remplace pas l'archive.

La case contractuelle est décochée sur une nouvelle demande. Elle accepte les Conditions de réservation et les Conditions générales. La confidentialité est présentée séparément ; sa présentation n'est jamais enregistrée comme consentement général au traitement. L'option marketing existante reste facultative et séparée.

Le bouton final dit « Confirmer ma demande de livraison ». Son explication précise : envoi au prix affiché, aucun chauffeur ni créneau confirmé, pas de prélèvement à ce clic. L'information sur préparation de carte reste distincte de l'autorisation et du paiement.

Une modification du devis, son renouvellement, la langue de présentation ou une modification des conditions invalide l'acceptation locale. La configuration est relue avant préparation de carte et avant création. Le mécanisme existant d'expiration/renouvellement reste autoritaire ; aucun devis expiré ne crée une mission.

## Contrat serveur et preuve

Le parseur refuse une configuration absente, non approuvée ou incomplète. Champs requis :
- schema_version=2, approved=true, version et approval_reference non vides ;
- payment_cycle égal au cycle implémenté setup_then_authorize_on_acceptance_capture_on_completion ;
- documents.booking, documents.terms et documents.privacy : version, URL HTTPS sans identifiants et contenu intégral ;
- payment_text et cancellation_text ; FR requis, EN/ES facultatifs mais non vides lorsqu'ils sont fournis ;
- taille totale limitée pour permettre l'archivage Firestore.

Le modèle fourni reste volontairement inutilisable : approved=false, setup_enabled=false, URL null, textes vides. Les champs EN/ES vides doivent être complétés ou retirés avant approbation ; un repli FR est identifié dans la lecture du document et sa langue effective est enregistrée. Les liens doivent mener à de véritables documents approuvés : aucun lien fictif n'est installé.

Le serveur calcule contract_hash sur le contenu normalisé, versions, textes visibles et métadonnées. Modifier un texte sans changer son numéro invalide quand même l'ancienne acceptation. La création relit booking_policy dans la même transaction que le devis et la mission, puis contrôle accepted=true, version de politique, hash, versions des deux contrats, version de confidentialité présentée et langue.

Dans delivery_requests/{id}/private/booking sont conservés :
- le contrat intégral original et son hash ;
- consent.accepted, accepted_at (horodatage serveur), accepted_by, versions, locale et langues réellement présentées ;
- privacy_presented_version, distinct d'une acceptation de confidentialité ;
- marketing_preference distincte, sans effet sur l'acceptation contractuelle.

Les règles existantes interdisent l'écriture client de ce document privé. Le montant et les snapshots financiers conservent leur structure ; le contrat est une archive séparée. Les rejeux d'une création déjà réussie renvoient la réservation d'origine sans la réécrire avec les conditions actuelles.

Le nouveau callable getBookingReceipt est authentifié et réservé au propriétaire de la réservation. Il retourne les montants officiels et l'archive historique, jamais la politique active. Les réservations anciennes sans texte intégral archivé affichent explicitement cette limite et seulement les extraits historiques disponibles.

## Récapitulatif conservable

Accessible après création et depuis le suivi à /{locale}/livraison/conditions/{missionId}. Le contrôle serveur reste obligatoire même avec un lien direct.

Le Web télécharge un HTML autonome, échappé, sans scripts ni dépendances externes, imprimable en PDF par le navigateur. Il contient référence, devis, total en CAD et ventilation officielle disponible, adresses, objets/options, date serveur d'acceptation et les trois documents d'origine. Il indique qu'il n'est pas une preuve de paiement. Sur plateforme non Web, le mécanisme disponible copie le texte intégral au presse-papiers ; aucune impression native n'est prétendue.

Le passage entre deux réservations recharge le document correspondant. Un changement de compte ne conserve pas l'archive du compte précédent.

## Décisions à obtenir avant ouverture réelle

| Sujet | Décision ou livrable manquant | Conséquence |
|---|---|---|
| Conditions de réservation | Texte intégral approuvé, numéro de version, URL réelle et référence d'approbation | Confirmation fermée |
| Paiement | Validation commerciale du texte décrivant setup, autorisation à acceptation et capture à fin ; gestion des incidents | Le code existant n'est pas modifié pour inventer une règle |
| Annulation avant assignation | Éligibilité, éventuels frais et sort de la demande à approuver | Aucun tarif/droit choisi par le développeur |
| Annulation après assignation / avant prise en charge | Conditions, frais éventuels, traitement de l'autorisation à approuver | Ne pas annoncer remboursement d'une somme non prélevée |
| Annulation après prise en charge / prestation partielle | Responsabilités, frais, montant éventuellement dû et traitement financier à approuver | Aucun automatisme ajouté |
| Annulation chauffeur / Movi-K, absence, refus, impossibilité | Traitement commercial et information du client à approuver | Pas de promesse générique |
| Après capture | Conditions d'un éventuel remboursement et modalités approuvées | Aucun droit ni délai bancaire inventé |
| Conditions générales | Version approuvée, texte intégral et URL réelle | Les pages statiques existantes ne servent pas de preuve versionnée |
| Confidentialité | Version approuvée du document présenté et URL réelle | Aucune assimilation à un consentement marketing |
| Langues | Textes approuvés FR et, selon offre, EN/ES ou repli explicite accepté | Tests multilingues ne valent pas approbation juridique |

Une libération d'autorisation et un remboursement après capture sont décrits séparément, sans délai bancaire annoncé. Ce document ne se prononce pas sur la conformité juridique des textes à venir.

## Préparation de mise en service, non exécutée

Le changement est préparé sur feature/booking-terms-20261018. Aucune publication n'est autorisée par cette tâche.

Avant une publication autorisée, relire les textes approuvés, vérifier leurs liens et leur cohérence avec le code, puis préparer une publication coordonnée UI/serveur. Ne pas publier seulement la nouvelle interface avec un ancien serveur.

La migration déjà prévue dans docs/CUSTOMER_JOURNEY_DELIVERY.md demeure nécessaire : booking_capacity.require_booking_details=true doit empêcher les nouveaux devis des anciens clients sans booking_snapshot. Le contrôle contractuel renforcé de cette intervention s'applique aux devis du parcours réservation avec booking_snapshot ; il ne prétend pas migrer automatiquement toutes les anciennes API. Ce point doit être vérifié avant toute ouverture des drapeaux. Les réservations historiques restent consultables.

Les prérequis photo/capacité/mapping, la vérification physique des véhicules et les flags opérationnels restent séparés. Aucun seuil physique, paiement, payout, commission, fiscalité ou décision d'ouverture n'a été modifié.

## Validation et limites

Preuves et décompte sans doublons : artifacts/booking-terms-20261018-1430/final-tests.json et CHECKPOINT_CONDITIONS_20261018.md. Tests UI avec services fictifs, intégration réelle des handlers sur émulateurs locaux et fournisseur de paiement fictif. Chrome a rendu/imprimé un récapitulatif synthétique autonome. Cela ne valide ni le nouveau parcours sur movi-k.com, ni Stripe réel/Sandbox, ni un lecteur d'écran physique.

La suite vérifie la sémantique d'accessibilité, Tab/Espace/Échap, FR/EN/ES, mobile/ordinateur et texte à 200 %. Une recette avec NVDA/VoiceOver et un navigateur connecté au serveur nouvellement publié restera nécessaire après autorisation et après approbation des textes.

P1-BOOKING-CONFIG-01 reste ouvert ; 1.3L reste BLOQUÉ ET REPORTÉ. Prochaine action : faire approuver le dossier contractuel (trois documents et matrice paiement/annulation ci-dessus), sans activer la réservation.
