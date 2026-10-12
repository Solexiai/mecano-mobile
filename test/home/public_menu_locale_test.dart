import 'dart:ui' show SemanticsAction;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import '../helpers/gps_offline_transport.dart';
import '../helpers/public_render_test_helpers.dart';
import 'home_screen_test.dart' show mountHome;

String menuLabel(String locale) => {
  'fr': 'Ouvrir le menu de navigation',
  'en': 'Open navigation menu',
  'es': 'Abrir el menú de navegación',
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
      offlineWidgetTest('public menu $locale $width x $height text=$scale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, height);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final semantics = tester.ensureSemantics();
        try {
          final (router, _) = await mountHome(
            tester,
            locale: locale,
            width: width,
            height: height,
            scale: scale,
          );
          final scaffold = find.byType(Scaffold).first;
          expect(
            MediaQuery.sizeOf(tester.element(scaffold)),
            Size(width, height),
          );
          final state = tester.state<ScaffoldState>(scaffold);
          if (width >= 980) {
            expect(find.byIcon(Icons.menu), findsNothing);
            final t = tester.element(scaffold).read<LocaleProvider>().t;
            final faq = find.descendant(
              of: find.byType(AppBar),
              matching: find.text(t('nav_faq')),
            );
            expect(faq, findsOneWidget);
            await tester.tap(faq);
            await tester.pumpAndSettle();
            expect(
              router.routeInformationProvider.value.uri.path,
              '/$locale/faq',
            );
            router.go('/$locale');
            await tester.pumpAndSettle();
            expect(find.byIcon(Icons.menu), findsNothing);
          } else {
            final button = find.byTooltip(menuLabel(locale));
            expect(button, findsOneWidget);
            final data = tester.getSemantics(button).getSemanticsData();
            expect(data.flagsCollection.isButton, isTrue);
            expect(data.hasAction(SemanticsAction.tap), isTrue);
            expect(
              '${data.label} ${data.tooltip}',
              contains(menuLabel(locale)),
            );
            await tester.runAsync(
              () => precacheImage(
                const AssetImage('assets/home/brand_logo.png'),
                tester.element(scaffold),
              ),
            );
            await tester.pumpAndSettle();
            await tester.longPress(button);
            await tester.pump(const Duration(milliseconds: 750));
            expect(find.text(menuLabel(locale)), findsOneWidget);
            await capturePublicOverlayViewport(
              tester,
              'menu-$locale-$width-$height-$scale',
              Size(width, height),
            );
            Tooltip.dismissAllToolTips();
            await tester.pumpAndSettle();
            await tester.tap(button);
            await tester.pumpAndSettle();
            expect(state.isDrawerOpen, isTrue);
            Navigator.of(tester.element(find.byType(Drawer))).pop();
            await tester.pumpAndSettle();
            expect(state.isDrawerOpen, isFalse);
            await tester.tap(button);
            await tester.pumpAndSettle();
            final t = tester.element(scaffold).read<LocaleProvider>().t;
            final contact = find.descendant(
              of: find.byType(Drawer),
              matching: find.text(t('nav_contact')),
            );
            await tester.scrollUntilVisible(
              contact,
              160,
              scrollable: find
                  .descendant(
                    of: find.byType(Drawer),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
            await tester.tap(contact);
            await tester.pumpAndSettle();
            expect(
              router.routeInformationProvider.value.uri.path,
              '/$locale/contact',
            );
            expect(find.byTooltip(menuLabel(locale)), findsOneWidget);
            router.go('/$locale');
            await tester.pumpAndSettle();
            expect(find.byTooltip(menuLabel(locale)), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      });
    }
  }
  offlineWidgetTest('public menu follows language changes during use', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final (router, _) = await mountHome(
      tester,
      locale: 'en',
      width: 375,
      height: 812,
    );
    for (final pair in [
      ('fr', 'Français'),
      ('es', 'Español'),
      ('en', 'English'),
    ]) {
      await tester.tap(find.byIcon(Icons.language));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining(pair.$2));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/${pair.$1}');
      expect(find.byTooltip(menuLabel(pair.$1)), findsOneWidget);
      await tester.tap(find.byTooltip(menuLabel(pair.$1)));
      await tester.pumpAndSettle();
      expect(
        tester.state<ScaffoldState>(find.byType(Scaffold).first).isDrawerOpen,
        isTrue,
      );
      Navigator.of(tester.element(find.byType(Drawer))).pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
