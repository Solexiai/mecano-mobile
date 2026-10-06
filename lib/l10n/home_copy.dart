/// Public-home copy only. No availability counts, invented prices or promises.
/// Keep all three locales together; category names remain in AppStrings.
abstract final class HomeCopy {
  static const strings = <String, Map<String, String>>{
    'eyebrow': {
      'fr': 'Livraison de meubles et d’objets volumineux',
      'en': 'Furniture and large-item delivery',
      'es': 'Entrega de muebles y objetos voluminosos',
    },
    'title': {
      'fr': 'Faites livrer ce qui ne rentre pas dans votre véhicule.',
      'en': 'Have it delivered when it won’t fit in your vehicle.',
      'es': 'Recibe lo que no cabe en tu vehículo.',
    },
    'intro': {
      'fr':
          'Meubles, électroménagers, boîtes, achats Marketplace et petits déménagements : décrivez votre projet et votre trajet pour préparer un devis.',
      'en':
          'Furniture, appliances, boxes, Marketplace purchases and small moves: describe your project and route to prepare a quote.',
      'es':
          'Muebles, electrodomésticos, cajas, compras de Marketplace y pequeñas mudanzas: describe tu proyecto y el trayecto para preparar un presupuesto.',
    },
    'quote': {
      'fr': 'Obtenir mon devis',
      'en': 'Get my quote',
      'es': 'Obtener presupuesto',
    },
    'quote_note': {
      'fr':
          'Préparez votre demande sans compte. Une connexion est requise seulement pour calculer le devis officiel.',
      'en':
          'Prepare your request without an account. Sign-in is required only when requesting the official quote.',
      'es':
          'Prepara tu solicitud sin cuenta. Solo debes iniciar sesión al solicitar el presupuesto oficial.',
    },
    'pilot': {
      'fr': 'Version pilote · disponibilité à confirmer dans votre secteur',
      'en': 'Pilot version · availability in your area must be confirmed',
      'es': 'Versión piloto · disponibilidad por confirmar en tu zona',
    },
    'driver_link': {
      'fr': 'Vous avez un véhicule ? Devenir chauffeur',
      'en': 'Have a vehicle? Become a driver',
      'es': '¿Tienes un vehículo? Conviértete en conductor',
    },
    'categories_title': {
      'fr': 'Que souhaitez-vous faire livrer ?',
      'en': 'What would you like delivered?',
      'es': '¿Qué quieres transportar?',
    },
    'categories_body': {
      'fr':
          'Choisissez une catégorie : elle sera déjà sélectionnée dans votre demande.',
      'en': 'Choose a category and it will be preselected in your request.',
      'es': 'Elige una categoría y aparecerá seleccionada en tu solicitud.',
    },
    'category_hint': {
      'fr': 'Commencer avec cette catégorie',
      'en': 'Start with this category',
      'es': 'Empezar con esta categoría',
    },
    'item_note': {
      'fr':
          'Renseignez les mesures de chaque objet emballé, le poids et les accès. Une mesure inconnue ou approximative nécessite une vérification avant le devis.',
      'en':
          'Enter measurements for each packaged item, weight and access details. Unknown or approximate measurements require a review before the quote.',
      'es':
          'Indica las medidas de cada objeto embalado, el peso y los accesos. Las medidas desconocidas o aproximadas requieren revisión antes del presupuesto.',
    },
    'steps_title': {
      'fr': 'De votre demande à la livraison',
      'en': 'From request to delivery',
      'es': 'De la solicitud a la entrega',
    },
    'step1': {
      'fr': 'Décrivez l’objet et le trajet',
      'en': 'Describe the item and route',
      'es': 'Describe el objeto y el trayecto',
    },
    'step1_body': {
      'fr':
          'Précisez les objets, leurs mesures, les adresses, les accès et la date souhaitée.',
      'en':
          'Provide items, measurements, addresses, access details and your preferred date.',
      'es':
          'Indica los objetos, las medidas, las direcciones, los accesos y la fecha deseada.',
    },
    'step2': {
      'fr': 'Consultez votre devis',
      'en': 'Review your quote',
      'es': 'Consulta el presupuesto',
    },
    'step2_body': {
      'fr':
          'Vérifiez le prix et les informations avant de confirmer la demande.',
      'en': 'Check the price and details before confirming your request.',
      'es': 'Revisa el precio y los datos antes de confirmar la solicitud.',
    },
    'step3': {
      'fr': 'Un chauffeur accepte',
      'en': 'A driver accepts',
      'es': 'Un conductor acepta',
    },
    'step3_body': {
      'fr': 'L’attribution dépend d’un chauffeur admissible et disponible.',
      'en': 'Assignment depends on an eligible, available driver.',
      'es': 'La asignación depende de un conductor apto y disponible.',
    },
    'step4': {
      'fr': 'Suivez votre livraison',
      'en': 'Follow your delivery',
      'es': 'Sigue tu entrega',
    },
    'step4_body': {
      'fr':
          'Consultez son état dans votre espace, puis la preuve de livraison.',
      'en': 'Check its status in your account, then view the delivery proof.',
      'es':
          'Consulta el estado en tu cuenta y después el comprobante de entrega.',
    },
    'details': {
      'fr': 'Comprendre les étapes',
      'en': 'See how it works',
      'es': 'Ver cómo funciona',
    },
    'trust_title': {
      'fr': 'Les informations utiles, au bon moment',
      'en': 'Useful details, when you need them',
      'es': 'La información útil, cuando la necesitas',
    },
    'trust1': {
      'fr': 'Un devis avant de décider',
      'en': 'A quote before you decide',
      'es': 'Un presupuesto antes de decidir',
    },
    'trust1_body': {
      'fr':
          'Le trajet, le véhicule et les options renseignées servent au calcul. Vérifiez la ventilation avant confirmation.',
      'en':
          'The route, vehicle and selected options inform the calculation. Review the breakdown before confirming.',
      'es':
          'El trayecto, el vehículo y las opciones indicadas sirven para el cálculo. Revisa el desglose antes de confirmar.',
    },
    'trust2': {
      'fr': 'Un dossier chauffeur à approuver',
      'en': 'Driver approval is required',
      'es': 'El conductor requiere aprobación',
    },
    'trust2_body': {
      'fr':
          'L’inscription chauffeur comprend un profil, un véhicule et des documents à soumettre à l’approbation.',
      'en':
          'Driver registration includes a profile, vehicle and documents submitted for approval.',
      'es':
          'El registro del conductor incluye un perfil, un vehículo y documentos sujetos a aprobación.',
    },
    'trust3': {
      'fr': 'Un suivi dans votre espace',
      'en': 'Status updates in your account',
      'es': 'Seguimiento en tu cuenta',
    },
    'trust3_body': {
      'fr':
          'Retrouvez la mission et sa progression, puis la photo de preuve une fois la livraison terminée.',
      'en':
          'Find your mission and its progress, then the proof photo once delivery is completed.',
      'es':
          'Consulta la misión y su avance, y después la foto de prueba al terminar la entrega.',
    },
    'coverage_title': {
      'fr': 'Et dans votre secteur ?',
      'en': 'What about your area?',
      'es': '¿Y en tu zona?',
    },
    'coverage_body': {
      'fr':
          'La prise en charge dépend des chauffeurs disponibles, de leur rayon d’action et du véhicule requis. Une demande ou un devis ne garantit pas encore un chauffeur.',
      'en':
          'Pickup depends on available drivers, their service areas and the required vehicle. A request or quote does not yet guarantee a driver.',
      'es':
          'La recogida depende de los conductores disponibles, su radio de servicio y el vehículo necesario. Una solicitud o presupuesto aún no garantiza un conductor.',
    },
    'faq_title': {
      'fr': 'Avant de faire votre demande',
      'en': 'Before you request a delivery',
      'es': 'Antes de solicitar una entrega',
    },
    'faq_price': {
      'fr': 'Comment connaître le prix ?',
      'en': 'How do I find out the price?',
      'es': '¿Cómo puedo saber el precio?',
    },
    'faq_price_body': {
      'fr':
          'Commencez sans compte : décrivez vos objets et leurs mesures, les adresses et l’aide nécessaire. Movi‑K vérifie les véhicules compatibles. La connexion est demandée pour le devis officiel, présenté avant confirmation.',
      'en':
          'Start without an account: describe your items and measurements, addresses and required help. Movi‑K checks compatible vehicles. Sign-in is required for the official quote, shown before confirmation.',
      'es':
          'Empieza sin cuenta: describe los objetos y sus medidas, las direcciones y la ayuda necesaria. Movi‑K verifica vehículos compatibles. Debes iniciar sesión para el presupuesto oficial, presentado antes de confirmar.',
    },
    'faq_help': {
      'fr': 'Qui aide à charger et à décharger ?',
      'en': 'Who helps with loading and unloading?',
      'es': '¿Quién ayuda a cargar y descargar?',
    },
    'faq_help_body': {
      'fr':
          'Précisez l’aide nécessaire, les étages, les escaliers et les contraintes d’accès dans votre demande. Ne présumez pas qu’une manutention particulière est incluse sans l’avoir indiquée.',
      'en':
          'Specify the help needed, floors, stairs and access constraints in your request. Do not assume special handling is included unless you have specified it.',
      'es':
          'Indica la ayuda necesaria, los pisos, las escaleras y las limitaciones de acceso. No supongas que se incluye una manipulación especial sin indicarla.',
    },
    'faq_available': {
      'fr': 'Et si aucun chauffeur n’est disponible ?',
      'en': 'What if no driver is available?',
      'es': '¿Y si no hay conductores disponibles?',
    },
    'faq_available_body': {
      'fr':
          'La demande peut rester en recherche. Consultez son état dans votre espace. La date et l’heure souhaitées dépendent de l’acceptation et de la disponibilité d’un chauffeur; elles ne constituent pas un créneau confirmé.',
      'en':
          'Your request may remain in search. Check its status in your account. Your preferred date and time depend on driver acceptance and availability; they are not a confirmed slot.',
      'es':
          'La solicitud puede seguir buscando conductor. Consulta su estado en tu cuenta. La fecha y hora deseadas dependen de la aceptación y disponibilidad del conductor; no son un horario confirmado.',
    },
    'faq_cancel': {
      'fr': 'Comment annuler ou obtenir de l’aide ?',
      'en': 'How do I cancel or get help?',
      'es': '¿Cómo puedo cancelar o pedir ayuda?',
    },
    'faq_cancel_body': {
      'fr':
          'Consultez les conditions d’annulation et la page Contact. Les modalités dépendent de l’état de la mission. Le canal de contact est encore en préparation pour le pilote.',
      'en':
          'Review the cancellation policy and Contact page. Terms depend on the mission status. The contact channel is still being prepared for the pilot.',
      'es':
          'Consulta la política de cancelación y la página de Contacto. Las condiciones dependen del estado de la misión. El canal de contacto sigue en preparación para la prueba piloto.',
    },
    'driver_title': {
      'fr': 'Votre véhicule peut rendre service.',
      'en': 'Put your vehicle to good use.',
      'es': 'Tu vehículo puede ser útil.',
    },
    'driver_body': {
      'fr':
          'Découvrez le parcours chauffeur, les documents demandés et les étapes d’approbation.',
      'en':
          'Explore driver registration, required documents and approval steps.',
      'es':
          'Descubre el registro de conductores, los documentos necesarios y las etapas de aprobación.',
    },
    'driver_cta': {
      'fr': 'Découvrir le parcours chauffeur',
      'en': 'Explore becoming a driver',
      'es': 'Descubrir cómo ser conductor',
    },
    'final_title': {
      'fr': 'Un objet à faire livrer ?',
      'en': 'Have something to deliver?',
      'es': '¿Tienes algo que transportar?',
    },
    'final_body': {
      'fr': 'Décrivez votre livraison et consultez votre devis.',
      'en': 'Describe your delivery and review your quote.',
      'es': 'Describe la entrega y consulta el presupuesto.',
    },
    'account': {'fr': 'Mon espace', 'en': 'My account', 'es': 'Mi cuenta'},
    'resume': {
      'fr': 'Reprendre ma demande',
      'en': 'Continue my request',
      'es': 'Continuar mi solicitud',
    },
    'footer_service': {'fr': 'Livraison', 'en': 'Delivery', 'es': 'Entrega'},
    'footer_drivers': {
      'fr': 'Chauffeurs',
      'en': 'Drivers',
      'es': 'Conductores',
    },
    'footer_help': {
      'fr': 'Aide et informations',
      'en': 'Help and information',
      'es': 'Ayuda e información',
    },
    'home_link': {
      'fr': 'Movi‑K — accueil',
      'en': 'Movi‑K — home',
      'es': 'Movi‑K — inicio',
    },
    'granby_launch': {
      'fr': 'Lancement à Granby et dans les environs',
      'en': 'Launching in Granby and surrounding areas',
      'es': 'Lanzamiento en Granby y alrededores',
    },
    'prelaunch_status': {
      'fr': 'Pré-lancement · disponibilité à confirmer avant toute livraison',
      'en': 'Pre-launch · availability must be confirmed before any delivery',
      'es':
          'Prelanzamiento · la disponibilidad debe confirmarse antes de cualquier entrega',
    },
    'quote_card_title': {
      'fr': 'Préparez votre demande de devis',
      'en': 'Prepare your quote request',
      'es': 'Prepara tu solicitud de presupuesto',
    },
    'quote_card_1': {
      'fr': 'Décrivez ce que vous voulez faire livrer',
      'en': 'Describe what you need delivered',
      'es': 'Describe lo que quieres transportar',
    },
    'quote_card_2': {
      'fr': 'Indiquez les adresses de départ et d’arrivée',
      'en': 'Enter pickup and delivery addresses',
      'es': 'Indica las direcciones de recogida y entrega',
    },
    'quote_card_3': {
      'fr': 'Un chauffeur admissible peut accepter votre demande',
      'en': 'An eligible driver may accept your request',
      'es': 'Un conductor elegible puede aceptar tu solicitud',
    },
    'quote_start': {
      'fr': 'Commencer ma demande',
      'en': 'Start my request',
      'es': 'Empezar mi solicitud',
    },
    'marketplace_examples': {
      'fr': 'Facebook Marketplace, Kijiji, etc.',
      'en': 'Facebook Marketplace, Kijiji, etc.',
      'es': 'Facebook Marketplace, Kijiji, etc.',
    },
    'reassurance_quote': {
      'fr': 'Devis transparent',
      'en': 'Transparent quote',
      'es': 'Presupuesto transparente',
    },
    'reassurance_quote_body': {
      'fr': 'Prix et ventilation avant confirmation',
      'en': 'Price and breakdown before confirmation',
      'es': 'Precio y desglose antes de confirmar',
    },
    'reassurance_tracking': {
      'fr': 'Suivi dans votre espace',
      'en': 'Tracking in your account',
      'es': 'Seguimiento en tu cuenta',
    },
    'reassurance_tracking_body': {
      'fr': 'Consultez la progression de la mission',
      'en': 'Check your mission progress',
      'es': 'Consulta el progreso de la misión',
    },
    'reassurance_local': {
      'fr': 'Un service près de chez vous',
      'en': 'A local service near you',
      'es': 'Un servicio cerca de ti',
    },
    'reassurance_local_body': {
      'fr': 'Lancement à Granby et dans les environs',
      'en': 'Launching in Granby and surrounding areas',
      'es': 'Lanzamiento en Granby y alrededores',
    },
    'local_cta_title': {
      'fr': 'Movi‑K arrive à Granby.',
      'en': 'Movi‑K is coming to Granby.',
      'es': 'Movi‑K llega a Granby.',
    },
    'local_cta_body': {
      'fr':
          'Préparez votre demande; la disponibilité d’un chauffeur sera confirmée au moment du lancement.',
      'en':
          'Prepare your request; driver availability will be confirmed when service launches.',
      'es':
          'Prepara tu solicitud; la disponibilidad de un conductor se confirmará cuando se lance el servicio.',
    },
  };
  static String text(String key, String locale) =>
      strings[key]?[locale] ?? strings[key]?['fr'] ?? key;
}
