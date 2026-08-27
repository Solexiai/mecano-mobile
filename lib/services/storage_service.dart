import 'package:hive_flutter/hive_flutter.dart';

/// Thin wrapper around Hive boxes used for local persistence.
/// No custom TypeAdapters are needed: we store plain `Map<String, dynamic>`
/// structures, which Hive supports natively.
class StorageService {
  static const String usersBox = 'movik_users';
  static const String sessionBox = 'movik_session';
  static const String deliveryBox = 'movik_delivery_requests';
  static const String mechanicBox = 'movik_mechanic_requests';
  static const String reviewsBox = 'movik_reviews';
  static const String favouritesBox = 'movik_favourites';
  static const String addressesBox = 'movik_addresses';
  static const String providerExtraBox = 'movik_provider_extra';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(usersBox);
    await Hive.openBox(sessionBox);
    await Hive.openBox(deliveryBox);
    await Hive.openBox(mechanicBox);
    await Hive.openBox(reviewsBox);
    await Hive.openBox(favouritesBox);
    await Hive.openBox(addressesBox);
    await Hive.openBox(providerExtraBox);
  }

  static Box box(String name) => Hive.box(name);
}
