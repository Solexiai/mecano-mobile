// Mesure du parcours (Daniel, 2026-11-22) : « qui me dit qu'il n'y a pas de
// clients qui ont essayé de s'inscrire ? » Jusqu'ici Google Analytics ne
// voyait que des pages vues ; le parcours de réservation tient sur une seule
// adresse, donc impossible de savoir à quelle étape les gens décrochent.
//
// Ces événements partent vers Google Analytics (gtag, déjà chargé par
// web/index.html). Aucune donnée personnelle : seulement le nom de l'étape.
// Hors navigateur, ou si gtag est bloqué, rien ne se passe.
//
//   booking_step      étape affichée (1 à 7)
//   price_wall        prix demandé sans compte (renvoi vers la connexion)
//   price_shown       prix affiché
//   sign_up           compte créé (method : customer | driver)
//   booking_created   réservation créée
//   driver_signup_step  étape de l'inscription chauffeur
//
// Pixel Meta (Daniel, 2026-11-26) : les mêmes moments partent aussi vers Meta,
// pour que ses publicités apprennent qui réserve. Voir [metaEventFor] pour la
// correspondance, et web/meta_pixel.js pour l'identifiant et l'accord du
// visiteur (rien ne part sans les deux).
import 'funnel_sender_stub.dart'
    if (dart.library.js_interop) 'funnel_sender_web.dart';

abstract final class FunnelAnalytics {
  /// Dernier événement envoyé par nom (tests, et anti-doublon d'étape).
  static final List<(String, Map<String, Object>)> sentForTest = [];

  /// [eventId] : identifiant unique de l'événement pour Meta (ex. la
  /// réservation), afin que la version serveur ne le compte pas en double.
  static void event(
    String name, [
    Map<String, Object> params = const {},
    String? eventId,
  ]) {
    try {
      if (sentForTest.length > 200) sentForTest.removeAt(0);
      sentForTest.add((name, params));
      sendFunnelEvent(name, params);
    } catch (_) {
      // La mesure ne doit jamais gêner le client.
    }
    try {
      final meta = metaEventFor(name, params);
      if (meta != null) sendMetaEvent(meta.$1, meta.$2, eventId);
    } catch (_) {
      // Idem.
    }
  }

  /// Montant d'un prix ou d'une réservation, pour Google Analytics et Meta.
  static Map<String, Object> priceParams(Object? total) =>
      total is num && total > 0 ? {'value': total, 'currency': 'CAD'} : const {};

  /// L'événement Meta qui correspond à un événement du parcours, ou `null`
  /// si Meta n'a pas à le recevoir.
  ///
  ///   booking_step 1            → ViewContent (la demande est ouverte)
  ///   booking_step 2            → InitiateCheckout (demande commencée)
  ///   price_shown               → Lead (prix vu)
  ///   deposit_checkout          → AddPaymentInfo (départ vers le paiement)
  ///   booking_created           → Purchase (réservation, avec son montant)
  ///   driver_signup_submitted   → CompleteRegistration (dossier chauffeur envoyé)
  static (String, Map<String, Object>)? metaEventFor(
    String name,
    Map<String, Object> params,
  ) {
    final price = priceParams(params['value']);
    switch (name) {
      case 'booking_step':
        if (params['step'] == 1) {
          return ('ViewContent', {'content_name': 'delivery_request'});
        }
        if (params['step'] == 2) return ('InitiateCheckout', const {});
        return null;
      case 'price_shown':
        return ('Lead', price);
      case 'deposit_checkout':
        return ('AddPaymentInfo', const {});
      case 'booking_created':
        // Meta exige un montant pour un achat.
        return price.isEmpty ? null : ('Purchase', price);
      case 'driver_signup_submitted':
        return ('CompleteRegistration', {'content_name': 'driver'});
    }
    return null;
  }

  static int? _lastStep;

  /// Étape de réservation affichée (une fois par changement).
  static void bookingStep(int step) {
    if (_lastStep == step) return;
    _lastStep = step;
    event('booking_step', {'step': step});
  }
}
