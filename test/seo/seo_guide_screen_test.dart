// Pages par objet et par ville (lib/seo/seo_guide_pages.dart) : chaque
// adresse ouvre SeoGuideScreen avec le même texte que la page lue par
// Google, sans débordement, et le changement de langue garde la même page.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movik_connect/backend/backend_status.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/router/app_router.dart';
import 'package:movik_connect/router/delivery_request_intent.dart';
import 'package:movik_connect/screens/info/seo_guide_screen.dart';
import 'package:movik_connect/seo/seo_pages.dart';

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

  test('switching language opens the same page in the other language', () {
    expect(
      DeliveryRequestIntent.switchLocale(Uri.parse('/fr/transport/refrigerateur'), 'en'),
      '/en/transport/refrigerator',
    );
    expect(
      DeliveryRequestIntent.switchLocale(Uri.parse('/en/cities/montreal'), 'es'),
      '/es/ciudades/montreal',
    );
    expect(DeliveryRequestIntent.switchLocale(Uri.parse('/fr/tarifs'), 'en'), '/en/pricing');
    // A campaign tag in the address must not lead to the 404.
    expect(
      DeliveryRequestIntent.switchLocale(
        Uri.parse('/fr/transport/refrigerateur?utm_source=facebook'),
        'en',
      ),
      '/en/transport/refrigerator',
    );
    expect(
      DeliveryRequestIntent.switchLocale(Uri.parse('/fr/livraison/demande?category=cat_tv'), 'en'),
      '/en/livraison/demande?category=cat_tv',
    );
  });

  for (final locale in ['fr', 'en', 'es']) {
    offlineWidgetTest('every guide page opens in $locale with its own text', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final auth = FirebaseAuthProvider(backendConfigured: false);
      await tester.pumpWidget(_app(auth));
      for (final page in seoGuidePages) {
        AppRouter.router.go(page.path(locale));
        await tester.pumpAndSettle();
        expect(find.byType(SeoGuideScreen), findsOneWidget, reason: page.path(locale));
        expect(find.text(page.headings[locale]!), findsOneWidget, reason: page.path(locale));
        expect(find.text(page.intros[locale]!), findsOneWidget, reason: page.path(locale));
        expect(find.byKey(const ValueKey('seo-guide-quote')), findsOneWidget);
        expect(tester.takeException(), isNull, reason: page.path(locale));
      }
    });
  }

  for (final width in [320.0, 1280.0]) {
    offlineWidgetTest('guide pages have no overflow at $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final auth = FirebaseAuthProvider(backendConfigured: false);
      await tester.pumpWidget(_app(auth, textScale: width == 320 ? 2 : 1));
      for (final path in [
        '/fr/transport/cuisiniere-lave-vaisselle',
        '/es/transporte/quitanieves-cortacesped',
        '/fr/villes/saint-jean-sur-richelieu',
        '/en/cities/quebec',
      ]) {
        AppRouter.router.go(path);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: path);
      }
    });
  }

  offlineWidgetTest('a link opens the other page', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = FirebaseAuthProvider(backendConfigured: false);
    AppRouter.router.go('/fr/villes/sherbrooke');
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();
    final link = find.byKey(const ValueKey('seo-link-/fr/transport/refrigerateur'));
    await tester.ensureVisible(link);
    await tester.pumpAndSettle();
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.text('Transport de réfrigérateur'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  offlineWidgetTest('an unknown guide address shows the 404 page', (tester) async {
    final auth = FirebaseAuthProvider(backendConfigured: false);
    AppRouter.router.go('/fr/transport/piano-a-queue');
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();
    expect(find.byType(SeoGuideScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
