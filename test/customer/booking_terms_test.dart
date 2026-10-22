import 'package:movik_connect/core/app_theme.dart';
import 'package:movik_connect/widgets/booking_terms_section.dart';
import '../helpers/public_render_test_helpers.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/services/booking/booking_draft.dart';
import 'package:movik_connect/services/booking/booking_receipt_document.dart';
import '../helpers/booking_test_harness.dart';

const acceptKey = ValueKey('booking-contract-acceptance');
final confirm = find.widgetWithText(
  FilledButton,
  'Confirmer ma demande de livraison',
);
Future<void> accept(WidgetTester t) async {
  final f = find.byKey(acceptKey);
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  setUpAll(loadLocalMaterialFonts);
  test(
    'new draft is never preaccepted',
    () => expect(BookingDraft().data['accepted'], false),
  );
  testWidgets(
    'explicit unchecked acceptance blocks confirmation and optional marketing stays separate',
    (t) async {
      final d = testDraft(step: 3, quote: true)..data['accepted'] = false;
      final storage = MemoryBookingStorage(d), api = TestBookingApi();
      await pumpBooking(t, storage: storage, api: api);
      expect(t.widget<FilledButton>(confirm).onPressed, isNull);
      expect(t.widget<CheckboxListTile>(find.byKey(acceptKey)).value, false);
      await accept(t);
      expect(t.widget<FilledButton>(confirm).onPressed, isNotNull);
      expect(storage.saved!.data['marketing'], false);
      await tapBooking(t, 'Confirmer ma demande de livraison');
      final payload = api.payloads[api.calls.indexOf('createDeliveryRequest')];
      expect(
        (payload['consent'] as Map)['privacy_presented_version'],
        'TEST-privacy',
      );
      expect(
        (payload['consent'] as Map).containsKey('privacy_accepted'),
        false,
      );
      expect((payload['consent'] as Map)['marketing'], false);
      await disposeBooking(t);
    },
  );
  testWidgets(
    'consulting all documents preserves draft, official quote and keyboard return',
    (t) async {
      final storage = MemoryBookingStorage(testDraft(step: 3, quote: true));
      final api = TestBookingApi();
      await pumpBooking(t, storage: storage, api: api);
      final before = BookingDraft.fromJson(storage.saved!.data);
      for (final key in ['booking', 'terms', 'privacy']) {
        final f = find.byKey(ValueKey('booking-document-$key'));
        await t.ensureVisible(f);
        await t.pumpAndSettle();
        await t.tap(f);
        await t.pumpAndSettle();
        expect(find.byType(Dialog), findsOneWidget);
        expect(find.textContaining('SIMULATION $key TEST'), findsOneWidget);
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
        expect(find.byType(Dialog), findsNothing);
      }
      expect(storage.saved!.load, before.load);
      expect(storage.saved!.contacts, before.contacts);
      expect(storage.saved!.quote!['quoteId'], before.quote!['quoteId']);
      expect(api.calls, isNot(contains('createDeliveryRequest')));
      await disposeBooking(t);
    },
  );
  testWidgets(
    'version or content change at confirmation requires fresh acceptance',
    (t) async {
      final api = TestBookingApi();
      final storage = MemoryBookingStorage(testDraft(step: 3, quote: true));
      await pumpBooking(t, storage: storage, api: api);
      api.policy = testBookingPolicy(version: 'NEW');
      await tapBooking(t, 'Confirmer ma demande de livraison');
      expect(api.calls, isNot(contains('createDeliveryRequest')));
      expect(storage.saved!.quote!['quoteId'], 'test_quote');
      expect(t.widget<CheckboxListTile>(find.byKey(acceptKey)).value, false);
      await accept(t);
      await tapBooking(t, 'Confirmer ma demande de livraison');
      expect(
        (api.payloads[api.calls.indexOf('createDeliveryRequest')]['consent']
            as Map)['contract_hash'],
        'TEST-HASH-NEW',
      );
      await disposeBooking(t);
    },
  );
  testWidgets(
    'expired quote disables confirmation and renewal clears previous acceptance',
    (t) async {
      final d = testDraft(step: 3, quote: true);
      final api = TestBookingApi();
      api.quote = {
        ...d.quote!,
        'expiresAtMillis': DateTime.now()
            .subtract(const Duration(minutes: 1))
            .millisecondsSinceEpoch,
      };
      final storage = MemoryBookingStorage(d);
      await pumpBooking(t, storage: storage, api: api);
      expect(t.widget<FilledButton>(confirm).onPressed, isNull);
      api.quote = {
        ...testQuote(),
        'quoteId': 'NEW-QUOTE',
        'customerTotal': 140.0,
      };
      await tapBooking(t, 'Recalculer mon prix');
      expect(storage.saved!.quote!['quoteId'], 'NEW-QUOTE');
      expect(storage.saved!.data['accepted'], false);
      expect(api.calls, isNot(contains('createDeliveryRequest')));
      await disposeBooking(t);
    },
  );
  testWidgets('restored boolean without accepted version is rejected', (
    t,
  ) async {
    final d = testDraft(step: 3, quote: true)
      ..data.remove('accepted_contract_hash');
    await pumpBooking(
      t,
      storage: MemoryBookingStorage(d),
      api: TestBookingApi(),
    );
    expect(t.widget<CheckboxListTile>(find.byKey(acceptKey)).value, false);
    expect(t.widget<FilledButton>(confirm).onPressed, isNull);
    await disposeBooking(t);
  });
  for (final locale in ['fr', 'en', 'es']) {
    for (final layout in [
      (390.0, 844.0, 1.0),
      (1440.0, 900.0, 1.0),
      (390.0, 844.0, 2.0),
    ]) {
      testWidgets('terms accessible $locale $layout', (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = Size(layout.$1, layout.$2);
        t.platformDispatcher.textScaleFactorTestValue = layout.$3;
        addTearDown(() {
          t.view.resetPhysicalSize();
          t.view.resetDevicePixelRatio();
          t.platformDispatcher.clearTextScaleFactorTestValue();
        });
        final semantics = t.ensureSemantics();
        // Dispose before Flutter's end-of-test semantics verification.
        final d = testDraft(step: 3, quote: true)..data['accepted'] = false;
        await pumpBooking(
          t,
          storage: MemoryBookingStorage(d),
          api: TestBookingApi(),
          locale: locale,
          theme: AppTheme.light().copyWith(
            textTheme: AppTheme.light().textTheme.apply(fontFamily: 'Roboto'),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: AppTheme.light().elevatedButtonTheme.style!.copyWith(
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w600),
                ),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: AppTheme.light().textButtonTheme.style!.copyWith(
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        );
        await t.ensureVisible(find.byKey(acceptKey));
        await t.pumpAndSettle();
        expect(
          t
                  .getSemantics(find.byKey(acceptKey))
                  .getSemanticsData()
                  .flagsCollection
                  .isChecked !=
              ui.CheckedState.none,
          true,
        );
        // Real keyboard activation of the focused checkbox.
        for (
          var n = 0;
          n < 60 &&
              t
                      .getSemantics(find.byKey(acceptKey))
                      .getSemanticsData()
                      .flagsCollection
                      .isFocused !=
                  ui.Tristate.isTrue;
          n++
        ) {
          await t.sendKeyEvent(LogicalKeyboardKey.tab);
          await t.pumpAndSettle();
        }
        expect(
          t
                  .getSemantics(find.byKey(acceptKey))
                  .getSemanticsData()
                  .flagsCollection
                  .isFocused ==
              ui.Tristate.isTrue,
          true,
        );
        await t.sendKeyEvent(LogicalKeyboardKey.space);
        await t.pumpAndSettle();
        expect(t.widget<CheckboxListTile>(find.byKey(acceptKey)).value, true);
        expect(
          find.byKey(const ValueKey('booking-document-privacy')),
          findsOneWidget,
        );
        expect(t.takeException(), isNull);
        for (final e in find.byType(RichText).evaluate()) {
          final r = e.renderObject;
          if (r is RenderParagraph) expect(r.didExceedMaxLines, false);
        }
        if (locale == 'fr' && layout.$3 == 1) {
          final boundary = t.renderObject<RenderRepaintBoundary>(
            find.byType(RepaintBoundary).first,
          );
          await t.runAsync(() async {
            final bytes = await (await boundary.toImage(
              pixelRatio: 1,
            )).toByteData(format: ui.ImageByteFormat.png);
            await writeTestArtifact(
              'artifacts/booking-terms-20261018-1430/terms-${layout.$1.toInt()}.png',
              bytes!.buffer.asUint8List(),
            );
          });
        }
        if (locale == 'fr' && layout.$3 == 1) {
          await Scrollable.ensureVisible(
            t.element(find.byType(BookingTermsSection)),
            alignment: 0,
          );
          await t.pumpAndSettle();
          final boundary = t.renderObject<RenderRepaintBoundary>(
            find.byType(RepaintBoundary).first,
          );
          await t.runAsync(() async {
            final img = await boundary.toImage(pixelRatio: 1);
            final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
            await writeTestArtifact(
              'artifacts/booking-terms-20261018-1430/terms-information-${layout.$1.toInt()}.png',
              bytes!.buffer.asUint8List(),
            );
            img.dispose();
          });
        }
        semantics.dispose();
        await disposeBooking(t);
      });
    }
  }
  test(
    'printable receipt escapes user content and preserves original versions and cents',
    () {
      final r = <String, dynamic>{
        'missionId': 'TEST',
        'quoteId': 'Q',
        'customerTotalMinor': 12345,
        'breakdown': {'taxAmount': 18.45},
        'pickup': {'line1': '<script>alert(1)</script>'},
        'dropoff': {},
        'contract': testBookingPolicy(version: 'ORIGINAL'),
        'acceptance': {'acceptedAtMillis': 1000},
      };
      final text = bookingReceiptText(r, 'fr'),
          html = bookingReceiptHtml(r, 'fr');
      expect(text, contains('ORIGINAL-booking'));
      expect(text, contains('123,45'));
      expect(text, contains('1970-01-01T00:00:01.000Z'));
      expect(html, isNot(contains('<script>')));
      expect(html, contains('&lt;script&gt;'));
      expect(html, contains('@media print'));
      writeTestArtifactSync(
        'artifacts/booking-terms-20261018-1430/receipt-preview.html',
        html,
      );
    },
  );
}
