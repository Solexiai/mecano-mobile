// ---------------------------------------------------------------------------
// DriverProfile (Firestore-ready) — collection `driver_profiles/{uid}`.
//
// Contient les informations d'onboarding et de statut d'un chauffeur.
// `status` ne doit être modifié QUE par les Cloud Functions
// `approveDriver()` / `rejectDriver()` (jamais écrit directement par le
// chauffeur lui-même).
// ---------------------------------------------------------------------------

import '../../models/enums.dart';

class DriverProfileV2 {
  final String uid;
  final String fullName;
  final String city;
  final DriverStatus status;
  final double serviceRadiusKm;
  final List<VehicleCategory> acceptedVehicleCategories;
  final List<String> acceptedItemCategoryKeys; // clés i18n cat_*
  final double rating;
  final int completedMissions;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final String? approvedByUserId;
  final String? rejectionReason;
  final bool identityVerified;
  final bool vehicleVerified;
  final DriverOnlineStatus onlineStatus;

  const DriverProfileV2({
    required this.uid,
    required this.fullName,
    required this.city,
    required this.status,
    required this.serviceRadiusKm,
    required this.acceptedVehicleCategories,
    required this.acceptedItemCategoryKeys,
    this.rating = 0,
    this.completedMissions = 0,
    required this.createdAt,
    this.approvedAt,
    this.approvedByUserId,
    this.rejectionReason,
    this.identityVerified = false,
    this.vehicleVerified = false,
    this.onlineStatus = DriverOnlineStatus.offline,
  });

  bool get canGoOnline => status.canGoOnline;

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'full_name': fullName,
        'city': city,
        'status': status.firestoreValue,
        'service_radius_km': serviceRadiusKm,
        'accepted_vehicle_categories': acceptedVehicleCategories.map((c) => c.firestoreValue).toList(),
        'accepted_item_category_keys': acceptedItemCategoryKeys,
        'rating': rating,
        'completed_missions': completedMissions,
        'created_at': createdAt.toIso8601String(),
        'approved_at': approvedAt?.toIso8601String(),
        'approved_by_user_id': approvedByUserId,
        'rejection_reason': rejectionReason,
        'identity_verified': identityVerified,
        'vehicle_verified': vehicleVerified,
        'online_status': onlineStatus.firestoreValue,
      };

  factory DriverProfileV2.fromJson(String uid, Map<String, dynamic> json) {
    return DriverProfileV2(
      uid: uid,
      fullName: json['full_name'] as String? ?? '',
      city: json['city'] as String? ?? '',
      status: DriverStatusX.fromFirestoreValue(json['status'] as String?),
      serviceRadiusKm: (json['service_radius_km'] as num? ?? 0).toDouble(),
      acceptedVehicleCategories: ((json['accepted_vehicle_categories'] as List?) ?? [])
          .map((v) => VehicleCategoryX.fromFirestoreValue(v as String?))
          .toList(),
      acceptedItemCategoryKeys:
          (json['accepted_item_category_keys'] as List?)?.cast<String>() ?? const [],
      rating: (json['rating'] as num? ?? 0).toDouble(),
      completedMissions: json['completed_missions'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      approvedAt:
          json['approved_at'] != null ? DateTime.parse(json['approved_at'] as String) : null,
      approvedByUserId: json['approved_by_user_id'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      identityVerified: json['identity_verified'] as bool? ?? false,
      vehicleVerified: json['vehicle_verified'] as bool? ?? false,
      onlineStatus: DriverOnlineStatusX.fromFirestoreValue(json['online_status'] as String?),
    );
  }
}
