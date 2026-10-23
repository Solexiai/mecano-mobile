import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/services/booking/booking_draft.dart';
import 'package:movik_connect/widgets/booking_load_summary.dart';
import 'package:movik_connect/widgets/booking_simple_steps.dart';
import '../helpers/booking_test_harness.dart';
import '../helpers/gps_offline_transport.dart';

void main() => offlineTests(() {
  for (final locale in ['fr', 'en', 'es']) {
    for (final spec in [
      (const Size(375, 812), 1.0),
      (const Size(430, 932), 1.0),
      (const Size(1440, 900), 1.0),
      (const Size(375, 812), 2.0),
    ]) {
      offlineWidgetTest('timing choices $locale ${spec.$1} text ${spec.$2}', (
        t,
      ) async {
        t.view.physicalSize = spec.$1;
        t.view.devicePixelRatio = 1;
        t.platformDispatcher.textScaleFactorTestValue = spec.$2;
        addTearDown(() {
          t.view.resetPhysicalSize();
          t.view.resetDevicePixelRatio();
          t.platformDispatcher.clearTextScaleFactorTestValue();
        });
        // The time is its own screen since 2026-10-23 (screen 4 of 7).
        final d = testDraft()
          ..part = 3
          ..data['requested_at'] = null;
        final storage = MemoryBookingStorage(d), api = TestBookingApi();
        await pumpBooking(t, storage: storage, api: api, locale: locale);
        final now = {
          'fr': 'Dès que possible',
          'en': 'As soon as possible',
          'es': 'Lo antes posible',
        }[locale]!;
        final scheduled = {
          'fr': 'Choisir un jour et une heure',
          'en': 'Choose a day and time',
          'es': 'Elegir un día y una hora',
        }[locale]!;
        expect(find.text(now), findsOneWidget);
        expect(find.text(scheduled), findsOneWidget);
        await tapBooking(t, now);
        expect(storage.saved!.load['timing_mode'], 'immediate');
        expect(storage.saved!.load['requested_at'], isNull);
        expect(find.byKey(const ValueKey('slot-hour-9')), findsNothing);
        await tapBookingKeyIfShown(t, 'booking-see-price');
        final index = api.calls.indexOf('calculateDeliveryQuote');
        expect(index, greaterThanOrEqualTo(0));
        expect(
          api.payloads[index]['booking'],
          containsPair('timing_mode', 'immediate'),
        );
        expect(
          api.payloads[index]['booking'],
          containsPair('requested_at', null),
        );
        expect(api.calls, isNot(contains('createDeliveryRequest')));
        expect(t.takeException(), isNull);
        await disposeBooking(t);
      });
    }
  }
  offlineWidgetTest(
    'switching mode invalidates quote and consent, preserves cargo and contacts',
    (t) async {
      final d = testDraft(quote: true)..part = 3;
      final contacts = Map.of(d.contacts), items = List.of(d.items);
      final storage = MemoryBookingStorage(d), api = TestBookingApi();
      await pumpBooking(t, storage: storage, api: api);
      await tapBookingKeyIfShown(t, 'timing-immediate');
      expect(storage.saved!.quote, isNull);
      expect(storage.saved!.data['accepted'], isFalse);
      expect(storage.saved!.contacts, contacts);
      expect(storage.saved!.items, items);
      await tapBookingKeyIfShown(t, 'timing-scheduled');
      expect(storage.saved!.load['timing_mode'], 'scheduled');
      expect(storage.saved!.load['requested_at'], isNull);
      final button = t.widget<FilledButton>(
        find.byKey(const ValueKey('booking-see-price')),
      );
      expect(button.onPressed, isNull);
      expect(
        find.text('Choisissez « Dès que possible », ou un jour et une heure.'),
        findsOneWidget,
      );
      await disposeBooking(t);
    },
  );
  offlineWidgetTest('a day and a fixed hour make the requested time', (
    t,
  ) async {
    final d = testDraft()
      ..part = 3
      ..data['requested_at'] = null
      ..data['timing_mode'] = 'scheduled';
    final storage = MemoryBookingStorage(d), api = TestBookingApi();
    await pumpBooking(t, storage: storage, api: api);
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final key = slotDayKey(
      DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
    );
    await tapBookingKeyIfShown(t, 'slot-day-$key');
    expect(storage.saved!.load['requested_at'], isNull);
    await tapBookingKeyIfShown(t, 'slot-hour-11');
    final requested = DateTime.parse(
      storage.saved!.load['requested_at'] as String,
    ).toLocal();
    expect(requested.day, tomorrow.day);
    expect(requested.hour, 11);
    expect(requested.minute, 0);
    await tapBookingKeyIfShown(t, 'booking-see-price');
    expect(api.calls, contains('calculateDeliveryQuote'));
    await disposeBooking(t);
  });
  offlineWidgetTest(
    'immediate choice survives widget recreation without becoming a date',
    (t) async {
      final d = testDraft()
        ..part = 3
        ..data['requested_at'] = null;
      final storage = MemoryBookingStorage(d), api = TestBookingApi();
      await pumpBooking(t, storage: storage, api: api);
      await tapBookingKeyIfShown(t, 'timing-immediate');
      await disposeBooking(t);
      await pumpBooking(t, storage: storage, api: api);
      expect(
        t
            .widget<Semantics>(
              find
                  .descendant(
                    of: find.byKey(const ValueKey('timing-immediate')),
                    matching: find.byType(Semantics),
                  )
                  .first,
            )
            .properties
            .selected,
        isTrue,
      );
      expect(storage.saved!.load['requested_at'], isNull);
      await disposeBooking(t);
    },
  );
  offlineWidgetTest(
    'unavailable reservation prices an immediate request but never sends it',
    (t) async {
      final storage = MemoryBookingStorage(testDraft()..part = 3),
          api = TestBookingApi()..configurationAvailable = false;
      await pumpBooking(t, storage: storage, api: api);
      await tapBookingKeyIfShown(t, 'timing-immediate');
      await tapBookingKeyIfShown(t, 'booking-see-price');
      // The official price does not require open booking (see
      // booking_quote_without_policy_test.dart); the request itself does.
      final quoteCall = api.calls.indexOf('calculateDeliveryQuote');
      expect(quoteCall, isNonNegative);
      expect(
        (api.payloads[quoteCall]['booking'] as Map)['timing_mode'],
        'immediate',
      );
      expect(api.calls, isNot(contains('createDeliveryRequest')));
      await disposeBooking(t);
    },
  );
  offlineWidgetTest(
    'confirmation honestly shows immediate preference and preserves quote',
    (t) async {
      final d = testDraft(step: 3, quote: true)
        ..data['timing_mode'] = 'immediate'
        ..data['requested_at'] = null;
      final storage = MemoryBookingStorage(d), api = TestBookingApi();
      await pumpBooking(t, storage: storage, api: api);
      expect(
        find.text('Dès maintenant — selon la disponibilité du chauffeur'),
        findsOneWidget,
      );
      expect(storage.saved!.quote!['customerTotal'], 123.45);
      expect(api.calls, isNot(contains('createDeliveryRequest')));
      await disposeBooking(t);
    },
  );
  offlineWidgetTest(
    'driver/client load summary communicates immediate request',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookingLoadSummary(
              locale: 'fr',
              snapshot: const {
                'load': {'timing_mode': 'immediate', 'requested_at': null},
              },
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.text('Dès maintenant — selon la disponibilité du chauffeur'),
        findsOneWidget,
      );
      await disposeBooking(t);
    },
  );
  offlineTest(
    'legacy draft does not silently change its quote payload',
    () async {
      final d = testDraft();
      final restored = BookingDraft.fromJson(d.data);
      expect(restored.load.containsKey('timing_mode'), isFalse);
      expect(restored.load['requested_at'], d.data['requested_at']);
    },
  );
});
