// Position « Vous êtes ici » affichée au chauffeur (2026-11-07) : la
// dernière position GPS connue si elle a moins de 30 minutes — la même
// fraîcheur que le dispatch serveur (functions/src/lib/dispatchDistance.ts,
// FRESH_LOCATION_MS). Au-delà, rien : mieux vaut aucun point qu'un point
// faux.
import 'package:latlong2/latlong.dart' as ll;

import '../backend/models/driver_location.dart';

const Duration liveLocationMaxAge = Duration(minutes: 30);

ll.LatLng? livePositionFor(DriverLocation? location, DateTime now) {
  if (location == null) return null;
  final updated = location.updatedAt;
  if (updated == null || now.difference(updated) > liveLocationMaxAge) return null;
  return ll.LatLng(location.latitude, location.longitude);
}
