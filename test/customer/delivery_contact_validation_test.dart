import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import '../helpers/booking_test_harness.dart';

class _NoNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw StateError('M audit: external HTTP forbidden');
}

class _ContactsApi extends TestBookingApi {
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
      throw StateError('Unexpected operation during contact tests: $name');
    }
    return super.call(name, data);
  }
}

Finder field(String name) => find.byWidgetPredicate(
  (w) =>
      w is TextFormField &&
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.endsWith('-$name'),
);
TextField inputOf(WidgetTester t, String name) => t.widget<TextField>(
  find.descendant(of: field(name), matching: find.byType(TextField)),
);
String valueOf(WidgetTester t, String name) => t
    .widget<TextField>(
      find.descendant(of: field(name), matching: find.byType(TextField)),
    )
    .controller!
    .text;
Future<void> enter(WidgetTester t, String name, String text) async {
  await t.ensureVisible(field(name));
  await t.enterText(field(name), text);
  await t.pumpAndSettle();
}

Future<(MemoryBookingStorage, _ContactsApi)> start(
  WidgetTester t, {
  String locale = 'fr',
  Size size = const Size(430, 932),
  double scale = 1,
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
  final api = _ContactsApi();
  final store =
      storage ?? MemoryBookingStorage(testDraft(step: 2, quote: true));
  // The remote stub returns the same quote, including its original expiry.
  // Two independent DateTime.now() calls are not the same server snapshot.
  if (store.saved?.quote != null) api.quote = store.saved!.quote!;
  await pumpBooking(t, storage: store, api: api, locale: locale);
  expect(Firebase.apps, isEmpty);
  return (store, api);
}

// Screen 6 of 7 since 2026-10-24: one "Suivant" button.
const review = {'fr': 'Suivant', 'en': 'Next', 'es': 'Siguiente'};
const invalid = {
  'fr': 'Téléphone invalide',
  'en': 'Invalid phone',
  'es': 'Teléfono inválido',
};
const requiredText = {
  'fr': 'Qui le chauffeur appelle ?',
  'en': 'Who does the driver call?',
  'es': '¿A quién llama el conductor?',
};
const hints = {
  'fr':
      'Au moins 8 chiffres. Espaces, parenthèses et tirets permis. Maximum 25 caractères, ou 26 avec + au début.',
  'en':
      'At least 8 digits. Spaces, parentheses and hyphens are allowed. Up to 25 characters, or 26 with a leading +.',
  'es':
      'Al menos 8 dígitos. Se permiten espacios, paréntesis y guiones. Máximo 25 caracteres, o 26 con + al inicio.',
};
String invalidFor(String locale) => '${invalid[locale]}\n${hints[locale]}';
void assertParagraphs(WidgetTester t, Finder scope) {
  for (final e
      in find
          .descendant(of: scope, matching: find.byType(RichText))
          .evaluate()) {
    final render = e.renderObject;
    if (render is RenderParagraph) {
      expect(
        render.didExceedMaxLines,
        isFalse,
        reason: render.text.toPlainText(),
      );
      final rect = MatrixUtils.transformRect(
        render.getTransformTo(null),
        render.paintBounds,
      );
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(t.view.physicalSize.width));
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('M isolation: default HTTP disabled and IO transport denied', () {
    expect(const bool.fromEnvironment('no_default_http_client'), isTrue);
    expect(() => http.Client(), throwsA(isA<StateError>()));
    HttpOverrides.runZoned(() {
      expect(() => HttpClient(), throwsA(isA<StateError>()));
    }, createHttpClient: _NoNetwork().createHttpClient);
    expect(Firebase.apps, isEmpty);
  });
  for (final name in ['pickup_phone', 'dropoff_phone']) {
    for (final v in [
      '--------',
      '        ',
      '()----()',
      '1234567',
      '1-------',
      '1234ABCD',
      '514.555.0100',
    ]) {
      testWidgets('M rejects $name [$v] before confirmation', (t) async {
        final (store, api) = await start(t);
        await enter(t, name, v);
        await tapBooking(t, review['fr']!);
        expect(store.saved!.step, 2);
        expect(
          find.text(v.trim().isEmpty ? 'Champ requis' : invalidFor('fr')),
          findsOneWidget,
        );
        expect(valueOf(t, name), v);
        expect(api.calls, isNot(contains('createDeliveryRequest')));
        expect(store.saved!.quote!['quoteId'], 'test_quote');
      });
    }
  }
  for (final name in [
    'pickup_name',
    'pickup_phone',
    'dropoff_name',
    'dropoff_phone',
  ]) {
    testWidgets('M required $name then correction permits progression', (
      t,
    ) async {
      final (store, api) = await start(t);
      await enter(t, name, '');
      await tapBooking(t, review['fr']!);
      expect(find.text('Champ requis'), findsOneWidget);
      expect(store.saved!.step, 2);
      await enter(
        t,
        name,
        name.endsWith('phone') ? '+33 1 23 45 67 89' : 'Contact fictif',
      );
      await tapBooking(t, review['fr']!);
      expect(store.saved!.step, 3);
      expect(find.text('Champ requis'), findsNothing);
      expect(api.calls, isNot(contains('createDeliveryRequest')));
    });
  }
  for (final v in [
    '12345678',
    '514-555-0100',
    '(514) 555 0100',
    '+33 1 23 45 67 89',
    '1234567890123456789012345',
    '+1234567890123456789012345',
  ]) {
    testWidgets('M accepts existing server phone format [$v] unchanged', (
      t,
    ) async {
      final (store, _) = await start(t);
      for (final name in ['pickup_phone', 'dropoff_phone']) {
        await enter(t, name, v);
        expect(valueOf(t, name), v);
      }
      await tapBooking(t, review['fr']!);
      expect(store.saved!.step, 3);
      expect(store.saved!.contacts['pickup_phone'], v);
      expect(store.saved!.contacts['dropoff_phone'], v);
    });
  }
  testWidgets('M phone counter follows 25 plus optional leading sign', (
    t,
  ) async {
    await start(t);
    await enter(t, 'pickup_phone', '12345678');
    expect(inputOf(t, 'pickup_phone').maxLength, 25);
    expect(find.text('8/25'), findsOneWidget);
    await enter(t, 'pickup_phone', '+12345678');
    expect(inputOf(t, 'pickup_phone').maxLength, 26);
    expect(find.text('9/26'), findsOneWidget);
    expect(inputOf(t, 'pickup_name').maxLength, 120);
    expect(inputOf(t, 'instructions').maxLength, 1200);
  });
  for (final v in [
    '12345678901234567890123456',
    '+12345678901234567890123456',
  ]) {
    testWidgets('M overlength paste [$v] remains editable and is rejected', (
      t,
    ) async {
      final (store, _) = await start(t);
      await enter(t, 'pickup_phone', v);
      expect(valueOf(t, 'pickup_phone'), v);
      await tapBooking(t, review['fr']!);
      expect(store.saved!.step, 2);
      expect(find.text(invalidFor('fr')), findsOneWidget);
      expect(store.saved!.contacts['pickup_phone'], v);
      await enter(t, 'pickup_phone', '514 555 0100');
      await tapBooking(t, review['fr']!);
      expect(store.saved!.step, 3);
    });
  }
  testWidgets('M name and optional instruction existing limits remain', (
    t,
  ) async {
    final (store, _) = await start(t);
    await enter(t, 'pickup_name', 'A');
    await enter(t, 'dropoff_name', 'B' * 120);
    await enter(t, 'instructions', '');
    await tapBooking(t, review['fr']!);
    expect(store.saved!.step, 3);
    await tapBookingKeyIfShown(t, 'recap-edit-contacts');
    await enter(t, 'pickup_name', 'A' * 121);
    expect(valueOf(t, 'pickup_name'), 'A' * 120);
    await enter(t, 'instructions', 'I' * 1201);
    expect(valueOf(t, 'instructions'), 'I' * 1200);
    await tapBooking(t, review['fr']!);
    expect(store.saved!.step, 3);
  });
  testWidgets(
    'M correction navigation and widget restoration preserve contacts and quote',
    (t) async {
      final (store, api) = await start(t);
      final quote = store.saved!.quote, items = store.saved!.items;
      await enter(t, 'pickup_phone', '--------');
      await tapBooking(t, review['fr']!);
      expect(store.saved!.step, 2);
      await enter(t, 'pickup_phone', '+33 1 23 45 67 89');
      await enter(t, 'instructions', 'Instructions fictives conservées');
      await tapBookingKeyIfShown(t, 'booking-back');
      expect(store.saved!.step, 1);
      await tapBooking(t, 'Réserver à ce prix');
      expect(valueOf(t, 'pickup_phone'), '+33 1 23 45 67 89');
      expect(valueOf(t, 'instructions'), 'Instructions fictives conservées');
      await disposeBooking(t);
      await pumpBooking(t, storage: store, api: api);
      expect(valueOf(t, 'pickup_phone'), '+33 1 23 45 67 89');
      expect(store.saved!.quote, quote);
      expect(store.saved!.items, items);
      await tapBooking(t, review['fr']!);
      expect(store.saved!.step, 3);
      expect(api.calls, isNot(contains('calculateDeliveryQuote')));
    },
  );
  testWidgets(
    'M valid contact payload reaches only simulated creation unchanged',
    (t) async {
      final (store, api) = await start(t);
      const phone = '+33 (1) 23-45-67-89';
      await enter(t, 'pickup_phone', phone);
      await enter(t, 'dropoff_phone', '(514) 555-0100');
      await enter(t, 'instructions', 'Contact fictif uniquement');
      final contacts = store.saved!.contacts, quote = store.saved!.quote;
      await tapBooking(t, review['fr']!);
      expect(store.saved!.quote, quote);
      await tapBooking(t, 'Confirmer ma demande de livraison');
      final indexes = [
        for (var i = 0; i < api.calls.length; i++)
          if (api.calls[i] == 'createDeliveryRequest') i,
      ];
      expect(indexes, hasLength(1));
      expect(api.payloads[indexes.single]['contacts'], contacts);
      expect(api.payloads[indexes.single]['quoteId'], 'test_quote');
      expect(store.saved!.data['missionId'], 'test_mission');
      expect(Firebase.apps, isEmpty);
    },
  );
  for (final locale in ['fr', 'en', 'es']) {
    for (final config in [
      (const Size(375, 812), 1.0),
      (const Size(430, 932), 1.0),
      (const Size(1440, 900), 1.0),
      (const Size(375, 812), 2.0),
      (const Size(430, 932), 2.0),
    ]) {
      final size = config.$1, scale = config.$2;
      testWidgets('M $locale $size text $scale messages fit', (t) async {
        final (store, _) = await start(
          t,
          locale: locale,
          size: size,
          scale: scale,
        );
        expect(find.text(requiredText[locale]!), findsOneWidget);
        for (final name in ['pickup_phone', 'dropoff_phone']) {
          await enter(t, name, '--------');
          expect(inputOf(t, name).decoration!.helperText, hints[locale]);
          assertParagraphs(t, field(name));
        }
        await tapBooking(t, review[locale]!);
        expect(find.text(invalidFor(locale)), findsNWidgets(2));
        expect(store.saved!.step, 2);
        for (final name in [
          'pickup_name',
          'pickup_phone',
          'dropoff_name',
          'dropoff_phone',
          'instructions',
        ]) {
          await t.ensureVisible(field(name));
          await t.pumpAndSettle();
          assertParagraphs(t, field(name));
          final labelFinder = find.byKey(ValueKey('contact-label-$name'));
          assertParagraphs(t, labelFinder);
          final labelRect = t.getRect(labelFinder);
          expect(
            labelRect.bottom,
            lessThanOrEqualTo(t.getRect(field(name)).top),
          );
          final box = t.getRect(field(name));
          expect(box.left, greaterThanOrEqualTo(0));
          expect(box.right, lessThanOrEqualTo(size.width));
        }
        expect(
          t.getRect(field('pickup_phone')).bottom,
          lessThanOrEqualTo(t.getRect(field('dropoff_name')).top),
        );
        expect(t.takeException(), isNull);
        await enter(t, 'pickup_phone', '+33 1 23 45 67 89');
        await enter(t, 'dropoff_phone', '514 555 0100');
        await tapBooking(t, review[locale]!);
        expect(store.saved!.step, 3);
        expect(t.takeException(), isNull);
      });
    }
  }
}
