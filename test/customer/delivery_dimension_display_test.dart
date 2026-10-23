import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/booking_test_harness.dart';
import '../helpers/gps_offline_transport.dart';

Finder dimensionField(String key, String unit) =>
    find.byKey(ValueKey('test-item-$key-$unit-kg'));
String dimensionText(WidgetTester t, String key, String unit) =>
    t.widget<TextFormField>(dimensionField(key, unit)).initialValue!;
Future<void> changeUnit(WidgetTester t, String unit) async {
  final dropdown = find.byWidgetPredicate(
    (w) =>
        w is DropdownButtonFormField<String> &&
        ['cm', 'in'].contains(w.initialValue),
  );
  await t.ensureVisible(dropdown);
  await t.tap(dropdown);
  await t.pumpAndSettle();
  await t.tap(find.text(unit).last);
  await t.pumpAndSettle();
}

void setupView(WidgetTester t, Size size, double scale) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() async {
    await disposeBooking(t);
    t.view.resetDevicePixelRatio();
    t.view.resetPhysicalSize();
    t.platformDispatcher.clearTextScaleFactorTestValue();
    expect(t.takeException(), isNull);
  });
}

String localized(String value, String locale) =>
    locale == 'en' ? value : value.replaceAll('.', ',');

void main() {
  offlineTests(() {
    for (final locale in ['fr', 'en', 'es']) {
      for (final view in [
        (const Size(375, 812), 1.0),
        (const Size(430, 932), 1.0),
        (const Size(1440, 900), 1.0),
        (const Size(375, 812), 2.0),
      ]) {
        offlineWidgetTest(
          'Q4 $locale ${view.$1} scale ${view.$2} compact conversion retains exact values',
          (t) async {
            setupView(t, view.$1, view.$2);
            final d = testDraft();
            d.items.first['length'] = 190;
            final store = MemoryBookingStorage(d);
            await pumpBooking(
              t,
              storage: store,
              api: TestBookingApi(),
              locale: locale,
            );
            await changeUnit(t, 'in');
            expect(dimensionText(t, 'length', 'in'), localized('74.8', locale));
            expect(dimensionText(t, 'width', 'in'), localized('19.69', locale));
            expect(
              dimensionText(t, 'height', 'in'),
              localized('23.62', locale),
            );
            expect(store.saved!.items.first['length'], 190 * (1 / 2.54));
            expect(store.saved!.items.first['width'], 50 * (1 / 2.54));
            final input = find.descendant(
              of: dimensionField('length', 'in'),
              matching: find.byType(EditableText),
            );
            await t.ensureVisible(input);
            RenderEditable? render;
            void visit(RenderObject object) {
              if (object is RenderEditable) {
                render = object;
              } else {
                object.visitChildren(visit);
              }
            }

            visit(t.renderObject(input));
            expect(render, isNotNull);
            final painter = TextPainter(
              text: TextSpan(
                text: localized('74.8', locale),
                style: t.widget<EditableText>(input).style,
              ),
              textDirection: TextDirection.ltr,
              textScaler: TextScaler.linear(view.$2),
            )..layout();
            expect(painter.width, lessThanOrEqualTo(render!.size.width));
            painter.dispose();
            await changeUnit(t, 'cm');
            expect(dimensionText(t, 'length', 'cm'), '190');
            expect(store.saved!.items.first['length'], closeTo(190, 1e-10));
            expect(store.saved!.items.first['weight'], 20);
          },
        );
      }
      offlineWidgetTest(
        'Q4 $locale confirmation uses compact dimensions without changing quote',
        (t) async {
          setupView(t, const Size(375, 812), 2);
          final d = testDraft(step: 3, quote: true);
          for (final key in ['length', 'width', 'height']) {
            d.items.first[key] =
                (key == 'length'
                    ? 190
                    : key == 'width'
                    ? 50
                    : 60) /
                2.54;
          }
          d.items.first['dimension_unit'] = 'in';
          final store = MemoryBookingStorage(d);
          final api = TestBookingApi()
            ..quote = Map<String, dynamic>.from(d.quote!);
          await pumpBooking(t, storage: store, api: api, locale: locale);
          final expected =
              '${localized('74.8', locale)} × ${localized('19.69', locale)} × ${localized('23.62', locale)} in';
          expect(find.textContaining(expected), findsOneWidget);
          expect(find.textContaining('74.803149'), findsNothing);
          expect(
            find.text(switch (locale) {
              'en' => r'CA$123.45',
              'es' => '123,45\u00a0CA\$',
              _ => '123,45\u00a0\$ CA',
            }),
            findsOneWidget,
          );
          expect(store.saved!.quote, d.quote);
          expect(store.saved!.items, d.items);
        },
      );
    }
    offlineWidgetTest(
      'Q4 quote payload receives full precision rather than displayed rounding',
      (t) async {
        setupView(t, const Size(430, 932), 1);
        final d = testDraft();
        d.items.first['length'] = 190;
        final store = MemoryBookingStorage(d), api = TestBookingApi();
        await pumpBooking(t, storage: store, api: api);
        await changeUnit(t, 'in');
        await goToBookingPrice(t);
        final i = api.calls.indexOf('calculateDeliveryQuote');
        expect(i, greaterThanOrEqualTo(0));
        expect(
          api.payloads[i]['booking']['items'][0]['length'],
          190 * (1 / 2.54),
        );
        expect(api.payloads[i]['booking']['items'][0]['length'], isNot(74.8));
        expect(find.text('123,45\u00a0\$ CA'), findsOneWidget);
        expect(api.calls, isNot(contains('createDeliveryRequest')));
      },
    );
    offlineWidgetTest(
      'Q4 recreation never overwrites converted numeric precision',
      (t) async {
        setupView(t, const Size(430, 932), 1);
        final d = testDraft();
        d.items.first['length'] = 190;
        final store = MemoryBookingStorage(d), api = TestBookingApi();
        await pumpBooking(t, storage: store, api: api);
        await changeUnit(t, 'in');
        final exact = store.saved!.items.first['length'];
        await disposeBooking(t);
        await pumpBooking(t, storage: store, api: api);
        expect(dimensionText(t, 'length', 'in'), '74,8');
        expect(store.saved!.items.first['length'], exact);
      },
    );
    offlineWidgetTest(
      'Q4 edited decimal comma remains the entered numeric value',
      (t) async {
        setupView(t, const Size(430, 932), 1);
        final store = MemoryBookingStorage(testDraft(quote: true));
        await pumpBooking(t, storage: store, api: TestBookingApi());
        final input = dimensionField('length', 'cm');
        await t.ensureVisible(input);
        await t.enterText(input, '74,8123');
        expect(store.saved!.items.first['length'], 74.8123);
        expect(store.saved!.quote, isNull);
      },
    );
    offlineWidgetTest('Q4 unknown dimensions remain unknown', (t) async {
      setupView(t, const Size(430, 932), 1);
      final d = testDraft();
      d.items[0] = Map<String, dynamic>.from(d.items.first as Map);
      d.items.first['length'] = null;
      final store = MemoryBookingStorage(d);
      await pumpBooking(t, storage: store, api: TestBookingApi());
      expect(dimensionText(t, 'length', 'cm'), '');
      await changeUnit(t, 'in');
      expect(dimensionText(t, 'length', 'in'), '');
      expect(store.saved!.items.first['length'], isNull);
    });
    offlineWidgetTest(
      'Q4 a small nonzero dimension is never displayed as zero',
      (t) async {
        setupView(t, const Size(430, 932), 1);
        final d = testDraft();
        d.items.first['length'] = 0.001;
        final store = MemoryBookingStorage(d);
        await pumpBooking(
          t,
          storage: store,
          api: TestBookingApi(),
          locale: 'en',
        );
        final text = dimensionText(t, 'length', 'cm');
        expect(double.parse(text), 0.001);
        expect(store.saved!.items.first['length'], 0.001);
      },
    );
  });
}
