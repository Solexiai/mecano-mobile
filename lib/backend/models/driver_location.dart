// ---------------------------------------------------------------------------
// DriverLocation (Firestore-ready) — collection `driver_locations/{driverId}`.
//
// Document unique par chauffeur (dernière position connue), mis à jour
// périodiquement (pas à chaque frame — cadence raisonnable, ex: 5-15s en
// mission active, beaucoup moins fréquent hors mission).
//
// SÉCURITÉ : Firestore Security Rules doivent garantir qu'un client ne peut
// lire la position d'un chauffeur QUE s'il a une mission active assignée à
// ce chauffeur (`delivery_id` correspondant à une mission dont il est
// customer_id). Jamais un accès global aux positions de tous les chauffeurs.
// ---------------------------------------------------------------------------

import 'firestore_date.dart';

class DriverLocation {
  final String driverId;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? heading;
  final double? speed;
  final DateTime updatedAt;
  final String? activeDeliveryId;

  const DriverLocation({
    required this.driverId,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.heading,
    this.speed,
    required this.updatedAt,
    this.activeDeliveryId,
  });

  Map<String, dynamic> toJson() => {
        'driver_id': driverId,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'heading': heading,
        'speed': speed,
        'updated_at': updatedAt.toIso8601String(),
        'active_delivery_id': activeDeliveryId,
      };

  factory DriverLocation.fromJson(Map<String, dynamic> json) {
    return DriverLocation(
      driverId: json['driver_id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      updatedAt: parseFirestoreDate(json['updated_at']) ?? DateTime.now(),
      activeDeliveryId: json['active_delivery_id'] as String?,
    );
  }
}
