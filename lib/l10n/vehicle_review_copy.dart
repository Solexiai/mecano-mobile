class VehicleReviewCopy {
  static String text(String locale, String key) =>
      _values[key]?[locale] ?? _values[key]?['fr'] ?? key;
  static const _values = <String, Map<String, String>>{
    'review': {
      'fr': 'Vérifier les capacités',
      'en': 'Verify capacity',
      'es': 'Verificar capacidad',
    },
    'title': {
      'fr': 'Capacités du véhicule',
      'en': 'Vehicle capacity',
      'es': 'Capacidad del vehículo',
    },
    'pending': {
      'fr': 'Capacités non validées',
      'en': 'Capacity not verified',
      'es': 'Capacidad no verificada',
    },
    'valid': {
      'fr': 'Capacités validées jusqu’au',
      'en': 'Capacity verified until',
      'es': 'Capacidad verificada hasta',
    },
    'expired': {
      'fr': 'Validation expirée',
      'en': 'Verification expired',
      'es': 'Validación vencida',
    },
    'help': {
      'fr':
          'Approuvez d’abord le dossier chauffeur. Vérifiez ensuite les capacités de ce véhicule à partir de mesures et de documents fiables. Ne reprenez pas les valeurs d’un autre véhicule.',
      'en':
          'Approve the driver file first. Then verify this vehicle’s capacity using reliable measurements and documents. Do not reuse another vehicle’s values.',
      'es':
          'Aprueba primero el expediente del conductor. Después verifica la capacidad de este vehículo con medidas y documentos fiables. No uses los valores de otro vehículo.',
    },
    'length_cm': {
      'fr': 'Longueur utile (cm)',
      'en': 'Usable length (cm)',
      'es': 'Largo útil (cm)',
    },
    'width_cm': {
      'fr': 'Largeur utile (cm)',
      'en': 'Usable width (cm)',
      'es': 'Ancho útil (cm)',
    },
    'height_cm': {
      'fr': 'Hauteur de chargement autorisée (cm)',
      'en': 'Permitted cargo height (cm)',
      'es': 'Altura de carga permitida (cm)',
    },
    'opening_width_cm': {
      'fr': 'Largeur du passage de chargement (cm)',
      'en': 'Loading opening width (cm)',
      'es': 'Ancho de acceso de carga (cm)',
    },
    'opening_height_cm': {
      'fr': 'Hauteur du passage de chargement (cm)',
      'en': 'Loading opening height (cm)',
      'es': 'Altura de acceso de carga (cm)',
    },
    'payload_kg': {
      'fr': 'Charge utile disponible (kg)',
      'en': 'Available payload (kg)',
      'es': 'Carga útil disponible (kg)',
    },
    'open_bed': {
      'fr':
          'Pour une caisse ouverte, indiquez les limites de chargement réellement autorisées, pas une hauteur illimitée.',
      'en':
          'For an open bed, enter the actual permitted loading limits, not unlimited height.',
      'es':
          'Para una caja abierta, indica los límites reales permitidos, no una altura ilimitada.',
    },
    'handlers': {
      'fr': 'Personnes disponibles pour la manutention',
      'en': 'Available cargo handlers',
      'es': 'Personas disponibles para manipular la carga',
    },
    'handling': {
      'fr': 'Aide au chargement et déchargement',
      'en': 'Loading and unloading help',
      'es': 'Ayuda para cargar y descargar',
    },
    'stairs': {
      'fr': 'Manutention dans les escaliers',
      'en': 'Handling on stairs',
      'es': 'Manipulación en escaleras',
    },
    'dolly': {'fr': 'Diable', 'en': 'Dolly', 'es': 'Carretilla'},
    'straps': {'fr': 'Sangles', 'en': 'Straps', 'es': 'Correas'},
    'liftgate': {
      'fr': 'Hayon élévateur',
      'en': 'Liftgate',
      'es': 'Plataforma elevadora',
    },
    'until': {
      'fr': 'Valide jusqu’au (AAAA-MM-JJ)',
      'en': 'Valid until (YYYY-MM-DD)',
      'es': 'Válido hasta (AAAA-MM-DD)',
    },
    'note': {
      'fr': 'Documents et mesures vérifiés',
      'en': 'Documents and measurements checked',
      'es': 'Documentos y medidas verificados',
    },
    'confirmed': {
      'fr':
          'J’ai vérifié ces capacités pour ce véhicule et la validité de ses documents.',
      'en':
          'I checked these capacities for this vehicle and the validity of its documents.',
      'es':
          'He verificado estas capacidades para este vehículo y la vigencia de sus documentos.',
    },
    'approve': {
      'fr': 'Valider les capacités',
      'en': 'Approve capacity',
      'es': 'Validar capacidad',
    },
    'revoke': {
      'fr': 'Retirer la validation',
      'en': 'Revoke verification',
      'es': 'Retirar validación',
    },
    'cancel': {'fr': 'Annuler', 'en': 'Cancel', 'es': 'Cancelar'},
    'positive': {
      'fr': 'Indiquez une valeur positive vérifiée.',
      'en': 'Enter a verified positive value.',
      'es': 'Indica un valor positivo verificado.',
    },
    'required': {
      'fr': 'Ce renseignement est requis.',
      'en': 'This information is required.',
      'es': 'Este dato es obligatorio.',
    },
    'date_error': {
      'fr': 'Choisissez une date future valide.',
      'en': 'Choose a valid future date.',
      'es': 'Elige una fecha futura válida.',
    },
    'error': {
      'fr':
          'Validation impossible. Vérifiez les documents approuvés, leurs dates et les capacités, puis rechargez le dossier si le véhicule a changé.',
      'en':
          'Unable to verify. Check approved documents, expiry dates and capacities, then reload the file if the vehicle changed.',
      'es':
          'No se pudo validar. Revisa los documentos aprobados, sus fechas y las capacidades; recarga el expediente si cambió el vehículo.',
    },
    'access': {
      'fr': 'Vous n’avez pas l’autorisation de valider ce véhicule.',
      'en': 'You are not allowed to verify this vehicle.',
      'es': 'No tienes permiso para validar este vehículo.',
    },
    'load_error': {
      'fr': 'Impossible de charger les véhicules. Réessayez.',
      'en': 'Unable to load vehicles. Try again.',
      'es': 'No se pudieron cargar los vehículos. Inténtalo de nuevo.',
    },
    'retry': {'fr': 'Réessayer', 'en': 'Try again', 'es': 'Reintentar'},
  };
}
