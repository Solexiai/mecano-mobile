import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/review.dart';
import '../services/storage_service.dart';

/// Manages post-booking reviews. Persisted locally via Hive so submitted
/// reviews survive a page refresh within this demo/preview environment.
class ReviewProvider extends ChangeNotifier {
  final List<Review> _reviews = [];

  List<Review> get reviews => List.unmodifiable(_reviews);

  ReviewProvider() {
    _load();
  }

  void _load() {
    final box = StorageService.box(StorageService.reviewsBox);
    _reviews.clear();
    for (final key in box.keys) {
      final data = box.get(key);
      if (data != null) {
        try {
          _reviews.add(Review.fromJson(Map<String, dynamic>.from(data)));
        } catch (_) {
          // Skip malformed/legacy entries rather than crashing the app.
        }
      }
    }
    notifyListeners();
  }

  /// A booking can only be reviewed once. Used to hide/disable the
  /// "leave a review" action on requests that already have one.
  bool hasReviewForBooking(String bookingId) => _reviews.any((r) => r.bookingId == bookingId);

  Review? reviewForBooking(String bookingId) {
    for (final r in _reviews) {
      if (r.bookingId == bookingId) return r;
    }
    return null;
  }

  List<Review> forProvider(String providerId) => _reviews.where((r) => r.targetProviderId == providerId).toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  double averageRatingForProvider(String providerId) {
    final list = forProvider(providerId);
    if (list.isEmpty) return 0.0;
    return list.map((r) => r.overall).reduce((a, b) => a + b) / list.length;
  }

  Future<Review> submitReview({
    required String bookingId,
    required String customerId,
    required String authorName,
    required String targetProviderId,
    required String requestType,
    required Map<String, double> categoryRatings,
    required String comment,
  }) async {
    final overall = categoryRatings.isEmpty
        ? 0.0
        : categoryRatings.values.reduce((a, b) => a + b) / categoryRatings.length;

    final review = Review(
      id: const Uuid().v4(),
      bookingId: bookingId,
      customerId: customerId,
      authorName: authorName,
      targetProviderId: targetProviderId,
      requestType: requestType,
      overall: double.parse(overall.toStringAsFixed(2)),
      categoryRatings: categoryRatings,
      comment: comment,
      createdAt: DateTime.now(),
      isVerifiedBooking: true,
    );

    _reviews.add(review);
    final box = StorageService.box(StorageService.reviewsBox);
    await box.put(review.id, review.toJson());
    notifyListeners();
    return review;
  }
}
