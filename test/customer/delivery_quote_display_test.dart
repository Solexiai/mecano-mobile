import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/delivery/delivery_request_flow_screen.dart';
import '../helpers/booking_test_harness.dart';
import '../helpers/gps_offline_transport.dart';

const locales = ['fr', 'en', 'es'];
const total = ['1 234,50 \$ CA', 'CA\$1,234.50', '1.234,50 CA\$'];
const route = ['Distance routière', 'Road distance', 'Distancia por carretera'];
String spaces(String text) =>
    text.replaceAll('\u00a0', ' ').replaceAll('\u202f', ' ');
String texts(WidgetTester t) => spaces(
  t.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? '').join('\n'),
);

class QuoteApi extends TestBookingApi {
  @override
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> data = const {},
  ]) {
    const allowed = {
      'getBookingConfiguration',
      'getBookingDraft',
      'getBookingQuote',
      'getBookingCardStatus',
      'saveBookingDraft',
      'createDeliveryRequest',
      'clearBookingDraft',
    };
    if (!allowed.contains(name)) {
      throw StateError('Unexpected fake operation: $name');
    }
    return super.call(name, data);
  }
}

Future<(MemoryBookingStorage, QuoteApi)> start(
  WidgetTester t, {
  int step = 1,
  String locale = 'fr',
  Size size = const Size(430, 932),
  double scale = 1,
  Object? amount = 1234.5,
  Object? km = 10.0,
  bool omit = false,
  bool largeBreakdown = false,
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() async {
    await disposeBooking(t);
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
    t.platformDispatcher.clearTextScaleFactorTestValue();
  });
  final d = testDraft(step: step, quote: true);
  final q = Map<String, dynamic>.from(d.quote!);
  if (omit) {
    q.remove('customerTotal');
    q.remove('distanceKm');
  } else {
    q['customerTotal'] = amount;
    q['distanceKm'] = km;
  }
  q['breakdown'] = {
    'missionBaseValue': largeBreakdown ? 1234567.89 : 1000.0,
    'handlingFeesTotal': 1.5,
    'customerServiceFee': 5.25,
    'customerDiscountAmount': 2.5,
    'taxAmount': 230.25,
  }; // Deliberately independent fixture: the client must not recompute this total.
  d.data['quote'] = q;
  final storage = MemoryBookingStorage(d);
  final api = QuoteApi()..quote = Map<String, dynamic>.from(q);
  final before = jsonEncode(q);
  await pumpBooking(t, storage: storage, api: api, locale: locale);
  expect(jsonEncode(storage.saved!.quote), before);
  expect(jsonEncode(api.quote), before);
  expect(Firebase.apps, isEmpty);
  return (storage, api);
}

