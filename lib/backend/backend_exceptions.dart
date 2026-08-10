// ---------------------------------------------------------------------------
// Exceptions partagées de la couche backend.
// ---------------------------------------------------------------------------

/// Levée par les implémentations "NotConfigured" des repositories lorsqu'une
/// opération d'écriture est tentée alors que Firebase n'est pas configuré.
/// Permet à l'UI d'afficher un message clair au lieu de simuler un succès.
class BackendNotConfiguredException implements Exception {
  final String message;
  const BackendNotConfiguredException(this.message);
  @override
  String toString() => 'BackendNotConfiguredException: $message';
}

/// Levée quand une Cloud Function distante renvoie une erreur métier
/// (ex: 'delivery_already_assigned', 'driver_not_approved').
class CloudFunctionException implements Exception {
  final String code;
  final String message;
  const CloudFunctionException(this.code, this.message);
  @override
  String toString() => 'CloudFunctionException[$code]: $message';
}
