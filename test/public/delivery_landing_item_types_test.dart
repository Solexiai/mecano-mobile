// The delivery page lists exactly the item types the request form accepts.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/router/app_router.dart';
import 'package:movik_connect/services/booking/item_types.dart';
import '../helpers/gps_offline_transport.dart';
import 'public_launch_pages_test.dart' show wrapPublicPage;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    expect(Firebase.apps, isEmpty);
  });
  tearDown(() => expect(Firebase.apps, isEmpty));

  for (final locale in ['fr', 'en', 'es']) {
    offlineWidgetTest('delivery page shows the real item types ($locale)', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final auth = FirebaseAuthProvider(backendConfigured: false);
      AppRouter.router.go('/$locale/livraison');
      await tester.pumpWidget(wrapPublicPage(auth));
      await tester.pumpAndSettle();

      for (final type in itemTypes) {
        final chip = find.byKey(Key('delivery-item-type-${type.id}'));
        expect(chip, findsOneWidget, reason: type.id);
        expect(
          find.descendant(of: chip, matching: find.text(type.label(locale))),
          findsOneWidget,
        );
      }
      // Old demo categories that the form never accepted.
      for (final gone in [
        'Moto',
        'VTT',
        'Palettes',
        'Achats Home Depot',
        'Motorcycle',
        'ATV',
        'Pallets',
      ]) {
        expect(find.text(gone), findsNothing, reason: gone);
      }
      expect(find.textContaining('catalogue actuellement'), findsNothing);
      expect(find.textContaining('appareils réels'), findsNothing);
      expect(find.textContaining('côté serveur'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
