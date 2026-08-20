// -----------------------------------------------------------------------------
// firestoreValue helper — convertit un nom d'enum Dart camelCase (ex:
// `registrationIncomplete`) en la valeur snake_case attendue par
// `functions/src/lib/types.ts` et `firestore.rules` (ex:
// `registration_incomplete`).
//
// CONTEXTE (voir audit Movi-K) : les Cloud Functions et les Security Rules
// écrivent/comparent EXCLUSIVEMENT des valeurs snake_case. Les modèles Dart
// sérialisaient jusqu'ici via `.name` (camelCase), ce qui aurait créé un
// écart silencieux entre ce que Flutter écrit et ce que le serveur attend.
// `firestoreValue` doit être utilisé pour TOUTE sérialisation Firestore ;
// `.name` reste utilisable pour l'affichage/debug interne uniquement.
// -----------------------------------------------------------------------------
String _camelToSnake(String input) {
  final buffer = StringBuffer();
  for (var i = 0; i < input.length; i++) {
    final char = input[i];
    if (char.toUpperCase() == char && char.toLowerCase() != char && i > 0) {
      buffer.write('_');
    }
    buffer.write(char.toLowerCase());
  }
  return buffer.toString();
}

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
  /// Valeur snake_case attendue par Firestore/Cloud Functions/Security
  /// Rules (ex: `registrationIncomplete` -> `registration_incomplete`).
  String get firestoreValue => _camelToSnake(name);

  static DriverStatus fromFirestoreValue(String? value) => DriverStatus.values.firstWhere(
        (s) => s.firestoreValue == value,
        orElse: () => DriverStatus.registrationIncomplete,
      );

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
  String get firestoreValue => _camelToSnake(name);

  static DriverDocumentType fromFirestoreValue(String? value) => DriverDocumentType.values.firstWhere(
        (t) => t.firestoreValue == value,
        orElse: () => DriverDocumentType.other,
      );

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
  String get firestoreValue => _camelToSnake(name);

  static DriverDocumentStatus fromFirestoreValue(String? value) => DriverDocumentStatus.values.firstWhere(
        (s) => s.firestoreValue == value,
        orElse: () => DriverDocumentStatus.missing,
      );

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
// VEHICLE CATEGORY — source unique de vérité pour tout type de véhicule
// dans l'application (démo ET architecture Firebase réelle).
//
// HISTORIQUE : un enum `VehicleType` distinct existait en parallèle
// (utilisé uniquement par les écrans démo ProviderProfile/DemoDataService/
// driver_onboarding_screen). Les deux nomenclatures se recoupaient à 100%
// sauf `suvWithTrailer`/`smallCommercial`, absents ici. Plutôt que de
// maintenir deux enums parallèles indéfiniment, `VehicleType` a été
// supprimé et ces deux valeurs ajoutées ci-dessous : `VehicleCategory` est
// désormais la SEULE nomenclature de véhicule dans tout le projet.
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
  suvWithTrailer,
  smallCommercial,
  other,
}

extension VehicleCategoryX on VehicleCategory {
  String get firestoreValue => _camelToSnake(name);

  static VehicleCategory fromFirestoreValue(String? value) => VehicleCategory.values.firstWhere(
        (c) => c.firestoreValue == value,
        orElse: () => VehicleCategory.other,
      );

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
      case VehicleCategory.suvWithTrailer:
        return 'vehicle_cat_suv_with_trailer';
      case VehicleCategory.smallCommercial:
        return 'vehicle_cat_small_commercial';
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
  /// Valeur snake_case attendue côté serveur (ex: `searchingDriver` ->
  /// `searching_driver`), conforme à `MissionStatuses` dans
  /// `functions/src/lib/types.ts`.
  String get firestoreValue => _camelToSnake(name);

  static MissionStatus fromFirestoreValue(String? value) => MissionStatus.values.firstWhere(
        (s) => s.firestoreValue == value,
        orElse: () => MissionStatus.draft,
      );

  String get key => 'mission_status_${name.toLowerCase()}';

  /// Statuses at which a mission is still open for offer/acceptance.
  bool get isOpenForAcceptance => this == MissionStatus.searchingDriver || this == MissionStatus.offered;
}

// =====================================================================
// FOUNDING DRIVER PROGRAM
// =====================================================================

enum FoundingDriverStatus { candidate, qualified, suspended, revoked, expired }

extension FoundingDriverStatusX on FoundingDriverStatus {
  String get firestoreValue => _camelToSnake(name);

  static FoundingDriverStatus fromFirestoreValue(String? value) => FoundingDriverStatus.values.firstWhere(
        (s) => s.firestoreValue == value,
        orElse: () => FoundingDriverStatus.candidate,
      );

  String get key => 'founding_driver_status_${name.toLowerCase()}';
}

// =====================================================================
// COMMISSION PROGRAM (hierarchy resolution — see CommissionResolver)
// =====================================================================

enum CommissionProgramType { foundingPreferred, promotional, standard }

