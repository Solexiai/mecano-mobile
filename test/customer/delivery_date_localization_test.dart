import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/widgets/booking_simple_steps.dart';
import '../helpers/booking_test_harness.dart';
import '../helpers/gps_offline_transport.dart';

// Since 2026-10-23 the time is chosen with day buttons and fixed hours
// (screen 4 of 7) instead of the Material date and time pickers.
Future<(MemoryBookingStorage, TestBookingApi)> startDate(
  WidgetTester t,
  String locale,
) async {
  final storage = MemoryBookingStorage(testDraft(part: 3)),
      api = TestBookingApi();
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

void main() => offlineTests(() {
  for (final locale in ['fr', 'en', 'es']) {
    offlineWidgetTest('Q1 day and hour buttons are localized $locale', (
      t,
    ) async {
      final pair = await startDate(t, locale);
      expect(
        find.text({'fr': 'Demain', 'en': 'Tomorrow', 'es': 'Mañana'}[locale]!),
        findsOneWidget,
      );
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      await tapBookingKeyIfShown(
        t,
        'slot-day-${slotDayKey(DateTime(tomorrow.year, tomorrow.month, tomorrow.day))}',
      );
      expect(
        find.text({'fr': '9 h', 'en': '9:00', 'es': '9 h'}[locale]!),
        findsOneWidget,
      );
      expect(pair.$2.calls, isNot(contains('createDeliveryRequest')));
    });
    offlineWidgetTest('Q1 selected date summary is localized $locale', (
      t,
    ) async {
      final pair = await startDate(t, locale);
      final labels = t
          .widgetList<Text>(find.byType(Text))
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
