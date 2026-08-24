/// Movi-k translation dictionary — French (default), English, Spanish.
/// Structured as a flat key -> {locale: value} map to keep all UI text
/// centralized and avoid hardcoded mixed-language strings in widgets.
class AppStrings {
  AppStrings._();

  static const Map<String, Map<String, String>> _t = {
    // ---------- App ----------
    'app_name': {'fr': 'Movi-k', 'en': 'Movi-k', 'es': 'Movi-k'},
    'tagline': {
      'fr': 'Livrer. Réparer. Là où vous êtes.',
      'en': 'Move it. Fix it. Wherever you are.',
      'es': 'Mover. Reparar. Donde estés.',
    },
    // ---------- Nav ----------
    'nav_home': {'fr': 'Accueil', 'en': 'Home', 'es': 'Inicio'},
    'nav_delivery': {'fr': 'Livraison', 'en': 'Delivery', 'es': 'Entrega'},
    'nav_mechanic': {
      'fr': 'Mécanicien mobile',
      'en': 'Mobile Mechanic',
      'es': 'Mecánico móvil',
    },
    'nav_become_provider': {
      'fr': 'Devenir fournisseur',
      'en': 'Become a Provider',
      'es': 'Convertirse en proveedor',
    },
    'nav_become_driver': {
      'fr': 'Devenir chauffeur',
      'en': 'Become a Driver',
      'es': 'Convertirse en conductor',
    },
    'nav_become_mechanic': {
      'fr': 'Devenir mécanicien',
      'en': 'Become a Mobile Mechanic',
      'es': 'Convertirse en mecánico',
    },
    'nav_pricing': {'fr': 'Tarifs', 'en': 'Pricing', 'es': 'Precios'},
    'nav_safety': {'fr': 'Sécurité', 'en': 'Safety', 'es': 'Seguridad'},
    'nav_faq': {'fr': 'FAQ', 'en': 'FAQ', 'es': 'Preguntas'},
    'nav_about': {'fr': 'À propos', 'en': 'About', 'es': 'Acerca de'},
    'nav_contact': {'fr': 'Contact', 'en': 'Contact', 'es': 'Contacto'},
    'nav_how_it_works': {
      'fr': 'Comment ça marche',
      'en': 'How it works',
      'es': 'Cómo funciona',
    },
    'nav_sign_in': {'fr': 'Connexion', 'en': 'Sign In', 'es': 'Iniciar sesión'},
    'nav_get_started': {
      'fr': 'Commencer',
      'en': 'Get Started',
      'es': 'Comenzar',
    },
    'nav_dashboard': {
      'fr': 'Tableau de bord',
      'en': 'Dashboard',
      'es': 'Panel',
    },
    'nav_my_requests': {
      'fr': 'Mes demandes',
      'en': 'My Requests',
      'es': 'Mis solicitudes',
    },
    'nav_my_bookings': {
      'fr': 'Mes réservations',
      'en': 'My Bookings',
      'es': 'Mis reservas',
    },
    'nav_messages': {'fr': 'Messages', 'en': 'Messages', 'es': 'Mensajes'},
    'nav_saved_addresses': {
      'fr': 'Adresses enregistrées',
      'en': 'Saved Addresses',
      'es': 'Direcciones guardadas',
    },
    'nav_favourites': {'fr': 'Favoris', 'en': 'Favourites', 'es': 'Favoritos'},
    'nav_profile': {'fr': 'Profil', 'en': 'Profile', 'es': 'Perfil'},
    'nav_settings': {
      'fr': 'Paramètres',
      'en': 'Settings',
      'es': 'Configuración',
    },
    'nav_logout': {'fr': 'Déconnexion', 'en': 'Logout', 'es': 'Cerrar sesión'},
    'nav_available_jobs': {
      'fr': 'Demandes disponibles',
      'en': 'Available Jobs',
      'es': 'Trabajos disponibles',
    },
    'nav_calendar': {'fr': 'Calendrier', 'en': 'Calendar', 'es': 'Calendario'},
    'nav_my_services': {
      'fr': 'Mes services',
      'en': 'My Services',
      'es': 'Mis servicios',
    },
    'nav_my_vehicle': {
      'fr': 'Mon véhicule',
      'en': 'My Vehicle',
      'es': 'Mi vehículo',
    },
    'nav_service_area': {
      'fr': 'Zone de service',
      'en': 'Service Area',
      'es': 'Área de servicio',
    },
    'nav_earnings': {'fr': 'Revenus', 'en': 'Earnings', 'es': 'Ganancias'},
    'nav_reviews': {'fr': 'Avis', 'en': 'Reviews', 'es': 'Reseñas'},
    'nav_documents': {'fr': 'Documents', 'en': 'Documents', 'es': 'Documentos'},
    'nav_admin': {
      'fr': 'Administration',
      'en': 'Admin',
      'es': 'Administración',
    },

    // ---------- Home ----------
    'home_hero_headline': {
      'fr': 'Livrer. Réparer. Là où vous êtes.',
      'en': 'Move it. Fix it. Wherever you are.',
      'es': 'Mover. Reparar. Donde estés.',
    },
    'home_hero_subheadline': {
      'fr':
          'Faites livrer un gros objet ou faites venir un mécanicien directement à votre véhicule.',
      'en':
          'Book a trusted local driver for a large delivery or have a mobile mechanic come directly to your vehicle.',
      'es':
          'Reserva un conductor local de confianza para una entrega grande o haz que un mecánico móvil venga directamente a tu vehículo.',
    },
    'home_cta_need_service': {
      'fr': "J'ai besoin d'un service",
      'en': 'I need a service',
      'es': 'Necesito un servicio',
    },
    'home_cta_offer_service': {
      'fr': 'Je veux offrir mes services',
      'en': 'I want to offer my services',
      'es': 'Quiero ofrecer mis servicios',
    },

    'home_card_delivery_title': {
      'fr': "J'ai besoin d'une livraison",
      'en': 'I need a delivery',
      'es': 'Necesito una entrega',
    },
    'home_card_delivery_desc': {
      'fr':
          "Avez-vous acheté quelque chose qui ne rentre pas dans votre véhicule? Trouvez un chauffeur local de confiance avec le bon véhicule.",
      'en':
          'Bought something that does not fit in your vehicle? Find a trusted local driver with the right vehicle.',
      'es':
          '¿Compraste algo que no cabe en tu vehículo? Encuentra un conductor local de confianza con el vehículo adecuado.',
    },
    'home_card_delivery_cta': {
      'fr': 'Trouver un chauffeur',
      'en': 'Find a Driver',
      'es': 'Encontrar un conductor',
    },
    'home_card_delivery_cta2': {
      'fr': 'Devenir chauffeur',
      'en': 'Become a Driver',
      'es': 'Convertirse en conductor',
    },

    'home_card_mechanic_title': {
      'fr': "J'ai besoin d'un mécanicien mobile",
      'en': 'I need a mobile mechanic',
      'es': 'Necesito un mecánico móvil',
    },
    'home_card_mechanic_desc': {
      'fr':
          'Problème de véhicule? Réservez un mécanicien mobile qualifié qui vient chez vous, au travail ou sur la route.',
      'en':
          'Vehicle problem? Book a qualified mobile mechanic who comes to your home, workplace or roadside location.',
      'es':
          '¿Problema con el vehículo? Reserva un mecánico móvil calificado que viene a tu casa, trabajo o carretera.',
    },
    'home_card_mechanic_cta': {
      'fr': 'Trouver un mécanicien',
      'en': 'Find a Mechanic',
      'es': 'Encontrar un mecánico',
    },
    'home_card_mechanic_cta2': {
      'fr': 'Devenir mécanicien mobile',
      'en': 'Become a Mobile Mechanic',
      'es': 'Convertirse en mecánico móvil',
    },

    'home_examples': {'fr': 'Exemples', 'en': 'Examples', 'es': 'Ejemplos'},

    'home_final_headline': {
      'fr': 'Une plateforme. Deux services locaux essentiels.',
      'en': 'One platform. Two essential local services.',
      'es': 'Una plataforma. Dos servicios locales esenciales.',
    },
    'home_final_sub': {
      'fr':
          "Que vous ayez besoin de faire livrer un gros objet ou d'envoyer un mécanicien à votre véhicule, Movi-k vous aide à trouver le bon fournisseur local.",
      'en':
          'Whether you need a large item delivered or a mechanic sent to your vehicle, Movi-k helps you find the right local provider.',
      'es':
          'Ya sea que necesites entregar un artículo grande o enviar un mecánico a tu vehículo, Movi-k te ayuda a encontrar el proveedor local adecuado.',
    },
    'home_final_cta1': {
      'fr': 'Demander un service',
      'en': 'Request a Service',
      'es': 'Solicitar un servicio',
    },
    'home_final_cta2': {
      'fr': 'Devenir fournisseur',
      'en': 'Become a Provider',
      'es': 'Convertirse en proveedor',
    },
    'home_trust_statement': {
      'fr':
          'Fournisseurs locaux. Profils transparents. Réservations flexibles.',
      'en': 'Local providers. Transparent profiles. Flexible bookings.',
      'es': 'Proveedores locales. Perfiles transparentes. Reservas flexibles.',
    },

    // ---------- Common ----------
    'common_next': {'fr': 'Suivant', 'en': 'Next', 'es': 'Siguiente'},
    'common_back': {'fr': 'Retour', 'en': 'Back', 'es': 'Atrás'},
    'common_submit': {'fr': 'Envoyer', 'en': 'Submit', 'es': 'Enviar'},
    'common_cancel': {'fr': 'Annuler', 'en': 'Cancel', 'es': 'Cancelar'},
    'common_confirm': {'fr': 'Confirmer', 'en': 'Confirm', 'es': 'Confirmar'},
    'common_save': {'fr': 'Enregistrer', 'en': 'Save', 'es': 'Guardar'},
    'common_continue': {'fr': 'Continuer', 'en': 'Continue', 'es': 'Continuar'},
    'common_optional': {'fr': 'optionnel', 'en': 'optional', 'es': 'opcional'},
    'common_required': {'fr': 'requis', 'en': 'required', 'es': 'requerido'},
    'common_coming_soon': {
      'fr': 'Bientôt disponible',
      'en': 'Coming soon',
      'es': 'Próximamente',
    },
    'common_demo_data': {
      'fr': 'Données de démonstration',
      'en': 'Demonstration data',
      'es': 'Datos de demostración',
    },
    'common_loading': {
      'fr': 'Chargement…',
      'en': 'Loading…',
      'es': 'Cargando…',
    },
    'common_error': {
      'fr': 'Une erreur est survenue',
      'en': 'An error occurred',
      'es': 'Ocurrió un error',
    },
    'common_empty': {
      'fr': "Rien à afficher pour l'instant",
      'en': 'Nothing to show yet',
      'es': 'Nada que mostrar todavía',
    },
    'common_retry': {'fr': 'Réessayer', 'en': 'Retry', 'es': 'Reintentar'},
    'common_see_all': {'fr': 'Tout voir', 'en': 'See all', 'es': 'Ver todo'},
    'common_upload_photo': {
      'fr': 'Ajouter des photos',
      'en': 'Upload photos',
      'es': 'Subir fotos',
    },
    'common_yes': {'fr': 'Oui', 'en': 'Yes', 'es': 'Sí'},
    'common_no': {'fr': 'Non', 'en': 'No', 'es': 'No'},

    // ---------- Auth ----------
    'auth_welcome': {
      'fr': 'Bienvenue sur Movi-k',
      'en': 'Welcome to Movi-k',
      'es': 'Bienvenido a Movi-k',
    },
    'auth_email': {
      'fr': 'Adresse courriel',
      'en': 'Email address',
      'es': 'Correo electrónico',
    },
    'auth_full_name': {
      'fr': 'Nom complet',
      'en': 'Full name',
      'es': 'Nombre completo',
    },
    'auth_phone': {
      'fr': 'Numéro de téléphone',
      'en': 'Phone number',
      'es': 'Número de teléfono',
    },
    'auth_send_link': {
      'fr': 'Envoyer le lien magique',
      'en': 'Send magic link',
      'es': 'Enviar enlace mágico',
    },
    'auth_magic_link_desc': {
      'fr':
          'Nous vous envoyons un lien sécurisé sans mot de passe pour vous connecter.',
      'en': 'We send you a secure passwordless link to sign in.',
      'es': 'Te enviamos un enlace seguro sin contraseña para iniciar sesión.',
    },
    'auth_check_inbox': {
      'fr': 'Vérifiez votre boîte de réception',
      'en': 'Check your inbox',
      'es': 'Revisa tu bandeja de entrada',
    },
    'auth_demo_notice': {
      'fr':
          "Mode démonstration : la connexion se fait localement sur cet appareil, sans envoi réel de courriel.",
      'en':
          'Demo mode: sign-in happens locally on this device, no real email is sent.',
      'es':
          'Modo demo: el inicio de sesión ocurre localmente en este dispositivo, no se envía correo real.',
    },
    'auth_choose_role': {
      'fr': 'Choisissez votre profil',
      'en': 'Choose your role',
      'es': 'Elige tu perfil',
    },
    'auth_role_customer': {'fr': 'Client', 'en': 'Customer', 'es': 'Cliente'},
    'auth_role_driver': {'fr': 'Chauffeur', 'en': 'Driver', 'es': 'Conductor'},
    'auth_role_mechanic': {
      'fr': 'Mécanicien mobile',
      'en': 'Mobile mechanic',
      'es': 'Mecánico móvil',
    },
    'auth_continue_as': {
      'fr': 'Continuer en tant que',
      'en': 'Continue as',
      'es': 'Continuar como',
    },
    'auth_logged_in_as': {
      'fr': 'Connecté en tant que',
      'en': 'Logged in as',
      'es': 'Conectado como',
    },

    // ---------- Delivery ----------
    'delivery_hero_headline': {
      'fr':
          "Besoin de transporter quelque chose? On trouve le bon chauffeur local.",
      'en': "Need something moved? We'll find the right local driver.",
      'es': '¿Necesitas mover algo? Encontramos al conductor local adecuado.',
    },
    'delivery_hero_sub': {
      'fr':
          "Pas de camion? Pas de remorque? Aucun problème. Décrivez ce qui doit être transporté et choisissez un fournisseur disponible.",
      'en':
          "No pickup? No trailer? No problem. Describe what needs to be transported and choose an available provider.",
      'es':
          '¿Sin camioneta? ¿Sin remolque? No hay problema. Describe qué necesitas transportar y elige un proveedor disponible.',
    },
    'delivery_step1_title': {
      'fr': "Informations sur l'objet",
      'en': 'Item information',
      'es': 'Información del artículo',
    },
    'delivery_step2_title': {
      'fr': 'Emplacements',
      'en': 'Locations',
      'es': 'Ubicaciones',
    },
    'delivery_step3_title': {
      'fr': 'Fournisseurs disponibles',
      'en': 'Provider matching',
      'es': 'Proveedores disponibles',
    },
    'delivery_step4_title': {
      'fr': 'Réservation',
      'en': 'Booking',
      'es': 'Reserva',
    },

    'delivery_item_category': {
      'fr': "Catégorie d'objet",
      'en': 'Item category',
      'es': 'Categoría de artículo',
    },
    'delivery_item_description': {
      'fr': 'Description',
      'en': 'Description',
      'es': 'Descripción',
    },
    'delivery_item_dimensions': {
      'fr': 'Dimensions approximatives',
      'en': 'Approximate dimensions',
      'es': 'Dimensiones aproximadas',
    },
    'delivery_item_weight': {
      'fr': 'Poids approximatif',
      'en': 'Approximate weight',
      'es': 'Peso aproximado',
    },
    'delivery_item_quantity': {
      'fr': 'Quantité',
      'en': 'Quantity',
      'es': 'Cantidad',
    },
    'delivery_item_stairs': {
      'fr': 'Escaliers, ascenseur ou manutention spéciale',
      'en': 'Stairs, elevator or special handling',
      'es': 'Escaleras, ascensor o manejo especial',
    },
    'delivery_item_loading_help': {
      'fr': "Aide au chargement nécessaire",
      'en': 'Loading assistance needed',
      'es': 'Ayuda de carga necesaria',
    },
    'delivery_item_unloading_help': {
      'fr': 'Aide au déchargement nécessaire',
      'en': 'Unloading assistance needed',
      'es': 'Ayuda de descarga necesaria',
    },
    'delivery_item_heavy': {
      'fr': 'Objet lourd (+50 kg)',
      'en': 'Heavy item (50+ kg)',
      'es': 'Objeto pesado (+50 kg)',
    },
    'delivery_item_bulky': {
      'fr': 'Objet volumineux',
      'en': 'Bulky item',
      'es': 'Objeto voluminoso',
    },
    'delivery_breakdown_base': {
      'fr': 'Valeur de base de la mission',
      'en': 'Mission base value',
      'es': 'Valor base de la misión',
    },
    'delivery_breakdown_service_fee': {
      'fr': 'Frais de service',
      'en': 'Service fee',
      'es': 'Tarifa de servicio',
    },
    'delivery_breakdown_tax': {'fr': 'Taxes', 'en': 'Taxes', 'es': 'Impuestos'},
    'delivery_breakdown_discount': {
      'fr': 'Remise',
      'en': 'Discount',
      'es': 'Descuento',
    },

    'delivery_pickup_address': {
      'fr': "Adresse d'enlèvement",
      'en': 'Pickup address',
      'es': 'Dirección de recogida',
    },
    'delivery_dropoff_address': {
      'fr': 'Adresse de livraison',
      'en': 'Delivery address',
      'es': 'Dirección de entrega',
    },
    'delivery_pref_date': {
      'fr': 'Date préférée',
      'en': 'Preferred date',
      'es': 'Fecha preferida',
    },
    'delivery_pref_time': {
      'fr': 'Plage horaire préférée',
      'en': 'Preferred time window',
      'es': 'Horario preferido',
    },
    'delivery_contact_instructions': {
      'fr': 'Instructions de contact',
      'en': 'Contact instructions',
      'es': 'Instrucciones de contacto',
    },
    'delivery_access_details': {
      'fr': "Détails d'accès",
      'en': 'Access details',
      'es': 'Detalles de acceso',
    },
    'delivery_extra_stop': {
      'fr': 'Arrêt additionnel (optionnel)',
      'en': 'Optional additional stop',
      'es': 'Parada adicional (opcional)',
    },

    'delivery_find_drivers': {
      'fr': 'Chauffeurs disponibles',
      'en': 'Available drivers',
      'es': 'Conductores disponibles',
    },
    'delivery_confirm_request': {
      'fr': 'Confirmer la demande',
      'en': 'Confirm Request',
      'es': 'Confirmar solicitud',
    },

    'delivery_status_submitted': {
      'fr': 'Demande envoyée',
      'en': 'Request submitted',
      'es': 'Solicitud enviada',
    },
    'delivery_status_awaiting': {
      'fr': 'En attente de réponse du fournisseur',
      'en': 'Awaiting provider response',
      'es': 'Esperando respuesta del proveedor',
    },
    'delivery_status_accepted': {
      'fr': 'Acceptée',
      'en': 'Accepted',
      'es': 'Aceptada',
    },
    'delivery_status_on_the_way': {
      'fr': 'Le fournisseur est en route',
      'en': 'Provider on the way',
      'es': 'El proveedor está en camino',
    },
    'delivery_status_pickup_done': {
      'fr': 'Enlèvement complété',
      'en': 'Pickup completed',
      'es': 'Recogida completada',
    },
    'delivery_status_in_progress': {
      'fr': 'Livraison en cours',
      'en': 'Delivery in progress',
      'es': 'Entrega en progreso',
    },
    'delivery_status_delivered': {
      'fr': 'Livré',
      'en': 'Delivered',
      'es': 'Entregado',
    },
    'delivery_status_cancelled': {
      'fr': 'Annulée',
      'en': 'Cancelled',
      'es': 'Cancelada',
    },
    'delivery_status_disputed': {
      'fr': 'En litige',
      'en': 'Disputed',
      'es': 'En disputa',
    },

    // ---------- Mission status (MissionStatus — flux Firebase réel) ----------
    'mission_status_draft': {
      'fr': 'Brouillon',
      'en': 'Draft',
      'es': 'Borrador',
    },
    'mission_status_quoted': {
      'fr': 'Devis généré',
      'en': 'Quoted',
      'es': 'Cotizado',
    },
    'mission_status_searchingdriver': {
      'fr': 'Recherche d\'un chauffeur…',
      'en': 'Searching for a driver…',
      'es': 'Buscando un conductor…',
    },
    'mission_status_offered': {
      'fr': 'Proposée à des chauffeurs',
      'en': 'Offered to drivers',
      'es': 'Ofrecida a conductores',
    },
    'mission_status_assigned': {
      'fr': 'Chauffeur assigné',
      'en': 'Driver assigned',
      'es': 'Conductor asignado',
    },
    'mission_status_drivertopickup': {
      'fr': 'Chauffeur en route vers l\'enlèvement',
      'en': 'Driver heading to pickup',
      'es': 'Conductor en camino a la recogida',
    },
    'mission_status_arrivedatpickup': {
      'fr': 'Chauffeur arrivé à l\'enlèvement',
      'en': 'Driver arrived at pickup',
      'es': 'Conductor llegó a la recogida',
    },
    'mission_status_pickedup': {
      'fr': 'Objet(s) récupéré(s)',
      'en': 'Item(s) picked up',
      'es': 'Artículo(s) recogido(s)',
    },
    'mission_status_intransit': {
      'fr': 'En transit',
      'en': 'In transit',
      'es': 'En tránsito',
    },
    'mission_status_arrivedatdropoff': {
      'fr': 'Chauffeur arrivé à la livraison',
      'en': 'Driver arrived at dropoff',
      'es': 'Conductor llegó a la entrega',
    },
    'mission_status_delivered': {
      'fr': 'Livré',
      'en': 'Delivered',
      'es': 'Entregado',
    },
    'mission_status_completed': {
      'fr': 'Terminée',
      'en': 'Completed',
      'es': 'Completada',
    },
    'mission_status_cancelled': {
      'fr': 'Annulée',
      'en': 'Cancelled',
      'es': 'Cancelada',
    },
    'mission_status_disputed': {
      'fr': 'En litige',
      'en': 'Disputed',
      'es': 'En disputa',
    },
    'mission_status_refunded': {
      'fr': 'Remboursée',
      'en': 'Refunded',
      'es': 'Reembolsada',
    },

    // ---------- Delivery flow (Firebase réel — Phase 4) ----------
    'delivery_login_required': {
      'fr': 'Connectez-vous pour créer une demande de livraison.',
      'en': 'Sign in to create a delivery request.',
      'es': 'Inicia sesión para crear una solicitud de entrega.',
    },
    'delivery_sign_in_button': {
      'fr': 'Se connecter',
      'en': 'Sign in',
      'es': 'Iniciar sesión',
    },
    'delivery_step_addresses_title': {
      'fr': 'Adresses',
      'en': 'Addresses',
      'es': 'Direcciones',
    },
    'delivery_step_vehicle_title': {
      'fr': 'Véhicule requis',
      'en': 'Required vehicle',
      'es': 'Vehículo requerido',
    },
    'delivery_step_quote_title': {
      'fr': 'Devis',
      'en': 'Quote',
      'es': 'Cotización',
    },
    'delivery_pickup_line1': {
      'fr': 'Adresse d\'enlèvement (rue, numéro)',
      'en': 'Pickup address (street, number)',
      'es': 'Dirección de recogida (calle, número)',
    },
    'delivery_pickup_city': {
      'fr': 'Ville d\'enlèvement',
      'en': 'Pickup city',
      'es': 'Ciudad de recogida',
    },
    'delivery_pickup_postal': {
      'fr': 'Code postal d\'enlèvement',
      'en': 'Pickup postal code',
      'es': 'Código postal de recogida',
    },
    'delivery_dropoff_line1': {
      'fr': 'Adresse de livraison (rue, numéro)',
      'en': 'Delivery address (street, number)',
      'es': 'Dirección de entrega (calle, número)',
    },
    'delivery_dropoff_city': {
      'fr': 'Ville de livraison',
      'en': 'Delivery city',
      'es': 'Ciudad de entrega',
    },
    'delivery_dropoff_postal': {
      'fr': 'Code postal de livraison',
      'en': 'Delivery postal code',
      'es': 'Código postal de entrega',
    },
    'delivery_coordinates_note': {
      'fr':
          'Coordonnées GPS approximatives requises (latitude/longitude) — utilisées uniquement pour estimer la distance.',
      'en':
          'Approximate GPS coordinates required (latitude/longitude) — used only to estimate distance.',
      'es':
          'Se requieren coordenadas GPS aproximadas (latitud/longitud) — usadas solo para estimar la distancia.',
    },
    'delivery_lat': {'fr': 'Latitude', 'en': 'Latitude', 'es': 'Latitud'},
    'delivery_lng': {'fr': 'Longitude', 'en': 'Longitude', 'es': 'Longitud'},
    'delivery_required_vehicle': {
      'fr': 'Type de véhicule requis',
      'en': 'Required vehicle type',
      'es': 'Tipo de vehículo requerido',
    },
    'delivery_get_quote': {
      'fr': 'Obtenir un devis',
      'en': 'Get a quote',
      'es': 'Obtener una cotización',
    },
    'delivery_getting_quote': {
      'fr': 'Calcul du devis en cours…',
      'en': 'Calculating quote…',
      'es': 'Calculando cotización…',
    },
    'delivery_quote_error': {
      'fr': 'Impossible de calculer le devis. Réessayez.',
      'en': 'Unable to calculate the quote. Please try again.',
      'es': 'No se pudo calcular la cotización. Inténtalo de nuevo.',
    },
    'delivery_quote_total': {
      'fr': 'Total estimé (devis officiel)',
      'en': 'Estimated total (official quote)',
      'es': 'Total estimado (cotización oficial)',
    },
    'delivery_quote_distance_note': {
      'fr':
          'Distance/durée estimées automatiquement (approximation à vol d\'oiseau, pas un itinéraire réel).',
      'en':
          'Distance/duration estimated automatically (straight-line approximation, not a real route).',
      'es':
          'Distancia/duración estimadas automáticamente (aproximación en línea recta, no una ruta real).',
    },
    'delivery_quote_expires_note': {
      'fr': 'Ce devis expire après un court délai — confirmez rapidement.',
      'en': 'This quote expires after a short delay — confirm quickly.',
      'es':
          'Esta cotización expira después de un breve plazo — confirma rápidamente.',
    },
    'delivery_confirm_and_create': {
      'fr': 'Confirmer et créer la mission',
      'en': 'Confirm and create mission',
      'es': 'Confirmar y crear la misión',
    },
    'delivery_creating_mission': {
      'fr': 'Création de la mission…',
      'en': 'Creating mission…',
      'es': 'Creando misión…',
    },
    'delivery_mission_error': {
      'fr': 'La création de la mission a échoué. Réessayez.',
      'en': 'Mission creation failed. Please try again.',
      'es': 'La creación de la misión falló. Inténtalo de nuevo.',
    },
    'delivery_mission_created_title': {
      'fr': 'Mission créée !',
      'en': 'Mission created!',
      'es': '¡Misión creada!',
    },
    'delivery_searching_driver_desc': {
      'fr':
          'Nous recherchons un chauffeur disponible pour votre mission. Vous serez notifié dès qu\'un chauffeur l\'accepte.',
      'en':
          'We are searching for an available driver for your mission. You will be notified as soon as a driver accepts it.',
      'es':
          'Estamos buscando un conductor disponible para tu misión. Serás notificado en cuanto un conductor la acepte.',
    },
    'delivery_view_my_requests': {
      'fr': 'Voir mes demandes',
      'en': 'View my requests',
      'es': 'Ver mis solicitudes',
    },

    // ---------- Customer requests (temps réel) ----------
    'requests_title': {
      'fr': 'Mes demandes',
      'en': 'My requests',
      'es': 'Mis solicitudes',
    },
    'requests_filter_all': {'fr': 'Toutes', 'en': 'All', 'es': 'Todas'},
    'requests_filter_delivery': {
      'fr': 'Livraisons',
      'en': 'Deliveries',
      'es': 'Entregas',
    },
    'requests_filter_mechanic': {
      'fr': 'Mécanique',
      'en': 'Mechanic',
      'es': 'Mecánica',
    },
    'requests_loading': {
      'fr': 'Chargement de vos demandes…',
      'en': 'Loading your requests…',
      'es': 'Cargando tus solicitudes…',
    },
    'requests_error': {
      'fr': 'Impossible de charger vos demandes.',
      'en': 'Unable to load your requests.',
      'es': 'No se pudieron cargar tus solicitudes.',
    },
    'requests_retry': {'fr': 'Réessayer', 'en': 'Retry', 'es': 'Reintentar'},
    'requests_empty': {
      'fr': 'Rien à afficher pour l\'instant',
      'en': 'Nothing to show yet',
      'es': 'Nada que mostrar todavía',
    },
    'requests_track_driver': {
      'fr': 'Suivre le chauffeur',
      'en': 'Track driver',
      'es': 'Seguir al conductor',
    },

    'overview_greeting': {'fr': 'Bonjour', 'en': 'Hello', 'es': 'Hola'},
    'overview_subtitle': {
      'fr': 'Voici un résumé de votre activité sur Movi-K.',
      'en': 'Here is a summary of your activity on Movi-K.',
      'es': 'Aquí tienes un resumen de tu actividad en Movi-K.',
    },
    'overview_stat_total': {
      'fr': 'Demandes totales',
      'en': 'Total requests',
      'es': 'Solicitudes totales',
    },
    'overview_stat_active': {'fr': 'Actives', 'en': 'Active', 'es': 'Activas'},
    'overview_new_delivery': {
      'fr': 'Nouvelle livraison',
      'en': 'New delivery',
      'es': 'Nueva entrega',
    },
    'overview_new_mechanic': {
      'fr': 'Nouveau service mécanique',
      'en': 'New mechanic service',
      'es': 'Nuevo servicio mecánico',
    },
    'overview_recent_title': {
      'fr': 'Demandes récentes',
      'en': 'Recent requests',
      'es': 'Solicitudes recientes',
    },
    'overview_see_all': {'fr': 'Tout voir', 'en': 'See all', 'es': 'Ver todo'},
    'overview_empty_title': {
      'fr': 'Aucune demande pour le moment',
      'en': 'No requests yet',
      'es': 'Aún no hay solicitudes',
    },
    'overview_empty_cta': {
      'fr': 'Créer ma première demande',
      'en': 'Create my first request',
      'es': 'Crear mi primera solicitud',
    },
    'overview_loading': {
      'fr': 'Chargement…',
      'en': 'Loading…',
      'es': 'Cargando…',
    },

    // ---------- Driver jobs / active mission (Firebase réel) ----------
    'driver_jobs_title': {
      'fr': 'Demandes disponibles',
      'en': 'Available requests',
      'es': 'Solicitudes disponibles',
    },
    'driver_jobs_loading': {
      'fr': 'Recherche de missions disponibles…',
      'en': 'Looking for available missions…',
      'es': 'Buscando misiones disponibles…',
    },
    'driver_jobs_error': {
      'fr': 'Impossible de charger les demandes disponibles.',
      'en': 'Unable to load available requests.',
      'es': 'No se pudieron cargar las solicitudes disponibles.',
    },
    'driver_jobs_empty': {
      'fr': 'Aucune nouvelle demande pour le moment',
      'en': 'No new requests at the moment',
      'es': 'No hay solicitudes nuevas por el momento',
    },
    'driver_jobs_accept': {'fr': 'Accepter', 'en': 'Accept', 'es': 'Aceptar'},
    'driver_jobs_accepting': {
      'fr': 'Acceptation en cours…',
      'en': 'Accepting…',
      'es': 'Aceptando…',
    },
    'driver_jobs_accept_error': {
      'fr':
          'Cette mission n\'est plus disponible (déjà acceptée par un autre chauffeur).',
      'en':
          'This mission is no longer available (already accepted by another driver).',
      'es':
          'Esta misión ya no está disponible (ya fue aceptada por otro conductor).',
    },
    'driver_jobs_offer_amount': {
      'fr': 'Montant offert',
      'en': 'Offer amount',
      'es': 'Monto ofrecido',
    },
    'driver_jobs_distance': {
      'fr': 'Distance estimée',
      'en': 'Estimated distance',
      'es': 'Distancia estimada',
    },
    'driver_active_mission_title': {
      'fr': 'Mission active',
      'en': 'Active mission',
      'es': 'Misión activa',
    },
    'driver_active_mission_none': {
      'fr': 'Aucune mission active pour le moment',
      'en': 'No active mission at the moment',
      'es': 'No hay misión activa por el momento',
    },
    'driver_active_mission_pickup': {
      'fr': 'Enlèvement',
      'en': 'Pickup',
      'es': 'Recogida',
    },
    'driver_active_mission_dropoff': {
      'fr': 'Livraison',
      'en': 'Dropoff',
      'es': 'Entrega',
    },
    'driver_active_mission_expected_pay': {
      'fr': 'Gain attendu',
      'en': 'Expected pay',
      'es': 'Ganancia esperada',
    },
    'driver_active_mission_mark_pickup': {
      'fr': 'Marquer l\'enlèvement comme complété',
      'en': 'Mark pickup as completed',
      'es': 'Marcar recogida como completada',
    },
    'driver_active_mission_mark_delivered': {
      'fr': 'Marquer la livraison comme complétée',
      'en': 'Mark delivery as completed',
      'es': 'Marcar entrega como completada',
    },
    'driver_active_mission_action_error': {
      'fr': 'L\'action a échoué. Réessayez.',
      'en': 'The action failed. Please try again.',
      'es': 'La acción falló. Inténtalo de nuevo.',
    },
    'driver_active_mission_cf_error': {
      'fr': 'Le serveur a refusé cette action. Actualisez et réessayez.',
      'en': 'The server rejected this action. Refresh and try again.',
      'es': 'El servidor rechazó esta acción. Actualice e inténtelo de nuevo.',
    },
    'driver_active_mission_not_found': {
      'fr': 'Mission introuvable. Elle a peut-être été supprimée.',
      'en': 'Mission not found. It may have been removed.',
      'es': 'Misión no encontrada. Puede haber sido eliminada.',
    },
    'driver_active_mission_cancelled': {
      'fr': 'Cette mission a été annulée.',
      'en': 'This mission has been cancelled.',
      'es': 'Esta misión ha sido cancelada.',
    },
    'driver_active_mission_already_completed': {
      'fr': 'Cette mission est déjà terminée.',
      'en': 'This mission is already completed.',
      'es': 'Esta misión ya está completada.',
    },
    'driver_active_mission_network_error': {
      'fr': 'Erreur réseau. Vérifiez votre connexion et réessayez.',
      'en': 'Network error. Check your connection and try again.',
      'es': 'Error de red. Verifique su conexión e inténtelo de nuevo.',
    },
    'driver_active_mission_access_denied': {
      'fr': 'Accès refusé à cette mission.',
      'en': 'Access denied to this mission.',
      'es': 'Acceso denegado a esta misión.',
    },
    'driver_active_mission_instructions': {
      'fr': 'Instructions',
      'en': 'Instructions',
      'es': 'Instrucciones',
    },
    'driver_active_mission_duration': {
      'fr': 'Durée estimée',
      'en': 'Estimated duration',
      'es': 'Duración estimada',
    },
    'driver_active_mission_vehicle': {
      'fr': 'Véhicule requis',
      'en': 'Required vehicle',
      'es': 'Vehículo requerido',
    },
    'driver_active_mission_start_to_pickup': {
      'fr': 'Commencer le trajet vers l\'enlèvement',
      'en': 'Start trip to pickup',
      'es': 'Iniciar viaje hacia la recogida',
    },
    'driver_active_mission_arrived_at_pickup': {
      'fr': 'Je suis arrivé à l\'enlèvement',
      'en': 'I have arrived at pickup',
      'es': 'He llegado a la recogida',
    },
    'driver_active_mission_start_transit': {
      'fr': 'Commencer le transport',
      'en': 'Start transport',
      'es': 'Iniciar transporte',
    },
    'driver_active_mission_arrived_at_dropoff': {
      'fr': 'Je suis arrivé à la livraison',
      'en': 'I have arrived at dropoff',
      'es': 'He llegado a la entrega',
    },
    'driver_active_mission_resume_banner': {
      'fr': 'Mission en cours — reprendre',
      'en': 'Mission in progress — resume',
      'es': 'Misión en curso — reanudar',
    },

    // ---------- Tracking GPS temps réel (Phase 5) ----------
    'driver_active_mission_gps_disabled': {
      'fr':
          'Votre GPS est désactivé. Activez-le pour que le client puisse vous suivre.',
      'en': 'Your GPS is disabled. Turn it on so the customer can track you.',
      'es':
          'Su GPS está desactivado. Actívelo para que el cliente pueda seguirlo.',
    },
    'driver_active_mission_gps_permission_denied': {
      'fr':
          'Autorisez la localisation pour que le client puisse suivre votre trajet.',
      'en': 'Allow location access so the customer can track your trip.',
      'es':
          'Permita el acceso a la ubicación para que el cliente pueda seguir su viaje.',
    },
    'driver_active_mission_gps_report_failed': {
      'fr': 'Impossible d\'envoyer votre position pour le moment.',
      'en': 'Unable to send your position right now.',
      'es': 'No se pudo enviar su posición en este momento.',
    },
    'tracking_title': {
      'fr': 'Suivi en direct',
      'en': 'Live tracking',
      'es': 'Seguimiento en vivo',
    },
    'tracking_not_available': {
      'fr':
          'Le suivi en direct sera disponible dès qu\'un chauffeur sera en route.',
      'en': 'Live tracking will be available once a driver is on the way.',
      'es':
          'El seguimiento en vivo estará disponible en cuanto un conductor esté en camino.',
    },
    'tracking_waiting_for_signal': {
      'fr': 'En attente du signal GPS du chauffeur…',
      'en': 'Waiting for the driver\'s GPS signal…',
      'es': 'Esperando la señal GPS del conductor…',
    },
    'tracking_driver_fallback': {
      'fr': 'Votre chauffeur',
      'en': 'Your driver',
      'es': 'Su conductor',
    },
    'tracking_route_legend': {
      'fr': 'Trajet parcouru',
      'en': 'Traveled route',
      'es': 'Ruta recorrida',
    },

    // ---------- Timeline client (Phase 5, partie 3) ----------
    'tracking_timeline_title': {
      'fr': 'Étapes de la livraison',
      'en': 'Delivery steps',
      'es': 'Etapas de la entrega',
    },

    // ---------- Preuve de livraison (Phase 5, partie 3) ----------
    'driver_active_mission_capture_photo': {
      'fr': 'Prendre une photo de livraison',
      'en': 'Take a delivery photo',
      'es': 'Tomar una foto de la entrega',
    },
    'driver_active_mission_photo_required_error': {
      'fr': 'Une photo de livraison est requise pour confirmer la livraison.',
      'en': 'A delivery photo is required to confirm the delivery.',
      'es': 'Se requiere una foto de la entrega para confirmar la entrega.',
    },
    'driver_active_mission_uploading_proof': {
      'fr': 'Téléversement de la preuve de livraison…',
      'en': 'Uploading delivery proof…',
      'es': 'Subiendo la prueba de entrega…',
    },
    'driver_active_mission_proof_upload_error': {
      'fr': 'Impossible de téléverser la photo. Réessayez.',
      'en': 'Unable to upload the photo. Please try again.',
      'es': 'No se pudo subir la foto. Inténtelo de nuevo.',
    },
    'driver_active_mission_retake_photo': {
      'fr': 'Reprendre la photo',
      'en': 'Retake photo',
      'es': 'Volver a tomar la foto',
    },
    'driver_active_mission_confirm_proof': {
      'fr': 'Confirmer la livraison',
      'en': 'Confirm delivery',
      'es': 'Confirmar la entrega',
    },
    'driver_active_mission_capture_error': {
      'fr': 'Impossible d\'accéder à la caméra. Réessayez.',
      'en': 'Unable to access the camera. Please try again.',
      'es': 'No se pudo acceder a la cámara. Inténtelo de nuevo.',
    },
    'driver_active_mission_proof_preview_title': {
      'fr': 'Photo de livraison',
      'en': 'Delivery photo',
      'es': 'Foto de la entrega',
    },
    'customer_tracking_completed_title': {
      'fr': 'Livraison complétée',
      'en': 'Delivery completed',
      'es': 'Entrega completada',
    },
    'customer_tracking_completed_message': {
      'fr': 'Votre objet a été livré avec succès.',
      'en': 'Your item has been successfully delivered.',
      'es': 'Su artículo ha sido entregado con éxito.',
    },
    'customer_tracking_proof_title': {
      'fr': 'Preuve de livraison',
      'en': 'Proof of delivery',
      'es': 'Prueba de entrega',
    },
    'customer_tracking_proof_unavailable': {
      'fr': 'Aucune preuve de livraison disponible pour cette mission.',
      'en': 'No proof of delivery available for this mission.',
      'es': 'No hay prueba de entrega disponible para esta misión.',
    },

    // ---------- Notifications (Phase 5, partie 3) ----------
    'notifications_title': {
      'fr': 'Notifications',
      'en': 'Notifications',
      'es': 'Notificaciones',
    },
    'notifications_empty': {
      'fr': 'Aucune notification pour le moment.',
      'en': 'No notifications yet.',
      'es': 'No hay notificaciones por el momento.',
    },
    'notifications_loading': {
      'fr': 'Chargement des notifications…',
      'en': 'Loading notifications…',
      'es': 'Cargando notificaciones…',
    },
    'notifications_error': {
      'fr': 'Impossible de charger les notifications.',
      'en': 'Unable to load notifications.',
      'es': 'No se pudieron cargar las notificaciones.',
    },
    'notifications_open_tooltip': {
      'fr': 'Notifications',
      'en': 'Notifications',
      'es': 'Notificaciones',
    },
    'notifications_mark_all_read': {
      'fr': 'Tout marquer comme lu',
      'en': 'Mark all as read',
      'es': 'Marcar todo como leído',
    },
    'notifications_just_now': {
      'fr': 'À l\'instant',
      'en': 'Just now',
      'es': 'Justo ahora',
    },

    // ---------- Audit i18n final (Phase 5, partie 3) : messages "non connecté" des dashboards ----------
    'customer_dashboard_locked_message': {
      'fr': 'Connectez-vous pour accéder à votre tableau de bord.',
      'en': 'Sign in to access your dashboard.',
      'es': 'Inicia sesión para acceder a tu panel.',
    },
    'provider_dashboard_locked_message': {
      'fr': 'Connectez-vous à votre espace fournisseur.',
      'en': 'Sign in to access your provider workspace.',
      'es': 'Inicia sesión para acceder a tu espacio de proveedor.',
    },
    // Phase 7, Bloc B (MIS-C-07) : message dédié pour un accès non
    // authentifié à l'écran de suivi de mission — évite d'afficher à tort
    // le message générique "erreur réseau" (voir CustomerTrackingScreen).
    'tracking_locked_message': {
      'fr': 'Connectez-vous pour suivre votre livraison.',
      'en': 'Sign in to track your delivery.',
      'es': 'Inicia sesión para seguir tu entrega.',
    },
    'provider_availability_toggle_error': {
      'fr': 'Impossible de changer votre statut de disponibilité.',
      'en': 'Unable to change your availability status.',
      'es': 'No se pudo cambiar tu estado de disponibilidad.',
    },

    // Notification content — resolved client-side via title_key/body_key.
    'notif_driver_assigned_title': {
      'fr': 'Chauffeur assigné',
      'en': 'Driver assigned',
      'es': 'Conductor asignado',
    },
    'notif_driver_assigned_body': {
      'fr': 'Un chauffeur a été assigné à votre livraison.',
      'en': 'A driver has been assigned to your delivery.',
      'es': 'Se ha asignado un conductor a su entrega.',
    },
    'notif_driver_to_pickup_title': {
      'fr': 'En route vers le ramassage',
      'en': 'On the way to pickup',
      'es': 'En camino a la recogida',
    },
    'notif_driver_to_pickup_body': {
      'fr': 'Votre chauffeur est en route vers le ramassage.',
      'en': 'Your driver is on the way to the pickup.',
      'es': 'Su conductor está en camino a la recogida.',
    },
    'notif_arrived_at_pickup_title': {
      'fr': 'Arrivé au ramassage',
      'en': 'Arrived at pickup',
      'es': 'Llegó a la recogida',
    },
    'notif_arrived_at_pickup_body': {
      'fr': 'Votre chauffeur est arrivé au point de ramassage.',
      'en': 'Your driver has arrived at the pickup point.',
      'es': 'Su conductor ha llegado al punto de recogida.',
    },
    'notif_picked_up_title': {
      'fr': 'Objet récupéré',
      'en': 'Item picked up',
      'es': 'Artículo recogido',
    },
    'notif_picked_up_body': {
      'fr': 'Votre objet a été récupéré. La livraison est en cours.',
      'en': 'Your item has been picked up. Delivery is in progress.',
      'es': 'Su artículo ha sido recogido. La entrega está en curso.',
    },
    'notif_in_transit_title': {
      'fr': 'Livraison en cours',
      'en': 'Delivery in progress',
      'es': 'Entrega en curso',
    },
    'notif_in_transit_body': {
      'fr': 'Votre livraison est en route vers sa destination.',
      'en': 'Your delivery is on its way to its destination.',
      'es': 'Su entrega está en camino a su destino.',
    },
    'notif_arrived_at_dropoff_title': {
      'fr': 'Arrivé à destination',
      'en': 'Arrived at destination',
      'es': 'Llegó al destino',
    },
    'notif_arrived_at_dropoff_body': {
      'fr': 'Votre chauffeur est arrivé à destination.',
      'en': 'Your driver has arrived at the destination.',
      'es': 'Su conductor ha llegado al destino.',
    },
    'notif_completed_title': {
      'fr': 'Livraison complétée',
      'en': 'Delivery completed',
      'es': 'Entrega completada',
    },
    'notif_completed_body': {
      'fr': 'Votre livraison est complétée.',
      'en': 'Your delivery is completed.',
      'es': 'Su entrega está completada.',
    },
    'notif_cancelled_title': {
      'fr': 'Mission annulée',
      'en': 'Mission cancelled',
      'es': 'Misión cancelada',
    },
    'notif_cancelled_body': {
      'fr': 'Votre demande de livraison a été annulée.',
      'en': 'Your delivery request has been cancelled.',
      'es': 'Su solicitud de entrega ha sido cancelada.',
    },
    'notif_document_expiring_soon_title': {
      'fr': 'Document bientôt expiré',
      'en': 'Document expiring soon',
      'es': 'Documento por vencer',
    },
    'notif_document_expiring_soon_body': {
      'fr':
          'Un de vos documents chauffeur arrive bientôt à expiration. Pensez à le renouveler.',
      'en': 'One of your driver documents is expiring soon. Please renew it.',
      'es':
          'Uno de sus documentos de conductor está por vencer. Renuévelo pronto.',
    },
    'notif_founding_preferred_rate_title': {
      'fr': 'Tarif préférentiel activé',
      'en': 'Preferred rate activated',
      'es': 'Tarifa preferencial activada',
    },
    'notif_founding_preferred_rate_body': {
      'fr':
          'Votre tarif préférentiel de chauffeur fondateur est maintenant actif.',
      'en': 'Your founding driver preferred rate is now active.',
      'es': 'Su tarifa preferencial de conductor fundador ya está activa.',
    },

    // ---------- Driver earnings (Firebase réel — lecture seule) ----------
    'earnings_title': {'fr': 'Revenus', 'en': 'Earnings', 'es': 'Ganancias'},
    'earnings_loading': {
      'fr': 'Chargement de vos revenus…',
      'en': 'Loading your earnings…',
      'es': 'Cargando tus ganancias…',
    },
    'earnings_error': {
      'fr': 'Impossible de charger vos revenus.',
      'en': 'Unable to load your earnings.',
      'es': 'No se pudieron cargar tus ganancias.',
    },
    'earnings_empty': {
      'fr': 'Aucun gain enregistré pour l\'instant',
      'en': 'No earnings recorded yet',
      'es': 'Aún no hay ganancias registradas',
    },
    'earnings_total_label': {
      'fr': 'Total des gains confirmés',
      'en': 'Total confirmed earnings',
      'es': 'Total de ganancias confirmadas',
    },
    'earnings_pending_label': {
      'fr': 'En attente de confirmation',
      'en': 'Pending confirmation',
      'es': 'Pendiente de confirmación',
    },
    'earnings_history_title': {
      'fr': 'Historique des transactions',
      'en': 'Transaction history',
      'es': 'Historial de transacciones',
    },
    'earnings_status_pending': {
      'fr': 'En attente',
      'en': 'Pending',
      'es': 'Pendiente',
    },
    'earnings_status_confirmed': {
      'fr': 'Confirmée',
      'en': 'Confirmed',
      'es': 'Confirmada',
    },
    'earnings_status_reversed': {
      'fr': 'Annulée',
      'en': 'Reversed',
      'es': 'Anulada',
    },
    'earnings_status_compensated': {
      'fr': 'Compensée',
      'en': 'Compensated',
      'es': 'Compensada',
    },

    'ledger_type_driver_earning': {
      'fr': 'Rémunération de mission',
      'en': 'Mission earning',
      'es': 'Ganancia de misión',
    },
    'ledger_type_driver_tip': {'fr': 'Pourboire', 'en': 'Tip', 'es': 'Propina'},
    'ledger_type_driver_bonus': {'fr': 'Bonus', 'en': 'Bonus', 'es': 'Bono'},
    'ledger_type_driver_payout': {
      'fr': 'Versement',
      'en': 'Payout',
      'es': 'Pago',
    },
    'ledger_type_driver_adjustment': {
      'fr': 'Ajustement',
      'en': 'Adjustment',
      'es': 'Ajuste',
    },
    'ledger_type_refund': {
      'fr': 'Remboursement',
      'en': 'Refund',
      'es': 'Reembolso',
    },
    'ledger_type_partial_refund': {
      'fr': 'Remboursement partiel',
      'en': 'Partial refund',
      'es': 'Reembolso parcial',
    },
    'ledger_type_chargeback': {
      'fr': 'Rétrofacturation',
      'en': 'Chargeback',
      'es': 'Contracargo',
    },

    // ---------- Mechanic ----------
    'mechanic_hero_headline': {
      'fr': 'Un mécanicien qui se déplace chez vous.',
      'en': 'A mechanic who comes to you.',
      'es': 'Un mecánico que viene a ti.',
    },
    'mechanic_hero_sub': {
      'fr':
          'Réservez un service automobile à domicile, au travail, sur un chantier ou en bord de route.',
      'en':
          'Book automotive service at home, at work, on a job site or on the roadside.',
      'es':
          'Reserva un servicio automotriz en casa, en el trabajo, en un sitio de trabajo o en la carretera.',
    },
    'mechanic_step1_title': {
      'fr': 'Informations sur le véhicule',
      'en': 'Vehicle information',
      'es': 'Información del vehículo',
    },
    'mechanic_step2_title': {
      'fr': 'Problème ou service',
      'en': 'Problem or service',
      'es': 'Problema o servicio',
    },
    'mechanic_step3_title': {
      'fr': 'Emplacement et horaire',
      'en': 'Location and schedule',
      'es': 'Ubicación y horario',
    },
    'mechanic_step4_title': {
      'fr': 'Mécaniciens disponibles',
      'en': 'Mechanic matching',
      'es': 'Mecánicos disponibles',
    },
    'mechanic_step5_title': {
      'fr': 'Résumé de la réservation',
      'en': 'Booking summary',
      'es': 'Resumen de la reserva',
    },

    'mechanic_vehicle_make': {
      'fr': 'Marque du véhicule',
      'en': 'Vehicle make',
      'es': 'Marca del vehículo',
    },
    'mechanic_vehicle_model': {'fr': 'Modèle', 'en': 'Model', 'es': 'Modelo'},
    'mechanic_vehicle_year': {'fr': 'Année', 'en': 'Year', 'es': 'Año'},
    'mechanic_vehicle_engine': {'fr': 'Moteur', 'en': 'Engine', 'es': 'Motor'},
    'mechanic_vehicle_vin': {
      'fr': 'NIV (optionnel)',
      'en': 'VIN (optional)',
      'es': 'VIN (opcional)',
    },
    'mechanic_vehicle_plate': {
      'fr': "Plaque d'immatriculation (optionnel)",
      'en': 'Licence plate (optional)',
      'es': 'Placa (opcional)',
    },
    'mechanic_vehicle_mileage': {
      'fr': 'Kilométrage actuel',
      'en': 'Current mileage',
      'es': 'Kilometraje actual',
    },
    'mechanic_vehicle_can_move': {
      'fr': 'Le véhicule peut-il se déplacer en sécurité?',
      'en': 'Can the vehicle move safely?',
      'es': '¿Puede el vehículo moverse con seguridad?',
    },

    'mechanic_disclaimer': {
      'fr':
          "Les descriptions en ligne ne remplacent pas un diagnostic mécanique en personne. Le prix final peut changer si l'état réel diffère de la demande initiale. Tout changement de prix doit être approuvé par le client avant le début de travaux supplémentaires.",
      'en':
          'Online descriptions do not replace an in-person mechanical diagnosis. The final price may change if the actual condition differs from the original request. Any price change must be approved by the customer before additional work begins.',
      'es':
          'Las descripciones en línea no reemplazan un diagnóstico mecánico en persona. El precio final puede cambiar si el estado real difiere de la solicitud original. Cualquier cambio de precio debe ser aprobado por el cliente antes de iniciar trabajo adicional.',
    },

    'mechanic_send_request': {
      'fr': 'Envoyer la demande de réservation',
      'en': 'Send Booking Request',
      'es': 'Enviar solicitud de reserva',
    },
    'mechanic_services_label': {
      'fr': 'Services :',
      'en': 'Services:',
      'es': 'Servicios:',
    },
    'mechanic_select_services_title': {
      'fr': 'Sélectionnez le(s) service(s)',
      'en': 'Select service(s)',
      'es': 'Seleccione el/los servicio(s)',
    },

    'mechanic_status_submitted': {
      'fr': 'Demande envoyée',
      'en': 'Request submitted',
      'es': 'Solicitud enviada',
    },
    'mechanic_status_awaiting': {
      'fr': 'En attente de réponse du mécanicien',
      'en': 'Awaiting mechanic response',
      'es': 'Esperando respuesta del mecánico',
    },
    'mechanic_status_accepted': {
      'fr': 'Acceptée',
      'en': 'Accepted',
      'es': 'Aceptada',
    },
    'mechanic_status_diagnosis': {
      'fr': 'Diagnostic requis',
      'en': 'Diagnosis required',
      'es': 'Diagnóstico requerido',
    },
    'mechanic_status_parts_needed': {
      'fr': 'Pièces requises',
      'en': 'Parts required',
      'es': 'Piezas requeridas',
    },
    'mechanic_status_parts_ordered': {
      'fr': 'Pièces commandées',
      'en': 'Parts ordered',
      'es': 'Piezas pedidas',
    },
    'mechanic_status_on_the_way': {
      'fr': 'Le mécanicien est en route',
      'en': 'Mechanic on the way',
      'es': 'El mecánico está en camino',
    },
    'mechanic_status_in_progress': {
      'fr': 'Travaux en cours',
      'en': 'Work in progress',
      'es': 'Trabajo en progreso',
    },
    'mechanic_status_approval_needed': {
      'fr': 'Approbation du client requise',
      'en': 'Customer approval required',
      'es': 'Se requiere aprobación del cliente',
    },
    'mechanic_status_completed': {
      'fr': 'Terminé',
      'en': 'Completed',
      'es': 'Completado',
    },
    'mechanic_status_cancelled': {
      'fr': 'Annulée',
      'en': 'Cancelled',
      'es': 'Cancelada',
    },
    'mechanic_status_disputed': {
      'fr': 'En litige',
      'en': 'Disputed',
      'es': 'En disputa',
    },

    // ---------- Item categories (delivery) ----------
    'cat_furniture': {'fr': 'Meubles', 'en': 'Furniture', 'es': 'Muebles'},
    'cat_appliances': {
      'fr': 'Appareils électroménagers',
      'en': 'Appliances',
      'es': 'Electrodomésticos',
    },
    'cat_marketplace': {
      'fr': 'Achats Marketplace',
      'en': 'Marketplace purchases',
      'es': 'Compras de Marketplace',
    },
    'cat_costco': {
      'fr': 'Achats Costco',
      'en': 'Costco purchases',
      'es': 'Compras de Costco',
    },
    'cat_home_depot': {
      'fr': 'Achats Home Depot',
      'en': 'Home Depot purchases',
      'es': 'Compras de Home Depot',
    },
    'cat_building_materials': {
      'fr': 'Matériaux de construction',
      'en': 'Building materials',
      'es': 'Materiales de construcción',
    },
    'cat_pallets': {'fr': 'Palettes', 'en': 'Pallets', 'es': 'Palets'},
    'cat_equipment': {'fr': 'Équipement', 'en': 'Equipment', 'es': 'Equipo'},
    'cat_bbq': {'fr': 'BBQ', 'en': 'BBQ', 'es': 'Parrilla (BBQ)'},
    'cat_tv': {
      'fr': 'Grand téléviseur',
      'en': 'Large TV',
      'es': 'Televisor grande',
    },
    'cat_boxes': {'fr': 'Boîtes', 'en': 'Boxes', 'es': 'Cajas'},
    'cat_motorcycle': {'fr': 'Moto', 'en': 'Motorcycle', 'es': 'Motocicleta'},
    'cat_atv': {'fr': 'VTT', 'en': 'ATV', 'es': 'Cuatrimoto (VTT)'},
    'cat_small_move': {
      'fr': 'Petit déménagement',
      'en': 'Small move',
      'es': 'Mudanza pequeña',
    },

    // ---------- Mechanic services ----------
    'svc_battery_boost': {
      'fr': 'Survoltage de batterie',
      'en': 'Battery boost',
      'es': 'Arranque de batería',
    },
    'svc_battery_replacement': {
      'fr': 'Remplacement de batterie',
      'en': 'Battery replacement',
      'es': 'Reemplazo de batería',
    },
    'svc_oil_change': {
      'fr': "Changement d'huile",
      'en': 'Oil change',
      'es': 'Cambio de aceite',
    },
    'svc_brakes': {'fr': 'Freins', 'en': 'Brakes', 'es': 'Frenos'},
    'svc_tires': {'fr': 'Pneus', 'en': 'Tires', 'es': 'Neumáticos'},
    'svc_suspension': {
      'fr': 'Suspension',
      'en': 'Suspension',
      'es': 'Suspensión',
    },
    'svc_starter': {
      'fr': 'Démarreur',
      'en': 'Starter',
      'es': 'Motor de arranque',
    },
    'svc_alternator': {
      'fr': 'Alternateur',
      'en': 'Alternator',
      'es': 'Alternador',
    },
    'svc_obd_diagnostic': {
      'fr': 'Diagnostic OBD',
      'en': 'OBD diagnostic',
      'es': 'Diagnóstico OBD',
    },
    'svc_warning_light': {
      'fr': 'Voyant lumineux',
      'en': 'Warning light',
      'es': 'Luz testigo',
    },
    'svc_wont_start': {
      'fr': 'Ne démarre pas',
      'en': "Won't start",
      'es': 'No arranca',
    },
    'svc_noise_vibration': {
      'fr': 'Bruit ou vibration',
      'en': 'Noise or vibration',
      'es': 'Ruido o vibración',
    },
    'svc_pre_purchase_inspection': {
      'fr': 'Inspection pré-achat',
      'en': 'Pre-purchase inspection',
      'es': 'Inspección previa a la compra',
    },
    'svc_roadside_emergency': {
      'fr': 'Urgence routière',
      'en': 'Roadside emergency',
      'es': 'Emergencia en carretera',
    },
    'svc_other': {'fr': 'Autre', 'en': 'Other', 'es': 'Otro'},

    // ---------- Driver recruitment ----------
    'driver_hero_headline': {
      'fr': 'Transformez votre véhicule en revenu.',
      'en': 'Turn your vehicle into income.',
      'es': 'Convierte tu vehículo en ingresos.',
    },
    'driver_hero_sub': {
      'fr':
          "Choisissez votre horaire, définissez votre zone de service et n'acceptez que les livraisons qui vous conviennent.",
      'en':
          'Choose your schedule, define your service area and accept only the delivery jobs that work for you.',
      'es':
          'Elige tu horario, define tu área de servicio y acepta solo los trabajos que te convengan.',
    },
    'driver_pending_verification': {
      'fr': 'En attente de vérification',
      'en': 'Pending verification',
      'es': 'Pendiente de verificación',
    },

    // ---------- Mechanic recruitment ----------
    'mech_provider_hero_headline': {
      'fr': "Plus de demandes. Moins de temps à chercher des clients.",
      'en': 'More jobs. Less time searching for customers.',
      'es': 'Más trabajos. Menos tiempo buscando clientes.',
    },
    'mech_provider_hero_sub': {
      'fr':
          'Définissez votre horaire, choisissez votre zone de service et recevez des demandes pertinentes sans gérer une infinité d\'appels.',
      'en':
          'Set your schedule, choose your service area and receive relevant requests without managing endless phone calls.',
      'es':
          'Establece tu horario, elige tu área de servicio y recibe solicitudes relevantes sin gestionar llamadas interminables.',
    },
    'mech_provider_fr_support': {
      'fr':
          'On vous connecte à nos clients. Vous vous connectez selon votre horaire et acceptez les interventions qui vous conviennent.',
      'en':
          'We connect you with our customers. You log in on your schedule and accept the jobs that suit you.',
      'es':
          'Te conectamos con nuestros clientes. Te conectas según tu horario y aceptas los trabajos que te convengan.',
    },

    // ---------- Pricing / payment ----------
    'pricing_title': {'fr': 'Tarifs', 'en': 'Pricing', 'es': 'Precios'},
    'pricing_mvp_notice': {
      'fr':
          "Au stade actuel, le paiement se fait directement entre le client et le fournisseur.",
      'en':
          'At this stage, payment takes place directly between the customer and the provider.',
      'es':
          'En esta etapa, el pago se realiza directamente entre el cliente y el proveedor.',
    },
    'payment_cash': {'fr': 'Comptant', 'en': 'Cash', 'es': 'Efectivo'},
    'payment_interac': {
      'fr': 'Virement Interac',
      'en': 'Interac e-Transfer',
      'es': 'Transferencia Interac',
    },
    'payment_arrangement': {
      'fr': 'Entente convenue avec le fournisseur',
      'en': 'Payment arrangement confirmed with provider',
      'es': 'Acuerdo de pago confirmado con el proveedor',
    },

    // ---------- Footer / legal ----------
    'footer_rights': {
      'fr': 'Tous droits réservés.',
      'en': 'All rights reserved.',
      'es': 'Todos los derechos reservados.',
    },
    'footer_privacy': {
      'fr': 'Politique de confidentialité',
      'en': 'Privacy Policy',
      'es': 'Política de privacidad',
    },
    'footer_terms': {
      'fr': "Conditions d'utilisation",
      'en': 'Terms of Service',
      'es': 'Términos de servicio',
    },

    // ---------- Trust ----------
    'trust_identity_verified': {
      'fr': 'Identité vérifiée',
      'en': 'Identity verified',
      'es': 'Identidad verificada',
    },
    'trust_documents_verified': {
      'fr': 'Documents vérifiés',
      'en': 'Documents verified',
      'es': 'Documentos verificados',
    },
    'trust_vehicle_verified': {
      'fr': 'Véhicule vérifié',
      'en': 'Vehicle verified',
      'es': 'Vehículo verificado',
    },
    'trust_member_since': {
      'fr': 'Membre depuis',
      'en': 'Member since',
      'es': 'Miembro desde',
    },
    'trust_completed_jobs': {
      'fr': 'Emplois complétés',
      'en': 'Completed jobs',
      'es': 'Trabajos completados',
    },

    // ---------- Testimonials ----------
    'testimonial_placeholder_label': {
      'fr': 'Témoignage exemple — à remplacer par un avis client vérifié',
      'en': 'Example testimonial — replace with verified customer review',
      'es':
          'Testimonio de ejemplo — reemplazar con reseña de cliente verificada',
    },

    // ---------- Vehicle categories (VehicleCategory enum) ----------
    'vehicle_cat_car': {'fr': 'Voiture', 'en': 'Car', 'es': 'Auto'},
    'vehicle_cat_suv': {'fr': 'VUS', 'en': 'SUV', 'es': 'Camioneta SUV'},
    'vehicle_cat_minivan': {
      'fr': 'Fourgonnette',
      'en': 'Minivan',
      'es': 'Minivan',
    },
    'vehicle_cat_cargo_van': {
      'fr': 'Fourgon cargo',
      'en': 'Cargo Van',
      'es': 'Furgoneta de carga',
    },
    'vehicle_cat_pickup_truck': {
      'fr': 'Camionnette',
      'en': 'Pickup Truck',
      'es': 'Camioneta pickup',
    },
    'vehicle_cat_cube_truck': {
      'fr': 'Camion cube',
      'en': 'Cube Truck',
      'es': 'Camión cubo',
    },
    'vehicle_cat_truck': {'fr': 'Camion', 'en': 'Truck', 'es': 'Camión'},
    'vehicle_cat_trailer': {
      'fr': 'Remorque',
      'en': 'Trailer',
      'es': 'Remolque',
    },
    'vehicle_cat_suv_with_trailer': {
      'fr': 'VUS + remorque',
      'en': 'SUV + Trailer',
      'es': 'SUV + remolque',
    },
    'vehicle_cat_small_commercial': {
      'fr': 'Véhicule commercial léger',
      'en': 'Small Commercial Vehicle',
      'es': 'Vehículo comercial ligero',
    },
    'vehicle_cat_other': {'fr': 'Autre', 'en': 'Other', 'es': 'Otro'},

    // ---------- Statuts chauffeur (DriverStatus enum) ----------
    'driver_status_registration_incomplete': {
      'fr': 'Inscription incomplète',
      'en': 'Registration incomplete',
      'es': 'Registro incompleto',
    },
    'driver_status_pending_review': {
      'fr': 'En attente de révision',
      'en': 'Pending review',
      'es': 'Pendiente de revisión',
    },
    'driver_status_documents_required': {
      'fr': 'Documents requis',
      'en': 'Documents required',
      'es': 'Documentos requeridos',
    },
    'driver_status_approved': {
      'fr': 'Approuvé',
      'en': 'Approved',
      'es': 'Aprobado',
    },
    'driver_status_rejected': {
      'fr': 'Refusé',
      'en': 'Rejected',
      'es': 'Rechazado',
    },
    'driver_status_suspended': {
      'fr': 'Suspendu',
      'en': 'Suspended',
      'es': 'Suspendido',
    },
    'driver_status_inactive': {
      'fr': 'Inactif',
      'en': 'Inactive',
      'es': 'Inactivo',
    },

    // ---------- Statuts document (DriverDocumentStatus enum) ----------
    'doc_status_missing': {'fr': 'Manquant', 'en': 'Missing', 'es': 'Faltante'},
    'doc_status_uploaded': {
      'fr': 'Téléversé',
      'en': 'Uploaded',
      'es': 'Cargado',
    },
    'doc_status_pending_review': {
      'fr': 'En attente de révision',
      'en': 'Pending review',
      'es': 'Pendiente de revisión',
    },
    'doc_status_approved': {
      'fr': 'Approuvé',
      'en': 'Approved',
      'es': 'Aprobado',
    },
    'doc_status_rejected': {
      'fr': 'Refusé',
      'en': 'Rejected',
      'es': 'Rechazado',
    },
    'doc_status_expired': {'fr': 'Expiré', 'en': 'Expired', 'es': 'Vencido'},
    'doc_status_replacement_required': {
      'fr': 'Remplacement requis',
      'en': 'Replacement required',
      'es': 'Reemplazo requerido',
    },

    // ---------- Types de document (DriverDocumentType enum) ----------
    'doc_type_drivers_licence': {
      'fr': 'Permis de conduire',
      'en': "Driver's licence",
      'es': 'Licencia de conducir',
    },
    'doc_type_vehicle_registration': {
      'fr': 'Immatriculation',
      'en': 'Vehicle registration',
      'es': 'Matrícula del vehículo',
    },
    'doc_type_insurance': {
      'fr': 'Assurance',
      'en': 'Insurance',
      'es': 'Seguro',
    },
    'doc_type_identity': {
      'fr': "Pièce d'identité",
      'en': 'Identity document',
      'es': 'Documento de identidad',
    },
    'doc_type_vehicle_photo': {
      'fr': 'Photo du véhicule',
      'en': 'Vehicle photo',
      'es': 'Foto del vehículo',
    },
    'doc_type_other': {
      'fr': 'Autre document',
      'en': 'Other document',
      'es': 'Otro documento',
    },

    // ---------- Portail analyste /admin/chauffeurs (Phase 2) ----------
    'admin_drivers_title': {
      'fr': 'Dossiers chauffeurs',
      'en': 'Driver applications',
      'es': 'Expedientes de conductores',
    },
    'admin_drivers_filter_all': {'fr': 'Tous', 'en': 'All', 'es': 'Todos'},
    'admin_drivers_filter_pending_review': {
      'fr': 'En attente',
      'en': 'Pending review',
      'es': 'Pendientes',
    },
    'admin_drivers_filter_documents_required': {
      'fr': 'Documents requis',
      'en': 'Documents required',
      'es': 'Documentos requeridos',
    },
    'admin_drivers_filter_approved': {
      'fr': 'Approuvés',
      'en': 'Approved',
      'es': 'Aprobados',
    },
    'admin_drivers_filter_rejected': {
      'fr': 'Refusés',
      'en': 'Rejected',
      'es': 'Rechazados',
    },
    'admin_drivers_filter_suspended': {
      'fr': 'Suspendus',
      'en': 'Suspended',
      'es': 'Suspendidos',
    },

    'admin_drivers_col_name': {'fr': 'Nom', 'en': 'Name', 'es': 'Nombre'},
    'admin_drivers_col_email': {
      'fr': 'Courriel',
      'en': 'Email',
      'es': 'Correo electrónico',
    },
    'admin_drivers_col_submitted_at': {
      'fr': 'Date de soumission',
      'en': 'Submission date',
      'es': 'Fecha de envío',
    },
    'admin_drivers_col_vehicle': {
      'fr': 'Véhicule',
      'en': 'Vehicle',
      'es': 'Vehículo',
    },
    'admin_drivers_col_status': {
      'fr': 'Statut',
      'en': 'Status',
      'es': 'Estado',
    },
    'admin_drivers_col_missing_docs': {
      'fr': 'Documents manquants',
      'en': 'Missing documents',
      'es': 'Documentos faltantes',
    },
    'admin_drivers_col_pending_docs': {
      'fr': 'Documents en attente',
      'en': 'Pending documents',
      'es': 'Documentos pendientes',
    },
    'admin_drivers_col_updated_at': {
      'fr': 'Dernière mise à jour',
      'en': 'Last update',
      'es': 'Última actualización',
    },

    'admin_drivers_loading': {
      'fr': 'Chargement des dossiers…',
      'en': 'Loading applications…',
      'es': 'Cargando expedientes…',
    },
    'admin_drivers_empty': {
      'fr': 'Aucun dossier chauffeur pour ce filtre.',
      'en': 'No driver applications for this filter.',
      'es': 'No hay expedientes de conductores para este filtro.',
    },
    'admin_drivers_error': {
      'fr': 'Impossible de charger les dossiers chauffeurs.',
      'en': 'Unable to load driver applications.',
      'es': 'No se pudieron cargar los expedientes de conductores.',
    },

    'admin_driver_detail_title': {
      'fr': 'Dossier chauffeur',
      'en': 'Driver application',
      'es': 'Expediente del conductor',
    },
    'admin_driver_section_profile': {
      'fr': 'Profil',
      'en': 'Profile',
      'es': 'Perfil',
    },
    'admin_driver_section_vehicle': {
      'fr': 'Véhicule',
      'en': 'Vehicle',
      'es': 'Vehículo',
    },
    'admin_driver_section_documents': {
      'fr': 'Documents',
      'en': 'Documents',
      'es': 'Documentos',
    },
    'admin_driver_section_notes': {
      'fr': 'Notes internes',
      'en': 'Internal notes',
      'es': 'Notas internas',
    },

    'admin_driver_field_first_name': {
      'fr': 'Prénom',
      'en': 'First name',
      'es': 'Nombre',
    },
    'admin_driver_field_last_name': {
      'fr': 'Nom',
      'en': 'Last name',
      'es': 'Apellido',
    },
    'admin_driver_field_phone': {
      'fr': 'Téléphone',
      'en': 'Phone',
      'es': 'Teléfono',
    },
    'admin_driver_field_email': {
      'fr': 'Courriel',
      'en': 'Email',
      'es': 'Correo electrónico',
    },
    'admin_driver_field_address': {
      'fr': 'Adresse',
      'en': 'Address',
      'es': 'Dirección',
    },
    'admin_driver_field_city': {'fr': 'Ville', 'en': 'City', 'es': 'Ciudad'},
    'admin_driver_field_province': {
      'fr': 'Province',
      'en': 'Province',
      'es': 'Provincia',
    },
    'admin_driver_field_postal_code': {
      'fr': 'Code postal',
      'en': 'Postal code',
      'es': 'Código postal',
    },
    'admin_driver_field_not_available': {
      'fr': 'Non renseigné',
      'en': 'Not provided',
      'es': 'No proporcionado',
    },

    'admin_driver_field_category': {
      'fr': 'Catégorie',
      'en': 'Category',
      'es': 'Categoría',
    },
    'admin_driver_field_make': {'fr': 'Marque', 'en': 'Make', 'es': 'Marca'},
    'admin_driver_field_model': {'fr': 'Modèle', 'en': 'Model', 'es': 'Modelo'},
    'admin_driver_field_year': {'fr': 'Année', 'en': 'Year', 'es': 'Año'},
    'admin_driver_field_color': {'fr': 'Couleur', 'en': 'Color', 'es': 'Color'},
    'admin_driver_field_plate': {'fr': 'Plaque', 'en': 'Plate', 'es': 'Placa'},
    'admin_driver_field_capacity': {
      'fr': 'Capacité',
      'en': 'Capacity',
      'es': 'Capacidad',
    },
    'admin_driver_field_vehicle_verified': {
      'fr': 'Statut de vérification',
      'en': 'Verification status',
      'es': 'Estado de verificación',
    },
    'admin_driver_verified': {
      'fr': 'Vérifié',
      'en': 'Verified',
      'es': 'Verificado',
    },
    'admin_driver_not_verified': {
      'fr': 'Non vérifié',
      'en': 'Not verified',
      'es': 'No verificado',
    },

    'admin_driver_doc_uploaded_at': {
      'fr': 'Date de téléversement',
      'en': 'Upload date',
      'es': 'Fecha de carga',
    },
    'admin_driver_doc_expires_at': {
      'fr': "Date d'expiration",
      'en': 'Expiration date',
      'es': 'Fecha de vencimiento',
    },
    'admin_driver_doc_no_documents': {
      'fr': 'Aucun document téléversé.',
      'en': 'No documents uploaded.',
      'es': 'No se han cargado documentos.',
    },
    'admin_driver_doc_view': {
      'fr': 'Voir le document',
      'en': 'View document',
      'es': 'Ver documento',
    },
    'admin_driver_doc_comment': {
      'fr': 'Commentaire analyste',
      'en': 'Analyst comment',
      'es': 'Comentario del analista',
    },

    'admin_action_approve': {
      'fr': 'Approuver',
      'en': 'Approve',
      'es': 'Aprobar',
    },
    'admin_action_reject': {'fr': 'Refuser', 'en': 'Reject', 'es': 'Rechazar'},
    'admin_action_request_documents': {
      'fr': 'Demander un nouveau document',
      'en': 'Request a new document',
      'es': 'Solicitar un nuevo documento',
    },
    'admin_action_suspend': {
      'fr': 'Suspendre',
      'en': 'Suspend',
      'es': 'Suspender',
    },
    'admin_action_reactivate': {
      'fr': 'Réactiver',
      'en': 'Reactivate',
      'es': 'Reactivar',
    },
    'admin_action_add_note': {
      'fr': 'Ajouter une note',
      'en': 'Add a note',
      'es': 'Agregar una nota',
    },

    'admin_confirm_approve_title': {
      'fr': 'Confirmer l\'approbation',
      'en': 'Confirm approval',
      'es': 'Confirmar aprobación',
    },
    'admin_confirm_approve_body': {
      'fr':
          'Ce chauffeur sera notifié et pourra ensuite décider lui-même de se mettre en ligne.',
      'en':
          'The driver will be notified and can then decide themselves when to go online.',
      'es':
          'Se notificará al conductor, quien luego decidirá por sí mismo cuándo conectarse.',
    },
    'admin_reason_reject_label': {
      'fr': 'Motif du refus',
      'en': 'Rejection reason',
      'es': 'Motivo del rechazo',
    },
    'admin_reason_reject_hint': {
      'fr': 'Expliquez pourquoi ce dossier est refusé…',
      'en': 'Explain why this application is being rejected…',
      'es': 'Explique por qué se rechaza este expediente…',
    },
    'admin_reason_request_documents_label': {
      'fr': 'Document(s) concerné(s) et motif',
      'en': 'Document(s) concerned and reason',
      'es': 'Documento(s) en cuestión y motivo',
    },
    'admin_reason_request_documents_hint': {
      'fr': 'Ex : permis illisible, assurance expirée…',
      'en': 'E.g.: illegible licence, expired insurance…',
      'es': 'Ej.: licencia ilegible, seguro vencido…',
    },
    'admin_reason_suspend_label': {
      'fr': 'Motif de la suspension',
      'en': 'Suspension reason',
      'es': 'Motivo de la suspensión',
    },
    'admin_note_hint': {
      'fr': 'Note interne (jamais visible au chauffeur)…',
      'en': 'Internal note (never visible to the driver)…',
      'es': 'Nota interna (nunca visible para el conductor)…',
    },
    'admin_note_empty': {
      'fr': 'Aucune note interne pour ce dossier.',
      'en': 'No internal notes for this application.',
      'es': 'No hay notas internas para este expediente.',
    },
    'admin_reason_required_error': {
      'fr': 'Un motif est requis (minimum 3 caractères).',
      'en': 'A reason is required (minimum 3 characters).',
      'es': 'Se requiere un motivo (mínimo 3 caracteres).',
    },

    'admin_action_success_approve': {
      'fr': 'Dossier approuvé avec succès.',
      'en': 'Application approved successfully.',
      'es': 'Expediente aprobado con éxito.',
    },
    'admin_action_success_reject': {
      'fr': 'Dossier refusé.',
      'en': 'Application rejected.',
      'es': 'Expediente rechazado.',
    },
    'admin_action_success_request_documents': {
      'fr': 'Demande de document envoyée au chauffeur.',
      'en': 'Document request sent to the driver.',
      'es': 'Solicitud de documento enviada al conductor.',
    },
    'admin_action_success_suspend': {
      'fr': 'Chauffeur suspendu.',
      'en': 'Driver suspended.',
      'es': 'Conductor suspendido.',
    },
    'admin_action_success_reactivate': {
      'fr': 'Chauffeur réactivé.',
      'en': 'Driver reactivated.',
      'es': 'Conductor reactivado.',
    },
    'admin_action_success_note': {
      'fr': 'Note ajoutée.',
      'en': 'Note added.',
      'es': 'Nota agregada.',
    },
    'admin_action_error': {
      'fr': "L'action a échoué. Veuillez réessayer.",
      'en': 'The action failed. Please try again.',
      'es': 'La acción falló. Por favor, inténtelo de nuevo.',
    },

    'admin_no_access_title': {
      'fr': 'Accès refusé',
      'en': 'Access denied',
      'es': 'Acceso denegado',
    },
    'admin_no_access_body': {
      'fr':
          'Vous n\'avez pas les droits nécessaires pour consulter cette page.',
      'en': 'You do not have the required permissions to view this page.',
      'es': 'No tiene los permisos necesarios para ver esta página.',
    },

    'admin_notes_author_you': {'fr': 'Vous', 'en': 'You', 'es': 'Usted'},

    // ---------- Statut chauffeur — vue chauffeur (point 14) ----------
    'driver_status_view_title': {
      'fr': 'Statut de mon dossier',
      'en': 'My application status',
      'es': 'Estado de mi expediente',
    },
    'driver_status_pending_message': {
      'fr':
          'Votre dossier est en cours d\'analyse. Nous vous contacterons dès qu\'une décision sera prise.',
      'en':
          'Your application is under review. We will contact you as soon as a decision is made.',
      'es':
          'Su expediente está siendo revisado. Nos pondremos en contacto tan pronto como se tome una decisión.',
    },
    'driver_status_approved_message': {
      'fr':
          'Félicitations, votre compte chauffeur est approuvé! Vous pouvez maintenant décider quand vous mettre en ligne.',
      'en':
          'Congratulations, your driver account is approved! You can now decide when to go online.',
      'es':
          '¡Felicidades, su cuenta de conductor ha sido aprobada! Ahora puede decidir cuándo conectarse.',
    },
    'driver_status_rejected_message': {
      'fr': 'Votre dossier a été refusé.',
      'en': 'Your application has been rejected.',
      'es': 'Su expediente ha sido rechazado.',
    },
    'driver_status_documents_required_message': {
      'fr':
          'Un ou plusieurs documents doivent être corrigés ou remplacés avant de continuer.',
      'en':
          'One or more documents need to be corrected or replaced before continuing.',
      'es':
          'Uno o más documentos deben ser corregidos o reemplazados antes de continuar.',
    },
    'driver_status_suspended_message': {
      'fr': 'Votre compte chauffeur est temporairement suspendu.',
      'en': 'Your driver account is temporarily suspended.',
      'es': 'Su cuenta de conductor está temporalmente suspendida.',
    },
    'driver_status_reason_label': {
      'fr': 'Motif',
      'en': 'Reason',
      'es': 'Motivo',
    },
    'driver_status_go_to_dashboard': {
      'fr': 'Voir mon tableau de bord',
      'en': 'Go to my dashboard',
      'es': 'Ir a mi panel',
    },
    'driver_status_refresh': {
      'fr': 'Actualiser',
      'en': 'Refresh',
      'es': 'Actualizar',
    },
    'driver_status_registration_incomplete_message': {
      'fr':
          'Votre inscription est incomplète. Terminez votre profil pour soumettre votre candidature.',
      'en':
          'Your registration is incomplete. Complete your profile to submit your application.',
      'es':
          'Su registro está incompleto. Complete su perfil para enviar su solicitud.',
    },
    'driver_status_inactive_message': {
      'fr': 'Votre compte chauffeur est actuellement inactif.',
      'en': 'Your driver account is currently inactive.',
      'es': 'Su cuenta de conductor está actualmente inactiva.',
    },
    'driver_status_error': {
      'fr': 'Impossible de charger le statut de votre dossier pour le moment.',
      'en': 'Unable to load your application status at the moment.',
      'es': 'No se pudo cargar el estado de su expediente en este momento.',
    },
    'driver_status_no_profile': {
      'fr': 'Aucun dossier chauffeur trouvé pour ce compte.',
      'en': 'No driver application found for this account.',
      'es': 'No se encontró ningún expediente de conductor para esta cuenta.',
    },
    'driver_status_complete_registration': {
      'fr': 'Compléter mon inscription',
      'en': 'Complete my registration',
      'es': 'Completar mi inscripción',
    },
    'driver_status_resubmit': {
      'fr': 'Soumettre à nouveau mon dossier',
      'en': 'Resubmit my application',
      'es': 'Volver a enviar mi expediente',
    },
    'driver_status_go_home': {
      'fr': 'Retour à l\'accueil',
      'en': 'Back to home',
      'es': 'Volver al inicio',
    },
    'driver_status_online_label': {
      'fr': 'Vous êtes en ligne',
      'en': 'You are online',
      'es': 'Está en línea',
    },
    'driver_status_offline_label': {
      'fr': 'Vous êtes hors ligne',
      'en': 'You are offline',
      'es': 'Está desconectado',
    },

    // ---------- Bloc J — Finance client (Phase 6) ----------
    'finance_section_title': {
      'fr': 'Détails financiers',
      'en': 'Financial details',
      'es': 'Detalles financieros',
    },
    'finance_summary_title': {'fr': 'Résumé', 'en': 'Summary', 'es': 'Resumen'},
    'finance_summary_mission_price': {
      'fr': 'Prix de la mission',
      'en': 'Mission price',
      'es': 'Precio de la misión',
    },
    'finance_summary_fees': {'fr': 'Frais', 'en': 'Fees', 'es': 'Cargos'},
    'finance_summary_taxes': {'fr': 'Taxes', 'en': 'Taxes', 'es': 'Impuestos'},
    'finance_summary_tip': {'fr': 'Pourboire', 'en': 'Tip', 'es': 'Propina'},
    'finance_summary_total': {'fr': 'Total', 'en': 'Total', 'es': 'Total'},
    'finance_payment_title': {'fr': 'Paiement', 'en': 'Payment', 'es': 'Pago'},
    'finance_payment_authorized_amount': {
      'fr': 'Montant autorisé',
      'en': 'Authorized amount',
      'es': 'Monto autorizado',
    },
    'finance_payment_captured_amount': {
      'fr': 'Montant capturé',
      'en': 'Captured amount',
      'es': 'Monto capturado',
    },
    'finance_payment_date': {'fr': 'Date', 'en': 'Date', 'es': 'Fecha'},
    'finance_payment_none': {
      'fr': 'Aucun paiement enregistré pour cette mission.',
      'en': 'No payment recorded for this mission.',
      'es': 'No hay ningún pago registrado para esta misión.',
    },
    'finance_refund_title': {
      'fr': 'Remboursement',
      'en': 'Refund',
      'es': 'Reembolso',
    },
    'finance_refund_none': {
      'fr': 'Aucun remboursement',
      'en': 'No refund',
      'es': 'Sin reembolso',
    },
    'finance_refund_partial': {
      'fr': 'Remboursement partiel',
      'en': 'Partial refund',
      'es': 'Reembolso parcial',
    },
    'finance_refund_full': {
      'fr': 'Remboursé',
      'en': 'Refunded',
      'es': 'Reembolsado',
    },
    'finance_refund_amount': {
      'fr': 'Montant remboursé',
      'en': 'Refunded amount',
      'es': 'Monto reembolsado',
    },
    'finance_history_title': {
      'fr': 'Historique',
      'en': 'History',
      'es': 'Historial',
    },
    'finance_history_empty': {
      'fr': 'Aucun mouvement à afficher.',
      'en': 'No activity to display.',
      'es': 'No hay movimientos para mostrar.',
    },
    'finance_loading': {
      'fr': 'Chargement des données financières…',
      'en': 'Loading financial data…',
      'es': 'Cargando datos financieros…',
    },
    'finance_error': {
      'fr': 'Impossible de charger les données financières.',
      'en': 'Unable to load financial data.',
      'es': 'No se pudieron cargar los datos financieros.',
    },
    'finance_receipt_title': {'fr': 'Reçu', 'en': 'Receipt', 'es': 'Recibo'},
    'finance_receipt_final_balance': {
      'fr': 'Solde final',
      'en': 'Final balance',
      'es': 'Saldo final',
    },
    'finance_view_receipt': {
      'fr': 'Voir le reçu',
      'en': 'View receipt',
      'es': 'Ver recibo',
    },

    // Statuts client (Bloc J point 9) — clés i18n dédiées, indépendantes de
    // `PaymentStatus` Dart (mapping fait par `PaymentDisplayStatus`, voir
    // lib/finance/presentation/payment_display_status.dart), afin de rester
    // compatible avec le futur Bloc M (i18n) sans dépendre de la machine
    // d'état interne complète (created/authorization_pending/etc. sont
    // regroupés en un nombre réduit d'états compréhensibles pour un client).
    'finance_status_pending': {
      'fr': 'Paiement en attente',
      'en': 'Payment pending',
      'es': 'Pago pendiente',
    },
    'finance_status_authorized': {
      'fr': 'Paiement autorisé',
      'en': 'Payment authorized',
      'es': 'Pago autorizado',
    },
    'finance_status_confirmed': {
      'fr': 'Paiement confirmé',
      'en': 'Payment confirmed',
      'es': 'Pago confirmado',
    },
    'finance_status_failed': {
      'fr': 'Paiement échoué',
      'en': 'Payment failed',
      'es': 'Pago fallido',
    },
    'finance_status_partially_refunded': {
      'fr': 'Remboursement partiel',
      'en': 'Partially refunded',
      'es': 'Reembolso parcial',
    },
    'finance_status_refunded': {
      'fr': 'Remboursé',
      'en': 'Refunded',
      'es': 'Reembolsado',
    },

    // ---------- Bloc K — Finance chauffeur (Phase 6) ----------
    'payout_section_title': {
      'fr': 'Versements',
      'en': 'Payouts',
      'es': 'Pagos',
    },
    'payout_summary_title': {
      'fr': 'Résumé des gains',
      'en': 'Earnings summary',
      'es': 'Resumen de ganancias',
    },
    'payout_summary_available': {
      'fr': 'Gains disponibles',
      'en': 'Available earnings',
      'es': 'Ganancias disponibles',
    },
    'payout_summary_pending': {
      'fr': 'Gains en attente',
      'en': 'Pending earnings',
      'es': 'Ganancias pendientes',
    },
    'payout_summary_paid': {
      'fr': 'Versements payés',
      'en': 'Paid payouts',
      'es': 'Pagos realizados',
    },
    'payout_missions_title': {
      'fr': 'Missions',
      'en': 'Missions',
      'es': 'Misiones',
    },
    'payout_missions_empty': {
      'fr': 'Aucune mission facturée pour le moment.',
      'en': 'No billed missions yet.',
      'es': 'Ninguna misión facturada por el momento.',
    },
    'payout_mission_offer_amount': {
      'fr': 'Montant offert',
      'en': 'Offer amount',
      'es': 'Monto ofrecido',
    },
    'payout_mission_bonus': {'fr': 'Bonus', 'en': 'Bonus', 'es': 'Bono'},
    'payout_mission_tip': {
      'fr': 'Pourboire (100% à vous)',
      'en': 'Tip (100% yours)',
      'es': 'Propina (100% para usted)',
    },
    'payout_mission_net': {
      'fr': 'Gain net',
      'en': 'Net earnings',
      'es': 'Ganancia neta',
    },
    'payout_list_title': {
      'fr': 'Historique des versements',
      'en': 'Payout history',
      'es': 'Historial de pagos',
    },
    'payout_list_empty': {
      'fr': 'Aucun versement pour le moment.',
      'en': 'No payouts yet.',
      'es': 'Ningún pago por el momento.',
    },
    'payout_amount': {'fr': 'Montant', 'en': 'Amount', 'es': 'Monto'},
    'payout_created_at': {
      'fr': 'Créé le',
      'en': 'Created on',
      'es': 'Creado el',
    },
    'payout_hold_period': {
      'fr': 'Période de rétention',
      'en': 'Hold period',
      'es': 'Período de retención',
    },
    'payout_hours_suffix': {'fr': 'heures', 'en': 'hours', 'es': 'horas'},
    'payout_eligible_at': {
      'fr': 'Disponible à partir du',
      'en': 'Available from',
      'es': 'Disponible a partir del',
    },
    'payout_paid_at': {'fr': 'Payé le', 'en': 'Paid on', 'es': 'Pagado el'},
    'payout_held_message': {
      'fr': 'En attente de versement — disponible à partir du',
      'en': 'Awaiting payout — available from',
      'es': 'A la espera del pago — disponible a partir del',
    },
    'payout_failed_message': {
      'fr':
          'Ce versement a échoué. Notre équipe a été notifiée et le traitera sous peu.',
      'en':
          'This payout failed. Our team has been notified and will process it shortly.',
      'es':
          'Este pago falló. Nuestro equipo ha sido notificado y lo procesará en breve.',
    },
    'payout_reversed_message': {
      'fr': 'Ce versement a été renversé.',
      'en': 'This payout was reversed.',
      'es': 'Este pago fue revertido.',
    },
    'payout_reversal_reason': {'fr': 'Raison', 'en': 'Reason', 'es': 'Motivo'},
    'payout_loading': {
      'fr': 'Chargement des versements…',
      'en': 'Loading payouts…',
      'es': 'Cargando pagos…',
    },
    'payout_error': {
      'fr': 'Impossible de charger les versements.',
      'en': 'Unable to load payouts.',
      'es': 'No se pudieron cargar los pagos.',
    },

    // Statuts payout (Bloc K point 5) — clés i18n dédiées, compatibles
    // avec le futur Bloc M, indépendantes du nom d'enum interne
    // `PayoutStatus` (mapping fait par PayoutDisplayStatus, voir
    // lib/finance/presentation/payout_display_status.dart).
    'payout_status_pending': {
      'fr': 'En attente',
      'en': 'Pending',
      'es': 'Pendiente',
    },
    'payout_status_held': {
      'fr': 'En période de retenue',
      'en': 'On hold',
      'es': 'En período de retención',
    },
    'payout_status_eligible': {
      'fr': 'Prêt pour versement',
      'en': 'Ready for payout',
      'es': 'Listo para el pago',
    },
    'payout_status_scheduled': {
      'fr': 'Versement planifié',
      'en': 'Payout scheduled',
      'es': 'Pago programado',
    },
    'payout_status_processing': {
      'fr': 'Versement en traitement',
      'en': 'Payout processing',
      'es': 'Pago en proceso',
    },
    'payout_status_paid': {'fr': 'Payé', 'en': 'Paid', 'es': 'Pagado'},
    'payout_status_failed': {
      'fr': 'Échec du versement',
      'en': 'Payout failed',
      'es': 'Pago fallido',
    },
    'payout_status_reversed': {
      'fr': 'Versement renversé',
      'en': 'Payout reversed',
      'es': 'Pago revertido',
    },

    // ---------- Bloc L — UI admin finance (Phase 6) ----------
    'admin_finance_title': {
      'fr': 'Centre financier',
      'en': 'Finance center',
      'es': 'Centro financiero',
    },
    'admin_finance_tab_payments': {
      'fr': 'Paiements',
      'en': 'Payments',
      'es': 'Pagos',
    },
    'admin_finance_tab_refunds': {
      'fr': 'Remboursements',
      'en': 'Refunds',
      'es': 'Reembolsos',
    },
    'admin_finance_tab_payouts': {
      'fr': 'Versements',
      'en': 'Payouts',
      'es': 'Pagos a conductores',
    },
    'admin_finance_tab_disputes': {
      'fr': 'Litiges',
      'en': 'Disputes',
      'es': 'Disputas',
    },
    'admin_finance_tab_ledger': {
      'fr': 'Registre',
      'en': 'Ledger',
      'es': 'Libro mayor',
    },
    'admin_finance_tab_reconciliation': {
      'fr': 'Réconciliation',
      'en': 'Reconciliation',
      'es': 'Reconciliación',
    },
    'admin_finance_tab_taxes': {
      'fr': 'Taxes',
      'en': 'Taxes',
      'es': 'Impuestos',
    },
    'admin_finance_tab_payout_policy': {
      'fr': 'Politique de versement',
      'en': 'Payout policy',
      'es': 'Política de pagos',
    },
    'admin_finance_loading': {
      'fr': 'Chargement des données financières…',
      'en': 'Loading financial data…',
      'es': 'Cargando datos financieros…',
    },
    'admin_finance_empty': {
      'fr': 'Aucune donnée pour le moment.',
      'en': 'No data yet.',
      'es': 'Aún no hay datos.',
    },
    'admin_finance_error': {
      'fr': 'Impossible de charger les données. Réessayez.',
      'en': 'Unable to load data. Please retry.',
      'es': 'No se pudieron cargar los datos. Reintente.',
    },
    'admin_finance_permission_denied': {
      'fr':
          'Accès refusé. Votre rôle ne permet pas de consulter cette section.',
      'en': 'Access denied. Your role cannot view this section.',
      'es': 'Acceso denegado. Su rol no permite ver esta sección.',
    },
    'admin_finance_filter_all': {'fr': 'Tous', 'en': 'All', 'es': 'Todos'},
    'admin_finance_retry': {
      'fr': 'Réessayer',
      'en': 'Retry',
      'es': 'Reintentar',
    },
    'admin_finance_action_admin_only': {
      'fr': 'Réservé aux administrateurs',
      'en': 'Admin only',
      'es': 'Solo para administradores',
    },

    // ---- Payments ----
    'admin_payments_col_id': {
      'fr': 'ID paiement',
      'en': 'Payment ID',
      'es': 'ID de pago',
    },
    'admin_payments_col_mission': {
      'fr': 'Mission',
      'en': 'Mission',
      'es': 'Misión',
    },
    'admin_payments_col_customer': {
      'fr': 'Client',
      'en': 'Customer',
      'es': 'Cliente',
    },
    'admin_payments_col_status': {
      'fr': 'Statut',
      'en': 'Status',
      'es': 'Estado',
    },
    'admin_payments_col_authorized': {
      'fr': 'Autorisé',
      'en': 'Authorized',
      'es': 'Autorizado',
    },
    'admin_payments_col_captured': {
      'fr': 'Capturé',
      'en': 'Captured',
      'es': 'Capturado',
    },
    'admin_payments_col_refunded': {
      'fr': 'Remboursé',
      'en': 'Refunded',
      'es': 'Reembolsado',
    },
    'admin_payments_col_provider': {
      'fr': 'Fournisseur',
      'en': 'Provider',
      'es': 'Proveedor',
    },
    'admin_payments_col_date': {'fr': 'Date', 'en': 'Date', 'es': 'Fecha'},
    'admin_payment_detail_title': {
      'fr': 'Détail du paiement',
      'en': 'Payment detail',
      'es': 'Detalle del pago',
    },
    'admin_payment_detail_mission': {
      'fr': 'Mission liée',
      'en': 'Linked mission',
      'es': 'Misión vinculada',
    },
    'admin_payment_detail_snapshot': {
      'fr': 'Solde financier',
      'en': 'Financial balance',
      'es': 'Balance financiero',
    },
    'admin_payment_detail_refunds': {
      'fr': 'Remboursements liés',
      'en': 'Linked refunds',
      'es': 'Reembolsos vinculados',
    },
    'admin_payment_detail_ledger': {
      'fr': 'Écritures liées',
      'en': 'Related ledger entries',
      'es': 'Entradas relacionadas',
    },
    'admin_payment_detail_disputes': {
      'fr': 'Litiges liés',
      'en': 'Linked disputes',
      'es': 'Disputas vinculadas',
    },
    'admin_payment_action_refund': {
      'fr': 'Rembourser',
      'en': 'Refund',
      'es': 'Reembolsar',
    },

    // ---- Refunds ----
    'admin_refunds_col_id': {
      'fr': 'ID remboursement',
      'en': 'Refund ID',
      'es': 'ID de reembolso',
    },
    'admin_refunds_col_payment': {
      'fr': 'Paiement',
      'en': 'Payment',
      'es': 'Pago',
    },
    'admin_refunds_col_amount': {
      'fr': 'Montant',
      'en': 'Amount',
      'es': 'Monto',
    },
    'admin_refunds_col_status': {
      'fr': 'Statut',
      'en': 'Status',
      'es': 'Estado',
    },
    'admin_refunds_col_reason': {'fr': 'Motif', 'en': 'Reason', 'es': 'Motivo'},
    'admin_refunds_col_requested_at': {
      'fr': 'Demandé le',
      'en': 'Requested on',
      'es': 'Solicitado el',
    },
    'admin_refunds_col_processed_at': {
      'fr': 'Traité le',
      'en': 'Processed on',
      'es': 'Procesado el',
    },

    // ---- Payouts ----
    'admin_payouts_col_driver': {
      'fr': 'Chauffeur',
      'en': 'Driver',
      'es': 'Conductor',
    },
    'admin_payouts_col_id': {
      'fr': 'ID versement',
      'en': 'Payout ID',
      'es': 'ID de pago',
    },
    'admin_payouts_col_amount': {
      'fr': 'Montant',
      'en': 'Amount',
      'es': 'Monto',
    },
    'admin_payouts_col_status': {
      'fr': 'Statut',
      'en': 'Status',
      'es': 'Estado',
    },
    'admin_payouts_col_hold': {
      'fr': 'Période de rétention',
      'en': 'Hold period',
      'es': 'Período de retención',
    },
    'admin_payouts_col_eligible_at': {
      'fr': 'Éligible le',
      'en': 'Eligible at',
      'es': 'Elegible el',
    },
    'admin_payouts_col_provider_id': {
      'fr': 'ID fournisseur',
      'en': 'Provider ID',
      'es': 'ID del proveedor',
    },
    'admin_payouts_col_paid_at': {
      'fr': 'Payé le',
      'en': 'Paid at',
      'es': 'Pagado el',
    },
    'admin_payouts_col_failed_at': {
      'fr': 'Échoué le',
      'en': 'Failed at',
      'es': 'Fallido el',
    },
    'admin_payouts_col_reversed_at': {
      'fr': 'Renversé le',
      'en': 'Reversed at',
      'es': 'Revertido el',
    },
    'admin_payout_action_reverse': {
      'fr': 'Renverser',
      'en': 'Reverse',
      'es': 'Revertir',
    },
    'admin_payout_reverse_reason_label': {
      'fr': 'Motif du renversement (obligatoire)',
      'en': 'Reversal reason (required)',
      'es': 'Motivo de reversión (obligatorio)',
    },
    'admin_payout_reverse_confirm': {
      'fr': 'Confirmer le renversement',
      'en': 'Confirm reversal',
      'es': 'Confirmar reversión',
    },
    'admin_payout_reverse_success': {
      'fr': 'Versement renversé avec succès.',
      'en': 'Payout reversed successfully.',
      'es': 'Pago revertido correctamente.',
    },

    // ---- Disputes ----
    'admin_disputes_col_id': {
      'fr': 'ID litige',
      'en': 'Dispute ID',
      'es': 'ID de disputa',
    },
    'admin_disputes_col_payment': {
      'fr': 'Paiement',
      'en': 'Payment',
      'es': 'Pago',
    },
    'admin_disputes_col_mission': {
      'fr': 'Mission',
      'en': 'Mission',
      'es': 'Misión',
    },
    'admin_disputes_col_amount': {
      'fr': 'Montant',
      'en': 'Amount',
      'es': 'Monto',
    },
    'admin_disputes_col_reason': {
      'fr': 'Motif',
      'en': 'Reason',
      'es': 'Motivo',
    },
    'admin_disputes_col_status': {
      'fr': 'Statut',
      'en': 'Status',
      'es': 'Estado',
    },
    'admin_disputes_col_opened_at': {
      'fr': 'Ouvert le',
      'en': 'Opened at',
      'es': 'Abierto el',
    },
    'admin_disputes_col_evidence_due': {
      'fr': 'Preuves dues le',
      'en': 'Evidence due',
      'es': 'Evidencia requerida',
    },
    'admin_disputes_col_updated_at': {
      'fr': 'Mis à jour le',
      'en': 'Updated at',
      'es': 'Actualizado el',
    },
    'dispute_status_opened': {'fr': 'Ouvert', 'en': 'Opened', 'es': 'Abierto'},
    'dispute_status_under_review': {
      'fr': 'En révision',
      'en': 'Under review',
      'es': 'En revisión',
    },
    'dispute_status_won': {'fr': 'Gagné', 'en': 'Won', 'es': 'Ganado'},
    'dispute_status_lost': {'fr': 'Perdu', 'en': 'Lost', 'es': 'Perdido'},
    'dispute_status_reversed': {
      'fr': 'Renversé',
      'en': 'Reversed',
      'es': 'Revertido',
    },
    'dispute_status_closed': {'fr': 'Clôturé', 'en': 'Closed', 'es': 'Cerrado'},

    // ---- Ledger ----
    'admin_ledger_col_date': {'fr': 'Date', 'en': 'Date', 'es': 'Fecha'},
    'admin_ledger_col_type': {'fr': 'Type', 'en': 'Type', 'es': 'Tipo'},
    'admin_ledger_col_mission': {
      'fr': 'Mission',
      'en': 'Mission',
      'es': 'Misión',
    },
    'admin_ledger_col_party': {'fr': 'Partie', 'en': 'Party', 'es': 'Parte'},
    'admin_ledger_col_amount': {'fr': 'Montant', 'en': 'Amount', 'es': 'Monto'},
    'admin_ledger_col_currency': {
      'fr': 'Devise',
      'en': 'Currency',
      'es': 'Moneda',
    },
    'admin_ledger_col_reference': {
      'fr': 'Référence',
      'en': 'Reference',
      'es': 'Referencia',
    },
    'admin_ledger_col_source': {'fr': 'Source', 'en': 'Source', 'es': 'Origen'},
    'admin_ledger_adjustment_title': {
      'fr': 'Nouvel ajustement financier',
      'en': 'New financial adjustment',
      'es': 'Nuevo ajuste financiero',
    },
    'admin_ledger_adjustment_notice': {
      'fr':
          'Ceci créera une NOUVELLE entrée compensatoire. L\'historique existant n\'est jamais modifié.',
      'en':
          'This will create a NEW compensating entry. Existing history is never modified.',
      'es':
          'Esto creará una NUEVA entrada compensatoria. El historial existente nunca se modifica.',
    },
    'admin_ledger_adjustment_amount': {
      'fr': 'Montant',
      'en': 'Amount',
      'es': 'Monto',
    },
    'admin_ledger_adjustment_type': {
      'fr': 'Type d\'entrée',
      'en': 'Entry type',
      'es': 'Tipo de entrada',
    },
    'admin_ledger_adjustment_reason': {
      'fr': 'Motif (recommandé)',
      'en': 'Reason (recommended)',
      'es': 'Motivo (recomendado)',
    },
    'admin_ledger_adjustment_create': {
      'fr': 'Créer l\'ajustement',
      'en': 'Create adjustment',
      'es': 'Crear ajuste',
    },
    'admin_ledger_adjustment_success': {
      'fr': 'Ajustement créé avec succès.',
      'en': 'Adjustment created successfully.',
      'es': 'Ajuste creado correctamente.',
    },

    // ---- Reconciliation ----
    'admin_reconciliation_open': {
      'fr': 'Ouvertes',
      'en': 'Open',
      'es': 'Abiertas',
    },
    'admin_reconciliation_critical': {
      'fr': 'Critiques',
      'en': 'Critical',
      'es': 'Críticas',
    },
    'admin_reconciliation_warning': {
      'fr': 'Avertissements',
      'en': 'Warnings',
      'es': 'Advertencias',
    },
    'admin_reconciliation_resolved': {
      'fr': 'Résolues',
      'en': 'Resolved',
      'es': 'Resueltas',
    },
    'admin_reconciliation_col_severity': {
      'fr': 'Sévérité',
      'en': 'Severity',
      'es': 'Severidad',
    },
    'admin_reconciliation_col_type': {'fr': 'Type', 'en': 'Type', 'es': 'Tipo'},
    'admin_reconciliation_col_mission': {
      'fr': 'Mission',
      'en': 'Mission',
      'es': 'Misión',
    },
    'admin_reconciliation_col_payment': {
      'fr': 'Paiement',
      'en': 'Payment',
      'es': 'Pago',
    },
    'admin_reconciliation_col_expected': {
      'fr': 'Attendu',
      'en': 'Expected',
      'es': 'Esperado',
    },
    'admin_reconciliation_col_actual': {
      'fr': 'Réel',
      'en': 'Actual',
      'es': 'Real',
    },
    'admin_reconciliation_col_detected_at': {
      'fr': 'Détecté le',
      'en': 'Detected at',
      'es': 'Detectado el',
    },
    'admin_reconciliation_col_status': {
      'fr': 'Statut',
      'en': 'Status',
      'es': 'Estado',
    },
    'admin_reconciliation_run_now': {
      'fr': 'Lancer une réconciliation',
      'en': 'Run reconciliation now',
      'es': 'Ejecutar reconciliación',
    },
    'admin_reconciliation_run_success': {
      'fr': 'Réconciliation lancée avec succès.',
      'en': 'Reconciliation run successfully.',
      'es': 'Reconciliación ejecutada correctamente.',
    },
    'admin_reconciliation_resolve': {
      'fr': 'Résoudre',
      'en': 'Resolve',
      'es': 'Resolver',
    },
    'admin_reconciliation_acknowledge': {
      'fr': 'Accuser réception',
      'en': 'Acknowledge',
      'es': 'Reconocer',
    },
    'admin_reconciliation_resolution_notes': {
      'fr': 'Notes de résolution (obligatoire)',
      'en': 'Resolution notes (required)',
      'es': 'Notas de resolución (obligatorio)',
    },
    'anomaly_status_open': {'fr': 'Ouverte', 'en': 'Open', 'es': 'Abierta'},
    'anomaly_status_acknowledged': {
      'fr': 'Accusée réception',
      'en': 'Acknowledged',
      'es': 'Reconocida',
    },
    'anomaly_status_resolved': {
      'fr': 'Résolue',
      'en': 'Resolved',
      'es': 'Resuelta',
    },
    'anomaly_severity_info': {'fr': 'Info', 'en': 'Info', 'es': 'Info'},
    'anomaly_severity_warning': {
      'fr': 'Avertissement',
      'en': 'Warning',
      'es': 'Advertencia',
    },
    'anomaly_severity_critical': {
      'fr': 'Critique',
      'en': 'Critical',
      'es': 'Crítica',
    },

    // ---- Taxes ----
    'admin_taxes_col_jurisdiction': {
      'fr': 'Juridiction',
      'en': 'Jurisdiction',
      'es': 'Jurisdicción',
    },
    'admin_taxes_col_tax_code': {
      'fr': 'Code taxe',
      'en': 'Tax code',
      'es': 'Código de impuesto',
    },
    'admin_taxes_col_rate': {'fr': 'Taux', 'en': 'Rate', 'es': 'Tasa'},
    'admin_taxes_col_components': {
      'fr': 'Composants taxables',
      'en': 'Taxable components',
      'es': 'Componentes gravables',
    },
    'admin_taxes_col_effective_from': {
      'fr': 'Effectif à partir de',
      'en': 'Effective from',
      'es': 'Vigente desde',
    },
    'admin_taxes_col_effective_until': {
      'fr': 'Effectif jusqu\'à',
      'en': 'Effective until',
      'es': 'Vigente hasta',
    },
    'admin_taxes_col_enabled': {
      'fr': 'Activé',
      'en': 'Enabled',
      'es': 'Habilitado',
    },
    'admin_taxes_col_version': {
      'fr': 'Version',
      'en': 'Version',
      'es': 'Versión',
    },
    'admin_taxes_new_config': {
      'fr': 'Nouvelle configuration fiscale',
      'en': 'New tax configuration',
      'es': 'Nueva configuración fiscal',
    },
    'admin_taxes_new_config_notice': {
      'fr':
          'Ceci créera une NOUVELLE version. Les valeurs fiscales réelles doivent être validées séparément — cette interface ne présume aucun taux.',
      'en':
          'This will create a NEW version. Real tax values must be validated separately — this UI does not assume any rate.',
      'es':
          'Esto creará una NUEVA versión. Los valores fiscales reales deben validarse por separado — esta interfaz no asume ninguna tasa.',
    },
    'admin_taxes_save': {
      'fr': 'Enregistrer la nouvelle version',
      'en': 'Save new version',
      'es': 'Guardar nueva versión',
    },
    'admin_taxes_save_success': {
      'fr': 'Configuration fiscale créée avec succès.',
      'en': 'Tax configuration created successfully.',
      'es': 'Configuración fiscal creada correctamente.',
    },

    // ---- Payout Policy ----
    'admin_payout_policy_default': {
      'fr': 'Rétention standard (heures)',
      'en': 'Default hold (hours)',
      'es': 'Retención estándar (horas)',
    },
    'admin_payout_policy_new_driver': {
      'fr': 'Rétention nouveau chauffeur (heures)',
      'en': 'New driver hold (hours)',
      'es': 'Retención nuevo conductor (horas)',
    },
    'admin_payout_policy_risky_driver': {
      'fr': 'Rétention chauffeur à risque/suspendu (heures)',
      'en': 'Risky/suspended driver hold (hours)',
      'es': 'Retención conductor riesgoso/suspendido (horas)',
    },
    'admin_payout_policy_updated_at': {
      'fr': 'Dernière mise à jour',
      'en': 'Last updated',
      'es': 'Última actualización',
    },
    'admin_payout_policy_save': {
      'fr': 'Enregistrer la politique',
      'en': 'Save policy',
      'es': 'Guardar política',
    },
    'admin_payout_policy_save_success': {
      'fr': 'Politique de versement mise à jour.',
      'en': 'Payout policy updated.',
      'es': 'Política de pagos actualizada.',
    },

    // ---- Bloc L (étape 2/N) — statuts détaillés admin, non résumés ----
    // (contrairement à `finance_status_*`, ces clés couvrent la machine
    // d'état SERVEUR complète, réservée à l'affichage admin.)
    'admin_payment_status_pending': {
      'fr': 'En attente',
      'en': 'Pending',
      'es': 'Pendiente',
    },
    'admin_payment_status_created': {
      'fr': 'Créé',
      'en': 'Created',
      'es': 'Creado',
    },
    'admin_payment_status_requires_payment_method': {
      'fr': 'Moyen de paiement requis',
      'en': 'Requires payment method',
      'es': 'Requiere método de pago',
    },
    'admin_payment_status_authorization_pending': {
      'fr': 'Autorisation en cours',
      'en': 'Authorization pending',
      'es': 'Autorización pendiente',
    },
    'admin_payment_status_authorized': {
      'fr': 'Autorisé',
      'en': 'Authorized',
      'es': 'Autorizado',
    },
    'admin_payment_status_capture_pending': {
      'fr': 'Capture en cours',
      'en': 'Capture pending',
      'es': 'Captura pendiente',
    },
    'admin_payment_status_captured': {
      'fr': 'Capturé',
      'en': 'Captured',
      'es': 'Capturado',
    },
    'admin_payment_status_failed': {
      'fr': 'Échoué',
      'en': 'Failed',
      'es': 'Fallido',
    },
    'admin_payment_status_cancelled': {
      'fr': 'Annulé',
      'en': 'Cancelled',
      'es': 'Cancelado',
    },
    'admin_payment_status_refunded': {
      'fr': 'Remboursé',
      'en': 'Refunded',
      'es': 'Reembolsado',
    },
    'admin_payment_status_partially_refunded': {
      'fr': 'Partiellement remboursé',
      'en': 'Partially refunded',
      'es': 'Parcialmente reembolsado',
    },
    'admin_payment_status_disputed': {
      'fr': 'En litige',
      'en': 'Disputed',
      'es': 'En disputa',
    },
    'admin_payment_status_chargeback': {
      'fr': 'Rétrofacturation',
      'en': 'Chargeback',
      'es': 'Contracargo',
    },

    'admin_refund_status_requested': {
      'fr': 'Demandé',
      'en': 'Requested',
      'es': 'Solicitado',
    },
    'admin_refund_status_processing': {
      'fr': 'En traitement',
      'en': 'Processing',
      'es': 'En proceso',
    },
    'admin_refund_status_succeeded': {
      'fr': 'Réussi',
      'en': 'Succeeded',
      'es': 'Exitoso',
    },
    'admin_refund_status_failed': {
      'fr': 'Échoué',
      'en': 'Failed',
      'es': 'Fallido',
    },

    'admin_refund_reason_customer_request': {
      'fr': 'Demande du client',
      'en': 'Customer request',
      'es': 'Solicitud del cliente',
    },
    'admin_refund_reason_cancelled_before_pickup': {
      'fr': 'Annulé avant la collecte',
      'en': 'Cancelled before pickup',
      'es': 'Cancelado antes de la recogida',
    },
    'admin_refund_reason_cancelled_after_pickup': {
      'fr': 'Annulé après la collecte',
      'en': 'Cancelled after pickup',
      'es': 'Cancelado después de la recogida',
    },
    'admin_refund_reason_payment_error': {
      'fr': 'Erreur de paiement',
      'en': 'Payment error',
      'es': 'Error de pago',
    },
    'admin_refund_reason_goodwill': {
      'fr': 'Geste commercial',
      'en': 'Goodwill',
      'es': 'Gesto comercial',
    },
    'admin_refund_reason_administrative': {
      'fr': 'Administratif',
      'en': 'Administrative',
      'es': 'Administrativo',
    },
    'admin_refund_reason_mission_impossible': {
      'fr': 'Mission impossible',
      'en': 'Mission impossible',
      'es': 'Misión imposible',
    },
    'admin_refund_reason_partial_delivery': {
      'fr': 'Livraison partielle',
      'en': 'Partial delivery',
      'es': 'Entrega parcial',
    },
    'admin_refund_reason_no_show': {
      'fr': 'Absence au rendez-vous',
      'en': 'No-show',
      'es': 'No presentado',
    },

    // ---- Ledger : types manquants (complète ledger_type_* du Bloc K) ----
    'ledger_type_customer_charge': {
      'fr': 'Charge client',
      'en': 'Customer charge',
      'es': 'Cargo al cliente',
    },
    'ledger_type_customer_service_fee': {
      'fr': 'Frais de service client',
      'en': 'Customer service fee',
      'es': 'Tarifa de servicio al cliente',
    },
    'ledger_type_platform_commission': {
      'fr': 'Commission plateforme',
      'en': 'Platform commission',
      'es': 'Comisión de la plataforma',
    },
    'ledger_type_tax': {'fr': 'Taxe', 'en': 'Tax', 'es': 'Impuesto'},
    'ledger_type_payment_processing_fee': {
      'fr': 'Frais de traitement du paiement',
      'en': 'Payment processing fee',
      'es': 'Tarifa de procesamiento de pago',
    },
    'ledger_type_payout_processing_fee': {
      'fr': 'Frais de traitement du versement',
      'en': 'Payout processing fee',
      'es': 'Tarifa de procesamiento de pago a conductor',
    },
    'ledger_type_insurance_cost': {
      'fr': 'Coût d\'assurance',
      'en': 'Insurance cost',
      'es': 'Costo de seguro',
    },
    'ledger_type_customer_adjustment': {
      'fr': 'Ajustement client',
      'en': 'Customer adjustment',
      'es': 'Ajuste del cliente',
    },

    'admin_ledger_party_customer': {
      'fr': 'Client',
      'en': 'Customer',
      'es': 'Cliente',
    },
    'admin_ledger_party_driver': {
      'fr': 'Chauffeur',
      'en': 'Driver',
      'es': 'Conductor',
    },
    'admin_ledger_party_platform': {
      'fr': 'Plateforme',
      'en': 'Platform',
      'es': 'Plataforma',
    },
    'admin_ledger_direction_credit': {
      'fr': 'Crédit',
      'en': 'Credit',
      'es': 'Crédito',
    },
    'admin_ledger_direction_debit': {
      'fr': 'Débit',
      'en': 'Debit',
      'es': 'Débito',
    },

    'admin_tax_type_gst': {'fr': 'TPS', 'en': 'GST', 'es': 'GST'},
    'admin_tax_type_qst': {'fr': 'TVQ', 'en': 'QST', 'es': 'QST'},
    'admin_tax_type_hst': {'fr': 'TVH', 'en': 'HST', 'es': 'HST'},
    'admin_tax_type_other_tax': {
      'fr': 'Autre taxe',
      'en': 'Other tax',
      'es': 'Otro impuesto',
    },
    'admin_tax_type_tax_exempt': {
      'fr': 'Exonéré de taxe',
      'en': 'Tax exempt',
      'es': 'Exento de impuestos',
    },
    'admin_tax_owner_platform': {
      'fr': 'Plateforme',
      'en': 'Platform',
      'es': 'Plataforma',
    },
    'admin_tax_owner_driver': {
      'fr': 'Chauffeur',
      'en': 'Driver',
      'es': 'Conductor',
    },
    'admin_tax_owner_not_applicable': {
      'fr': 'Non applicable',
      'en': 'Not applicable',
      'es': 'No aplicable',
    },

    // ---- Nav Finance (shell 8 sections) ----
    'admin_nav_finance': {'fr': 'Finance', 'en': 'Finance', 'es': 'Finanzas'},
    'admin_finance_filter_mission': {
      'fr': 'Filtrer par ID mission',
      'en': 'Filter by mission ID',
      'es': 'Filtrar por ID de misión',
    },
    'admin_finance_filter_customer': {
      'fr': 'Filtrer par ID client',
      'en': 'Filter by customer ID',
      'es': 'Filtrar por ID de cliente',
    },
    'admin_finance_filter_date_from': {
      'fr': 'Depuis le',
      'en': 'From',
      'es': 'Desde el',
    },
    'admin_finance_filter_date_to': {
      'fr': 'Jusqu\'au',
      'en': 'To',
      'es': 'Hasta el',
    },
    'admin_finance_filter_clear': {
      'fr': 'Réinitialiser les filtres',
      'en': 'Clear filters',
      'es': 'Restablecer filtros',
    },
    'admin_finance_no_sensitive_data': {
      'fr':
          'Aucune donnée sensible du fournisseur de paiement (clés secrètes, données de carte) n\'est jamais affichée ici.',
      'en':
          'No sensitive payment provider data (secret keys, card data) is ever displayed here.',
      'es':
          'Ningún dato sensible del proveedor de pago (claves secretas, datos de tarjeta) se muestra aquí.',
    },

    // -----------------------------------------------------------------
    // BLOC M — I18N GLOBAL PHASE 6 : clés manquantes détectées lors de
    // l'audit complet des écrans Finance (admin + chauffeur + client).
    // Réutilise `common_cancel`/`common_confirm` partout où c'était déjà
    // possible ; les clés ci-dessous couvrent uniquement les libellés qui
    // n'avaient pas encore d'entrée i18n dédiée.
    // -----------------------------------------------------------------
    'admin_ledger_new_adjustment': {
      'fr': 'Ajustement',
      'en': 'Adjustment',
      'es': 'Ajuste',
    },
    'admin_ledger_adjustment_dialog_title': {
      'fr': 'Ajustement financier',
      'en': 'Financial adjustment',
      'es': 'Ajuste financiero',
    },
    'admin_ledger_col_amount_cad': {
      'fr': 'Montant (\$)',
      'en': 'Amount (\$)',
      'es': 'Monto (\$)',
    },
    'admin_ledger_col_direction': {
      'fr': 'Direction',
      'en': 'Direction',
      'es': 'Dirección',
    },
    'admin_ledger_col_reason': {'fr': 'Raison', 'en': 'Reason', 'es': 'Razón'},
    'admin_ledger_create': {'fr': 'Créer', 'en': 'Create', 'es': 'Crear'},
    'admin_ledger_validation_required': {
      'fr': 'Montant et raison requis.',
      'en': 'Amount and reason are required.',
      'es': 'Monto y razón son obligatorios.',
    },
    'admin_ledger_adjustment_created': {
      'fr': 'Ajustement créé.',
      'en': 'Adjustment created.',
      'es': 'Ajuste creado.',
    },
    'admin_reconciliation_summary_open': {
      'fr': 'Ouvertes',
      'en': 'Open',
      'es': 'Abiertas',
    },
    'admin_reconciliation_summary_critical': {
      'fr': 'Critiques',
      'en': 'Critical',
      'es': 'Críticas',
    },
    'admin_reconciliation_summary_warning': {
      'fr': 'Avertissements',
      'en': 'Warnings',
      'es': 'Advertencias',
    },
    'admin_reconciliation_summary_resolved': {
      'fr': 'Résolues',
      'en': 'Resolved',
      'es': 'Resueltas',
    },
    'admin_reconciliation_resolve_dialog_title': {
      'fr': 'Résoudre l\'anomalie',
      'en': 'Resolve anomaly',
      'es': 'Resolver anomalía',
    },
    'admin_reconciliation_anomaly_resolved': {
      'fr': 'Anomalie résolue.',
      'en': 'Anomaly resolved.',
      'es': 'Anomalía resuelta.',
    },
    'admin_taxes_col_display_name': {
      'fr': 'Nom affiché',
      'en': 'Display name',
      'es': 'Nombre visible',
    },
    'admin_taxes_col_type': {'fr': 'Type', 'en': 'Type', 'es': 'Tipo'},
    'admin_taxes_col_owner': {
      'fr': 'Responsable de la taxe',
      'en': 'Tax owner',
      'es': 'Responsable del impuesto',
    },
    'admin_taxes_validation_required': {
      'fr': 'Juridiction, code et taux requis.',
      'en': 'Jurisdiction, code and rate are required.',
      'es': 'Jurisdicción, código y tasa son obligatorios.',
    },
    'admin_payout_policy_edit': {
      'fr': 'Modifier',
      'en': 'Edit',
      'es': 'Modificar',
    },
    'admin_payout_policy_validation_invalid': {
      'fr': 'Valeurs invalides.',
      'en': 'Invalid values.',
      'es': 'Valores inválidos.',
    },
    'admin_payouts_reverse_dialog_title': {
      'fr': 'Annuler le versement',
      'en': 'Reverse payout',
      'es': 'Revertir el pago',
    },
    'admin_payouts_reverse_action': {
      'fr': 'Reverse',
      'en': 'Reverse',
      'es': 'Revertir',
    },
    'admin_payouts_reversed_success': {
      'fr': 'Versement annulé.',
      'en': 'Payout reversed.',
      'es': 'Pago revertido.',
    },
  };

  static String t(String key, String locale) {
    final entry = _t[key];
    if (entry == null) return key;
    return entry[locale] ?? entry['fr'] ?? entry['en'] ?? key;
  }
}
