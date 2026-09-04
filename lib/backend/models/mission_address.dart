// ---------------------------------------------------------------------------
// MissionAddress — adresse structurée d'un stop (pickup ou dropoff).
//
// Extrait dans son propre fichier (Phase 4) pour être partagé sans cycle
// d'import entre `delivery_mission.dart` (lecture du document mission, qui
// contient `pickup_address`/`dropoff_address` dénormalisés) et
// `mission_repository.dart` (construction de `CreateMissionRequest`).
// Miroir exact de `StopInput.address` dans
// `functions/src/functions/createDeliveryRequest.ts`.
//
// EXTENSION (MOVI-K — CORRECTION UX LIVRAISON, adresses réelles +
// autocomplete + géocodage) : `formattedAddress`/`placeId` ajoutés en
// OPTIONNEL (nullable) pour tracer l'adresse formatée réelle et
// l'identifiant fournisseur (Google Place ID ou équivalent) ayant permis de
// générer `lat`/`lng`. Ces deux champs sont TOUJOURS générés
// automatiquement par `AddressAutocompleteProvider.resolvePlace()` — jamais
// saisis manuellement par le client. Nullable pour rester rétrocompatible
// avec les missions historiques créées avant cette évolution (aucun de ces
// deux champs n'existait alors) : `fromJson` ne lève jamais d'exception sur
// un document qui ne les contient pas.
// ---------------------------------------------------------------------------

class MissionAddress {
  final String line1;
  final String city;
  final String postalCode;
  final double lat;
  final double lng;

  /// Adresse formatée telle que renvoyée par le fournisseur cartographique
  /// (ex: "527 Rue Lacasse, Terrebonne, QC J6W 4Y7, Canada"). `null` pour
  /// les missions historiques créées avant cette extension.
  final String? formattedAddress;

  /// Identifiant opaque du lieu chez le fournisseur (ex: Google Place ID).
  /// `null` pour les missions historiques créées avant cette extension.
  final String? placeId;

  const MissionAddress({
    required this.line1,
    required this.city,
    required this.postalCode,
    required this.lat,
    required this.lng,
    this.formattedAddress,
    this.placeId,
  });

  Map<String, dynamic> toJson() => {
        'line1': line1,
        'city': city,
        'postal_code': postalCode,
        'lat': lat,
        'lng': lng,
        if (formattedAddress != null) 'formatted_address': formattedAddress,
        if (placeId != null) 'place_id': placeId,
      };

  factory MissionAddress.fromJson(Map<String, dynamic> json) => MissionAddress(
        line1: json['line1'] as String? ?? '',
        city: json['city'] as String? ?? '',
        postalCode: json['postal_code'] as String? ?? '',
        lat: (json['lat'] as num? ?? 0).toDouble(),
        lng: (json['lng'] as num? ?? 0).toDouble(),
        formattedAddress: json['formatted_address'] as String?,
        placeId: json['place_id'] as String?,
      );
}
