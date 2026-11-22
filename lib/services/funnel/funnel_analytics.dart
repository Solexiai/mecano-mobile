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
import 'funnel_sender_stub.dart'
    if (dart.library.js_interop) 'funnel_sender_web.dart';

abstract final class FunnelAnalytics {
  /// Dernier événement envoyé par nom (tests, et anti-doublon d'étape).
  static final List<(String, Map<String, Object>)> sentForTest = [];

  static void event(String name, [Map<String, Object> params = const {}]) {
    try {
      if (sentForTest.length > 200) sentForTest.removeAt(0);
      sentForTest.add((name, params));
      sendFunnelEvent(name, params);
    } catch (_) {
      // La mesure ne doit jamais gêner le client.
    }
  }

  static int? _lastStep;

  /// Étape de réservation affichée (une fois par changement).
  static void bookingStep(int step) {
    if (_lastStep == step) return;
    _lastStep = step;
    event('booking_step', {'step': step});
  }
}
