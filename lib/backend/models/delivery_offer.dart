// ---------------------------------------------------------------------------
// DeliveryOffer (Firestore-ready) — collection `delivery_offers/{id}`.
//
// Représente une offre de mission poussée à un ou plusieurs chauffeurs
// candidats pendant la phase de dispatch (avant acceptation atomique).
// ---------------------------------------------------------------------------

import 'firestore_date.dart';

class DeliveryOffer {
  final String id;
  final String missionId;
  final String driverId;
  final DateTime offeredAt;
  final DateTime expiresAt;

  /// pending | accepted | expired | declined | superseded (un autre chauffeur
  /// a accepté en premier)
  final String status;

  const DeliveryOffer({
    required this.id,
    required this.missionId,
    required this.driverId,
    required this.offeredAt,
    required this.expiresAt,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'mission_id': missionId,
        'driver_id': driverId,
        'offered_at': offeredAt.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'status': status,
      };

  factory DeliveryOffer.fromJson(String id, Map<String, dynamic> json) {
    return DeliveryOffer(
      id: id,
      missionId: json['mission_id'] as String? ?? '',
      driverId: json['driver_id'] as String? ?? '',
      offeredAt: parseFirestoreDate(json['offered_at']) ?? DateTime.now(),
      expiresAt: parseFirestoreDate(json['expires_at']) ?? DateTime.now(),
      status: json['status'] as String? ?? 'pending',
    );
  }
}
