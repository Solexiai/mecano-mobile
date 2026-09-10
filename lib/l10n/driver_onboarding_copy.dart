/// Copy dedicated to the driver onboarding flow.
///
/// Kept outside the widget so every visible string added by the redesigned
/// four-step flow is available consistently in French, English and Spanish.
class DriverOnboardingCopy {
  DriverOnboardingCopy._();

  static const Map<String, Map<String, String>> _values = {
    'subtitle': {
      'fr': 'Créez votre dossier chauffeur en 4 étapes. Les informations servent à vérifier votre admissibilité et à préparer votre zone de livraison.',
      'en': 'Create your driver file in 4 steps. This information is used to verify eligibility and prepare your delivery area.',
      'es': 'Crea tu expediente de conductor en 4 pasos. Esta información se utiliza para verificar tu elegibilidad y preparar tu zona de entrega.',
    },
    'step_contact': {'fr': 'Coordonnées', 'en': 'Contact', 'es': 'Contacto'},
    'step_vehicle': {'fr': 'Véhicule', 'en': 'Vehicle', 'es': 'Vehículo'},
    'step_services': {
      'fr': 'Zone & services',
      'en': 'Area & services',
      'es': 'Zona y servicios',
    },
    'step_documents': {
      'fr': 'Documents & validation',
      'en': 'Documents & review',
      'es': 'Documentos y validación',
    },
    'contact_title': {
      'fr': 'Vos coordonnées',
      'en': 'Your contact details',
      'es': 'Tus datos de contacto',
    },
    'contact_subtitle': {
      'fr': 'Indiquez comment nous pouvons vous joindre et l’adresse qui servira de base à votre zone de service.',
      'en': 'Tell us how to reach you and which address will be used as the base of your service area.',
      'es': 'Indica cómo podemos contactarte y qué dirección se utilizará como base de tu zona de servicio.',
    },
    'service_address': {
      'fr': 'Adresse principale / base de service',
      'en': 'Primary address / service base',
      'es': 'Dirección principal / base de servicio',
    },
    'address_private': {
      'fr': 'Cette adresse sert à établir votre zone de service et à la vérification administrative. Elle n’est pas affichée publiquement aux clients.',
      'en': 'This address is used to establish your service area and for administrative verification. It is not displayed publicly to customers.',
      'es': 'Esta dirección se utiliza para establecer tu zona de servicio y para la verificación administrativa. No se muestra públicamente a los clientes.',
    },
    'address_resolved': {
      'fr': 'Adresse validée',
      'en': 'Address verified',
      'es': 'Dirección validada',
    },
    'signed_in_account': {
      'fr': 'Compte déjà connecté',
      'en': 'Account already signed in',
      'es': 'Cuenta ya conectada',
    },
    'vehicle_title': {
      'fr': 'Votre véhicule de livraison',
      'en': 'Your delivery vehicle',
      'es': 'Tu vehículo de entrega',
    },
    'vehicle_subtitle': {
      'fr': 'Renseignez précisément votre véhicule. Ces informations servent à vérifier votre dossier et à vous proposer uniquement des livraisons adaptées à sa capacité réelle.',
      'en': 'Describe your vehicle accurately. This information is used to verify your file and only offer deliveries that match its actual capacity.',
      'es': 'Describe tu vehículo con precisión. Esta información se utiliza para verificar tu expediente y ofrecerte solo entregas adaptadas a su capacidad real.',
    },
    'vehicle_make': {
      'fr': 'Marque du véhicule',
      'en': 'Vehicle make',
      'es': 'Marca del vehículo',
    },
    'vehicle_model': {
      'fr': 'Modèle du véhicule',
      'en': 'Vehicle model',
      'es': 'Modelo del vehículo',
    },
    'vehicle_color': {
      'fr': 'Couleur du véhicule',
      'en': 'Vehicle colour',
      'es': 'Color del vehículo',
    },
    'payload_help': {
      'fr': 'Indiquez la charge utile maximale que le véhicule peut transporter. Exemple : 500, 1 000 ou 2 000 kg.',
      'en': 'Enter the maximum payload the vehicle can carry. Example: 500, 1,000 or 2,000 kg.',
      'es': 'Indica la carga útil máxima que puede transportar el vehículo. Ejemplo: 500, 1.000 o 2.000 kg.',
    },
    'vehicle_photos_title': {
      'fr': 'Photos de vérification du véhicule',
      'en': 'Vehicle verification photos',
      'es': 'Fotos de verificación del vehículo',
    },
    'vehicle_photos_subtitle': {
      'fr': 'Les photos doivent être récentes, nettes et montrer le même véhicule que celui déclaré ci-dessus.',
      'en': 'Photos must be recent, clear and show the same vehicle declared above.',
      'es': 'Las fotos deben ser recientes, claras y mostrar el mismo vehículo declarado arriba.',
    },
    'vehicle_main_photo': {
      'fr': 'Photo principale du véhicule',
      'en': 'Main vehicle photo',
      'es': 'Foto principal del vehículo',
    },
    'vehicle_main_photo_help': {
      'fr': 'Prenez une vue claire de l’extérieur permettant d’identifier facilement le véhicule.',
      'en': 'Take a clear exterior view that makes the vehicle easy to identify.',
      'es': 'Toma una vista exterior clara que permita identificar fácilmente el vehículo.',
    },
    'vehicle_rear_photo': {
      'fr': 'Photo arrière du véhicule',
      'en': 'Rear vehicle photo',
      'es': 'Foto trasera del vehículo',
    },
    'vehicle_rear_photo_help': {
      'fr': 'Photographiez clairement l’arrière du véhicule utilisé pour les livraisons.',
      'en': 'Clearly photograph the rear of the vehicle used for deliveries.',
      'es': 'Fotografía claramente la parte trasera del vehículo utilizado para las entregas.',
    },
    'vehicle_plate_photo': {
      'fr': 'Photo de la plaque d’immatriculation',
      'en': 'License plate photo',
      'es': 'Foto de la placa de matrícula',
    },
    'vehicle_plate_photo_help': {
      'fr': 'La plaque doit être entièrement visible et lisible pour la vérification administrative.',
      'en': 'The plate must be fully visible and readable for administrative verification.',
      'es': 'La placa debe estar completamente visible y legible para la verificación administrativa.',
    },
    'vehicle_verification_notice': {
      'fr': 'La plaque saisie et les photos seront comparées au certificat d’immatriculation transmis à l’étape 4.',
      'en': 'The entered plate and photos will be compared with the vehicle registration certificate submitted in step 4.',
      'es': 'La placa ingresada y las fotos se compararán con el certificado de matrícula enviado en el paso 4.',
    },
    'service_title': {
      'fr': 'Votre zone et vos services',
      'en': 'Your area and services',
      'es': 'Tu zona y servicios',
    },
    'service_subtitle': {
      'fr': 'Définissez jusqu’où vous souhaitez vous déplacer et les types de livraisons que vous êtes prêt à accepter.',
      'en': 'Set how far you want to travel and the types of deliveries you are willing to accept.',
      'es': 'Define hasta dónde deseas desplazarte y los tipos de entregas que estás dispuesto a aceptar.',
    },
    'compensation_title': {
      'fr': 'Rémunération',
      'en': 'Compensation',
      'es': 'Remuneración',
    },
    'compensation_body': {
      'fr': 'Les prix de mission sont calculés par Movi-k selon les règles de la plateforme. Les pourboires sont versés à 100 % au chauffeur.',
      'en': 'Mission pricing is calculated by Movi-k according to platform rules. Drivers receive 100% of tips.',
      'es': 'Los precios de las misiones son calculados por Movi-k según las reglas de la plataforma. El conductor recibe el 100 % de las propinas.',
    },
    'documents_title': {
      'fr': 'Documents requis',
      'en': 'Required documents',
      'es': 'Documentos requeridos',
    },
    'documents_subtitle': {
      'fr': 'Téléversez des photos lisibles. Votre dossier demeure en attente tant que l’administration n’a pas terminé la vérification.',
      'en': 'Upload clear, readable photos. Your file remains pending until the administration completes its review.',
      'es': 'Sube fotos claras y legibles. Tu expediente permanecerá pendiente hasta que la administración termine la revisión.',
    },
    'vehicle_registration': {
      'fr': 'Certificat d’immatriculation du véhicule',
      'en': 'Vehicle registration certificate',
      'es': 'Certificado de matrícula del vehículo',
    },
    'identity_document': {
      'fr': 'Pièce d’identité avec photo',
      'en': 'Government photo ID',
      'es': 'Documento de identidad con foto',
    },
    'required_badge': {
      'fr': 'Requis',
      'en': 'Required',
      'es': 'Obligatorio',
    },
    'review_title': {
      'fr': 'Avant d’envoyer votre dossier',
      'en': 'Before submitting your file',
      'es': 'Antes de enviar tu expediente',
    },
    'review_body': {
      'fr': 'Vérifiez que vos coordonnées, votre véhicule et vos documents sont exacts. Une fois envoyé, le dossier sera placé en révision administrative.',
      'en': 'Check that your contact details, vehicle and documents are accurate. Once submitted, your file will be placed under administrative review.',
      'es': 'Verifica que tus datos, tu vehículo y tus documentos sean correctos. Una vez enviado, tu expediente pasará a revisión administrativa.',
    },
    'field_required': {
      'fr': 'Complétez les champs requis pour continuer.',
      'en': 'Complete the required fields to continue.',
      'es': 'Completa los campos obligatorios para continuar.',
    },
  };

  static String text(String locale, String key) {
    final values = _values[key];
    if (values == null) return key;
    return values[locale] ?? values['fr'] ?? key;
  }
}
