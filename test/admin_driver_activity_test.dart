import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/screens/dashboard/admin/drivers/admin_drivers_list_screen.dart';
import 'package:movik_connect/screens/dashboard/admin/drivers/admin_driver_activity_summary.dart';
import 'package:movik_connect/services/driver_presence.dart';
import 'package:movik_connect/backend/models/driver_profile_v2.dart';
import 'package:movik_connect/models/enums.dart';

void main() {
  test('connected shortcut searches all application statuses', () {
    expect(adminDriverInitialFilter('connected'), isNull);
    expect(adminDriverInitialFilter('offline'), isNull);
  });
  final now = DateTime.utc(2026, 10, 19);
  test('presence deduplicates tabs and expires without new snapshots', () {
    final sessions = [
      (driverId: 'a', updatedAt: now),
      (driverId: 'a', updatedAt: now.subtract(const Duration(seconds: 30))),
      (driverId: 'b', updatedAt: now.subtract(const Duration(seconds: 90))),
      (driverId: 'future', updatedAt: now.add(const Duration(minutes: 1))),
    ];
    expect(connectedDriverIds(sessions, now), {'a'});
    expect(
      connectedDriverIds(
        sessions.take(3),
        now.add(const Duration(seconds: 90)),
      ),
      isEmpty,
    );
  });
  final driver = DriverProfileV2(
    uid: 'd',
    fullName: 'Test',
    city: 'Montréal',
    status: DriverStatus.approved,
    serviceRadiusKm: 40,
    acceptedVehicleCategories: const [],
    acceptedItemCategoryKeys: const [],
    createdAt: now,
  );
  test('city ignores case accents and surrounding whitespace', () {
    expect(matchesDriverDirectory(driver, ' MONTREAL ', 'all', null), isTrue);
    expect(matchesDriverDirectory(driver, 'Granby', 'all', {'d'}), isFalse);
  });
  test('unknown presence is not offline and filters combine', () {
    expect(
      matchesDriverDirectory(driver, 'montreal', 'offline', null),
      isFalse,
    );
    expect(
      matchesDriverDirectory(driver, 'montreal', 'connected', {'d'}),
      isTrue,
    );
    expect(matchesDriverDirectory(driver, 'montreal', 'offline', {}), isTrue);
    expect(
      matchesDriverDirectory(driver, 'montreal', 'offline', {'d'}),
      isFalse,
    );
  });
  for (final width in [375.0, 1440.0]) {
    for (final locale in ['fr', 'en', 'es']) {
      testWidgets('activity statistics and reviews $width $locale at 200%', (
        tester,
      ) async {
        tester.view.resetPhysicalSize();
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: AdminDriverActivitySummary(
                    driverId: 'd',
                    locale: locale,
                    loader: () async => {
                      'completed': 3,
                      'cancelled': 1,
                      'disputed': 0,
                      'failed': null,
                      'rating': 4.5,
                      'ratingCount': 2,
                      'reviews': [
                        {'stars': 5, 'comment': 'Excellent'},
                        {'stars': 4, 'comment': ''},
                      ],
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('4.5 / 5'), findsOneWidget);
        await tester.tap(find.byType(ExpansionTile));
        await tester.pumpAndSettle();
        expect(find.text('Excellent'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('activity error can retry without setState Future exception', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminDriverActivitySummary(
            driverId: 'd',
            locale: 'fr',
            loader: () async {
              calls++;
              if (calls == 1) throw StateError('unavailable');
              return {
                'completed': 0,
                'cancelled': 0,
                'disputed': 0,
                'rating': null,
                'ratingCount': 0,
                'reviews': [],
              };
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Statistiques indisponibles · Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Aucun avis'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
