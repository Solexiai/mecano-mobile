import 'dart:collection';

import '../models/driver_profile_v2.dart';

/// Read-only list of active driver profiles, retaining the raw Firestore
/// window size before excluding migrated legacy profiles. An empty visible
/// list does not imply there are no later, non-migrated profiles.
class FirestoreDriverWindow extends UnmodifiableListView<DriverProfileV2> {
  FirestoreDriverWindow(super.items, {required this.fetchedCount});

  final int fetchedCount;
}
