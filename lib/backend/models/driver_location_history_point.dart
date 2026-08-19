// ---------------------------------------------------------------------------
// DriverLocationHistoryPoint (Firestore-ready) — collection
// `driver_locations/{driverId}/history/{eventId}`.
//
// Un document par point GPS enregistré par `recordTrackingPoint()` PENDANT
// une mission active réelle (voir en-tête de cette Cloud Function). Forme
// volontairement DIFFÉRENTE de `DriverLocation` (position courante, document
// unique) : ici chaque document est un point figé dans le temps, rattaché à
// une mission précise (`deliveryId`), utilisé pour reconstituer le trajet
// réellement parcouru (polyline).
//
// SÉCURITÉ : lecture protégée par `firestore.rules`
// (`driver_locations/{driverId}/history/{eventId}`) — le chauffeur
// lui-même, un analyste/admin, ou un client ayant une mission active dont
// `delivery_id` correspond. Écriture exclusivement Cloud Functions
// (`allow write: if false`).
// ---------------------------------------------------------------------------

import 'firestore_date.dart';

class DriverLocationHistoryPoint {
  final String deliveryId;
  final double latitude;
  final double longitude;
  final DateTime recordedAt;

  const DriverLocationHistoryPoint({
    required this.deliveryId,
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
  });

  factory DriverLocationHistoryPoint.fromJson(Map<String, dynamic> json) {
    return DriverLocationHistoryPoint(
      deliveryId: json['delivery_id'] as String? ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      recordedAt: parseFirestoreDate(json['recorded_at']) ?? DateTime.now(),
    );
  }
}
