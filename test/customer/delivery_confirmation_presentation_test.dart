import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import '../helpers/booking_test_harness.dart';

class ConfirmationApi extends TestBookingApi {
  Completer<Map<String, dynamic>>? setup;
  Object? setupError, statusError;
  @override
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> data = const {},
  ]) async {
    const allowed = {
      'getBookingConfiguration',
      'getBookingDraft',
      'getBookingQuote',
      'getBookingCardStatus',
      'saveBookingDraft',
      'startBookingCardSetup',
      'createDeliveryRequest',
      'clearBookingDraft',
    };
    if (!allowed.contains(name)) {
      throw StateError('Unexpected fake operation: $name');
    }
    if (name == 'startBookingCardSetup') {
      calls.add(name);
      payloads.add(data);
      if (setupError != null) throw setupError!;
      return setup == null ? {'ready': true} : await setup!.future;
    }
    if (name == 'getBookingCardStatus' && statusError != null) {
      throw statusError!;
    }
    return super.call(name, data);
  }
}

const confirm = {
  'fr': 'Confirmer ma demande de livraison',
  'en': 'Confirm my delivery request',
  'es': 'Confirmar mi solicitud de entrega',
};
const notReady = {
  'fr': 'Préparation du moyen de paiement non confirmée.',
  'en': 'Payment method preparation is not confirmed.',
  'es': 'La preparación del método de pago no está confirmada.',
};
const ready = {
  'fr':
      'Moyen de paiement prêt pour la confirmation. Cela ne confirme ni une autorisation ni un paiement.',
  'en':
      'Payment method ready for confirmation. This does not confirm an authorization or a payment.',
  'es':
      'Método de pago listo para confirmar. Esto no confirma una autorización ni un pago.',
};
const unknown = {
  'fr': 'Date et heure non précisées',
  'en': 'Date and time not specified',
  'es': 'Fecha y hora no especificadas',
};
const requested = {
  'fr': 'Créneau demandé',
  'en': 'Requested time',
  'es': 'Horario solicitado',
};
const setupLabel = 'Enregistrer ma carte avec Stripe';
const checkLabel = 'J’ai terminé chez Stripe : vérifier';
String visibleText(WidgetTester t) =>
    t.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? '').join('\n');
Finder confirmation(String locale) =>
    find.widgetWithText(FilledButton, confirm[locale]!);
void honest(WidgetTester t) {
  final text = visibleText(t);
  for (final claim in [
    'Votre carte est enregistrée',
    'Carte enregistrée.',
    'Your card is saved',
    'Card saved.',
    'Stripe guarda tu tarjeta',
    'Tarjeta guardada.',
  ]) {
    expect(text, isNot(contains(claim)));
  }
}

