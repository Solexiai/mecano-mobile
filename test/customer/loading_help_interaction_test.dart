import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/widgets/booking_access_section.dart';
import 'package:movik_connect/widgets/booking_load_summary.dart';
import 'package:movik_connect/services/booking/booking_draft.dart';
import '../helpers/booking_test_harness.dart';

void main() {
  Future<void> tapKey(WidgetTester t, String key) async {
    final f = find.byKey(ValueKey(key));
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  // Since 2026-10-23 the booking asks one simple help question (screen 3 of
  // 7) instead of per-address help, interior and lifting questions.
  testWidgets('help choice fills both addresses; quote and back keep it', (
    t,
  ) async {
    final d = testDraft(quote: true)..part = 2;
    final storage = MemoryBookingStorage(d), api = TestBookingApi();
    await pumpBooking(t, storage: storage, api: api);
    await tapKey(t, 'help-choice-two_movers');
    expect(storage.saved!.data['handlers'], 2);
    expect(storage.saved!.data['pickup_access']['onsite_help'], 'no');
    expect(storage.saved!.data['dropoff_access']['help'], true);
    expect(storage.saved!.quote, isNull);
    expect(storage.saved!.data['accepted'], false);
    await tapKey(t, 'booking-next-help');
    await tapKey(t, 'booking-see-price');
    final payload =
        api.payloads[api.calls.lastIndexOf('calculateDeliveryQuote')]['booking']
            as Map;
    expect(payload['handlers'], 2);
    expect(payload['pickup']['help'], true);
    expect(payload['dropoff']['onsite_help'], 'no');
    expect(storage.saved!.quote!['customerTotal'], 123.45);
    await tapKey(t, 'booking-back');
    await tapKey(t, 'booking-back');
    expect(storage.saved!.data['help_choice'], 'two_movers');
    await disposeBooking(t);
    await pumpBooking(t, storage: storage, api: TestBookingApi());
    expect(find.text('Pouvez-vous aider à porter ?'), findsOneWidget);
    expect(storage.saved!.data['handlers'], 2);
    await disposeBooking(t);
  });
  testWidgets('unanswered help cannot go further and keeps the draft', (
    t,
  ) async {
    final d = testDraft()..part = 2;
    final api = TestBookingApi(), storage = MemoryBookingStorage(d);
    await pumpBooking(t, storage: storage, api: api);
    final next = t.widget<FilledButton>(
      find.byKey(const ValueKey('booking-next-help')),
    );
    expect(next.onPressed, isNull);
    expect(find.text('Choisissez une réponse.'), findsOneWidget);
    expect(api.calls, isNot(contains('calculateDeliveryQuote')));
    expect(storage.saved!.items, isNotEmpty);
    await disposeBooking(t);
  });
  testWidgets('a draft without help answers is sent back to the question', (
    t,
  ) async {
    final d = testDraft()..part = 3;
    d.data['pickup_access']['help'] = null;
    final api = TestBookingApi(), storage = MemoryBookingStorage(d);
    await pumpBooking(t, storage: storage, api: api);
    await tapKey(t, 'booking-see-price');
    expect(api.calls, isNot(contains('calculateDeliveryQuote')));
    expect(storage.saved!.step, 0);
    expect(storage.saved!.part, 2);
    await disposeBooking(t);
  });
  testWidgets('stairs answer survives a reload', (t) async {
    final d = testDraft()..part = 1;
    final storage = MemoryBookingStorage(d);
    await pumpBooking(t, storage: storage, api: TestBookingApi());
    await tapKey(t, 'pickup-stairs-yes');
    expect(storage.saved!.data['pickup_access']['stairs'], true);
    expect(storage.saved!.data['pickup_access']['floor'], 1);
    await disposeBooking(t);
    await pumpBooking(t, storage: storage, api: TestBookingApi());
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is FilledButton && w.key == const ValueKey('pickup-stairs-yes'),
      ),
      findsOneWidget,
    );
    await disposeBooking(t);
  });
  test('legacy defaults are not proof of access confirmation', () {
    expect(
      accessSummary({'floor': 0, 'stairs': false, 'help': true}, 'fr'),
      'Accès à préciser',
    );
    final d = testDraft();
    d.data['pickup_access'].remove('confirmed_fields');
    final restored = BookingDraft.fromJson(d.data);
    expect(restored.data['pickup_access']['help'], true);
    expect(accessAnswersComplete(restored.data['pickup_access']), false);
  });
  testWidgets('keyboard selection and accessible checked state', (t) async {
    final access = BookingDraft().data['pickup_access'] as Map;
    final semantics = t.ensureSemantics();

    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (_, update) => BookingAccessSection(
                access: access,
                pickup: true,
                locale: 'fr',
                onChanged: () => update(() {}),
              ),
            ),
          ),
        ),
      ),
    );
    final button = find.byKey(const ValueKey('pickup-help-false'));
    Focus.of(
      t.element(find.descendant(of: button, matching: find.byType(Text)).first),
    ).requestFocus();
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(access['help'], false);
    expect(
      t.getSemantics(button),
      matchesSemantics(
        isButton: true,
        isFocusable: true,
        isFocused: true,
        hasEnabledState: true,
        isEnabled: true,
        label: 'Sans aide Movi-K\nNous organisons le chargement.',
        isInMutuallyExclusiveGroup: true,
        hasCheckedState: true,
        isChecked: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    semantics.dispose();
    await t.pumpWidget(const SizedBox());
  });
  for (final locale in ['fr', 'en', 'es']) {
    for (final width in [375.0, 1440.0]) {
      testWidgets('access responsive $locale $width text 200%', (t) async {
        t.view.physicalSize = Size(width, 1000);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final access = testDraft().data['pickup_access'] as Map;
        await t.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 1000),
                textScaler: TextScaler.linear(2),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: BookingAccessSection(
                    access: access,
                    pickup: true,
                    locale: locale,
                    onChanged: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      });
    }
  }
  testWidgets(
    'summary distinguishes requested help, on-site help and interior',
    (t) async {
      final load = testDraft().load;
      load['pickup']['help'] = false;
      load['dropoff']['onsite_help'] = 'no';
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BookingLoadSummary(snapshot: {'load': load}, locale: 'fr'),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Sans aide Movi-K'), findsOneWidget);
      expect(find.text('Avec aide Movi-K'), findsOneWidget);
      expect(find.text('Aide pour soulever sur place : Non'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
  );
}
