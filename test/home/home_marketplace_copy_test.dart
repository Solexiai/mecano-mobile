// P2-COPY-001: preserve the existing public examples and category route.
// Real Flutter widgets with the shared offline transport, not Chrome proof.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movik_connect/l10n/home_copy.dart';
import 'package:movik_connect/screens/delivery/delivery_request_flow_screen.dart';
import '../helpers/booking_test_harness.dart';
import '../helpers/gps_offline_transport.dart';
import '../helpers/public_render_test_helpers.dart' show loadRobotoTestFonts;
import 'home_screen_test.dart' show mountHome;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRobotoTestFonts);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    expect(Firebase.apps, isEmpty);
  });
  tearDown(() => expect(Firebase.apps, isEmpty));
  tearDownAll(() {
    expect(rejectedRequests, isEmpty);
    expect(offlineTileRequests, isEmpty);
    // ignore: avoid_print
    print(
      'OFFLINE_TRANSPORT: in_memory=0; unexpected=0; external_transport=none',
    );
  });

  for (final locale in ['fr', 'en', 'es']) {
    for (final scenario in [
      (375.0, 812.0, 1.0),
      (430.0, 932.0, 1.0),
      (1440.0, 900.0, 1.0),
      (375.0, 812.0, 2.0),
    ]) {
      final (width, height, scale) = scenario;
      offlineWidgetTest(
        'marketplace examples and request route $locale $width x $height text=$scale',
        (tester) async {
          final (router, _) = await mountHome(
            tester,
            locale: locale,
            width: width,
            height: height,
            scale: scale,
          );
          final examples = HomeCopy.text('marketplace_examples', locale);
          expect(examples, 'Facebook Marketplace, Kijiji, etc.');
          final category = find.byKey(
            const Key('home-category-cat_marketplace'),
          );
          expect(category, findsOneWidget);
          await tester.ensureVisible(category);
          await tester.pumpAndSettle();

          expect(
            find.descendant(of: category, matching: find.text(examples)),
            findsOneWidget,
          );
          final rendered = tester
              .widgetList<RichText>(find.byType(RichText))
              .map((text) => text.text.toPlainText())
              .join('\n');
          expect(
            RegExp(r'le\s*bon\s*coin', caseSensitive: false).hasMatch(rendered),
            isFalse,
          );
          for (final entry in HomeCopy.strings.entries) {
            expect(
              RegExp(
                r'le\s*bon\s*coin',
                caseSensitive: false,
              ).hasMatch(entry.value[locale] ?? ''),
              isFalse,
              reason: entry.key,
            );
          }
          expect(
            find.text(HomeCopy.text('granby_launch', locale)),
            findsWidgets,
          );
          expect(
            find.text(HomeCopy.text('prelaunch_status', locale)),
            findsWidgets,
          );
          final paragraphs = find.descendant(
            of: category,
            matching: find.byType(RichText),
          );
          expect(paragraphs, findsWidgets);
          for (final element in paragraphs.evaluate()) {
            final render = element.renderObject! as RenderParagraph;
            expect(
              render.didExceedMaxLines,
              isFalse,
              reason: render.text.toPlainText(),
            );
            expect(
              tester
                  .getRect(category)
                  .inflate(0.1)
                  .contains(
                    tester.getRect(find.byWidget(element.widget)).center,
                  ),
              isTrue,
            );
          }
          expect(tester.takeException(), isNull);

          await tester.tap(category);
          await tester.pumpAndSettle();
          expect(
            router.routeInformationProvider.value.uri.toString(),
            '/$locale/livraison/demande?category=cat_marketplace',
          );
          final screen = tester.widget<DeliveryRequestFlowScreen>(
            find.byType(DeliveryRequestFlowScreen),
          );
          expect(screen.initialCategory, 'cat_marketplace');
          expect(screen.api, isA<TestBookingApi>());
          expect(
            (screen.api! as TestBookingApi).calls,
            isNot(contains('createDeliveryRequest')),
          );
          expect(tester.takeException(), isNull);
          expect(Firebase.apps, isEmpty);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
