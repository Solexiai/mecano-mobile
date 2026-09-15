// ---------------------------------------------------------------------------
// DriverProfile (Firestore-ready) — collection `driver_profiles/{uid}`.
//
// Contient les informations d'onboarding, de zone de service et de statut
// d'un chauffeur. Les champs d'adresse exacte restent privés : les règles
// Firestore n'autorisent la lecture du profil qu'au chauffeur propriétaire
// et aux rôles analyst/admin/super_admin.
// ---------------------------------------------------------------------------

import '../../models/enums.dart';

class DriverProfileV2 {
  final String uid;
  final String fullName;
  final String city;

  // Coordonnées déclaratives d'onboarding. Ces champs sont optionnels pour
  // rester compatibles avec les profils créés avant la refonte du wizard.
  final String phone;
  final String baseAddressFormatted;
  final String baseAddressLine1;
  final String baseRegion;
  final String basePostalCode;
  final String baseCountry;
  final String? basePlaceId;
  final double? baseLat;
  final double? baseLng;
  final List<String> spokenLanguages;
  final bool loadingAssistanceAvailable;

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
  final bool documentsAllValid;
  final DriverOnlineStatus onlineStatus;
  final DateTime? submittedForReviewAt;

  // Phase 2 — portail analyste.
  final String? documentsRequiredReason;
  final DateTime? documentsRequiredAt;
  final String? suspensionReason;
  final DateTime? suspendedAt;

  // Stripe Connect — lecture seule côté Flutter.
  final String? stripeConnectedAccountId;
  final String? stripeOnboardingUrl;
  final bool stripeChargesEnabled;
  final bool stripePayoutsEnabled;

  const DriverProfileV2({
    required this.uid,
    required this.fullName,
    required this.city,
    this.phone = '',
    this.baseAddressFormatted = '',
    this.baseAddressLine1 = '',
    this.baseRegion = '',
    this.basePostalCode = '',
    this.baseCountry = '',
    this.basePlaceId,
    this.baseLat,
    this.baseLng,
    this.spokenLanguages = const [],
    this.loadingAssistanceAvailable = false,
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
    this.documentsAllValid = false,
    this.onlineStatus = DriverOnlineStatus.offline,
    this.submittedForReviewAt,
    this.documentsRequiredReason,
    this.documentsRequiredAt,
    this.suspensionReason,
    this.suspendedAt,
    this.stripeConnectedAccountId,
    this.stripeOnboardingUrl,
    this.stripeChargesEnabled = false,
    this.stripePayoutsEnabled = false,
  });

  bool get canGoOnline => status.canGoOnline;

  DateTime get lastUpdatedAt {
    final candidates = <DateTime?>[
      approvedAt,
      documentsRequiredAt,
      suspendedAt,
      submittedForReviewAt,
      createdAt,
    ].whereType<DateTime>();
    return candidates.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'full_name': fullName,
    'city': city,
    'phone': phone,
    'base_address_formatted': baseAddressFormatted,
    'base_address_line1': baseAddressLine1,
    'base_region': baseRegion,
    'base_postal_code': basePostalCode,
    'base_country': baseCountry,
    'base_place_id': basePlaceId,
    'base_lat': baseLat,
    'base_lng': baseLng,
    'spoken_languages': spokenLanguages,
    'loading_assistance_available': loadingAssistanceAvailable,
    'status': status.firestoreValue,
    'service_radius_km': serviceRadiusKm,
    'accepted_vehicle_categories': acceptedVehicleCategories
        .map((c) => c.firestoreValue)
        .toList(),
    'accepted_item_category_keys': acceptedItemCategoryKeys,
    'rating': rating,
    'completed_missions': completedMissions,
    'created_at': createdAt.toIso8601String(),
    'approved_at': approvedAt?.toIso8601String(),
    'approved_by_user_id': approvedByUserId,
    'rejection_reason': rejectionReason,
    'identity_verified': identityVerified,
    'vehicle_verified': vehicleVerified,
    'documents_all_valid': documentsAllValid,
    'online_status': onlineStatus.firestoreValue,
    'submitted_for_review_at': submittedForReviewAt?.toIso8601String(),
    'documents_required_reason': documentsRequiredReason,
    'documents_required_at': documentsRequiredAt?.toIso8601String(),
    'suspension_reason': suspensionReason,
    'suspended_at': suspendedAt?.toIso8601String(),
    'stripe_connected_account_id': stripeConnectedAccountId,
    'stripe_onboarding_url': stripeOnboardingUrl,
    'stripe_charges_enabled': stripeChargesEnabled,
    'stripe_payouts_enabled': stripePayoutsEnabled,
  };

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) {
      try {
        return DateTime.parse(raw);
      } catch (_) {
        return null;
      }
    }
    try {
      return (raw as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }

  factory DriverProfileV2.fromJson(String uid, Map<String, dynamic> json) {
    return DriverProfileV2(
      uid: uid,
      fullName: json['full_name'] as String? ?? '',
      city: json['city'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      baseAddressFormatted: json['base_address_formatted'] as String? ?? '',
      baseAddressLine1: json['base_address_line1'] as String? ?? '',
      baseRegion: json['base_region'] as String? ?? '',
      basePostalCode: json['base_postal_code'] as String? ?? '',
      baseCountry: json['base_country'] as String? ?? '',
      basePlaceId: json['base_place_id'] as String?,
      baseLat: (json['base_lat'] as num?)?.toDouble(),
      baseLng: (json['base_lng'] as num?)?.toDouble(),
      spokenLanguages:
          (json['spoken_languages'] as List?)?.cast<String>() ?? const [],
      loadingAssistanceAvailable:
          json['loading_assistance_available'] as bool? ?? false,
      status: DriverStatusX.fromFirestoreValue(json['status'] as String?),
      serviceRadiusKm: (json['service_radius_km'] as num? ?? 0).toDouble(),
      acceptedVehicleCategories:
          ((json['accepted_vehicle_categories'] as List?) ?? [])
              .map((v) => VehicleCategoryX.fromFirestoreValue(v as String?))
              .toList(),
      acceptedItemCategoryKeys:
          (json['accepted_item_category_keys'] as List?)?.cast<String>() ??
          const [],
      rating: (json['rating'] as num? ?? 0).toDouble(),
      completedMissions: json['completed_missions'] as int? ?? 0,
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      approvedAt: _parseDate(json['approved_at']),
      approvedByUserId: json['approved_by_user_id'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      identityVerified: json['identity_verified'] as bool? ?? false,
      vehicleVerified: json['vehicle_verified'] as bool? ?? false,
      documentsAllValid: json['documents_all_valid'] as bool? ?? false,
      onlineStatus: DriverOnlineStatusX.fromFirestoreValue(
        json['online_status'] as String?,
      ),
      submittedForReviewAt: _parseDate(json['submitted_for_review_at']),
      documentsRequiredReason: json['documents_required_reason'] as String?,
      documentsRequiredAt: _parseDate(json['documents_required_at']),
      suspensionReason: json['suspension_reason'] as String?,
      suspendedAt: _parseDate(json['suspended_at']),
      stripeConnectedAccountId: json['stripe_connected_account_id'] as String?,
      stripeOnboardingUrl: json['stripe_onboarding_url'] as String?,
      stripeChargesEnabled: json['stripe_charges_enabled'] as bool? ?? false,
      stripePayoutsEnabled: json['stripe_payouts_enabled'] as bool? ?? false,
    );
  }
}
