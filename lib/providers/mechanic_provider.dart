import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/mechanic_request.dart';
import '../models/enums.dart';

class MechanicRequestProvider extends ChangeNotifier {
  final List<MechanicRequest> _requests = [];

  List<MechanicRequest> get requests => List.unmodifiable(_requests);

  List<MechanicRequest> forCustomer(String customerId) =>
      _requests.where((r) => r.customerId == customerId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  MechanicRequest createDraft(String customerId) {
    final req = MechanicRequest(id: const Uuid().v4(), customerId: customerId);
    _requests.add(req);
    notifyListeners();
    return req;
  }

  void updateRequest(MechanicRequest request) {
    final idx = _requests.indexWhere((r) => r.id == request.id);
    if (idx != -1) {
      _requests[idx] = request;
      notifyListeners();
    }
  }

  void submit(String requestId, {String? mechanicId, double? estimatedPrice}) {
    final idx = _requests.indexWhere((r) => r.id == requestId);
    if (idx != -1) {
      _requests[idx].status = MechanicJobStatus.awaitingResponse;
      if (mechanicId != null) _requests[idx].assignedMechanicId = mechanicId;
      if (estimatedPrice != null) _requests[idx].estimatedPrice = estimatedPrice;
      notifyListeners();
    }
  }

  void updateStatus(String requestId, MechanicJobStatus status) {
    final idx = _requests.indexWhere((r) => r.id == requestId);
    if (idx != -1) {
      _requests[idx].status = status;
      notifyListeners();
    }
  }

  void removeDraft(String requestId) {
    _requests.removeWhere((r) => r.id == requestId && r.status == MechanicJobStatus.submitted);
    notifyListeners();
  }
}