extension CommissionProgramTypeX on CommissionProgramType {
  /// `foundingPreferred` -> `founding_preferred` (cohérent avec
  /// `CommissionProgramTypes` dans `functions/src/lib/types.ts`).
  String get firestoreValue => _camelToSnake(name);

  static CommissionProgramType fromFirestoreValue(String? value) => CommissionProgramType.values.firstWhere(
        (t) => t.firestoreValue == value,
        orElse: () => CommissionProgramType.standard,
      );
}

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

extension LedgerEntryTypeX on LedgerEntryType {
  String get firestoreValue => _camelToSnake(name);

  static LedgerEntryType fromFirestoreValue(String? value) => LedgerEntryType.values.firstWhere(
        (t) => t.firestoreValue == value,
        orElse: () => LedgerEntryType.driverAdjustment,
      );
}

enum LedgerDirection { credit, debit }

extension LedgerDirectionX on LedgerDirection {
  String get firestoreValue => name; // déjà snake_case (mot unique)

  static LedgerDirection fromFirestoreValue(String? value) => LedgerDirection.values.firstWhere(
        (d) => d.firestoreValue == value,
        orElse: () => LedgerDirection.credit,
      );
}

enum LedgerParty { customer, driver, platform }

extension LedgerPartyX on LedgerParty {
  String get firestoreValue => name; // déjà snake_case (mot unique)

  static LedgerParty fromFirestoreValue(String? value) => LedgerParty.values.firstWhere(
        (p) => p.firestoreValue == value,
        orElse: () => LedgerParty.platform,
      );
}

enum LedgerEntryStatus { pending, confirmed, reversed, compensated }

extension LedgerEntryStatusX on LedgerEntryStatus {
  String get firestoreValue => name; // déjà snake_case (mot unique)

  static LedgerEntryStatus fromFirestoreValue(String? value) => LedgerEntryStatus.values.firstWhere(
        (s) => s.firestoreValue == value,
        orElse: () => LedgerEntryStatus.pending,
      );
}

// =====================================================================
// PAYMENT
//
// Machine d'état COMPLÈTE alignée sur `PaymentStatuses` dans
// `functions/src/lib/types.ts` (Phase 6, directive 38 points) :
//   created -> requiresPaymentMethod -> authorizationPending -> authorized
//   authorized -> capturePending -> captured
//   authorized -> cancelled | failed
//   captured -> partiallyRefunded -> refunded
//   captured -> refunded
//   captured | partiallyRefunded -> disputed -> chargeback
// `pending` est CONSERVÉ comme valeur de repli historique (`orElse` de
// `fromFirestoreValue`) pour la rétro-compatibilité de code existant, mais
// ne correspond à AUCUNE valeur `PaymentStatuses` réelle côté serveur.
// =====================================================================

enum PaymentStatus {
  pending, // repli historique uniquement — jamais écrit par le serveur
  created,
  requiresPaymentMethod,
  authorizationPending,
  authorized,
  capturePending,
  captured,
  failed,
  cancelled,
  refunded,
  partiallyRefunded,
  disputed,
  chargeback,
}

extension PaymentStatusX on PaymentStatus {
  String get firestoreValue => _camelToSnake(name);

  static PaymentStatus fromFirestoreValue(String? value) => PaymentStatus.values.firstWhere(
        (s) => s.firestoreValue == value,
        orElse: () => PaymentStatus.pending,
      );
}

// =====================================================================
// REFUND — aligné sur `RefundStatuses`/`RefundReasons` dans
// `functions/src/lib/types.ts` (Phase 6, directive 38 points).
//   REQUESTED -> PROCESSING -> SUCCEEDED
//   REQUESTED -> PROCESSING -> FAILED
// =====================================================================

enum RefundStatus { requested, processing, succeeded, failed }

extension RefundStatusX on RefundStatus {
  String get firestoreValue => _camelToSnake(name);

  static RefundStatus fromFirestoreValue(String? value) => RefundStatus.values.firstWhere(
        (s) => s.firestoreValue == value,
        orElse: () => RefundStatus.requested,
      );
}

enum RefundReason {
  customerRequest,
  cancelledBeforePickup,
  cancelledAfterPickup,
  paymentError,
  goodwill,
  administrative,
  missionImpossible,
  partialDelivery,
  noShow,
}

extension RefundReasonX on RefundReason {
  String get firestoreValue => _camelToSnake(name);

  static RefundReason fromFirestoreValue(String? value) => RefundReason.values.firstWhere(
        (r) => r.firestoreValue == value,
        orElse: () => RefundReason.administrative,
      );
}

enum DriverOnlineStatus { offline, online, onMission }

extension DriverOnlineStatusX on DriverOnlineStatus {
  String get firestoreValue => _camelToSnake(name);

  static DriverOnlineStatus fromFirestoreValue(String? value) => DriverOnlineStatus.values.firstWhere(
        (s) => s.firestoreValue == value,
        orElse: () => DriverOnlineStatus.offline,
      );
}

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
