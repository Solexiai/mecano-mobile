// ---------------------------------------------------------------------------
// LocationRepository — suivi GPS. `watchDriverLocation()` ne doit être
// utilisable côté client QUE si l'utilisateur courant a une mission active
// avec ce chauffeur — cette contrainte est appliquée par les Firestore
// Security Rules, pas ici (ce fichier est purement l'interface Dart).
// ---------------------------------------------------------------------------

import '../models/driver_location.dart';
import '../models/driver_location_history_point.dart';
import '../backend_exceptions.dart';

abstract class LocationRepository {
  /// À appeler périodiquement par l'app chauffeur (pas à chaque frame).
  Future<void> reportDriverLocation(DriverLocation location);

  /// Utilisé par le client pour suivre le chauffeur de SA mission active
  /// uniquement.
  Stream<DriverLocation?> watchDriverLocation(String driverId);

  /// Historique GPS du chauffeur (Phase 5, partie 2 — trajet réellement
  /// parcouru). Retourne TOUS les points connus pour ce chauffeur (toutes
  /// missions confondues, non triés) — le filtrage par mission active
  /// courante ET le tri chronologique sont effectués côté appelant
  /// (`LiveTrackingMap`), conformément à la convention du projet
  /// "requête simple + tri en mémoire" (évite un index composite dédié).
  Stream<List<DriverLocationHistoryPoint>> watchDriverLocationHistory(
    String driverId,
  );
}

class NotConfiguredLocationRepository implements LocationRepository {
  const NotConfiguredLocationRepository();

  @override
  Future<void> reportDriverLocation(DriverLocation location) {
    throw BackendNotConfiguredException('reportDriverLocation: backend Firebase non configuré.');
  }

  @override
  Stream<DriverLocation?> watchDriverLocation(String driverId) => Stream.value(null);

  @override
  Stream<List<DriverLocationHistoryPoint>> watchDriverLocationHistory(
    String driverId,
  ) => Stream.value(const []);
}
