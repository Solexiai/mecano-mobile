// Carte d'estimation par codes postaux (Daniel, 2026-11-26) sur la page
// Tarifs et sur les pages par objet, enseigne et ville, dans la langue de
// la page.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movik_connect/backend/backend_status.dart';
import 'package:movik_connect/l10n/home_copy.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/router/app_router.dart';
import 'package:movik_connect/widgets/estimate_card.dart';

import '../helpers/gps_offline_transport.dart';

Widget _app(FirebaseAuthProvider auth, {double textScale = 1}) => MultiProvider(
  providers: [
    Provider<BackendStatus>.value(value: BackendStatus.notConfigured()),
    ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
    ChangeNotifierProvider<FirebaseAuthProvider>.value(value: auth),
  ],
  child: MaterialApp.router(
    routerConfig: AppRouter.router,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    expect(Firebase.apps, isEmpty);
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => expect(Firebase.apps, isEmpty));

  offlineWidgetTest('pricing and guide pages carry the estimate card', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = FirebaseAuthProvider(backendConfigured: false);
    await tester.pumpWidget(_app(auth));
    for (final (path, locale, prefix) in [
      ('/fr/tarifs', 'fr', 'pricing-estimate'),
      ('/en/pricing', 'en', 'pricing-estimate'),
      ('/es/precios', 'es', 'pricing-estimate'),
      ('/fr/transport/refrigerateur', 'fr', 'seo-guide-estimate'),
      ('/fr/transport/prix-livraison-meuble', 'fr', 'seo-guide-estimate'),
      ('/fr/transport/livraison-ikea', 'fr', 'seo-guide-estimate'),
      ('/en/cities/montreal', 'en', 'seo-guide-estimate'),
      ('/es/ciudades/montreal', 'es', 'seo-guide-estimate'),
    ]) {
      AppRouter.router.go(path);
      await tester.pumpAndSettle();
      expect(find.byType(EstimateCard), findsOneWidget, reason: path);
      expect(
        find.text(HomeCopy.text('estimate_title', locale)),
        findsOneWidget,
        reason: path,
      );
      for (final part in ['from', 'to', 'medium', 'photo', 'submit']) {
        expect(find.byKey(Key('$prefix-$part')), findsOneWidget, reason: path);
      }
      expect(tester.takeException(), isNull, reason: path);
    }
  });

  offlineWidgetTest('the card has no overflow at 320 px with large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = FirebaseAuthProvider(backendConfigured: false);
    await tester.pumpWidget(_app(auth, textScale: 2));
    for (final path in ['/fr/tarifs', '/es/precios', '/en/cities/quebec']) {
      AppRouter.router.go(path);
      await tester.pumpAndSettle();
      final card = find.byType(EstimateCard);
      expect(card, findsOneWidget, reason: path);
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: path);
    }
  });

  offlineWidgetTest('an invalid postal code on the pricing page says why', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = FirebaseAuthProvider(backendConfigured: false);
    await tester.pumpWidget(_app(auth));
    AppRouter.router.go('/fr/tarifs');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('pricing-estimate-from')),
      'Granby',
    );
    final submit = find.byKey(const Key('pricing-estimate-submit'));
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text(HomeCopy.text('estimate_invalid', 'fr')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
