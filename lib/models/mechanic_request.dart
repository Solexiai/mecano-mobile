import 'enums.dart';

class MechanicRequest {
  final String id;
  final String customerId;

  // Step 1 - vehicle info
  String vehicleMake;
  String vehicleModel;
  String vehicleYear;
  String engine;
  String vin;
  String plate;
  String mileage;
  bool canMoveSafely;

  // Step 2 - problem/service
  List<String> selectedServices;
  String problemDescription;
  List<String> photoPaths;
  String urgency; // normal, urgent, emergency
  bool partsAlreadyPurchased;
  bool partsDeliveryRequired;

  // Step 3 - location & schedule
  String location;
  DateTime? preferredDate;
  String preferredTime;
  String locationType; // roadside, home, work, job-site
  bool safeWorkspaceConfirmed;
  String accessInstructions;

  // Step 4/5 - booking
  String? assignedMechanicId;
  double? estimatedPrice;
  PaymentMethod paymentMethod;

  MechanicJobStatus status;
  final DateTime createdAt;

  MechanicRequest({
    required this.id,
    required this.customerId,
    this.vehicleMake = '',
    this.vehicleModel = '',
    this.vehicleYear = '',
    this.engine = '',
    this.vin = '',
    this.plate = '',
    this.mileage = '',
    this.canMoveSafely = true,
    List<String>? selectedServices,
    this.problemDescription = '',
    List<String>? photoPaths,
    this.urgency = 'normal',
    this.partsAlreadyPurchased = false,
    this.partsDeliveryRequired = false,
    this.location = '',
    this.preferredDate,
    this.preferredTime = '',
    this.locationType = 'home',
    this.safeWorkspaceConfirmed = false,
    this.accessInstructions = '',
    this.assignedMechanicId,
    this.estimatedPrice,
    this.paymentMethod = PaymentMethod.cash,
    this.status = MechanicJobStatus.submitted,
    DateTime? createdAt,
  })  : selectedServices = selectedServices ?? [],
        photoPaths = photoPaths ?? [],
        createdAt = createdAt ?? DateTime.now();
}
