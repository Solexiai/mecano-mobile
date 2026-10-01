import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/delivery/delivery_request_flow_screen.dart';
import 'package:movik_connect/services/address/address_suggestion.dart';
import 'package:movik_connect/services/delivery_request_draft.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'signed-in request screen restores the guest draft saved before login',
    (tester) async {
      const draft = DeliveryRequestDraft(
        category: 'cat_furniture',
        description: 'Canapé trois places Granby',
        quantity: 2,
        needsStairs: true,
        needsSecondHandler: false,
        isHeavyItem: false,
        isBulkyItem: true,
        pickup: ResolvedAddress(
          placeId: 'pickup-granby',
          formattedAddress: '100 Rue Principale, Granby, QC',
          lat: 45.401,
          lng: -72.733,
          city: 'Granby',
          region: 'QC',
          country: 'CA',
        ),
        dropoff: ResolvedAddress(
          placeId: 'dropoff-granby',
          formattedAddress: '200 Rue Principale, Granby, QC',
          lat: 45.405,
          lng: -72.720,
          city: 'Granby',
          region: 'QC',
          country: 'CA',
        ),
        contactInstructions: 'Appeler à l’arrivée',
        accessDetails: 'Escalier extérieur',
        vehicleCategory: 'cargo_van',
      );
      await draft.save();

      final auth = FirebaseAuthProvider(backendConfigured: false)
        ..debugForceSignedIn = true
        ..debugForceUid = 'customer-granby'
        ..debugForceRoles = [PlatformRole.customer];

      final router = GoRouter(
        initialLocation: '/fr/livraison/demande',
        routes: [
          GoRoute(
            path: '/fr/livraison/demande',
            builder: (_, __) => const DeliveryRequestFlowScreen(locale: 'fr'),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LocaleProvider>(
              create: (_) => LocaleProvider(),
            ),
            ChangeNotifierProvider<FirebaseAuthProvider>.value(value: auth),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      final descriptionField = tester.widget<TextField>(
        find.byType(TextField).first,
      );
      expect(descriptionField.controller?.text, 'Canapé trois places Granby');

      final selectedFurniture = tester
          .widgetList<ChoiceChip>(find.byType(ChoiceChip))
          .where((chip) => chip.selected)
          .toList();
      expect(selectedFurniture, hasLength(1));

      final switches = tester
          .widgetList<SwitchListTile>(find.byType(SwitchListTile))
          .toList();
      expect(switches[0].value, isTrue);
      expect(switches[3].value, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
