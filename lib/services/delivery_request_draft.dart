import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'address/address_suggestion.dart';

/// Local-only draft used to resume a public delivery request after sign-in.
///
/// Nothing is sent to Firestore or analytics by this helper. The official
/// quote remains server-authoritative and is requested only after sign-in.
class DeliveryRequestDraft {
  static const storageKey = 'delivery_request_draft_v1';

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

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(toJson()));
  }

  static Future<DeliveryRequestDraft?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return DeliveryRequestDraft.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
  }
}
