// ---------------------------------------------------------------------------
// MissionAddress — adresse structurée d'un stop (pickup ou dropoff).
//
// Extrait dans son propre fichier (Phase 4) pour être partagé sans cycle
// d'import entre `delivery_mission.dart` (lecture du document mission, qui
// contient `pickup_address`/`dropoff_address` dénormalisés) et
// `mission_repository.dart` (construction de `CreateMissionRequest`).
// Miroir exact de `StopInput.address` dans
// `functions/src/functions/createDeliveryRequest.ts`.
// ---------------------------------------------------------------------------

class MissionAddress {
  final String line1;
  final String city;
  final String postalCode;
  final double lat;
  final double lng;

  const MissionAddress({
    required this.line1,
    required this.city,
    required this.postalCode,
    required this.lat,
    required this.lng,
  });

  Map<String, dynamic> toJson() => {
        'line1': line1,
        'city': city,
        'postal_code': postalCode,
        'lat': lat,
        'lng': lng,
      };

  factory MissionAddress.fromJson(Map<String, dynamic> json) => MissionAddress(
        line1: json['line1'] as String? ?? '',
        city: json['city'] as String? ?? '',
        postalCode: json['postal_code'] as String? ?? '',
        lat: (json['lat'] as num? ?? 0).toDouble(),
        lng: (json['lng'] as num? ?? 0).toDouble(),
      );
}
