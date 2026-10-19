/// Public-safe diagnostic for a multi-step driver registration attempt.
/// A failure can leave earlier steps persisted; never expose SDK messages or credentials.
enum DriverRegistrationStage {
  account,
  session,
  profile,
  vehicle,
  claims,
  documents,
  review,
}

String driverRegistrationFailureMessage(
  String locale,
  DriverRegistrationStage stage,
) {
  final stageText = switch (stage) {
    DriverRegistrationStage.account => (
      'la création ou la connexion au compte',
      'account creation or sign-in',
      'la creación o el acceso a la cuenta',
    ),
    DriverRegistrationStage.session => (
      'la vérification de la session',
      'session verification',
      'la verificación de la sesión',
    ),
    DriverRegistrationStage.profile => (
      "l'enregistrement du profil chauffeur",
      'driver profile registration',
      'el registro del perfil del conductor',
    ),
    DriverRegistrationStage.vehicle => (
      "l'enregistrement du véhicule",
      'vehicle registration',
      'el registro del vehículo',
    ),
    DriverRegistrationStage.claims => (
      "l'actualisation des autorisations du compte",
      'refreshing account permissions',
      'la actualización de los permisos de la cuenta',
    ),
    DriverRegistrationStage.documents => (
      'le téléversement des documents',
      'document upload',
      'la carga de documentos',
    ),
    DriverRegistrationStage.review => (
      "l'envoi du dossier en vérification",
      'submitting the file for review',
      'el envío del expediente a revisión',
    ),
  };
  return switch (locale) {
    'en' =>
      'Registration could not be completed during ${stageText.$2}. '
          'Earlier steps may already be saved. Check your existing application '
          'before trying again to avoid duplicates.',
    'es' =>
      'No se pudo completar el registro durante ${stageText.$3}. '
          'Los pasos anteriores podrían haberse guardado. Revisa tu expediente '
          'antes de reintentarlo para evitar duplicados.',
    _ =>
      "L'inscription n'a pas pu être terminée pendant ${stageText.$1}. "
          'Les étapes précédentes peuvent déjà être enregistrées. '
          'Consultez votre dossier avant de réessayer pour éviter les doublons.',
  };
}