Future<(MemoryBookingStorage, ConfirmationApi)> start(
  WidgetTester t, {
  String locale = 'fr',
  bool card = false,
  Size size = const Size(430, 932),
  double scale = 1,
  ConfirmationApi? api,
  MemoryBookingStorage? storage,
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
  final a = api ?? ConfirmationApi();
  a.cardReady = card;
  final s = storage ?? MemoryBookingStorage(testDraft(step: 3, quote: true));
  // The draft and fake server share the same quote, including its expiry.
  a.quote = Map<String, dynamic>.from(s.saved!.quote!);
  await pumpBooking(t, storage: s, api: a, locale: locale);
  expect(Firebase.apps, isEmpty);
  return (s, a);
}

void paragraphs(WidgetTester t) {
  for (final element in find.byType(RichText).evaluate()) {
    final r = element.renderObject;
    if (r is RenderParagraph) {
      expect(r.didExceedMaxLines, isFalse, reason: r.text.toPlainText());
      final rect = MatrixUtils.transformRect(
        r.getTransformTo(null),
        r.paintBounds,
      );
      expect(
        rect.left,
        greaterThanOrEqualTo(-0.1),
        reason: r.text.toPlainText(),
      );
      expect(
        rect.right,
        lessThanOrEqualTo(t.view.physicalSize.width + 0.1),
        reason: r.text.toPlainText(),
      );
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('N isolation: HTTP disabled; no Firebase app', () {
    expect(const bool.fromEnvironment('no_default_http_client'), isTrue);
    expect(() => http.Client(), throwsStateError);
    HttpOverrides.runZoned(
      () => expect(() => HttpClient(), throwsStateError),
      createHttpClient: (_) => throw StateError('No external HTTP'),
    );
    expect(Firebase.apps, isEmpty);
  });
  for (final locale in ['fr', 'en', 'es']) {
    for (final card in [false, true]) {
      for (final layout in [
        (375.0, 812.0, 1.0),
        (430.0, 932.0, 1.0),
        (1440.0, 900.0, 1.0),
        (375.0, 812.0, 2.0),
      ]) {
        testWidgets('N payment $locale ready=$card $layout', (t) async {
          await start(
            t,
            locale: locale,
            card: card,
            size: Size(layout.$1, layout.$2),
            scale: layout.$3,
          );
          honest(t);
          expect(
            find.text(card ? ready[locale]! : notReady[locale]!),
            findsOneWidget,
          );
          expect(
            t.widget<FilledButton>(confirmation(locale)).onPressed,
            card ? isNotNull : isNull,
          );
          await t.ensureVisible(confirmation(locale));
          await t.pumpAndSettle();
          paragraphs(t);
          expect(t.takeException(), isNull);
        });
      }
    }
  }
  testWidgets(
    'N setup loading then explicit ready response; no premature success',
    (t) async {
      final a = ConfirmationApi()..setup = Completer<Map<String, dynamic>>();
      await start(t, api: a);
      await t.ensureVisible(find.text(setupLabel));
      await t.pumpAndSettle();
      await t.tap(find.text(setupLabel));
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      honest(t);
      expect(find.text(ready['fr']!), findsNothing);
      expect(t.widget<FilledButton>(confirmation('fr')).onPressed, isNull);
      expect(a.calls.where((x) => x == 'startBookingCardSetup').length, 1);
      a.setup!.complete({'ready': true});
      await t.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text(ready['fr']!), findsOneWidget);
      expect(a.calls, isNot(contains('createDeliveryRequest')));
    },
  );
  testWidgets('N setup failure retains data and permits retry', (t) async {
    final a = ConfirmationApi()
      ..setupError = FirebaseFunctionsException(
        code: 'unavailable',
        message: 'SECRET_ERROR',
      );
    final (s, _) = await start(t, api: a);
    final contacts = jsonEncode(s.saved!.contacts),
        quote = jsonEncode(s.saved!.quote);
    await tapBooking(t, setupLabel);
    honest(t);
    expect(visibleText(t), contains('Cette opération n’a pas abouti.'));
    expect(visibleText(t), isNot(contains('SECRET_ERROR')));
    expect(find.text(notReady['fr']!), findsOneWidget);
    expect(jsonEncode(s.saved!.contacts), contacts);
    expect(jsonEncode(s.saved!.quote), quote);
    a.setupError = null;
    await tapBooking(t, setupLabel);
    expect(find.text(ready['fr']!), findsOneWidget);
  });
  testWidgets(
    'N no prepared method and failed status do not claim saved card',
    (t) async {
      final a = ConfirmationApi()
        ..statusError = FirebaseFunctionsException(
          code: 'unavailable',
          message: 'SIMULATED',
        );
      await start(t, api: a);
      await tapBooking(t, checkLabel);
      honest(t);
      expect(find.text(notReady['fr']!), findsOneWidget);
      expect(t.widget<FilledButton>(confirmation('fr')).onPressed, isNull);
    },
  );
  for (final locale in ['fr', 'en', 'es']) {
    for (final item in [
      (
        '2099-01-31T17:45:00Z',
        'janvier',
        'January',
        'enero',
        '2099',
        '12:45',
        'UTC-05:00',
      ),
      (
        '2099-03-01T02:15:00Z',
        'février',
        'February',
        'febrero',
        '2099',
        '21:15',
        'UTC-05:00',
      ),
      (
        '2100-01-01T02:15:00Z',
        'décembre',
        'December',
        'diciembre',
        '2099',
        '21:15',
        'UTC-05:00',
      ),
      (
        '2099-07-31T17:45:00Z',
        'juillet',
        'July',
        'julio',
        '2099',
        '13:45',
        'UTC-04:00',
      ),
      (
        '2099-01-31T12:45:00-05:00',
        'janvier',
        'January',
        'enero',
        '2099',
        '12:45',
        'UTC-05:00',
      ),
    ]) {
      testWidgets('N date $locale $item local Quebec display only', (t) async {
        final d = testDraft(step: 3, quote: true);
        d.data['requested_at'] = item.$1;
        final s = MemoryBookingStorage(d);
        await start(t, locale: locale, storage: s);
        final line = t
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data ?? '')
            .firstWhere((v) => v.startsWith(requested[locale]!));
        final month = locale == 'fr'
            ? item.$2
            : locale == 'en'
            ? item.$3
            : item.$4;
        expect(line, contains(month));
        expect(line, contains(item.$5));
        expect(line, contains(item.$6));
        expect(line, contains(item.$7));
        expect(line, isNot(contains(item.$1)));
        expect(s.saved!.data['requested_at'], item.$1);
        expect(
          DateTime.parse(item.$1).toLocal().timeZoneOffset,
          Duration(hours: item.$7 == 'UTC-04:00' ? -4 : -5),
          reason: 'This fixture requires an Eastern timezone runner.',
        );
      });
    }
    for (final source in [null, 'not-a-date', '']) {
      testWidgets('N unknown date $locale source=$source', (t) async {
        final d = testDraft(step: 3, quote: true);
        d.data['requested_at'] = source;
        final s = MemoryBookingStorage(d);
        await start(t, locale: locale, storage: s);
        expect(visibleText(t), contains(unknown[locale]!));
        expect(visibleText(t), isNot(contains('not-a-date')));
        expect(s.saved!.data['requested_at'], source);
      });
    }
  }
  testWidgets(
    'N navigation and reconstruction preserve date contacts and quote',
    (t) async {
      final (s, a) = await start(t, card: true);
      final raw = s.saved!.data['requested_at'];
      final q = jsonEncode(s.saved!.quote), c = jsonEncode(s.saved!.contacts);
      final initial = t
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? '')
          .firstWhere((x) => x.startsWith('Créneau demandé'));
      await tapBooking(t, 'Modifier mes coordonnées');
      await tapBooking(t, 'Vérifier et confirmer');
      honest(t);
      expect(visibleText(t), contains(initial));
      await disposeBooking(t);
      await pumpBooking(t, storage: s, api: a);
      expect(visibleText(t), contains(initial));
      honest(t);
      expect(s.saved!.data['requested_at'], raw);
      expect(jsonEncode(s.saved!.contacts), c);
      expect(jsonEncode(s.saved!.quote), q);
    },
  );
  testWidgets(
    'N confirmation payload unchanged and duplicate callback guarded',
    (t) async {
      final (s, a) = await start(t, card: true);
      final contacts = jsonEncode(s.saved!.contacts);
      final quoteId = s.saved!.quote!['quoteId'];
      a.delay = const Duration(milliseconds: 250);
      final callback = t.widget<FilledButton>(confirmation('fr')).onPressed!;
      callback();
      callback();
      await t.pumpAndSettle();
      final indices = <int>[
        for (var i = 0; i < a.calls.length; i++)
          if (a.calls[i] == 'createDeliveryRequest') i,
      ];
      expect(indices, hasLength(1));
      final payload = a.payloads[indices.single];
      expect(payload['quoteId'], quoteId);
      expect(jsonEncode(payload['contacts']), contacts);
      expect(payload.containsKey('customerTotal'), isFalse);
      expect(visibleText(t), contains('test_mission'));
    },
  );
}