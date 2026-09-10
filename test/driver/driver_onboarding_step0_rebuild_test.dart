import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:movik_connect/backend/backend_status.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/driver/driver_onboarding_screen.dart';
import 'package:movik_connect/services/address/address_autocomplete_provider.dart';
import 'package:movik_connect/services/address/address_backend_locator.dart';
import 'package:movik_connect/services/address/address_suggestion.dart';

class _FakeAddressProvider implements AddressAutocompleteProvider {
  @override
  Future<List<AddressSuggestion>> searchSuggestions(String query) async {
    return const [
      AddressSuggestion(
        placeId: 'place-terrebonne',
        description: '527 Rue Lacasse, Terrebonne, QC J6W 4Y7, Canada',
      ),
    ];
  }

  @override
  Future<ResolvedAddress> resolvePlace(String placeId) async {
    return const ResolvedAddress(
      placeId: 'place-terrebonne',
      formattedAddress: '527 Rue Lacasse, Terrebonne, QC J6W 4Y7, Canada',
      streetNumber: '527',
      street: 'Rue Lacasse',
      city: 'Terrebonne',
      region: 'QC',
      postalCode: 'J6W 4Y7',
      country: 'Canada',
      lat: 45.70,
      lng: -73.64,
    );
  }
}

Widget _buildTestApp(FirebaseAuthProvider auth) {
  final router = GoRouter(
    initialLocation: '/fr/devenir-chauffeur/inscription',
    routes: [
      GoRoute(
        path: '/fr/devenir-chauffeur/inscription',
        builder: (context, state) =>
            const DriverOnboardingScreen(locale: 'fr'),
      ),
    ],
  );
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
      ChangeNotifierProvider<FirebaseAuthProvider>.value(value: auth),
      Provider<BackendStatus>.value(
        value: const BackendStatus.notConfigured(),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  late FirebaseAuthProvider auth;

  setUp(() {
    auth = FirebaseAuthProvider(backendConfigured: false);
    AddressBackendLocator.autocompleteProviderOverride = _FakeAddressProvider();
  });

  tearDown(() {
    AddressBackendLocator.autocompleteProviderOverride = null;
  });

  Future<void> enter(
    WidgetTester tester,
    Finder finder,
    String text,
  ) async {
    await tester.ensureVisible(finder);
    await tester.enterText(finder, text);
    await tester.pump();
  }

  testWidgets(
    'driver onboarding contact step requires contact details and a resolved service-base address',
    (tester) async {
      await tester.pumpWidget(_buildTestApp(auth));
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await enter(tester, fields.at(0), 'Jean Tremblay');
      await enter(tester, fields.at(1), 'jean.tremblay@example.com');
      await enter(tester, fields.at(2), 'motdepasse123');
      await enter(tester, fields.at(3), '5145551234');

      final nextButtonFinder = find.widgetWithText(ElevatedButton, 'Suivant');
      await tester.ensureVisible(nextButtonFinder);
      expect(tester.widget<ElevatedButton>(nextButtonFinder).onPressed, isNull);

      // AddressAutocompleteField is the fifth TextField. Typing opens the
      // deterministic suggestion from the fake provider; selecting it
      // resolves city/province/postal code and the GPS coordinates.
      await enter(tester, fields.at(4), '527 Rue Lacasse');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      final suggestion = find.text(
        '527 Rue Lacasse, Terrebonne, QC J6W 4Y7, Canada',
      );
      expect(suggestion, findsOneWidget);
      await tester.tap(suggestion);
      await tester.pumpAndSettle();

      expect(find.text('Adresse validée'), findsOneWidget);
      expect(find.text('Terrebonne'), findsOneWidget);
      expect(find.text('QC'), findsOneWidget);
      expect(find.text('J6W 4Y7'), findsOneWidget);

      final nextButton = tester.widget<ElevatedButton>(nextButtonFinder);
      expect(nextButton.onPressed, isNotNull);
    },
  );
}
