// P1-HOME-001: real HomeScreen geometry, not a Chrome rendering claim.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/l10n/home_copy.dart';
import '../helpers/gps_offline_transport.dart';
import 'home_screen_test.dart' show mountHome;

Finder component(String name) =>
    find.byWidgetPredicate((widget) => widget.runtimeType.toString() == name);

void expectOrdered(WidgetTester tester, Finder first, Finder second) {
  expect(
    tester.getRect(first).bottom,
    lessThanOrEqualTo(tester.getRect(second).top + 0.01),
    reason: '$first must end before $second',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDownAll(() {
    expect(rejectedRequests, isEmpty);
    expect(offlineTileRequests, isEmpty);
    // ignore: avoid_print
    print(
      "OFFLINE_TRANSPORT: in_memory=0; unexpected=0; external_transport=none",
    );
  });
  for (final locale in ['fr', 'en', 'es']) {
    for (final scenario in [
      (375.0, 812.0, 1.0),
      (430.0, 932.0, 1.0),
      (1440.0, 900.0, 1.0),
      (375.0, 812.0, 2.0),
      (430.0, 932.0, 2.0),
    ]) {
      final (width, height, scale) = scenario;
      offlineWidgetTest(
        'home sections and actions do not overlap $locale ${width}x$height text=$scale',
        (tester) async {
          expect(Firebase.apps, isEmpty);
          await mountHome(
            tester,
            locale: locale,
            width: width,
            height: height,
            scale: scale,
          );
          final hero = find.byKey(const Key('home-hero'));
          final trust = component('_Trust');
          final quote = component('_QuoteCard');
          final heroCopy = component('_HeroCopy');
          expectOrdered(tester, heroCopy, trust);
          expectOrdered(tester, quote, trust);
          expectOrdered(tester, hero, component('_Categories'));
          expectOrdered(tester, component('_Categories'), component('_Steps'));
          expectOrdered(tester, component('_Steps'), component('_Reassurance'));
          expectOrdered(
            tester,
            component('_Reassurance'),
            component('_LocalCta'),
          );

          // 2026-11-26 : the estimate card is the action of the hero. The
          // invitation to drivers is the button of the header when it has
          // room for one, otherwise a link under the card.
          final quoteAction = find.byKey(const Key('home-estimate-submit'));
          final headerDriver = find.byKey(const Key('public-header-driver'));
          final driverLink = find.descendant(
            of: hero,
            matching: find.byKey(const Key('home-driver-link')),
          );
          final headerHasButton = width >= 1200 && scale == 1.0;
          expect(headerDriver, headerHasButton ? findsOneWidget : findsNothing);
          expect(driverLink, headerHasButton ? findsNothing : findsOneWidget);
          final driverAction = headerHasButton ? headerDriver : driverLink;
          expect(
            find.descendant(of: hero, matching: find.byType(OutlinedButton)),
            findsNothing,
          );
          expect(find.byKey(const Key('home-primary-quote')), findsNothing);
          expectOrdered(tester, heroCopy, quote);
          // On a computer the two postal codes sit side by side and the
          // photo is as tall as the column of the card.
          final from = tester.getRect(
            find.byKey(const Key('home-estimate-from')),
          );
          final to = tester.getRect(find.byKey(const Key('home-estimate-to')));
          if (width >= 1200) {
            expect(from.top, to.top);
            expect(from.right, lessThan(to.left));
            final scene = tester.getRect(component('_HeroScene'));
            expect(scene.top, closeTo(tester.getRect(heroCopy).top, 0.01));
            expect(scene.bottom, closeTo(tester.getRect(quote).bottom, 0.01));
          } else {
            expect(from.bottom, lessThan(to.top));
            expectOrdered(tester, quote, component('_HeroScene'));
          }
          expect(
            tester.getRect(quoteAction).overlaps(tester.getRect(driverAction)),
            isFalse,
          );
          expect(
            tester.getRect(quoteAction).bottom,
            lessThan(tester.getRect(trust).top),
          );
          expect(
            tester.getRect(driverAction).bottom,
            lessThan(tester.getRect(trust).top),
          );
          if (width >= 980) {
            expect(
              find.descendant(of: hero, matching: find.byType(Positioned)),
              findsNothing,
            );
          }

          final cards = component('_StepCard');
          expect(cards, findsNWidgets(4));
          final cardRects = [
            for (var i = 0; i < 4; i++) tester.getRect(cards.at(i)),
          ];
          for (var i = 0; i < cardRects.length; i++) {
            for (var j = i + 1; j < cardRects.length; j++) {
              expect(cardRects[i].overlaps(cardRects[j]), isFalse);
            }
          }
          for (final area in [hero, component('_Steps')]) {
            for (final element
                in find
                    .descendant(of: area, matching: find.byType(RichText))
                    .evaluate()) {
              final render = element.renderObject;
              if (render is RenderParagraph) {
                expect(
                  render.didExceedMaxLines,
                  isFalse,
                  reason: render.text.toPlainText(),
                );
              }
            }
          }
          for (final section in [
            quote,
            trust,
            component('_Categories'),
            component('_Steps'),
            component('_Reassurance'),
            component('_LocalCta'),
          ]) {
            await tester.ensureVisible(section);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          expect(Firebase.apps, isEmpty);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );
    }

    offlineWidgetTest('header invites drivers on a computer in $locale', (
      tester,
    ) async {
      final (router, _) = await mountHome(
        tester,
        locale: locale,
        width: 1440,
        height: 900,
      );
      final action = find.byKey(const Key('public-header-driver'));
      expect(action, findsOneWidget);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/$locale/devenir-chauffeur',
      );
      expect(tester.takeException(), isNull);
      expect(Firebase.apps, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    offlineWidgetTest('driver action preserves the existing $locale route', (
      tester,
    ) async {
      final (router, _) = await mountHome(
        tester,
        locale: locale,
        width: 430,
        height: 932,
      );
      final action = find.descendant(
        of: find.byKey(const Key('home-hero')),
        matching: find.byKey(const Key('home-driver-link')),
      );
      expect(
        find.descendant(
          of: action,
          matching: find.text(HomeCopy.text('driver_link', locale)),
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/$locale/devenir-chauffeur',
      );
      expect(tester.takeException(), isNull);
      expect(Firebase.apps, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
