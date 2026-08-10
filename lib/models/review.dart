/// Post-booking review submitted by a customer for a completed delivery
/// or mechanic job. Restricted (in the UI layer) to bookings that are
/// actually connected to a real request the customer made and that has
/// reached a terminal "completed" state — never a free-form/anonymous
/// review disconnected from a booking.
class Review {
  final String id;
  final String bookingId;
  final String customerId;
  final String authorName;
  final String targetProviderId;
  final String requestType; // 'delivery' | 'mechanic'
  final double overall;
  final Map<String, double> categoryRatings;
  final String comment;
  final DateTime createdAt;
  final bool isVerifiedBooking;

  const Review({
    required this.id,
    required this.bookingId,
    required this.authorName,
    required this.targetProviderId,
    required this.overall,
    required this.categoryRatings,
    required this.comment,
    required this.createdAt,
    this.customerId = 'demo',
    this.requestType = 'delivery',
    this.isVerifiedBooking = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookingId': bookingId,
        'customerId': customerId,
        'authorName': authorName,
        'targetProviderId': targetProviderId,
        'requestType': requestType,
        'overall': overall,
        'categoryRatings': categoryRatings,
        'comment': comment,
        'createdAt': createdAt.toIso8601String(),
        'isVerifiedBooking': isVerifiedBooking,
      };

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        id: json['id'] as String,
        bookingId: json['bookingId'] as String,
        customerId: json['customerId'] as String? ?? 'demo',
        authorName: json['authorName'] as String? ?? 'Client Movi-k',
        targetProviderId: json['targetProviderId'] as String,
        requestType: json['requestType'] as String? ?? 'delivery',
        overall: (json['overall'] as num?)?.toDouble() ?? 0.0,
        categoryRatings: (json['categoryRatings'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
            ) ??
            const {},
        comment: json['comment'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        isVerifiedBooking: json['isVerifiedBooking'] as bool? ?? true,
      );
}
