# Movi-K — Raccordement IA photo
Date : 2026-10-15. Branche feature/photo-assisted-booking-20261015, base 197855b77063fdade69193f883a712e89dcdac74.
État actuel au 16 octobre 2026 : service réel publié et contrôlé dans Chrome. Les préparations et limites historiques ci-dessous sont conservées; voir les mises à jour datées en fin de document.

## Parcours implémenté
Le client connecté téléverse sa photo dans le stockage privé existant. Le bouton « Analyser la photo » précise qu'elle sera transmise à OpenAI. La callable analyzeBookingPhoto vérifie le propriétaire, le brouillon actif, l'objet, la référence exacte de photo, le consentement, le format JPEG et la limite de 5 Mo.
La réponse propose une catégorie du catalogue existant, une description courte et le signalement d'un objet spécial/incertain. Le client peut appliquer la suggestion, la corriger puis confirmer l'objet. Les poids/dimensions inconnus restent inconnus, les valeurs déjà saisies restent inchangées.
Une suggestion n'autorise aucun devis, véhicule, paiement ou mission. Aucun montant n'est calculé par l'IA.
L'IA ne reçoit ni compte client, ni adresse du formulaire, ni coordonnées, ni montant; uniquement la photo et une instruction fixe avec la langue. Une photo peut néanmoins contenir des données visibles en arrière-plan.

## Configuration à fournir avant essai réel
1. Une clé API OpenAI propre au projet, avec accès au modèle retenu et facturation contrôlée, doit être ajoutée dans Secret Manager sous OPENAI_API_KEY. La fonction déclare ce secret côté serveur. Ne jamais la coller dans le clavardage, le code, un journal, un dart-define ou le navigateur.
2. Choisir un modèle actuellement disponible dans le compte, compatible images + Responses + Structured Outputs. Aucun modèle par défaut n'est inventé; une configuration vide reste désactivée. Vérifier son coût et sa qualité sur le jeu de photos du pilote, ainsi que le budget de sortie de 700 tokens et le délai de 25 secondes; les réponses incomplètes sont refusées.
3. Préparer system_config/photo_analysis à partir de config/photo_analysis.template.json. Fournir provider=openai, model, allowedUserUids (comptes de recette seulement), userDailyLimit et globalDailyLimit. Le modèle livré a enabled=false et des plafonds à zéro : il ne doit pas être activé tel quel.
4. Faire approuver les plafonds quotidiens d'appels et le budget fournisseur. Ce compteur d'appels n'est pas un plafond monétaire chez OpenAI. Les tentatives échouées consomment aussi une unité. Plafonds techniques maximaux acceptés par le code : 100 par utilisateur et 10000 globalement; ce ne sont pas des recommandations commerciales.
5. Déployer explicitement en recette non productive la fonction analyzeBookingPhoto et préparer une interface de recette ENABLE_PHOTO_INTAKE=true. Aucun de ces déploiements n'a été effectué.
6. Tester des photos fictives/consenties : sofa, réfrigérateur, boîtes, matériaux, piano, photo ambiguë, objets multiples; vérifier les refus, les données privées, les reprises et la pertinence des catégories. Tester aussi Firestore/Storage/App Auth ensemble et les quotas réels. Le présent checkpoint ne prouve pas ces intégrations.
7. Vérifier les conditions de confidentialité du fournisseur et l'information au client avant ouverture. store=false est envoyé; il ne constitue pas une garantie générale de rétention zéro.
8. L'ouverture du devis photo nécessite séparément le mapping approuvé de config/photo_intake.template.json, les capacités vérifiées et le parcours spécial encore incomplet. Activer l'analyse seule ne rend pas tout le parcours commercial prêt.

## Protections
- URL OpenAI fixe, redirections refusées, aucun téléchargement d'URL fournie par le client.
- Photo privée téléchargée par génération Storage immuable, taille/métadonnées/signature vérifiées; pas de lien public créé.
- Réponse JSON strictement validée et limitée au catalogue. Champs supplémentaires, refus et réponses incomplètes rejetés.
- Instructions dans les images considérées comme données non fiables. Aucun outil ou action métier n'est exposé au modèle.
- Limites utilisateur/globales réservées dans une transaction, un seul appel actif par utilisateur, bail de 90 secondes, libération conditionnée au jeton du propriétaire.
- Auth et liste de comptes autorisés; system_config existant interdit les écritures clientes. La nouvelle collection de compteurs est refusée aux clients par les règles existantes.
- Erreur neutre, aucune exception fournisseur brute, aucun retry automatique.
- Réponse ignorée après changement du compte, brouillon, langue, photo ou contenu de l'objet.
- Transport réel interdit depuis les émulateurs/demo et tests; les tests injectent un transport fictif. Un essai fournisseur réel doit se faire dans une recette explicitement autorisée.
- Désactivation : enabled=false côté configuration arrête les nouveaux appels. Aucun effet rétroactif sur les appels déjà partis; couper aussi le flag UI lors d'un retour arrière.

