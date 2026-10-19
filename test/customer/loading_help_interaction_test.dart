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

  testWidgets(
    'independent choices, conditional lifting answer, draft save and reload',
    (t) async {
      final d = testDraft(quote: true);
      for (final k in ['pickup_access', 'dropoff_access']) {
        d.data[k]['help'] = null;
        d.data[k]['onsite_help'] = null;
      }
      final storage = MemoryBookingStorage(d);
      await pumpBooking(t, storage: storage, api: TestBookingApi());
      expect(
        find.text('Quelqu’un sur place pourra-t-il aider à soulever ?'),
        findsNothing,
      );
      await tapKey(t, 'pickup-help-true');
      expect(
        find.text('Quelqu’un sur place pourra-t-il aider à soulever ?'),
        findsOneWidget,
      );
      await tapKey(t, 'pickup-onsite_help-no');
      await tapKey(t, 'dropoff-help-false');
      expect(storage.saved!.data['pickup_access']['help'], true);
      expect(storage.saved!.data['dropoff_access']['help'], false);
      expect(storage.saved!.data['pickup_access']['onsite_help'], 'no');
      expect(storage.saved!.quote, isNull);
      expect(storage.saved!.data['accepted'], false);
      await disposeBooking(t);
      await pumpBooking(t, storage: storage, api: TestBookingApi());
      expect(
        t
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('pickup-onsite_help-no')),
            )
            .selected,
        true,
      );
      expect(storage.saved!.data['dropoff_access']['help'], false);
      await disposeBooking(t);
    },
  );
  testWidgets(
    'quote receives distinct service and onsite answers; back retains them',
    (t) async {
      final d = testDraft();
      d.data['pickup_access']['help'] = false;
      d.data['pickup_access']['onsite_help'] = null;
      d.data['dropoff_access']['onsite_help'] = 'yes';
      final storage = MemoryBookingStorage(d), api = TestBookingApi();
      await pumpBooking(t, storage: storage, api: api);
      await tapBooking(t, 'Voir mon prix');
      final payload =
          api.payloads[api.calls.lastIndexOf(
                'calculateDeliveryQuote',
              )]['booking']
              as Map;
      expect(payload['pickup']['help'], false);
      expect(payload['dropoff']['help'], true);
      expect(payload['dropoff']['onsite_help'], 'yes');
      expect(payload['handlers'], 1);
      expect(storage.saved!.quote!['customerTotal'], 123.45);
      await tapBooking(t, 'Retour');
      expect(storage.saved!.data['pickup_access']['help'], false);
      await disposeBooking(t);
    },
  );
  testWidgets('unanswered help cannot produce a quote and keeps draft', (
    t,
  ) async {
    final d = testDraft();
    d.data['pickup_access']['help'] = null;
    final api = TestBookingApi(), storage = MemoryBookingStorage(d);
    await pumpBooking(t, storage: storage, api: api);
    await tapBooking(t, 'Voir mon prix');
    expect(api.calls, isNot(contains('calculateDeliveryQuote')));
    expect(storage.saved!.items, isNotEmpty);
    expect(storage.saved!.step, 0);
    await disposeBooking(t);
  });
  testWidgets(
    'interior contradiction needs clarification without selecting paid help',
    (t) async {
      final d = testDraft();
      d.data['pickup_access']['help'] = false;
      final api = TestBookingApi(), storage = MemoryBookingStorage(d);
      await pumpBooking(t, storage: storage, api: api);
      await tapKey(t, 'pickup-inside-true');
      await tapBooking(t, 'Voir mon prix');
      expect(api.calls, isNot(contains('calculateDeliveryQuote')));
      expect(storage.saved!.data['pickup_access']['help'], false);
      await tapKey(t, 'pickup-customer-inside');
      await tapBooking(t, 'Voir mon prix');
      expect(api.calls, contains('calculateDeliveryQuote'));
      expect(storage.saved!.data['pickup_access']['help'], false);
      await disposeBooking(t);
    },
  );
  testWidgets('stairs and elevator coexist and closing panel keeps answers', (
    t,
  ) async {
    final storage = MemoryBookingStorage(testDraft());
    await pumpBooking(t, storage: storage, api: TestBookingApi());
    await tapBooking(t, 'Accès au ramassage');
    await tapKey(t, 'pickup-stairs-true');
    await tapKey(t, 'pickup-elevator-true');
    await tapBooking(t, 'Accès au ramassage');
    expect(storage.saved!.data['pickup_access']['stairs'], true);
    expect(storage.saved!.data['pickup_access']['elevator'], true);
    expect(
      find.text('Rez-de-chaussée · Escaliers · Ascenseur'),
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
