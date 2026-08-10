/// Shared enums for Movi-k marketplace.

enum UserRole { customer, driver, mechanic, admin }

enum VerificationStatus { pending, verified, rejected }

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
