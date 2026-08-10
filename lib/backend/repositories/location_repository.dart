// ---------------------------------------------------------------------------
// LocationRepository — suivi GPS. `watchDriverLocation()` ne doit être
// utilisable côté client QUE si l'utilisateur courant a une mission active
// avec ce chauffeur — cette contrainte est appliquée par les Firestore
// Security Rules, pas ici (ce fichier est purement l'interface Dart).
// ---------------------------------------------------------------------------

import '../models/driver_location.dart';
import '../backend_exceptions.dart';

abstract class LocationRepository {
  /// À appeler périodiquement par l'app chauffeur (pas à chaque frame).
  Future<void> reportDriverLocation(DriverLocation location);

  /// Utilisé par le client pour suivre le chauffeur de SA mission active
  /// uniquement.
  Stream<DriverLocation?> watchDriverLocation(String driverId);
}

class NotConfiguredLocationRepository implements LocationRepository {
  const NotConfiguredLocationRepository();

  @override
  Future<void> reportDriverLocation(DriverLocation location) {
    throw BackendNotConfiguredException('reportDriverLocation: backend Firebase non configuré.');
  }

  @override
  Stream<DriverLocation?> watchDriverLocation(String driverId) => Stream.value(null);
}
