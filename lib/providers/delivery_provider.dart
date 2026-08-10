import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/delivery_request.dart';
import '../models/enums.dart';
import '../services/storage_service.dart';

class DeliveryProvider extends ChangeNotifier {
  final List<DeliveryRequest> _requests = [];

  List<DeliveryRequest> get requests => List.unmodifiable(_requests);

  List<DeliveryRequest> forCustomer(String customerId) =>
      _requests.where((r) => r.customerId == customerId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  DeliveryProvider() {
    _load();
  }

  void _load() {
    // Data persistence kept simple for demo; in-memory list is source of
    // truth per session. The Hive box is reserved for future persistence.
    StorageService.box(StorageService.deliveryBox);
  }

  DeliveryRequest createDraft(String customerId) {
    final req = DeliveryRequest(id: const Uuid().v4(), customerId: customerId);
    _requests.add(req);
    notifyListeners();
    return req;
  }

  void updateRequest(DeliveryRequest request) {
    final idx = _requests.indexWhere((r) => r.id == request.id);
    if (idx != -1) {
      _requests[idx] = request;
      notifyListeners();
    }
  }

  void submit(String requestId, {String? providerId, double? quotedPrice}) {
    final idx = _requests.indexWhere((r) => r.id == requestId);
    if (idx != -1) {
      _requests[idx].status = DeliveryStatus.awaitingResponse;
      if (providerId != null) _requests[idx].assignedProviderId = providerId;
      if (quotedPrice != null) _requests[idx].quotedPrice = quotedPrice;
      notifyListeners();
    }
  }

  void updateStatus(String requestId, DeliveryStatus status) {
    final idx = _requests.indexWhere((r) => r.id == requestId);
    if (idx != -1) {
      _requests[idx].status = status;
      notifyListeners();
    }
  }

  void removeDraft(String requestId) {
    _requests.removeWhere((r) => r.id == requestId && r.status == DeliveryStatus.submitted);
    notifyListeners();
  }
}
