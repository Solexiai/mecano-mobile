import 'enums.dart';

class DeliveryRequest {
  final String id;
  final String customerId;

  // Step 1 - item info
  String itemCategory;
  String description;
  List<String> photoPaths;
  String dimensions;
  String weight;
  int quantity;
  bool needsStairsHandling;
  bool needsLoadingAssistance;
  bool needsUnloadingAssistance;

  // Step 2 - locations
  String pickupAddress;
  String deliveryAddress;
  DateTime? preferredDate;
  String preferredTimeWindow;
  String contactInstructions;
  String accessDetails;
  String? extraStop;

  // Step 3/4 - booking
  String? assignedProviderId;
  double? quotedPrice;
  PaymentMethod paymentMethod;
  String customerNotes;

  DeliveryStatus status;
  final DateTime createdAt;

  DeliveryRequest({
    required this.id,
    required this.customerId,
    this.itemCategory = '',
    this.description = '',
    List<String>? photoPaths,
    this.dimensions = '',
    this.weight = '',
    this.quantity = 1,
    this.needsStairsHandling = false,
    this.needsLoadingAssistance = false,
    this.needsUnloadingAssistance = false,
    this.pickupAddress = '',
    this.deliveryAddress = '',
    this.preferredDate,
    this.preferredTimeWindow = '',
    this.contactInstructions = '',
    this.accessDetails = '',
    this.extraStop,
    this.assignedProviderId,
    this.quotedPrice,
    this.paymentMethod = PaymentMethod.cash,
    this.customerNotes = '',
    this.status = DeliveryStatus.submitted,
    DateTime? createdAt,
  })  : photoPaths = photoPaths ?? [],
        createdAt = createdAt ?? DateTime.now();
}
