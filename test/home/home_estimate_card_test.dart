// Carte d'estimation de l'accueil (Daniel, 2026-11-26) : deux codes postaux
// et un poids ouvrent la page d'estimation légère.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movik_connect/l10n/home_copy.dart';
import 'package:movik_connect/screens/delivery/delivery_request_flow_screen.dart';

import '../helpers/gps_offline_transport.dart';
import 'home_screen_test.dart' show mountHome;

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Same isolation as the other home tests: empty device storage, no Firebase.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    expect(Firebase.apps, isEmpty);
  });
  tearDown(() => expect(Firebase.apps, isEmpty));

  for (final locale in ['fr', 'en', 'es']) {
    offlineWidgetTest('estimate card $locale opens the estimate page', (
      tester,
    ) async {
      final opened = <String>[];
      await mountHome(
        tester,
        locale: locale,
        openEstimate: (path) async => opened.add(path),
      );
      expect(find.text(HomeCopy.text('estimate_title', locale)), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('home-estimate-from')),
        'j2g3v5',
      );
      await tester.enterText(find.byKey(const Key('home-estimate-to')), 'J2L');
      await tapVisible(tester, find.byKey(const Key('home-estimate-heavy')));
      await tapVisible(tester, find.byKey(const Key('home-estimate-submit')));

      expect(opened, hasLength(1));
      final uri = Uri.parse(opened.single);
      expect(uri.path, {
        'fr': '/fr/estimation',
        'en': '/en/estimate',
        'es': '/es/estimacion',
      }[locale]);
      expect(uri.queryParameters, {
        'de': 'J2G 3V5',
        'a': 'J2L',
        'poids': 'heavy',
      });
      expect(find.byKey(const Key('home-estimate-invalid')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  offlineWidgetTest('medium is the default weight', (tester) async {
    final opened = <String>[];
    await mountHome(tester, openEstimate: (path) async => opened.add(path));
    await tester.enterText(
      find.byKey(const Key('home-estimate-from')),
      'J2G 3V5',
    );
    await tester.enterText(
      find.byKey(const Key('home-estimate-to')),
      'H2X 1Y4',
    );
    await tapVisible(tester, find.byKey(const Key('home-estimate-submit')));
    expect(Uri.parse(opened.single).queryParameters['poids'], 'medium');
  });

  offlineWidgetTest('an invalid postal code opens nothing and says why', (
    tester,
  ) async {
    final opened = <String>[];
    await mountHome(tester, openEstimate: (path) async => opened.add(path));
    await tester.enterText(
      find.byKey(const Key('home-estimate-from')),
      'Granby',
    );
    await tester.enterText(
      find.byKey(const Key('home-estimate-to')),
      'J2L 1A1',
    );
    await tapVisible(tester, find.byKey(const Key('home-estimate-submit')));
    expect(opened, isEmpty);
    expect(
      find.text(HomeCopy.text('estimate_invalid', 'fr')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('home-estimate-from')),
      'J2G 3V5',
    );
    await tapVisible(tester, find.byKey(const Key('home-estimate-submit')));
    expect(opened, hasLength(1));
    expect(find.byKey(const Key('home-estimate-invalid')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  offlineWidgetTest('"not sure" opens the delivery request, which takes a photo', (
    tester,
  ) async {
    final (router, _) = await mountHome(
      tester,
      openEstimate: (_) async => fail('the estimate page must not open'),
    );
    await tapVisible(tester, find.byKey(const Key('home-estimate-photo')));
    expect(
      router.routeInformationProvider.value.uri.path,
      '/fr/livraison/demande',
    );
    expect(find.byType(DeliveryRequestFlowScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