## Sources consultées le 15 octobre 2026
- OpenAI, images dans Responses : https://developers.openai.com/api/docs/guides/images-vision
- OpenAI, sorties structurées et refus : https://developers.openai.com/api/docs/guides/structured-outputs?api-mode=responses
- Code et journaux locaux : artifacts/photo-ai-20261015-1705/.
Aucun accès au compte fournisseur ou à sa facturation n'a été vérifié. Aucun appel IA payant, aucune modification de production, aucun commit/push/déploiement dans cette intervention.

## Préparation Web — 15 octobre 2026, après l'essai réel
Le premier appel réel avec gpt-5.6-luna est réussi sur une image de fauteuil du dépôt : voir artifacts/photo-ai-live-20261015-144359-b70008/CHECKPOINT.md. Cela ne valide pas encore les vraies photos ni le parcours Firebase intégré.

Le script scripts/vercel_build.sh accepte maintenant ENABLE_PHOTO_INTAKE=true|false. Valeur par défaut : false ; toute autre valeur arrête la compilation. Il transmet explicitement la valeur à Flutter. Cette variable ne contient aucun secret.
Tests permanents : node --test test/scripts/photo_preview_build_flag_test.cjs (utilise un exécutable Flutter fictif dans un dossier temporaire, sans téléchargement).
Un build avec ce flag affiche l'entrée photo ; il ne suffit pas à autoriser le serveur. La liste allowedUserUids et la configuration Firebase sont indispensables.

Configuration privée proposée (pas écrite dans Firestore) : provider=openai, model=gpt-5.6-luna, 10 appels/jour/compte, 20 appels/jour globalement, enabled=false jusqu'à identification du compte de recette et décision d'activation.
La clé existe dans Secret Manager, version 1. Ne jamais l'insérer dans un dart-define ni une variable Web.
Le budget d'intervention de 5 USD n'est pas un plafond fournisseur configuré. Les quotas quotidiens ne garantissent pas un plafond monétaire total.
L'activation de l'analyse ne valide pas le devis photo, le mapping catégories/véhicules ou le parcours spécial.

## Mise à jour intégration — 15 octobre 2026, parcours photo → prix → chauffeur
Le questionnaire spécial et la chaîne de réservation/acceptation sont maintenant implémentés et testés avec Firestore Emulator et fournisseurs fictifs. Voir docs/PHOTO_ASSISTED_BOOKING.md et artifacts/photo-journey-20261015-150639-1611abe5/.
Cela remplace la limite de code « parcours spécial incomplet », mais pas les prérequis de mise en ligne.
La lecture seule de production a constaté l'absence des quatre documents system_config/booking_capacity, booking_policy, service_zones et photo_analysis. Aucun de ces documents n'a été créé. Les capacités du véhicule et les conditions du pilote doivent être renseignées et approuvées avant activation commerciale.
Le compte client de recette a été identifié lors de la préparation précédente; aucune adresse électronique ni clé API n'est nécessaire dans un build Web. Ne pas copier les identifiants ou fixtures des tests dans la production.


## Publication effective — 16 octobre 2026
- analyzeBookingPhoto est déployée en us-central1 sur movik-connect-prod, liée à OPENAI_API_KEY version 1. Le secret reste exclusivement côté serveur.
- system_config/photo_analysis: enabled=true, allowAuthenticatedUsers=true, provider=openai, model=gpt-5.6-luna, 10 tentatives par compte/jour UTC et 100 tentatives globales/jour UTC. Les tentatives en échec consomment le quota. Ces limites ne constituent pas un plafond monétaire fournisseur.
- allowedUserUids reste le mécanisme de recette lorsque allowAuthenticatedUsers=false. Une liste vide ne permet pas implicitement l'accès public.
- Un compte client temporaire sans privilèges a réellement téléversé un JPEG privé et reçu une suggestion « fauteuil » via la fonction publiée. Refus UNAUTHENTICATED vérifié; compte, photo et brouillon de cet essai nettoyés. Pas de mission ni de paiement.
- La version Web photo a été compilée avec la clé Maps publique déjà configurée sur Vercel, puis publiée sous dpl_HL6SUteTr7ySAEK2TLRsVU5NZu3D. movi-k.com et www.movi-k.com servent le bundle SHA256 0b7cdab8e8203b437ded736a53d29c470865056e892b3dfb3e2ef094fe6401b6.
- ENABLE_PHOTO_INTAKE=true est aussi enregistré dans l'environnement Vercel Production pour les prochaines compilations utilisant scripts/vercel_build.sh.
- Contact approuvé par Daniel: info@movi-k.com, affiché avec un lien mailto. Aucune réception de courriel vérifiée.
- Réservations, paiements, capacités réelles et conditions du pilote restent des prérequis distincts. L'ouverture de l'analyse ne prouve pas l'ouverture des ventes.
- Le test cartographique autonome 1.3L reste reporté; aucune validation GPS terrain ajoutée.

