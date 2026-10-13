import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movik_connect/backend/backend_locator.dart';
import 'package:movik_connect/backend/models/driver_profile_v2.dart';
import 'package:movik_connect/backend/repositories/driver_repository.dart';
import 'package:movik_connect/backend/repositories/firestore_driver_window.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/dashboard/admin/drivers/admin_drivers_list_screen.dart';

class _WindowedDriverRepository implements DriverRepository {
  _WindowedDriverRepository(this.all);
  final List<DriverProfileV2> all;
  final List<int> windows = [];
  final List<DriverStatus?> filters = [];

  @override
  Stream<List<DriverProfileV2>> watchDriversByStatus(
    DriverStatus? status, {
    int limit = 50,
  }) {
    windows.add(limit);
    filters.add(status);
    final matching = status == null
        ? all
        : all.where((driver) => driver.status == status).toList();
    return Stream.value(matching.take(limit).toList());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DriverProfileV2 _driver(int i) => DriverProfileV2(
  uid: 'gap_m06_driver_$i',
  fullName: 'Driver $i',
  city: 'Granby',
  status: DriverStatus.approved,
  serviceRadiusKm: 20,
  acceptedVehicleCategories: const [VehicleCategory.pickupTruck],
  acceptedItemCategoryKeys: const ['furniture'],
  createdAt: DateTime(2026, 1, 1).add(Duration(days: i)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    BackendLocator.driverRepositoryOverride = null;
  });

  testWidgets('GAP-M-06 admin retry creates a fresh listener after an error', (
    tester,
  ) async {
    final repo = _FailOnceDriverRepository();
    BackendLocator.driverRepositoryOverride = repo;
    final auth = FirebaseAuthProvider(backendConfigured: false)
      ..debugForceSignedIn = true
      ..debugForceUid = 'gap_m06_admin';
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LocaleProvider>(
            create: (_) => LocaleProvider(),
          ),
          ChangeNotifierProvider<FirebaseAuthProvider>.value(value: auth),
        ],
        child: const MaterialApp(
          home: Scaffold(body: AdminDriversListScreen(initialFilter: 'all')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.calls, 1);
    final retry = find.byType(OutlinedButton);
    expect(retry, findsOneWidget);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(repo.calls, 2);
    expect(find.text('Driver 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GAP-M-06: migrated aliases cannot hide a later valid profile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1250, 940);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _MigratedDriverPageRepository();
    BackendLocator.driverRepositoryOverride = repo;
    final auth = FirebaseAuthProvider(backendConfigured: false)
      ..debugForceSignedIn = true
      ..debugForceUid = 'gap_m06_admin';
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LocaleProvider>(
            create: (_) => LocaleProvider(),
          ),
          ChangeNotifierProvider<FirebaseAuthProvider>.value(value: auth),
        ],
        child: const MaterialApp(
          home: Scaffold(body: AdminDriversListScreen(initialFilter: 'all')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.windows, [50]);
    final more = find.byKey(const Key('admin-drivers-load-more'));
    expect(more, findsOneWidget);
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(repo.windows, [50, 100]);
    expect(find.text('Driver 51'), findsOneWidget);
    expect(find.byKey(const Key('admin-drivers-load-more')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'GAP-M-06 driver directory loads 50, then 100 on request, filters reset',
    (tester) async {
      tester.view.physicalSize = const Size(1250, 940);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _WindowedDriverRepository(List.generate(63, _driver));
      BackendLocator.driverRepositoryOverride = repo;
      final auth = FirebaseAuthProvider(backendConfigured: false)
        ..debugForceSignedIn = true
        ..debugForceUid = 'gap_m06_admin';
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LocaleProvider>(
              create: (_) => LocaleProvider(),
            ),
            ChangeNotifierProvider<FirebaseAuthProvider>.value(value: auth),
          ],
          child: const MaterialApp(
            home: Scaffold(body: AdminDriversListScreen(initialFilter: 'all')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.windows, [50]);
      final more = find.byKey(const Key('admin-drivers-load-more'));
      expect(more, findsOneWidget);
      await tester.ensureVisible(more);
      await tester.pumpAndSettle();
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(repo.windows, [50, 100]);
      expect(find.byKey(const Key('admin-drivers-load-more')), findsNothing);

      // A change of filter resets the window, so it never silently excludes
      // an entire selected status group using the previous query's cursor.
      final pendingFilter = find.byType(ChoiceChip).at(1);
      await tester.ensureVisible(pendingFilter);
      await tester.pumpAndSettle();
      await tester.tap(pendingFilter);
      await tester.pumpAndSettle();
      expect(repo.windows.last, 50);
      expect(repo.filters.last, DriverStatus.pendingReview);
      expect(tester.takeException(), isNull);
    },
  );
}

class _MigratedDriverPageRepository implements DriverRepository {
  final List<int> windows = [];

  @override
  Stream<List<DriverProfileV2>> watchDriversByStatus(
    DriverStatus? status, {
    int limit = 50,
  }) {
    windows.add(limit);
    if (limit == 50) {
      // First 50 Firestore documents are legacy aliases filtered by the
      // real repository; a later valid driver must remain discoverable.
      return Stream.value(FirestoreDriverWindow([], fetchedCount: 50));
    }
    return Stream.value(FirestoreDriverWindow([_driver(51)], fetchedCount: 51));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailOnceDriverRepository implements DriverRepository {
  int calls = 0;

  @override
  Stream<List<DriverProfileV2>> watchDriversByStatus(
    DriverStatus? status, {
    int limit = 50,
  }) {
    calls++;
    if (calls == 1) return Stream.error(StateError('offline test'));
    return Stream.value([_driver(1)]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
