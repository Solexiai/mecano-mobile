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

/// Message serveur STABLE renvoyé par un kill switch (Phase 7, Bloc X) quand
/// `system_config/runtime_flags` refuse une opération — voir
/// `functions/src/lib/runtimeFlags.ts::KILL_SWITCH_ERROR_CODE`. La Cloud
/// Function renvoie ce texte comme `HttpsError.message` (jamais le nom du
/// flag, sa valeur, ni un détail interne) ; le client le compare pour
/// afficher la clé i18n générique `service_temporarily_unavailable` au lieu
/// du message brut du serveur.
const String kKillSwitchServerMessage = 'service_temporarily_unavailable';

/// Valeur stable d'`errorCode` (voir [AcceptMissionResult.errorCode] et
/// équivalents) utilisée par les repositories pour signaler à l'UI qu'un
/// refus provient d'un kill switch plutôt que d'un code HttpsError générique
/// (`failed-precondition` est partagé avec d'autres refus métier ordinaires
/// — voir acceptDelivery.ts). Les écrans mappent CETTE valeur vers la clé
/// i18n `service_temporarily_unavailable`.
const String kKillSwitchErrorCode = 'service_temporarily_unavailable';

/// Vrai si `e` est une [CloudFunctionException] déclenchée par un kill
/// switch serveur (Phase 7, Bloc X) plutôt qu'une erreur métier ordinaire.
/// Utilisé par les écrans qui appellent `createDeliveryRequest`,
/// `acceptDelivery`, ou tout point d'entrée protégé par
/// `system_config/runtime_flags`, pour mapper la refusal vers la clé i18n
/// `service_temporarily_unavailable` plutôt que d'afficher un message brut
/// ou un message métier inadapté (ex: "mission déjà acceptée").
bool isKillSwitchException(Object e) =>
    e is CloudFunctionException && e.message == kKillSwitchServerMessage;
