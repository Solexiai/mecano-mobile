/// Shared enums for Movi-k marketplace.
///
/// NOTE ON ROLES: `UserRole` is retained for backward compatibility with the
/// existing local-demo AuthProvider/AppUser code path. The new Firebase-backed
/// authorization model uses `PlatformRole` (see below), which is the source
/// of truth once Firebase Authentication + custom claims are configured.
/// A Flutter-side enum value is NEVER sufficient authorization on its own —
/// see AUTHZ NOTE in `platform_role` below.
enum UserRole { customer, driver, mechanic, admin }

enum VerificationStatus { pending, verified, rejected }

// =====================================================================
// PLATFORM ROLES (Firebase custom-claims backed)
// =====================================================================

/// Roles enforced by Firebase custom claims + Firestore Security Rules +
/// Cloud Functions. A `PlatformRole` value read on the Flutter client is
/// ONLY used to drive UI (show/hide). It is never trusted as authorization
/// by itself — every sensitive write MUST be re-validated server-side
/// (Security Rules and/or Cloud Functions reading `request.auth.token`).
enum PlatformRole { customer, driver, mechanic, analyst, admin, superAdmin }

extension PlatformRoleX on PlatformRole {
  String get claimValue => name;

  static PlatformRole fromClaim(String value) => PlatformRole.values.firstWhere(
        (r) => r.name == value,
        orElse: () => PlatformRole.customer,
      );

  /// Roles allowed to review/approve driver documents and applications.
  bool get canReviewDrivers => this == PlatformRole.analyst || this == PlatformRole.admin || this == PlatformRole.superAdmin;

  /// Only super_admin may change protected financial policy (tip %, etc).
  bool get canModifyProtectedFinancialPolicy => this == PlatformRole.superAdmin;

  /// admin/super_admin may edit standard pricing configuration.
  bool get canEditPricingConfig => this == PlatformRole.admin || this == PlatformRole.superAdmin;
}

// =====================================================================
// DRIVER STATUS (approval workflow)
// =====================================================================

enum DriverStatus {
  registrationIncomplete,
  pendingReview,
  documentsRequired,
  approved,
  rejected,
  suspended,
  inactive,
}

extension DriverStatusX on DriverStatus {
  String get key {
    switch (this) {
      case DriverStatus.registrationIncomplete:
        return 'driver_status_registration_incomplete';
      case DriverStatus.pendingReview:
        return 'driver_status_pending_review';
      case DriverStatus.documentsRequired:
        return 'driver_status_documents_required';
      case DriverStatus.approved:
        return 'driver_status_approved';
      case DriverStatus.rejected:
        return 'driver_status_rejected';
      case DriverStatus.suspended:
        return 'driver_status_suspended';
      case DriverStatus.inactive:
        return 'driver_status_inactive';
    }
  }

  /// Only an approved, non-suspended driver may ever go online / receive offers.
  bool get canGoOnline => this == DriverStatus.approved;
}

// =====================================================================
// DRIVER DOCUMENTS
// =====================================================================

enum DriverDocumentType {
  driversLicence,
  vehicleRegistration,
  insurance,
  identity,
  vehiclePhoto,
  other,
}

extension DriverDocumentTypeX on DriverDocumentType {
  String get key {
    switch (this) {
      case DriverDocumentType.driversLicence:
        return 'doc_type_drivers_licence';
      case DriverDocumentType.vehicleRegistration:
        return 'doc_type_vehicle_registration';
      case DriverDocumentType.insurance:
        return 'doc_type_insurance';
      case DriverDocumentType.identity:
        return 'doc_type_identity';
      case DriverDocumentType.vehiclePhoto:
        return 'doc_type_vehicle_photo';
      case DriverDocumentType.other:
        return 'doc_type_other';
    }
  }
}

enum DriverDocumentStatus {
  missing,
  uploaded,
  pendingReview,
  approved,
  rejected,
  expired,
  replacementRequired,
}

extension DriverDocumentStatusX on DriverDocumentStatus {
  String get key {
    switch (this) {
      case DriverDocumentStatus.missing:
        return 'doc_status_missing';
      case DriverDocumentStatus.uploaded:
        return 'doc_status_uploaded';
      case DriverDocumentStatus.pendingReview:
        return 'doc_status_pending_review';
      case DriverDocumentStatus.approved:
        return 'doc_status_approved';
      case DriverDocumentStatus.rejected:
        return 'doc_status_rejected';
      case DriverDocumentStatus.expired:
        return 'doc_status_expired';
      case DriverDocumentStatus.replacementRequired:
        return 'doc_status_replacement_required';
    }
  }
}

// =====================================================================
// VEHICLE CATEGORY (extended set per new spec — superset of VehicleType)
// =====================================================================

enum VehicleCategory {
  car,
  suv,
  minivan,
  cargoVan,
  pickupTruck,
  cubeTruck,
  truck,
  trailer,
  other,
}

extension VehicleCategoryX on VehicleCategory {
  String get key {
    switch (this) {
      case VehicleCategory.car:
        return 'vehicle_cat_car';
      case VehicleCategory.suv:
        return 'vehicle_cat_suv';
      case VehicleCategory.minivan:
        return 'vehicle_cat_minivan';
      case VehicleCategory.cargoVan:
        return 'vehicle_cat_cargo_van';
      case VehicleCategory.pickupTruck:
        return 'vehicle_cat_pickup_truck';
      case VehicleCategory.cubeTruck:
        return 'vehicle_cat_cube_truck';
      case VehicleCategory.truck:
        return 'vehicle_cat_truck';
      case VehicleCategory.trailer:
        return 'vehicle_cat_trailer';
      case VehicleCategory.other:
        return 'vehicle_cat_other';
    }
  }
}

