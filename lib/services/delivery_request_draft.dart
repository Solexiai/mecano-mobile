import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'address/address_suggestion.dart';

/// Local-only draft used to resume a public delivery request after sign-in.
///
/// Nothing is sent to Firestore or analytics by this helper. The official
/// quote remains server-authoritative and is requested only after sign-in.
class DeliveryRequestDraft {
  static const storageKey = 'delivery_request_draft_v1';
  static const maxAge = Duration(hours: 24);
  static const authHandoffMaxAge = Duration(minutes: 15);

  final String category;
  final String description;
  final int quantity;
  final bool needsStairs;
  final bool needsSecondHandler;
  final bool isHeavyItem;
  final bool isBulkyItem;
  final ResolvedAddress? pickup;
  final ResolvedAddress? dropoff;
  final String contactInstructions;
  final String accessDetails;
  final String? vehicleCategory;

  const DeliveryRequestDraft({
    required this.category,
    required this.description,
    required this.quantity,
    required this.needsStairs,
    required this.needsSecondHandler,
    required this.isHeavyItem,
    required this.isBulkyItem,
    required this.pickup,
    required this.dropoff,
    required this.contactInstructions,
    required this.accessDetails,
    required this.vehicleCategory,
  });

  Map<String, dynamic> toJson() => {
    'category': category,
    'description': description,
    'quantity': quantity,
    'needs_stairs': needsStairs,
    'needs_second_handler': needsSecondHandler,
    'is_heavy_item': isHeavyItem,
    'is_bulky_item': isBulkyItem,
    'pickup': _addressToJson(pickup),
    'dropoff': _addressToJson(dropoff),
    'contact_instructions': contactInstructions,
    'access_details': accessDetails,
    'vehicle_category': vehicleCategory,
  };

  static Map<String, dynamic>? _addressToJson(ResolvedAddress? address) {
    if (address == null) return null;
    return {
      'place_id': address.placeId,
      'formatted_address': address.formattedAddress,
      'street_number': address.streetNumber,
      'street': address.street,
      'city': address.city,
      'region': address.region,
      'postal_code': address.postalCode,
      'country': address.country,
      'lat': address.lat,
      'lng': address.lng,
    };
  }

  static ResolvedAddress? _addressFromJson(dynamic raw) {
    if (raw is! Map) return null;
    final data = Map<String, dynamic>.from(raw);
    final lat = data['lat'];
    final lng = data['lng'];
    final placeId = data['place_id'];
    final formatted = data['formatted_address'];
    if (lat is! num ||
        lng is! num ||
        placeId is! String ||
        placeId.isEmpty ||
        formatted is! String ||
        formatted.isEmpty) {
      return null;
    }
    String s(String key) => data[key] is String ? data[key] as String : '';
    return ResolvedAddress(
      placeId: placeId,
      formattedAddress: formatted,
      lat: lat.toDouble(),
      lng: lng.toDouble(),
      streetNumber: s('street_number'),
      street: s('street'),
      city: s('city'),
      region: s('region'),
      postalCode: s('postal_code'),
      country: s('country'),
    );
  }

  factory DeliveryRequestDraft.fromJson(Map<String, dynamic> json) {
    int quantity = 1;
    final rawQuantity = json['quantity'];
    if (rawQuantity is num && rawQuantity >= 1) quantity = rawQuantity.toInt();

    String s(String key) => json[key] is String ? json[key] as String : '';
    bool b(String key) => json[key] == true;

    return DeliveryRequestDraft(
      category: s('category'),
      description: s('description'),
      quantity: quantity,
      needsStairs: b('needs_stairs'),
      needsSecondHandler: b('needs_second_handler'),
      isHeavyItem: b('is_heavy_item'),
      isBulkyItem: b('is_bulky_item'),
      pickup: _addressFromJson(json['pickup']),
      dropoff: _addressFromJson(json['dropoff']),
      contactInstructions: s('contact_instructions'),
      accessDetails: s('access_details'),
      vehicleCategory: json['vehicle_category'] is String
          ? json['vehicle_category'] as String
          : null,
    );
  }

  Future<void> save({String? uid, DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final envelope = toJson()
      ..['schema_version'] = 2
      ..['created_at_ms'] = (now ?? DateTime.now()).millisecondsSinceEpoch
      ..['owner_uid'] = uid;
    await prefs.setString(storageKey, jsonEncode(envelope));
  }

  /// Marks a short-lived, one-time guest-to-account handoff before auth.
  /// The UID is never put in the return URL.
  static Future<void> beginAuthHandoff({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final envelope = Map<String, dynamic>.from(decoded);
      if (envelope['owner_uid'] != null) return;
      envelope['handoff_at_ms'] =
          (now ?? DateTime.now()).millisecondsSinceEpoch;
      await prefs.setString(storageKey, jsonEncode(envelope));
    } catch (_) {
      await prefs.remove(storageKey);
    }
  }

  static Future<DeliveryRequestDraft?> load({
    String? uid,
    DateTime? now,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException('Invalid draft');
      final envelope = Map<String, dynamic>.from(decoded);
      final current = (now ?? DateTime.now()).millisecondsSinceEpoch;
      final createdAt = envelope['created_at_ms'];
      final ownerUid = envelope['owner_uid'];
      if (envelope['schema_version'] != 2 ||
          createdAt is! int ||
          createdAt > current ||
          current - createdAt > maxAge.inMilliseconds ||
          (ownerUid != null && ownerUid is! String)) {
        throw const FormatException('Expired or unsupported draft');
      }

      if (ownerUid != uid) {
        // Keep another account's draft intact while auth state settles or
        // when users switch accounts; never expose it to the current user.
        if (ownerUid != null) {
          return null;
        }
        final handoffAt = envelope['handoff_at_ms'];
        final canClaimGuestDraft =
            ownerUid == null &&
            uid != null &&
            handoffAt is int &&
            handoffAt <= current &&
            current - handoffAt <= authHandoffMaxAge.inMilliseconds;
        if (!canClaimGuestDraft) {
          throw const FormatException('Draft owner mismatch');
        }
        envelope['owner_uid'] = uid;
        envelope.remove('handoff_at_ms');
        await prefs.setString(storageKey, jsonEncode(envelope));
      }
      return DeliveryRequestDraft.fromJson(envelope);
    } catch (_) {
      await prefs.remove(storageKey);
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
  }
}