Preuves: artifacts/ai-rollout-20261016-0940/. Les essais navigateur locaux et leurs éventuels échecs restent distincts de la preuve réelle du callable et du contrôle du bundle publié.

Retour arrière: mettre uniquement system_config/photo_analysis.enabled=false pour arrêter les nouveaux appels; les appels déjà partis ne sont pas annulés. Pour le site, promouvoir l'ancien déploiement dpl_2HjAYKYcSdMfNzUEVjJtk4wR6mFY (https://mecano-mobile-henz9i8nn-solexis-projects-4c019079.vercel.app) dans le même projet. Sauvegardes de configuration et règles dans le dossier de preuves. Ne pas supprimer une clé utilisée par une autre fonction.
Avertissement de déploiement: Node 20 annoncé en fin de déploiement supporté au 30 octobre 2026 par Firebase CLI; migration à planifier séparément. Aucune mise à jour de dépendances effectuée ici.


## Vérification finale navigateur — 16 octobre 2026, 14:10 UTC
Après un retour temporaire à l'ancien site pour diagnostic, la version dpl_HL6SUteTr7ySAEK2TLRsVU5NZu3D a été remise en production. Le test Chrome public final confirme connexion → JPEG privé et aperçu → analyse IA réelle → suggestion fauteuil → application → sauvegarde de armchair/fauteuil, sans dimensions ni poids inventés. Aucune erreur dans cette exécution finale; compte, photo et brouillon de test nettoyés. Les essais antérieurs échoués sont conservés et expliqués, pas requalifiés comme réussis. Contact examiné sur le site, mailto correct; réception non testée.
Preuve définitive : artifacts/ai-rollout-20261016-0940/CHECKPOINT_RACCORDEMENT_IA_SITE_20261016.md et browser-public-final-result.json. Les ventes ne sont pas ouvertes par cette activation IA.


## Photos plus grandes et formulaire compact — 16 octobre 2026
État actuel : publié sur movi-k.com, dpl_2wFirDS82DMkdJZtEqfkaFKDqB5L. Preuve : artifacts/photo-simple-20261016-1030/CHECKPOINT_PHOTOS_FORMULAIRE_20261016.md.
Le Web accepte JPEG/PNG/WebP jusqu’à 20 MiB et prépare localement un JPEG ≤5 MiB, côté long ≤1600 px; garde de 48 millions de pixels. La limite privée Storage/serveur reste 5 MiB. HEIC non pris en charge directement. Trois photos par objet conservées.
photo-identification-v2 ajoute size_estimate nullable : fourchettes entières en cm, base typical_object/visible_reference, confiance low/medium. Une taille typique n’est pas une mesure. Les valeurs réelles length/width/height/weight et la tarification ne sont jamais alimentées par cette suggestion. Le brouillon conserve photo_size_hint séparément et le rejette si photo/catégorie/description changent. Aucune transmission de ces fourchettes au snapshot financier ou au dossier chauffeur revendiquée ici.
Budget de sortie de l’adaptateur : 1200 tokens (remplace les 700 historiques), délai 25 secondes, modèle et quotas inchangés. Incertitude ou objet inadapté : estimation absente. Aucune estimation de poids ajoutée.
Catalogue manuel, détails d’objet, accès aux lieux et aide/équipement repliables; valeurs et validations préexistantes conservées. Rendu FR/EN/ES et texte 200 % dans les tests widget.
79 tests Flutter et 83 TypeScript réussis, analyse/format/build/lint/diff check réussis. Chrome réel : PNG de 10 371 067 octets converti en JPEG privé de 226 711 octets; IA HTTP 200, fauteuil reconnu, fourchettes indicatives sauvegardées séparément, mesures réelles null. Compte/données temporaires nettoyés; aucun devis, mission ni paiement réels.
Les essais de harnais antérieurs restent documentés, non comptés comme réussis. Ventes et capacités véhicules restent distinctes. Retour arrière Web : dpl_HL6SUteTr7ySAEK2TLRsVU5NZu3D. Aucun secret, règle financière ou configuration commerciale modifié.
