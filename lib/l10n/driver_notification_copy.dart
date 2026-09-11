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
  };

  static String? maybeTranslate(String key, String locale) {
    final values = _t[key];
    if (values == null) return null;
    return values[locale] ?? values['fr'];
  }
}
