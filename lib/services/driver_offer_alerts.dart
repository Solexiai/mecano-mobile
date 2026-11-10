// Offre « qui sonne » (2026-11-09, « comme Uber », approuvé par Daniel).
//
// Quand un chauffeur EN SERVICE reçoit une nouvelle offre pendant que l'app
// est ouverte, un écran plein écran apparaît (montant en gros, trajet,
// compte à rebours, Accepter / Refuser) et le téléphone sonne et vibre en
// boucle jusqu'à sa réponse — au plus `maxRing`, puis l'offre reste dans la
// liste. App fermée ou en arrière-plan : c'est la notification push (canal
// Android « movik_delivery_offers », son Movi-K, vibration longue) qui
// alerte ; en l'ouvrant, l'écran d'offre apparaît.
//
// `enabled` vaut false par défaut (tests, outils) ; main.dart l'active.
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform, visibleForTesting;
import 'package:flutter/services.dart';

/// Joue / arrête la sonnerie et la vibration d'offre.
abstract class OfferAlertPlayer {
  Future<void> start();
  Future<void> stop();
}

/// Android : MediaPlayer en boucle + vibration (MainActivity.kt). Ailleurs :
/// une vibration courte seulement (aucun son natif sur le web).
class NativeOfferAlertPlayer implements OfferAlertPlayer {
  const NativeOfferAlertPlayer();
  static const _channel = MethodChannel('movik/offer_alert');

  bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> start() async {
    try {
      if (_android) {
        await _channel.invokeMethod<void>('start');
      } else {
        await HapticFeedback.heavyImpact();
      }
    } catch (_) {
      // Pas de son ? L'écran d'offre reste affiché : rien ne bloque.
    }
  }

  @override
  Future<void> stop() async {
    if (!_android) return;
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {}
  }
}

class DriverOfferAlerts {
  DriverOfferAlerts._();

  /// Activé au démarrage de l'app (main.dart). Désactivé dans les tests.
  static bool enabled = false;

  /// Durée maximale de la sonnerie pour une offre (l'écran reste ouvert).
  static const Duration maxRing = Duration(seconds: 30);

  static OfferAlertPlayer player = const NativeOfferAlertPlayer();

  @visibleForTesting
  static void resetForTest() {
    enabled = false;
    player = const NativeOfferAlertPlayer();
  }
}
