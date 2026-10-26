import 'package:cloud_firestore/cloud_firestore.dart';

/// The customer's saved home address, `users/{uid}.saved_addresses.home`
/// (2026-10-26). Same shape as a booking address. The user writes it
/// directly: firestore.rules let the owner change their declarative fields.
class SavedAddresses {
  /// Test seam.
  static SavedAddresses? override;
  static SavedAddresses get instance => override ?? SavedAddresses();

  static const fields = [
    'line1',
    'city',
    'postal_code',
    'lat',
    'lng',
    'formatted_address',
    'place_id',
  ];

  /// Null when none is saved or the profile cannot be read.
  Future<Map<String, dynamic>?> home(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      return parseHome(doc.data());
    } catch (_) {
      return null;
    }
  }

  Future<void> saveHome(String uid, Map<String, dynamic> address) =>
      FirebaseFirestore.instance.collection('users').doc(uid).set({
        'saved_addresses': {
          'home': {for (final f in fields) f: address[f]},
        },
      }, SetOptions(merge: true));

  /// A usable address has a street line, a city and coordinates.
  static Map<String, dynamic>? parseHome(Map<String, dynamic>? user) {
    final saved = user?['saved_addresses'];
    final home = saved is Map ? saved['home'] : null;
    if (home is! Map) return null;
    final value = Map<String, dynamic>.from(home);
    if (value['line1'] is! String ||
        (value['line1'] as String).trim().isEmpty ||
        value['city'] is! String ||
        value['lat'] is! num ||
        value['lng'] is! num) {
      return null;
    }
    return value;
  }
}