// =====================================================================
// MISSION / DISPATCH STATUS (delivery_requests collection state machine)
// =====================================================================

/// Server-authoritative mission lifecycle. Distinct from the existing
/// customer-facing `DeliveryStatus` (kept for backward compatibility with
/// current local screens); `MissionStatus` is the Firestore state machine
/// enforced by Cloud Functions / Security Rules for the new architecture.
enum MissionStatus {
  draft,
  quoted,
  searchingDriver,
  offered,
  assigned,
  driverToPickup,
  arrivedAtPickup,
  pickedUp,
  inTransit,
  arrivedAtDropoff,
  delivered,
  completed,
  cancelled,
  disputed,
  refunded,
}

extension MissionStatusX on MissionStatus {
  String get key => 'mission_status_${name.toLowerCase()}';

  /// Statuses at which a mission is still open for offer/acceptance.
  bool get isOpenForAcceptance => this == MissionStatus.searchingDriver || this == MissionStatus.offered;
}

// =====================================================================
// FOUNDING DRIVER PROGRAM
// =====================================================================

enum FoundingDriverStatus { candidate, qualified, suspended, revoked, expired }

extension FoundingDriverStatusX on FoundingDriverStatus {
  String get key => 'founding_driver_status_${name.toLowerCase()}';
}

// =====================================================================
// COMMISSION PROGRAM (hierarchy resolution — see CommissionResolver)
// =====================================================================

enum CommissionProgramType { foundingPreferred, promotional, standard }

// =====================================================================
// SURCHARGE MODES
// =====================================================================

enum SurchargeMode { fixedAmount, percentage }

// =====================================================================
// LEDGER
// =====================================================================

enum LedgerEntryType {
  customerCharge,
  customerServiceFee,
  platformCommission,
  driverEarning,
  driverTip,
  driverBonus,
  tax,
  paymentProcessingFee,
  payoutProcessingFee,
  insuranceCost,
  refund,
  partialRefund,
  chargeback,
  driverAdjustment,
  customerAdjustment,
  driverPayout,
}

enum LedgerDirection { credit, debit }

enum LedgerParty { customer, driver, platform }

enum LedgerEntryStatus { pending, confirmed, reversed, compensated }

// =====================================================================
// PAYMENT
// =====================================================================

enum PaymentStatus { pending, authorized, captured, failed, refunded, partiallyRefunded, disputed }

enum DriverOnlineStatus { offline, online, onMission }

enum DeliveryStatus {
  submitted,
  awaitingResponse,
  accepted,
  onTheWay,
  pickupCompleted,
  inProgress,
  delivered,
  cancelled,
  disputed,
}

enum MechanicJobStatus {
  submitted,
  awaitingResponse,
  accepted,
  diagnosisRequired,
  partsRequired,
  partsOrdered,
  onTheWay,
  inProgress,
  approvalRequired,
  completed,
  cancelled,
  disputed,
}

enum PaymentMethod { cash, interac, arrangement }

enum VehicleType { pickupTruck, cargoVan, cubeTruck, trailer, suvWithTrailer, smallCommercial }

extension DeliveryStatusX on DeliveryStatus {
  String get key {
    switch (this) {
      case DeliveryStatus.submitted:
        return 'delivery_status_submitted';
      case DeliveryStatus.awaitingResponse:
        return 'delivery_status_awaiting';
      case DeliveryStatus.accepted:
        return 'delivery_status_accepted';
      case DeliveryStatus.onTheWay:
        return 'delivery_status_on_the_way';
      case DeliveryStatus.pickupCompleted:
        return 'delivery_status_pickup_done';
      case DeliveryStatus.inProgress:
        return 'delivery_status_in_progress';
      case DeliveryStatus.delivered:
        return 'delivery_status_delivered';
      case DeliveryStatus.cancelled:
        return 'delivery_status_cancelled';
      case DeliveryStatus.disputed:
        return 'delivery_status_disputed';
    }
  }
}

extension MechanicJobStatusX on MechanicJobStatus {
  String get key {
    switch (this) {
      case MechanicJobStatus.submitted:
        return 'mechanic_status_submitted';
      case MechanicJobStatus.awaitingResponse:
        return 'mechanic_status_awaiting';
      case MechanicJobStatus.accepted:
        return 'mechanic_status_accepted';
      case MechanicJobStatus.diagnosisRequired:
        return 'mechanic_status_diagnosis';
      case MechanicJobStatus.partsRequired:
        return 'mechanic_status_parts_needed';
      case MechanicJobStatus.partsOrdered:
        return 'mechanic_status_parts_ordered';
      case MechanicJobStatus.onTheWay:
        return 'mechanic_status_on_the_way';
      case MechanicJobStatus.inProgress:
        return 'mechanic_status_in_progress';
      case MechanicJobStatus.approvalRequired:
        return 'mechanic_status_approval_needed';
      case MechanicJobStatus.completed:
        return 'mechanic_status_completed';
      case MechanicJobStatus.cancelled:
        return 'mechanic_status_cancelled';
      case MechanicJobStatus.disputed:
        return 'mechanic_status_disputed';
    }
  }
}
