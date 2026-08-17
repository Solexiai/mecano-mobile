// ---------------------------------------------------------------------------
// DriverVehicle (Firestore-ready) — collection `driver_vehicles/{id}`.
// ---------------------------------------------------------------------------

import '../../models/enums.dart';

class DriverVehicle {
  final String id;
  final String driverId;
  final VehicleCategory category;
  final String makeModel;
  final int year;
  final String plate;
  final double? maxPayloadKg;
  final bool isVerified;
  final DateTime createdAt;
  // Champ optionnel ajouté pour le portail analyste (fiche véhicule détaillée
  // — point 5). Non capturé par le formulaire d'onboarding actuel
  // (`makeModel` reste le champ combiné source), donc quasi toujours null
  // pour les véhicules existants : l'UI doit afficher "Non renseigné" le cas
  // échéant plutôt que de supposer une valeur.
  final String? color;

  const DriverVehicle({
    required this.id,
    required this.driverId,
    required this.category,
    required this.makeModel,
    required this.year,
    required this.plate,
    this.maxPayloadKg,
    this.isVerified = false,
    required this.createdAt,
    this.color,
  });

  /// Sépare `makeModel` (ex: "Toyota Corolla") en (marque, modèle) au mieux
  /// pour l'affichage — premier mot = marque, reste = modèle. Purement
  /// cosmétique pour la fiche analyste, ne modifie pas les données stockées.
  String get displayMake => makeModel.trim().split(' ').first;
  String get displayModel {
    final parts = makeModel.trim().split(' ');
    return parts.length > 1 ? parts.skip(1).join(' ') : '';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'driver_id': driverId,
        'category': category.firestoreValue,
        'make_model': makeModel,
        'year': year,
        'plate': plate,
        'max_payload_kg': maxPayloadKg,
        'is_verified': isVerified,
        'created_at': createdAt.toIso8601String(),
        'color': color,
      };

  factory DriverVehicle.fromJson(String id, Map<String, dynamic> json) {
    return DriverVehicle(
      id: id,
      driverId: json['driver_id'] as String,
      category: VehicleCategoryX.fromFirestoreValue(json['category'] as String?),
      makeModel: json['make_model'] as String? ?? '',
      year: json['year'] as int? ?? 0,
      plate: json['plate'] as String? ?? '',
      maxPayloadKg: (json['max_payload_kg'] as num?)?.toDouble(),
      isVerified: json['is_verified'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      color: json['color'] as String?,
    );
  }
}
