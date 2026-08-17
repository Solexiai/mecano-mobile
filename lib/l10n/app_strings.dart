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
    'nav_mechanic': {'fr': 'Mécanicien mobile', 'en': 'Mobile Mechanic', 'es': 'Mecánico móvil'},
    'nav_become_provider': {'fr': 'Devenir fournisseur', 'en': 'Become a Provider', 'es': 'Convertirse en proveedor'},
    'nav_become_driver': {'fr': 'Devenir chauffeur', 'en': 'Become a Driver', 'es': 'Convertirse en conductor'},
    'nav_become_mechanic': {'fr': 'Devenir mécanicien', 'en': 'Become a Mobile Mechanic', 'es': 'Convertirse en mecánico'},
    'nav_pricing': {'fr': 'Tarifs', 'en': 'Pricing', 'es': 'Precios'},
    'nav_safety': {'fr': 'Sécurité', 'en': 'Safety', 'es': 'Seguridad'},
    'nav_faq': {'fr': 'FAQ', 'en': 'FAQ', 'es': 'Preguntas'},
    'nav_about': {'fr': 'À propos', 'en': 'About', 'es': 'Acerca de'},
    'nav_contact': {'fr': 'Contact', 'en': 'Contact', 'es': 'Contacto'},
    'nav_how_it_works': {'fr': 'Comment ça marche', 'en': 'How it works', 'es': 'Cómo funciona'},
    'nav_sign_in': {'fr': 'Connexion', 'en': 'Sign In', 'es': 'Iniciar sesión'},
    'nav_get_started': {'fr': 'Commencer', 'en': 'Get Started', 'es': 'Comenzar'},
    'nav_dashboard': {'fr': 'Tableau de bord', 'en': 'Dashboard', 'es': 'Panel'},
    'nav_my_requests': {'fr': 'Mes demandes', 'en': 'My Requests', 'es': 'Mis solicitudes'},
    'nav_my_bookings': {'fr': 'Mes réservations', 'en': 'My Bookings', 'es': 'Mis reservas'},
    'nav_messages': {'fr': 'Messages', 'en': 'Messages', 'es': 'Mensajes'},
    'nav_saved_addresses': {'fr': 'Adresses enregistrées', 'en': 'Saved Addresses', 'es': 'Direcciones guardadas'},
    'nav_favourites': {'fr': 'Favoris', 'en': 'Favourites', 'es': 'Favoritos'},
    'nav_profile': {'fr': 'Profil', 'en': 'Profile', 'es': 'Perfil'},
    'nav_settings': {'fr': 'Paramètres', 'en': 'Settings', 'es': 'Configuración'},
    'nav_logout': {'fr': 'Déconnexion', 'en': 'Logout', 'es': 'Cerrar sesión'},
    'nav_available_jobs': {'fr': 'Demandes disponibles', 'en': 'Available Jobs', 'es': 'Trabajos disponibles'},
    'nav_calendar': {'fr': 'Calendrier', 'en': 'Calendar', 'es': 'Calendario'},
    'nav_my_services': {'fr': 'Mes services', 'en': 'My Services', 'es': 'Mis servicios'},
    'nav_my_vehicle': {'fr': 'Mon véhicule', 'en': 'My Vehicle', 'es': 'Mi vehículo'},
    'nav_service_area': {'fr': 'Zone de service', 'en': 'Service Area', 'es': 'Área de servicio'},
    'nav_earnings': {'fr': 'Revenus', 'en': 'Earnings', 'es': 'Ganancias'},
    'nav_reviews': {'fr': 'Avis', 'en': 'Reviews', 'es': 'Reseñas'},
    'nav_documents': {'fr': 'Documents', 'en': 'Documents', 'es': 'Documentos'},
    'nav_admin': {'fr': 'Administration', 'en': 'Admin', 'es': 'Administración'},

    // ---------- Home ----------
    'home_hero_headline': {
      'fr': 'Livrer. Réparer. Là où vous êtes.',
      'en': 'Move it. Fix it. Wherever you are.',
      'es': 'Mover. Reparar. Donde estés.',
    },
    'home_hero_subheadline': {
      'fr': 'Faites livrer un gros objet ou faites venir un mécanicien directement à votre véhicule.',
      'en': 'Book a trusted local driver for a large delivery or have a mobile mechanic come directly to your vehicle.',
      'es': 'Reserva un conductor local de confianza para una entrega grande o haz que un mecánico móvil venga directamente a tu vehículo.',
    },
    'home_cta_need_service': {'fr': "J'ai besoin d'un service", 'en': 'I need a service', 'es': 'Necesito un servicio'},
    'home_cta_offer_service': {'fr': 'Je veux offrir mes services', 'en': 'I want to offer my services', 'es': 'Quiero ofrecer mis servicios'},

    'home_card_delivery_title': {'fr': "J'ai besoin d'une livraison", 'en': 'I need a delivery', 'es': 'Necesito una entrega'},
    'home_card_delivery_desc': {
      'fr': "Avez-vous acheté quelque chose qui ne rentre pas dans votre véhicule? Trouvez un chauffeur local de confiance avec le bon véhicule.",
      'en': 'Bought something that does not fit in your vehicle? Find a trusted local driver with the right vehicle.',
      'es': '¿Compraste algo que no cabe en tu vehículo? Encuentra un conductor local de confianza con el vehículo adecuado.',
    },
    'home_card_delivery_cta': {'fr': 'Trouver un chauffeur', 'en': 'Find a Driver', 'es': 'Encontrar un conductor'},
    'home_card_delivery_cta2': {'fr': 'Devenir chauffeur', 'en': 'Become a Driver', 'es': 'Convertirse en conductor'},

    'home_card_mechanic_title': {'fr': "J'ai besoin d'un mécanicien mobile", 'en': 'I need a mobile mechanic', 'es': 'Necesito un mecánico móvil'},
    'home_card_mechanic_desc': {
      'fr': 'Problème de véhicule? Réservez un mécanicien mobile qualifié qui vient chez vous, au travail ou sur la route.',
      'en': 'Vehicle problem? Book a qualified mobile mechanic who comes to your home, workplace or roadside location.',
      'es': '¿Problema con el vehículo? Reserva un mecánico móvil calificado que viene a tu casa, trabajo o carretera.',
    },
    'home_card_mechanic_cta': {'fr': 'Trouver un mécanicien', 'en': 'Find a Mechanic', 'es': 'Encontrar un mecánico'},
    'home_card_mechanic_cta2': {'fr': 'Devenir mécanicien mobile', 'en': 'Become a Mobile Mechanic', 'es': 'Convertirse en mecánico móvil'},

    'home_examples': {'fr': 'Exemples', 'en': 'Examples', 'es': 'Ejemplos'},

    'home_final_headline': {'fr': 'Une plateforme. Deux services locaux essentiels.', 'en': 'One platform. Two essential local services.', 'es': 'Una plataforma. Dos servicios locales esenciales.'},
    'home_final_sub': {
      'fr': "Que vous ayez besoin de faire livrer un gros objet ou d'envoyer un mécanicien à votre véhicule, Movi-k vous aide à trouver le bon fournisseur local.",
      'en': 'Whether you need a large item delivered or a mechanic sent to your vehicle, Movi-k helps you find the right local provider.',
      'es': 'Ya sea que necesites entregar un artículo grande o enviar un mecánico a tu vehículo, Movi-k te ayuda a encontrar el proveedor local adecuado.',
    },
    'home_final_cta1': {'fr': 'Demander un service', 'en': 'Request a Service', 'es': 'Solicitar un servicio'},
    'home_final_cta2': {'fr': 'Devenir fournisseur', 'en': 'Become a Provider', 'es': 'Convertirse en proveedor'},
    'home_trust_statement': {
      'fr': 'Fournisseurs locaux. Profils transparents. Réservations flexibles.',
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
    'common_coming_soon': {'fr': 'Bientôt disponible', 'en': 'Coming soon', 'es': 'Próximamente'},
    'common_demo_data': {'fr': 'Données de démonstration', 'en': 'Demonstration data', 'es': 'Datos de demostración'},
    'common_loading': {'fr': 'Chargement…', 'en': 'Loading…', 'es': 'Cargando…'},
    'common_error': {'fr': 'Une erreur est survenue', 'en': 'An error occurred', 'es': 'Ocurrió un error'},
    'common_empty': {'fr': "Rien à afficher pour l'instant", 'en': 'Nothing to show yet', 'es': 'Nada que mostrar todavía'},
    'common_retry': {'fr': 'Réessayer', 'en': 'Retry', 'es': 'Reintentar'},
    'common_see_all': {'fr': 'Tout voir', 'en': 'See all', 'es': 'Ver todo'},
    'common_upload_photo': {'fr': 'Ajouter des photos', 'en': 'Upload photos', 'es': 'Subir fotos'},
    'common_yes': {'fr': 'Oui', 'en': 'Yes', 'es': 'Sí'},
    'common_no': {'fr': 'Non', 'en': 'No', 'es': 'No'},

    // ---------- Auth ----------
    'auth_welcome': {'fr': 'Bienvenue sur Movi-k', 'en': 'Welcome to Movi-k', 'es': 'Bienvenido a Movi-k'},
    'auth_email': {'fr': 'Adresse courriel', 'en': 'Email address', 'es': 'Correo electrónico'},
    'auth_full_name': {'fr': 'Nom complet', 'en': 'Full name', 'es': 'Nombre completo'},
    'auth_phone': {'fr': 'Numéro de téléphone', 'en': 'Phone number', 'es': 'Número de teléfono'},
    'auth_send_link': {'fr': 'Envoyer le lien magique', 'en': 'Send magic link', 'es': 'Enviar enlace mágico'},
    'auth_magic_link_desc': {
      'fr': 'Nous vous envoyons un lien sécurisé sans mot de passe pour vous connecter.',
      'en': 'We send you a secure passwordless link to sign in.',
      'es': 'Te enviamos un enlace seguro sin contraseña para iniciar sesión.',
    },
    'auth_check_inbox': {'fr': 'Vérifiez votre boîte de réception', 'en': 'Check your inbox', 'es': 'Revisa tu bandeja de entrada'},
    'auth_demo_notice': {
      'fr': "Mode démonstration : la connexion se fait localement sur cet appareil, sans envoi réel de courriel.",
      'en': 'Demo mode: sign-in happens locally on this device, no real email is sent.',
      'es': 'Modo demo: el inicio de sesión ocurre localmente en este dispositivo, no se envía correo real.',
    },
    'auth_choose_role': {'fr': 'Choisissez votre profil', 'en': 'Choose your role', 'es': 'Elige tu perfil'},
    'auth_role_customer': {'fr': 'Client', 'en': 'Customer', 'es': 'Cliente'},
    'auth_role_driver': {'fr': 'Chauffeur', 'en': 'Driver', 'es': 'Conductor'},
    'auth_role_mechanic': {'fr': 'Mécanicien mobile', 'en': 'Mobile mechanic', 'es': 'Mecánico móvil'},
    'auth_continue_as': {'fr': 'Continuer en tant que', 'en': 'Continue as', 'es': 'Continuar como'},
    'auth_logged_in_as': {'fr': 'Connecté en tant que', 'en': 'Logged in as', 'es': 'Conectado como'},

    // ---------- Delivery ----------
    'delivery_hero_headline': {
      'fr': "Besoin de transporter quelque chose? On trouve le bon chauffeur local.",
      'en': "Need something moved? We'll find the right local driver.",
      'es': '¿Necesitas mover algo? Encontramos al conductor local adecuado.',
    },
    'delivery_hero_sub': {
      'fr': "Pas de camion? Pas de remorque? Aucun problème. Décrivez ce qui doit être transporté et choisissez un fournisseur disponible.",
      'en': "No pickup? No trailer? No problem. Describe what needs to be transported and choose an available provider.",
      'es': '¿Sin camioneta? ¿Sin remolque? No hay problema. Describe qué necesitas transportar y elige un proveedor disponible.',
    },
    'delivery_step1_title': {'fr': "Informations sur l'objet", 'en': 'Item information', 'es': 'Información del artículo'},
    'delivery_step2_title': {'fr': 'Emplacements', 'en': 'Locations', 'es': 'Ubicaciones'},
    'delivery_step3_title': {'fr': 'Fournisseurs disponibles', 'en': 'Provider matching', 'es': 'Proveedores disponibles'},
    'delivery_step4_title': {'fr': 'Réservation', 'en': 'Booking', 'es': 'Reserva'},

    'delivery_item_category': {'fr': "Catégorie d'objet", 'en': 'Item category', 'es': 'Categoría de artículo'},
    'delivery_item_description': {'fr': 'Description', 'en': 'Description', 'es': 'Descripción'},
    'delivery_item_dimensions': {'fr': 'Dimensions approximatives', 'en': 'Approximate dimensions', 'es': 'Dimensiones aproximadas'},
    'delivery_item_weight': {'fr': 'Poids approximatif', 'en': 'Approximate weight', 'es': 'Peso aproximado'},
    'delivery_item_quantity': {'fr': 'Quantité', 'en': 'Quantity', 'es': 'Cantidad'},
    'delivery_item_stairs': {'fr': 'Escaliers, ascenseur ou manutention spéciale', 'en': 'Stairs, elevator or special handling', 'es': 'Escaleras, ascensor o manejo especial'},
    'delivery_item_loading_help': {'fr': "Aide au chargement nécessaire", 'en': 'Loading assistance needed', 'es': 'Ayuda de carga necesaria'},
    'delivery_item_unloading_help': {'fr': 'Aide au déchargement nécessaire', 'en': 'Unloading assistance needed', 'es': 'Ayuda de descarga necesaria'},

    'delivery_pickup_address': {'fr': "Adresse d'enlèvement", 'en': 'Pickup address', 'es': 'Dirección de recogida'},
    'delivery_dropoff_address': {'fr': 'Adresse de livraison', 'en': 'Delivery address', 'es': 'Dirección de entrega'},
    'delivery_pref_date': {'fr': 'Date préférée', 'en': 'Preferred date', 'es': 'Fecha preferida'},
    'delivery_pref_time': {'fr': 'Plage horaire préférée', 'en': 'Preferred time window', 'es': 'Horario preferido'},
    'delivery_contact_instructions': {'fr': 'Instructions de contact', 'en': 'Contact instructions', 'es': 'Instrucciones de contacto'},
    'delivery_access_details': {'fr': "Détails d'accès", 'en': 'Access details', 'es': 'Detalles de acceso'},
    'delivery_extra_stop': {'fr': 'Arrêt additionnel (optionnel)', 'en': 'Optional additional stop', 'es': 'Parada adicional (opcional)'},

    'delivery_find_drivers': {'fr': 'Chauffeurs disponibles', 'en': 'Available drivers', 'es': 'Conductores disponibles'},
    'delivery_confirm_request': {'fr': 'Confirmer la demande', 'en': 'Confirm Request', 'es': 'Confirmar solicitud'},

    'delivery_status_submitted': {'fr': 'Demande envoyée', 'en': 'Request submitted', 'es': 'Solicitud enviada'},
    'delivery_status_awaiting': {'fr': 'En attente de réponse du fournisseur', 'en': 'Awaiting provider response', 'es': 'Esperando respuesta del proveedor'},
    'delivery_status_accepted': {'fr': 'Acceptée', 'en': 'Accepted', 'es': 'Aceptada'},
    'delivery_status_on_the_way': {'fr': 'Le fournisseur est en route', 'en': 'Provider on the way', 'es': 'El proveedor está en camino'},
    'delivery_status_pickup_done': {'fr': 'Enlèvement complété', 'en': 'Pickup completed', 'es': 'Recogida completada'},
    'delivery_status_in_progress': {'fr': 'Livraison en cours', 'en': 'Delivery in progress', 'es': 'Entrega en progreso'},
    'delivery_status_delivered': {'fr': 'Livré', 'en': 'Delivered', 'es': 'Entregado'},
    'delivery_status_cancelled': {'fr': 'Annulée', 'en': 'Cancelled', 'es': 'Cancelada'},
    'delivery_status_disputed': {'fr': 'En litige', 'en': 'Disputed', 'es': 'En disputa'},

    // ---------- Mechanic ----------
    'mechanic_hero_headline': {'fr': 'Un mécanicien qui se déplace chez vous.', 'en': 'A mechanic who comes to you.', 'es': 'Un mecánico que viene a ti.'},
    'mechanic_hero_sub': {
      'fr': 'Réservez un service automobile à domicile, au travail, sur un chantier ou en bord de route.',
      'en': 'Book automotive service at home, at work, on a job site or on the roadside.',
      'es': 'Reserva un servicio automotriz en casa, en el trabajo, en un sitio de trabajo o en la carretera.',
    },
    'mechanic_step1_title': {'fr': 'Informations sur le véhicule', 'en': 'Vehicle information', 'es': 'Información del vehículo'},
    'mechanic_step2_title': {'fr': 'Problème ou service', 'en': 'Problem or service', 'es': 'Problema o servicio'},
    'mechanic_step3_title': {'fr': 'Emplacement et horaire', 'en': 'Location and schedule', 'es': 'Ubicación y horario'},
    'mechanic_step4_title': {'fr': 'Mécaniciens disponibles', 'en': 'Mechanic matching', 'es': 'Mecánicos disponibles'},
    'mechanic_step5_title': {'fr': 'Résumé de la réservation', 'en': 'Booking summary', 'es': 'Resumen de la reserva'},

    'mechanic_vehicle_make': {'fr': 'Marque du véhicule', 'en': 'Vehicle make', 'es': 'Marca del vehículo'},
    'mechanic_vehicle_model': {'fr': 'Modèle', 'en': 'Model', 'es': 'Modelo'},
    'mechanic_vehicle_year': {'fr': 'Année', 'en': 'Year', 'es': 'Año'},
    'mechanic_vehicle_engine': {'fr': 'Moteur', 'en': 'Engine', 'es': 'Motor'},
    'mechanic_vehicle_vin': {'fr': 'NIV (optionnel)', 'en': 'VIN (optional)', 'es': 'VIN (opcional)'},
    'mechanic_vehicle_plate': {'fr': "Plaque d'immatriculation (optionnel)", 'en': 'Licence plate (optional)', 'es': 'Placa (opcional)'},
    'mechanic_vehicle_mileage': {'fr': 'Kilométrage actuel', 'en': 'Current mileage', 'es': 'Kilometraje actual'},
    'mechanic_vehicle_can_move': {'fr': 'Le véhicule peut-il se déplacer en sécurité?', 'en': 'Can the vehicle move safely?', 'es': '¿Puede el vehículo moverse con seguridad?'},

    'mechanic_disclaimer': {
      'fr': "Les descriptions en ligne ne remplacent pas un diagnostic mécanique en personne. Le prix final peut changer si l'état réel diffère de la demande initiale. Tout changement de prix doit être approuvé par le client avant le début de travaux supplémentaires.",
      'en': 'Online descriptions do not replace an in-person mechanical diagnosis. The final price may change if the actual condition differs from the original request. Any price change must be approved by the customer before additional work begins.',
      'es': 'Las descripciones en línea no reemplazan un diagnóstico mecánico en persona. El precio final puede cambiar si el estado real difiere de la solicitud original. Cualquier cambio de precio debe ser aprobado por el cliente antes de iniciar trabajo adicional.',
    },

    'mechanic_send_request': {'fr': 'Envoyer la demande de réservation', 'en': 'Send Booking Request', 'es': 'Enviar solicitud de reserva'},
    'mechanic_services_label': {'fr': 'Services :', 'en': 'Services:', 'es': 'Servicios:'},
    'mechanic_select_services_title': {'fr': 'Sélectionnez le(s) service(s)', 'en': 'Select service(s)', 'es': 'Seleccione el/los servicio(s)'},

    'mechanic_status_submitted': {'fr': 'Demande envoyée', 'en': 'Request submitted', 'es': 'Solicitud enviada'},
    'mechanic_status_awaiting': {'fr': 'En attente de réponse du mécanicien', 'en': 'Awaiting mechanic response', 'es': 'Esperando respuesta del mecánico'},
    'mechanic_status_accepted': {'fr': 'Acceptée', 'en': 'Accepted', 'es': 'Aceptada'},
    'mechanic_status_diagnosis': {'fr': 'Diagnostic requis', 'en': 'Diagnosis required', 'es': 'Diagnóstico requerido'},
    'mechanic_status_parts_needed': {'fr': 'Pièces requises', 'en': 'Parts required', 'es': 'Piezas requeridas'},
    'mechanic_status_parts_ordered': {'fr': 'Pièces commandées', 'en': 'Parts ordered', 'es': 'Piezas pedidas'},
    'mechanic_status_on_the_way': {'fr': 'Le mécanicien est en route', 'en': 'Mechanic on the way', 'es': 'El mecánico está en camino'},
    'mechanic_status_in_progress': {'fr': 'Travaux en cours', 'en': 'Work in progress', 'es': 'Trabajo en progreso'},
    'mechanic_status_approval_needed': {'fr': 'Approbation du client requise', 'en': 'Customer approval required', 'es': 'Se requiere aprobación del cliente'},
    'mechanic_status_completed': {'fr': 'Terminé', 'en': 'Completed', 'es': 'Completado'},
    'mechanic_status_cancelled': {'fr': 'Annulée', 'en': 'Cancelled', 'es': 'Cancelada'},
    'mechanic_status_disputed': {'fr': 'En litige', 'en': 'Disputed', 'es': 'En disputa'},

    // ---------- Item categories (delivery) ----------
    'cat_furniture': {'fr': 'Meubles', 'en': 'Furniture', 'es': 'Muebles'},
    'cat_appliances': {'fr': 'Appareils électroménagers', 'en': 'Appliances', 'es': 'Electrodomésticos'},
    'cat_marketplace': {'fr': 'Achats Marketplace', 'en': 'Marketplace purchases', 'es': 'Compras de Marketplace'},
    'cat_costco': {'fr': 'Achats Costco', 'en': 'Costco purchases', 'es': 'Compras de Costco'},
    'cat_home_depot': {'fr': 'Achats Home Depot', 'en': 'Home Depot purchases', 'es': 'Compras de Home Depot'},
    'cat_building_materials': {'fr': 'Matériaux de construction', 'en': 'Building materials', 'es': 'Materiales de construcción'},
    'cat_pallets': {'fr': 'Palettes', 'en': 'Pallets', 'es': 'Palets'},
    'cat_equipment': {'fr': 'Équipement', 'en': 'Equipment', 'es': 'Equipo'},
    'cat_bbq': {'fr': 'BBQ', 'en': 'BBQ', 'es': 'Parrilla (BBQ)'},
    'cat_tv': {'fr': 'Grand téléviseur', 'en': 'Large TV', 'es': 'Televisor grande'},
    'cat_boxes': {'fr': 'Boîtes', 'en': 'Boxes', 'es': 'Cajas'},
    'cat_motorcycle': {'fr': 'Moto', 'en': 'Motorcycle', 'es': 'Motocicleta'},
    'cat_atv': {'fr': 'VTT', 'en': 'ATV', 'es': 'Cuatrimoto (VTT)'},
    'cat_small_move': {'fr': 'Petit déménagement', 'en': 'Small move', 'es': 'Mudanza pequeña'},

    // ---------- Mechanic services ----------
    'svc_battery_boost': {'fr': 'Survoltage de batterie', 'en': 'Battery boost', 'es': 'Arranque de batería'},
    'svc_battery_replacement': {'fr': 'Remplacement de batterie', 'en': 'Battery replacement', 'es': 'Reemplazo de batería'},
    'svc_oil_change': {'fr': "Changement d'huile", 'en': 'Oil change', 'es': 'Cambio de aceite'},
    'svc_brakes': {'fr': 'Freins', 'en': 'Brakes', 'es': 'Frenos'},
    'svc_tires': {'fr': 'Pneus', 'en': 'Tires', 'es': 'Neumáticos'},
    'svc_suspension': {'fr': 'Suspension', 'en': 'Suspension', 'es': 'Suspensión'},
    'svc_starter': {'fr': 'Démarreur', 'en': 'Starter', 'es': 'Motor de arranque'},
    'svc_alternator': {'fr': 'Alternateur', 'en': 'Alternator', 'es': 'Alternador'},
    'svc_obd_diagnostic': {'fr': 'Diagnostic OBD', 'en': 'OBD diagnostic', 'es': 'Diagnóstico OBD'},
    'svc_warning_light': {'fr': 'Voyant lumineux', 'en': 'Warning light', 'es': 'Luz testigo'},
    'svc_wont_start': {'fr': 'Ne démarre pas', 'en': "Won't start", 'es': 'No arranca'},
    'svc_noise_vibration': {'fr': 'Bruit ou vibration', 'en': 'Noise or vibration', 'es': 'Ruido o vibración'},
    'svc_pre_purchase_inspection': {'fr': 'Inspection pré-achat', 'en': 'Pre-purchase inspection', 'es': 'Inspección previa a la compra'},
    'svc_roadside_emergency': {'fr': 'Urgence routière', 'en': 'Roadside emergency', 'es': 'Emergencia en carretera'},
    'svc_other': {'fr': 'Autre', 'en': 'Other', 'es': 'Otro'},

    // ---------- Driver recruitment ----------
    'driver_hero_headline': {'fr': 'Transformez votre véhicule en revenu.', 'en': 'Turn your vehicle into income.', 'es': 'Convierte tu vehículo en ingresos.'},
    'driver_hero_sub': {
      'fr': "Choisissez votre horaire, définissez votre zone de service et n'acceptez que les livraisons qui vous conviennent.",
      'en': 'Choose your schedule, define your service area and accept only the delivery jobs that work for you.',
      'es': 'Elige tu horario, define tu área de servicio y acepta solo los trabajos que te convengan.',
    },
    'driver_pending_verification': {'fr': 'En attente de vérification', 'en': 'Pending verification', 'es': 'Pendiente de verificación'},

    // ---------- Mechanic recruitment ----------
    'mech_provider_hero_headline': {'fr': "Plus de demandes. Moins de temps à chercher des clients.", 'en': 'More jobs. Less time searching for customers.', 'es': 'Más trabajos. Menos tiempo buscando clientes.'},
    'mech_provider_hero_sub': {
      'fr': 'Définissez votre horaire, choisissez votre zone de service et recevez des demandes pertinentes sans gérer une infinité d\'appels.',
      'en': 'Set your schedule, choose your service area and receive relevant requests without managing endless phone calls.',
      'es': 'Establece tu horario, elige tu área de servicio y recibe solicitudes relevantes sin gestionar llamadas interminables.',
    },
    'mech_provider_fr_support': {
      'fr': 'On vous connecte à nos clients. Vous vous connectez selon votre horaire et acceptez les interventions qui vous conviennent.',
      'en': 'We connect you with our customers. You log in on your schedule and accept the jobs that suit you.',
      'es': 'Te conectamos con nuestros clientes. Te conectas según tu horario y aceptas los trabajos que te convengan.',
    },

    // ---------- Pricing / payment ----------
    'pricing_title': {'fr': 'Tarifs', 'en': 'Pricing', 'es': 'Precios'},
    'pricing_mvp_notice': {
      'fr': "Au stade actuel, le paiement se fait directement entre le client et le fournisseur.",
      'en': 'At this stage, payment takes place directly between the customer and the provider.',
      'es': 'En esta etapa, el pago se realiza directamente entre el cliente y el proveedor.',
    },
    'payment_cash': {'fr': 'Comptant', 'en': 'Cash', 'es': 'Efectivo'},
    'payment_interac': {'fr': 'Virement Interac', 'en': 'Interac e-Transfer', 'es': 'Transferencia Interac'},
    'payment_arrangement': {'fr': 'Entente convenue avec le fournisseur', 'en': 'Payment arrangement confirmed with provider', 'es': 'Acuerdo de pago confirmado con el proveedor'},

    // ---------- Footer / legal ----------
    'footer_rights': {'fr': 'Tous droits réservés.', 'en': 'All rights reserved.', 'es': 'Todos los derechos reservados.'},
    'footer_privacy': {'fr': 'Politique de confidentialité', 'en': 'Privacy Policy', 'es': 'Política de privacidad'},
    'footer_terms': {'fr': "Conditions d'utilisation", 'en': 'Terms of Service', 'es': 'Términos de servicio'},

    // ---------- Trust ----------
    'trust_identity_verified': {'fr': 'Identité vérifiée', 'en': 'Identity verified', 'es': 'Identidad verificada'},
    'trust_documents_verified': {'fr': 'Documents vérifiés', 'en': 'Documents verified', 'es': 'Documentos verificados'},
    'trust_vehicle_verified': {'fr': 'Véhicule vérifié', 'en': 'Vehicle verified', 'es': 'Vehículo verificado'},
    'trust_member_since': {'fr': 'Membre depuis', 'en': 'Member since', 'es': 'Miembro desde'},
    'trust_completed_jobs': {'fr': 'Emplois complétés', 'en': 'Completed jobs', 'es': 'Trabajos completados'},

    // ---------- Testimonials ----------
    'testimonial_placeholder_label': {
      'fr': 'Témoignage exemple — à remplacer par un avis client vérifié',
      'en': 'Example testimonial — replace with verified customer review',
      'es': 'Testimonio de ejemplo — reemplazar con reseña de cliente verificada',
    },

    // ---------- Vehicle categories (VehicleCategory enum) ----------
    'vehicle_cat_car': {'fr': 'Voiture', 'en': 'Car', 'es': 'Auto'},
    'vehicle_cat_suv': {'fr': 'VUS', 'en': 'SUV', 'es': 'Camioneta SUV'},
    'vehicle_cat_minivan': {'fr': 'Fourgonnette', 'en': 'Minivan', 'es': 'Minivan'},
    'vehicle_cat_cargo_van': {'fr': 'Fourgon cargo', 'en': 'Cargo Van', 'es': 'Furgoneta de carga'},
    'vehicle_cat_pickup_truck': {'fr': 'Camionnette', 'en': 'Pickup Truck', 'es': 'Camioneta pickup'},
    'vehicle_cat_cube_truck': {'fr': 'Camion cube', 'en': 'Cube Truck', 'es': 'Camión cubo'},
    'vehicle_cat_truck': {'fr': 'Camion', 'en': 'Truck', 'es': 'Camión'},
    'vehicle_cat_trailer': {'fr': 'Remorque', 'en': 'Trailer', 'es': 'Remolque'},
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
    'driver_status_approved': {'fr': 'Approuvé', 'en': 'Approved', 'es': 'Aprobado'},
    'driver_status_rejected': {'fr': 'Refusé', 'en': 'Rejected', 'es': 'Rechazado'},
    'driver_status_suspended': {'fr': 'Suspendu', 'en': 'Suspended', 'es': 'Suspendido'},
    'driver_status_inactive': {'fr': 'Inactif', 'en': 'Inactive', 'es': 'Inactivo'},

    // ---------- Statuts document (DriverDocumentStatus enum) ----------
    'doc_status_missing': {'fr': 'Manquant', 'en': 'Missing', 'es': 'Faltante'},
    'doc_status_uploaded': {'fr': 'Téléversé', 'en': 'Uploaded', 'es': 'Cargado'},
    'doc_status_pending_review': {
      'fr': 'En attente de révision',
      'en': 'Pending review',
      'es': 'Pendiente de revisión',
    },
    'doc_status_approved': {'fr': 'Approuvé', 'en': 'Approved', 'es': 'Aprobado'},
    'doc_status_rejected': {'fr': 'Refusé', 'en': 'Rejected', 'es': 'Rechazado'},
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
    'doc_type_insurance': {'fr': 'Assurance', 'en': 'Insurance', 'es': 'Seguro'},
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
    'doc_type_other': {'fr': 'Autre document', 'en': 'Other document', 'es': 'Otro documento'},

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
    'admin_drivers_filter_approved': {'fr': 'Approuvés', 'en': 'Approved', 'es': 'Aprobados'},
    'admin_drivers_filter_rejected': {'fr': 'Refusés', 'en': 'Rejected', 'es': 'Rechazados'},
    'admin_drivers_filter_suspended': {'fr': 'Suspendus', 'en': 'Suspended', 'es': 'Suspendidos'},

    'admin_drivers_col_name': {'fr': 'Nom', 'en': 'Name', 'es': 'Nombre'},
    'admin_drivers_col_email': {'fr': 'Courriel', 'en': 'Email', 'es': 'Correo electrónico'},
    'admin_drivers_col_submitted_at': {
      'fr': 'Date de soumission',
      'en': 'Submission date',
      'es': 'Fecha de envío',
    },
    'admin_drivers_col_vehicle': {'fr': 'Véhicule', 'en': 'Vehicle', 'es': 'Vehículo'},
    'admin_drivers_col_status': {'fr': 'Statut', 'en': 'Status', 'es': 'Estado'},
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
    'admin_driver_section_profile': {'fr': 'Profil', 'en': 'Profile', 'es': 'Perfil'},
    'admin_driver_section_vehicle': {'fr': 'Véhicule', 'en': 'Vehicle', 'es': 'Vehículo'},
    'admin_driver_section_documents': {'fr': 'Documents', 'en': 'Documents', 'es': 'Documentos'},
    'admin_driver_section_notes': {
      'fr': 'Notes internes',
      'en': 'Internal notes',
      'es': 'Notas internas',
    },

    'admin_driver_field_first_name': {'fr': 'Prénom', 'en': 'First name', 'es': 'Nombre'},
    'admin_driver_field_last_name': {'fr': 'Nom', 'en': 'Last name', 'es': 'Apellido'},
    'admin_driver_field_phone': {'fr': 'Téléphone', 'en': 'Phone', 'es': 'Teléfono'},
    'admin_driver_field_email': {'fr': 'Courriel', 'en': 'Email', 'es': 'Correo electrónico'},
    'admin_driver_field_address': {'fr': 'Adresse', 'en': 'Address', 'es': 'Dirección'},
    'admin_driver_field_city': {'fr': 'Ville', 'en': 'City', 'es': 'Ciudad'},
    'admin_driver_field_province': {'fr': 'Province', 'en': 'Province', 'es': 'Provincia'},
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

    'admin_driver_field_category': {'fr': 'Catégorie', 'en': 'Category', 'es': 'Categoría'},
    'admin_driver_field_make': {'fr': 'Marque', 'en': 'Make', 'es': 'Marca'},
    'admin_driver_field_model': {'fr': 'Modèle', 'en': 'Model', 'es': 'Modelo'},
    'admin_driver_field_year': {'fr': 'Année', 'en': 'Year', 'es': 'Año'},
    'admin_driver_field_color': {'fr': 'Couleur', 'en': 'Color', 'es': 'Color'},
    'admin_driver_field_plate': {'fr': 'Plaque', 'en': 'Plate', 'es': 'Placa'},
    'admin_driver_field_capacity': {'fr': 'Capacité', 'en': 'Capacity', 'es': 'Capacidad'},
    'admin_driver_field_vehicle_verified': {
      'fr': 'Statut de vérification',
      'en': 'Verification status',
      'es': 'Estado de verificación',
    },
    'admin_driver_verified': {'fr': 'Vérifié', 'en': 'Verified', 'es': 'Verificado'},
    'admin_driver_not_verified': {'fr': 'Non vérifié', 'en': 'Not verified', 'es': 'No verificado'},

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

    'admin_action_approve': {'fr': 'Approuver', 'en': 'Approve', 'es': 'Aprobar'},
    'admin_action_reject': {'fr': 'Refuser', 'en': 'Reject', 'es': 'Rechazar'},
    'admin_action_request_documents': {
      'fr': 'Demander un nouveau document',
      'en': 'Request a new document',
      'es': 'Solicitar un nuevo documento',
    },
    'admin_action_suspend': {'fr': 'Suspendre', 'en': 'Suspend', 'es': 'Suspender'},
    'admin_action_reactivate': {'fr': 'Réactiver', 'en': 'Reactivate', 'es': 'Reactivar'},
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
      'fr': 'Ce chauffeur sera notifié et pourra ensuite décider lui-même de se mettre en ligne.',
      'en': 'The driver will be notified and can then decide themselves when to go online.',
      'es': 'Se notificará al conductor, quien luego decidirá por sí mismo cuándo conectarse.',
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
      'fr': 'Vous n\'avez pas les droits nécessaires pour consulter cette page.',
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
      'fr': 'Votre dossier est en cours d\'analyse. Nous vous contacterons dès qu\'une décision sera prise.',
      'en': 'Your application is under review. We will contact you as soon as a decision is made.',
      'es': 'Su expediente está siendo revisado. Nos pondremos en contacto tan pronto como se tome una decisión.',
    },
    'driver_status_approved_message': {
      'fr': 'Félicitations, votre compte chauffeur est approuvé! Vous pouvez maintenant décider quand vous mettre en ligne.',
      'en': 'Congratulations, your driver account is approved! You can now decide when to go online.',
      'es': '¡Felicidades, su cuenta de conductor ha sido aprobada! Ahora puede decidir cuándo conectarse.',
    },
    'driver_status_rejected_message': {
      'fr': 'Votre dossier a été refusé.',
      'en': 'Your application has been rejected.',
      'es': 'Su expediente ha sido rechazado.',
    },
    'driver_status_documents_required_message': {
      'fr': 'Un ou plusieurs documents doivent être corrigés ou remplacés avant de continuer.',
      'en': 'One or more documents need to be corrected or replaced before continuing.',
      'es': 'Uno o más documentos deben ser corregidos o reemplazados antes de continuar.',
    },
    'driver_status_suspended_message': {
      'fr': 'Votre compte chauffeur est temporairement suspendu.',
      'en': 'Your driver account is temporarily suspended.',
      'es': 'Su cuenta de conductor está temporalmente suspendida.',
    },
    'driver_status_reason_label': {'fr': 'Motif', 'en': 'Reason', 'es': 'Motivo'},
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
  };

  static String t(String key, String locale) {
    final entry = _t[key];
    if (entry == null) return key;
    return entry[locale] ?? entry['fr'] ?? entry['en'] ?? key;
  }
}
