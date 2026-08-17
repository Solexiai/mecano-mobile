import 'enums.dart';

/// Demonstration provider profile used to power provider matching screens.
/// All data here is clearly demo/sample data (see DemoDataService).
class ProviderProfile {
  final String id;
  final String fullName;
  final String? businessName;
  final String profilePhotoUrl;
  final String city;
  final double serviceRadiusKm;
  final UserRole type; // driver or mechanic
  final VerificationStatus verification;
  final double rating; // 0-5
  final int completedJobs;
  final int responseRateHrs; // avg response time in hours (demo)
  final List<String> languages;
  final DateTime memberSince;
  final bool identityVerified;
  final bool documentsVerified;
  final bool vehicleVerified;

  // Driver-specific
  final VehicleCategory? vehicleType;
  final String? vehicleMakeModel;
  final int? vehicleYear;
  final double? maxPayloadKg;
  final List<String> acceptedItemCategories;

  // Mechanic-specific
  final List<String> specialties;
  final int? yearsExperience;
  final bool emergencyAvailable;

  // Pricing (demo)
  final double hourlyRate;
  final double perKmRate;
  final double travelFee;
  final double minimumFee;

  const ProviderProfile({
    required this.id,
    required this.fullName,
    this.businessName,
    required this.profilePhotoUrl,
    required this.city,
    required this.serviceRadiusKm,
    required this.type,
    required this.verification,
    required this.rating,
    required this.completedJobs,
    required this.responseRateHrs,
    required this.languages,
    required this.memberSince,
    this.identityVerified = false,
    this.documentsVerified = false,
    this.vehicleVerified = false,
    this.vehicleType,
    this.vehicleMakeModel,
    this.vehicleYear,
    this.maxPayloadKg,
    this.acceptedItemCategories = const [],
    this.specialties = const [],
    this.yearsExperience,
    this.emergencyAvailable = false,
    required this.hourlyRate,
    required this.perKmRate,
    required this.travelFee,
    required this.minimumFee,
  });
}
