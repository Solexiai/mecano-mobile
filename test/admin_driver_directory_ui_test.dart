import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movik_connect/backend/backend_locator.dart';
import 'package:movik_connect/backend/models/driver_profile_v2.dart';
import 'package:movik_connect/backend/repositories/driver_repository.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/dashboard/admin/drivers/admin_drivers_list_screen.dart';
import 'package:movik_connect/screens/dashboard/admin/drivers/admin_driver_presence_card.dart';

class Drivers implements DriverRepository {
  @override
  Stream<List<DriverProfileV2>> watchDriversByStatus(
    DriverStatus? status, {
    int limit = 50,
  }) => Stream.value([
    for (final city in ['Granby', 'Montréal'])
      DriverProfileV2(
        uid: city,
        fullName: 'Chauffeur $city',
        city: city,
        status: DriverStatus.approved,
        serviceRadiusKm: 40,
        acceptedVehicleCategories: const [],
        acceptedItemCategoryKeys: const [],
        createdAt: DateTime(2026),
      ),
  ]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => BackendLocator.driverRepositoryOverride = null);
  testWidgets(
    'connected card remains navigable by keyboard without presence data',
    (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                const Scaffold(body: AdminDriverPresenceCard(locale: 'fr')),
          ),
          GoRoute(
            path: '/fr/admin/chauffeurs',
            builder: (_, state) => Scaffold(body: Text(state.uri.toString())),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      expect(find.text('—'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        find.text('/fr/admin/chauffeurs?filter=connected'),
        findsOneWidget,
      );
    },
  );
  for (final width in [375.0, 1440.0]) {
    testWidgets('directory city search and unknown presence $width at 200%', (
      tester,
    ) async {
      BackendLocator.driverRepositoryOverride = Drivers();
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = FirebaseAuthProvider(backendConfigured: false)
        ..debugForceSignedIn = true;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => LocaleProvider()),
            ChangeNotifierProvider<FirebaseAuthProvider>.value(value: auth),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(2)),
              child: const Scaffold(
                body: AdminDriversListScreen(initialFilter: 'all'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.enterText(
        find.byKey(const Key('driver-city-search')),
        'montreal',
      );
      await tester.pumpAndSettle();
      expect(find.text('Chauffeur Montréal'), findsOneWidget);
      expect(find.text('Chauffeur Granby'), findsNothing);
      final offline = find.widgetWithText(ChoiceChip, 'Hors ligne');
      await tester.ensureVisible(offline);
      await tester.tap(offline);
      await tester.pumpAndSettle();
      expect(find.text('Chauffeur Montréal'), findsNothing);
      expect(find.textContaining('Présence indisponible'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
