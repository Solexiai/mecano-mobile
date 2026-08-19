// ---------------------------------------------------------------------------
// DriverLocationReporter — boucle de partage GPS temps réel (Phase 5).
//
// RÈGLES RESPECTÉES :
// - Ne lit/écrit JAMAIS Firestore directement : passe systématiquement par
//   `LocationRepository.reportDriverLocation()` (elle-même backée par la
//   Cloud Function `recordTrackingPoint`, voir firebase_location_repository.dart).
// - Ne tourne QUE pendant que l'écran Mission Active est affiché ET que la
//   mission est dans un statut de trajet actif (assigné -> arrivée au
//   dropoff). Ne tourne jamais en arrière-plan (aucune permission
//   ACCESS_BACKGROUND_LOCATION demandée, voir AndroidManifest.xml).
// - Périodicité raisonnable (toutes les 8 secondes) : suffisant pour un
//   suivi temps réel fluide côté client sans surcharger le device/Firestore
//   ni consommer excessivement la batterie du chauffeur (voir consigne
//   "à appeler périodiquement, pas à chaque frame" dans location_repository.dart).
// - Toute erreur (permission refusée, GPS désactivé, Cloud Function en
//   échec) est capturée et exposée via `onError`, jamais silencieusement
//   avalée ni affichée comme un faux succès.
// ---------------------------------------------------------------------------

import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../backend/backend_locator.dart';
import '../backend/models/driver_location.dart';

enum LocationReporterError {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  reportFailed,
}

class DriverLocationReporter {
  DriverLocationReporter({this.interval = const Duration(seconds: 8)});

  final Duration interval;
  Timer? _timer;
  bool _busy = false;
  bool get isRunning => _timer != null;

  /// Démarre la boucle. Idempotent : un appel alors qu'elle tourne déjà ne
  /// fait rien. `onError` est invoqué à chaque échec (permission, GPS,
  /// réseau) sans jamais interrompre silencieusement la boucle — l'appelant
  /// décide s'il veut arrêter (`stop()`) ou laisser réessayer au prochain tick.
  Future<void> start({
    required void Function(LocationReporterError error) onError,
  }) async {
    if (isRunning) return;

    final ready = await _ensurePermission(onError);
    if (!ready) return;

    // Premier envoi immédiat, puis boucle périodique.
    await _tick(onError);
    _timer = Timer.periodic(interval, (_) => _tick(onError));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<bool> _ensurePermission(
    void Function(LocationReporterError) onError,
  ) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      onError(LocationReporterError.serviceDisabled);
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      onError(LocationReporterError.permissionDenied);
      return false;
    }
    if (permission == LocationPermission.deniedForever) {
      onError(LocationReporterError.permissionDeniedForever);
      return false;
    }
    return true;
  }

  Future<void> _tick(void Function(LocationReporterError) onError) async {
    if (_busy) return; // évite le chevauchement si un envoi précédent traîne.
    _busy = true;
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      await BackendLocator.locationRepository.reportDriverLocation(
        DriverLocation(
          driverId: '', // ignoré à l'écriture : ctx.uid fait foi côté serveur.
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          heading: position.heading,
          speed: position.speed,
          updatedAt: DateTime.now(),
        ),
      );
    } catch (_) {
      onError(LocationReporterError.reportFailed);
    } finally {
      _busy = false;
    }
  }
}