void layout(WidgetTester t) {
  for (final e in find.byType(RichText).evaluate()) {
    final p = e.renderObject;
    if (p is RenderParagraph) {
      expect(p.didExceedMaxLines, isFalse, reason: p.text.toPlainText());
      final r = MatrixUtils.transformRect(
        p.getTransformTo(null),
        p.paintBounds,
      );
      expect(r.left, greaterThanOrEqualTo(-0.1), reason: p.text.toPlainText());
      expect(
        r.right,
        lessThanOrEqualTo(t.view.physicalSize.width + 0.1),
        reason: p.text.toPlainText(),
      );
    }
  }
  expect(t.takeException(), isNull);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    expect(Firebase.apps, isEmpty);
    expect(rejectedRequests, isEmpty);
    expect(offlineTileRequests, isEmpty);
  });
  for (var l = 0; l < locales.length; l++) {
    for (final step in [1, 3]) {
      for (final size in [
        (375.0, 812.0, 1.0),
        (430.0, 932.0, 1.0),
        (1440.0, 900.0, 1.0),
        (375.0, 812.0, 2.0),
      ]) {
        offlineWidgetTest('S quote ${locales[l]} step=$step layout=$size', (
          t,
        ) async {
          final (s, a) = await start(
            t,
            step: step,
            locale: locales[l],
            size: Size(size.$1, size.$2),
            scale: size.$3,
          );
          expect(texts(t), contains(total[l]));
          expect(texts(t), contains('${route[l]} : 10 km'));
          expect(texts(t), isNot(contains('10.0 km')));
          final discount = ['-2,50 \$ CA', '-CA\$2.50', '-2,50 CA\$'][l];
          expect(texts(t), contains(discount));
          final amountFinder = find.byWidgetPredicate(
            (w) => w is Text && spaces(w.data ?? '') == total[l],
          );
          await t.ensureVisible(amountFinder);
          await t.pumpAndSettle();
          layout(t);
          expect(s.saved!.quote!['customerTotal'], 1234.5);
          expect(s.saved!.quote!['distanceKm'], 10.0);
          expect(a.calls, isNot(contains('calculateDeliveryQuote')));
          expect(a.calls, isNot(contains('createDeliveryRequest')));
        });
      }
    }
    for (final step in [1, 3]) {
      offlineWidgetTest('S large amount ${locales[l]} step=$step mobile 200%', (
        t,
      ) async {
        final (s, a) = await start(
          t,
          step: step,
          locale: locales[l],
          size: const Size(375, 812),
          scale: 2,
          amount: 1234567.89,
          km: 12345.67,
          largeBreakdown: true,
        );
        final expected = [
          '1 234 567,89 \$ CA',
          'CA\$1,234,567.89',
          '1.234.567,89 CA\$',
        ][l];
        expect(texts(t), contains(expected));
        final amountFinder = find
            .byWidgetPredicate(
              (w) => w is Text && spaces(w.data ?? '') == expected,
            )
            .first;
        await t.ensureVisible(amountFinder);
        await t.pumpAndSettle();
        layout(t);
        expect(s.saved!.quote!['customerTotal'], 1234567.89);
        expect(a.quote['distanceKm'], 12345.67);
      });
    }
    offlineWidgetTest('S money boundaries ${locales[l]} preserve source', (
      t,
    ) async {
      final cases = [
        (0.0, ['0,00 \$ CA', 'CA\$0.00', '0,00 CA\$']),
        (1.5, ['1,50 \$ CA', 'CA\$1.50', '1,50 CA\$']),
        (10.0, ['10,00 \$ CA', 'CA\$10.00', '10,00 CA\$']),
        (1234.5, total),
        (
          1234567.89,
          ['1 234 567,89 \$ CA', 'CA\$1,234,567.89', '1.234.567,89 CA\$'],
        ),
        (-1.5, ['-1,50 \$ CA', '-CA\$1.50', '-1,50 CA\$']),
      ];
      for (final c in cases) {
        final (s, a) = await start(t, locale: locales[l], amount: c.$1);
        expect(texts(t), contains(c.$2[l]));
        expect(s.saved!.quote!['customerTotal'], c.$1);
        expect(a.quote['customerTotal'], c.$1);
        await disposeBooking(t);
      }
    });
    offlineWidgetTest('S distance boundaries ${locales[l]} preserve source', (
      t,
    ) async {
      for (final c in [
        (0.0, ['0', '0', '0']),
        (0.5, ['0,5', '0.5', '0,5']),
        (1.0, ['1', '1', '1']),
        (10.0, ['10', '10', '10']),
        (10.5, ['10,5', '10.5', '10,5']),
        (12345.67, ['12 345,7', '12,345.7', '12.345,7']),
      ]) {
        final (s, a) = await start(t, locale: locales[l], km: c.$1);
        expect(texts(t), contains('${route[l]} : ${c.$2[l]} km'));
        expect(s.saved!.quote!['distanceKm'], c.$1);
        expect(a.quote['distanceKm'], c.$1);
        await disposeBooking(t);
      }
    });
    offlineWidgetTest(
      'S absent and invalid display values ${locales[l]} are not invented',
      (t) async {
        for (final missing in [true, false]) {
          final (s, _) = await start(
            t,
            locale: locales[l],
            omit: missing,
            amount: null,
            km: null,
          );
          expect(texts(t), contains('${route[l]} : —'));
          expect(find.text('—'), findsOneWidget);
          expect(s.saved!.quote!.containsKey('customerTotal'), !missing);
          expect(s.saved!.quote!.containsKey('distanceKm'), !missing);
          expect(t.takeException(), isNull);
          await disposeBooking(t);
        }
        final (s, _) = await start(
          t,
          locale: locales[l],
          km: -5,
          amount: 'invalid',
        );
        expect(texts(t), contains('${route[l]} : —'));
        expect(find.text('—'), findsOneWidget);
        expect(s.saved!.quote!['distanceKm'], -5);
        expect(s.saved!.quote!['customerTotal'], 'invalid');
        expect(t.takeException(), isNull);
      },
    );
  }
  offlineWidgetTest(
    'S locale switches rebuild the real flow without changing quote or inputs',
    (t) async {
      final d = testDraft(step: 3, quote: true);
      d.data['quote']['customerTotal'] = 1234.5;
      d.data['quote']['distanceKm'] = 10.5;
      final s = MemoryBookingStorage(d),
          a = QuoteApi()..quote = Map<String, dynamic>.from(d.quote!);
      final before = jsonEncode(d.quote),
          contacts = jsonEncode(d.contacts),
          load = jsonEncode(d.load);
      final auth = BookingTestAuth(), language = ValueNotifier('fr');
      SharedPreferences.setMockInitialValues({});
      addTearDown(() async {
        await disposeBooking(t);
        language.dispose();
        auth.dispose();
      });
      await t.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LocaleProvider>(
              create: (_) => LocaleProvider(),
            ),
            ChangeNotifierProvider<FirebaseAuthProvider>.value(value: auth),
          ],
          child: MaterialApp(
            home: ValueListenableBuilder<String>(
              valueListenable: language,
              builder: (_, locale, __) =>
                  DeliveryRequestFlowScreen(locale: locale, api: a, storage: s),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final state = t.state(find.byType(DeliveryRequestFlowScreen));
      for (var l = 0; l < 3; l++) {
        language.value = locales[l];
        await t.pumpAndSettle();
        expect(t.state(find.byType(DeliveryRequestFlowScreen)), same(state));
        expect(texts(t), contains(total[l]));
        expect(
          texts(t),
          contains("${route[l]} : ${l == 1 ? '10.5' : '10,5'} km"),
        );
        expect(jsonEncode(s.saved!.quote), before);
        expect(jsonEncode(s.saved!.contacts), contacts);
        expect(jsonEncode(s.saved!.load), load);
      }
      expect(a.calls, isNot(contains('calculateDeliveryQuote')));
      expect(a.calls, isNot(contains('createDeliveryRequest')));
    },
  );
  offlineWidgetTest(
    'S price details confirmation reconstruction preserve exact quote and fake submission',
    (t) async {
      final (s, a) = await start(t, step: 3, km: 10.54);
      final q = jsonEncode(s.saved!.quote),
          contacts = jsonEncode(s.saved!.contacts),
          load = jsonEncode(s.saved!.load),
          stops = jsonEncode(s.saved!.stops);
      await tapBooking(t, 'Modifier mes coordonnées');
      await tapBooking(t, 'Vérifier et confirmer');
      expect(texts(t), contains(total.first));
      expect(texts(t), contains('Distance routière : 10,5 km'));
      expect(jsonEncode(s.saved!.quote), q);
      await disposeBooking(t);
      await pumpBooking(t, storage: s, api: a);
      expect(jsonEncode(s.saved!.quote), q);
      final button = find.widgetWithText(
        FilledButton,
        'Confirmer ma demande de livraison',
      );
      final callback = t.widget<FilledButton>(button).onPressed!;
      callback();
      callback();
      await t.pumpAndSettle();
      final index = a.calls.indexOf('createDeliveryRequest');
      expect(index, greaterThanOrEqualTo(0));
      expect(a.calls.where((x) => x == 'createDeliveryRequest'), hasLength(1));
      final payload = a.payloads[index];
      expect(payload['quoteId'], 'test_quote');
      expect(jsonEncode(payload['contacts']), contacts);
      expect(jsonEncode(payload['booking']), load);
      expect(jsonEncode(payload['stops']), stops);
      for (final key in [
        'customerTotal',
        'distanceKm',
        'customer_total_minor',
        'amount',
      ]) {
        expect(payload.containsKey(key), isFalse);
      }
      expect(jsonEncode(a.quote), q);
      final saves = [
        for (var i = 0; i < a.calls.length; i++)
          if (a.calls[i] == 'saveBookingDraft') a.payloads[i],
      ];
      expect(saves, isNotEmpty);
      for (final save in saves) {
        expect(jsonEncode(save['draft']['quote']), q);
      }
      expect(texts(t), contains('test_mission'));
    },
  );
}
