import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/services/booking/booking_draft.dart';
import '../helpers/booking_test_harness.dart';
import '../helpers/gps_offline_transport.dart';

Future<(MemoryBookingStorage, TestBookingApi)> startDate(
  WidgetTester t,
  String locale,
) async {
  final storage = MemoryBookingStorage(testDraft()), api = TestBookingApi();
  t.view.physicalSize = const Size(430, 932);
  t.view.devicePixelRatio = 1;
  addTearDown(() async {
    await t.pumpWidget(const SizedBox());
    await t.pump();
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
    expect(t.takeException(), isNull);
  });
  await pumpBooking(t, storage: storage, api: api, locale: locale);
  return (storage, api);
}

Future<void> openDate(WidgetTester t) async {
  final button = find.widgetWithIcon(OutlinedButton, Icons.schedule);
  await t.ensureVisible(button);
  await t.pumpAndSettle();
  await t.tap(button);
  await t.pumpAndSettle();
}

void main() => offlineTests(() {
  for (final locale in ['fr', 'en', 'es']) {
    offlineWidgetTest('Q1 date picker language $locale', (t) async {
      final pair = await startDate(t, locale);
      final before = BookingDraft.fromJson(
        pair.$1.saved!.data,
      ).data['requested_at'];
      await openDate(t);
      final ctx = t.element(find.byType(DatePickerDialog));
      expect(Localizations.localeOf(ctx).languageCode, locale);
      final expected = await GlobalMaterialLocalizations.delegate.load(
        Locale(locale),
      );
      final actual = MaterialLocalizations.of(ctx);
      expect(actual.cancelButtonLabel, expected.cancelButtonLabel);
      await t.tap(find.text(actual.cancelButtonLabel));
      await t.pumpAndSettle();
      expect(pair.$1.saved!.data['requested_at'], before);
      expect(pair.$2.calls, isNot(contains('createDeliveryRequest')));
    });
    offlineWidgetTest(
      'Q1 time picker language and cancel preserves instant $locale',
      (t) async {
        final pair = await startDate(t, locale);
        final before = pair.$1.saved!.data['requested_at'];
        await openDate(t);
        final labels = MaterialLocalizations.of(
          t.element(find.byType(DatePickerDialog)),
        );
        await t.tap(find.text(labels.okButtonLabel));
        await t.pumpAndSettle();
        final ctx = t.element(find.byType(TimePickerDialog));
        expect(Localizations.localeOf(ctx).languageCode, locale);
        final expected = await GlobalMaterialLocalizations.delegate.load(
          Locale(locale),
        );
        final actual = MaterialLocalizations.of(ctx);
        expect(actual.cancelButtonLabel, expected.cancelButtonLabel);
        await t.tap(find.text(actual.cancelButtonLabel));
        await t.pumpAndSettle();
        expect(pair.$1.saved!.data['requested_at'], before);
      },
    );
    offlineWidgetTest('Q1 selected date summary is localized $locale', (
      t,
    ) async {
      final pair = await startDate(t, locale);
      final button = find.widgetWithIcon(OutlinedButton, Icons.schedule);
      final labels = t
          .widgetList<Text>(
            find.descendant(of: button, matching: find.byType(Text)),
          )
          .map((w) => w.data ?? '')
          .join(' ');
      expect(
        labels.toLowerCase(),
        contains({'fr': 'janvier', 'en': 'jan', 'es': 'enero'}[locale]!),
      );
      expect(pair.$1.saved!.data['requested_at'], '2099-01-01T12:00:00Z');
    });
  }
});
