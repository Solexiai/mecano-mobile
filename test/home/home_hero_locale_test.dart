import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/gps_offline_transport.dart';
import '../helpers/public_render_test_helpers.dart';
import 'home_screen_test.dart' show mountHome;

Finder heroImage() => find.byWidgetPredicate(
  (widget) =>
      widget is Image &&
      widget.image is AssetImage &&
      (widget.image as AssetImage).assetName.startsWith('assets/home/hero_'),
);
String assetFor(String locale) => locale == 'fr'
    ? 'assets/home/hero_clean.png'
    : 'assets/home/hero_neutral.png';
String labelFor(String locale) => {
  'fr': 'Camionnette Movi-K et chauffeur préparant une livraison',
  'en': 'Movi-K van and driver preparing a delivery',
  'es': 'Furgoneta Movi-K y conductor preparando una entrega',
}[locale]!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadLocalMaterialFonts);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    expect(Firebase.apps, isEmpty);
  });
  tearDown(() => expect(Firebase.apps, isEmpty));
  tearDownAll(() {
    expect(rejectedRequests, isEmpty);
    expect(offlineTileRequests, isEmpty);
  });
  for (final locale in ['fr', 'en', 'es']) {
    for (final scenario in [
      (375.0, 812.0, 1.0),
      (430.0, 932.0, 1.0),
      (1440.0, 900.0, 1.0),
      (375.0, 812.0, 2.0),
    ]) {
      final (width, height, scale) = scenario;
      offlineWidgetTest('hero locale $locale $width x $height text=$scale', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        try {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, height);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await mountHome(
            tester,
            locale: locale,
            width: width,
            height: height,
            scale: scale,
          );
          expect(heroImage(), findsOneWidget);
          expect(
            MediaQuery.sizeOf(tester.element(heroImage())),
            Size(width, height),
          );
          await tester.runAsync(
            () => precacheImage(
              tester.widget<Image>(heroImage()).image,
              tester.element(heroImage()),
            ),
          );
          await tester.pumpAndSettle();
          final raw = find.descendant(
            of: heroImage(),
            matching: find.byType(RawImage),
          );
          expect(tester.renderObject<RenderImage>(raw).image, isNotNull);
          if (width >= 980) {
            expect(tester.getSize(heroImage()).width, lessThan(width / 2));
          }
          expect(
            (tester.widget<Image>(heroImage()).image as AssetImage).assetName,
            assetFor(locale),
          );
          expect(find.bySemanticsLabel(labelFor(locale)), findsWidgets);
          await tester.ensureVisible(heroImage());
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await capturePublicViewport(
            tester,
            heroImage(),
            'hero-$locale-$width-$height-$scale',
            Size(width, height),
          );
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      });
    }
  }
  offlineWidgetTest('hero changes with language selector without stale asset', (
    tester,
  ) async {
    final (router, _) = await mountHome(
      tester,
      locale: 'fr',
      width: 375,
      height: 812,
    );
    for (final pair in [
      ('en', 'English'),
      ('es', 'Español'),
      ('fr', 'Français'),
    ]) {
      await tester.tap(find.byIcon(Icons.language));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining(pair.$2));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/${pair.$1}');
      expect(
        (tester.widget<Image>(heroImage()).image as AssetImage).assetName,
        assetFor(pair.$1),
      );
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
