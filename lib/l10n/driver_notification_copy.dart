/// Textes i18n dédiés aux nouvelles notifications chauffeur (Phase 8D).
///
/// Gardés dans un petit fichier séparé pour éviter de modifier le très gros
/// dictionnaire historique AppStrings uniquement pour deux clés. LocaleProvider
/// consulte d'abord ce dictionnaire, puis retombe sur AppStrings.
class DriverNotificationCopy {
  DriverNotificationCopy._();

  static const Map<String, Map<String, String>> _t = {
    'notif_delivery_offer_title': {
      'fr': 'Nouvelle livraison disponible',
      'en': 'New delivery available',
      'es': 'Nueva entrega disponible',
    },
    'notif_delivery_offer_body': {
      'fr': 'Une demande est disponible près de vous. Ouvrez-la pour voir les détails.',
      'en': 'A delivery request is available near you. Open it to view the details.',
      'es': 'Hay una solicitud de entrega cerca de ti. Ábrela para ver los detalles.',
    },
    'driver_offer_time_left': {'fr': "Temps pour répondre :", 'en': "Time to respond:", 'es': "Tiempo para responder:"},
    'driver_offer_distance': {'fr': "Distance géographique jusqu'à l'enlèvement :", 'en': "Straight-line distance to pickup:", 'es': "Distancia geográfica hasta la recogida:"},
    'driver_offer_details': {'fr': "Voir les détails", 'en': "View details", 'es': "Ver detalles"},
    'driver_offer_action_error': {'fr': "L’offre n’a pas pu être traitée. Vérifiez votre connexion ou réessayez.", 'en': "The offer could not be processed. Check your connection or try again.", 'es': "No se pudo procesar la oferta. Revisa tu conexión o inténtalo de nuevo."},
    'driver_offer_close': {'fr': "Fermer", 'en': "Close", 'es': "Cerrar"},
    'driver_offer_decline': {'fr': "Refuser", 'en': "Decline", 'es': "Rechazar"},
    'driver_offer_accept': {'fr': "Accepter", 'en': "Accept", 'es': "Aceptar"},
  };

  static Map<String, Map<String, String>> get allEntries => Map.unmodifiable(_t);

  static String? maybeTranslate(String key, String locale) {
    final values = _t[key];
    if (values == null) return null;
    return values[locale] ?? values['fr'];
  }
}
