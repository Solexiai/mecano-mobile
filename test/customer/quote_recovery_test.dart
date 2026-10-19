import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/booking_test_harness.dart';

const blocked = [
  'photo_policy_unconfigured',
  'capacity_unconfigured',
  'photo_category_unconfigured',
];
final photoBytes = File('assets/home/brand_logo.png').readAsBytesSync();
MemoryBookingStorage photoDraft({bool confirmed = false}) {
  final d = testDraft(step: 1);
  d.data['intake_mode'] = 'photo_assisted';
  d.items[0] = Map<String, dynamic>.from(d.items.first as Map);
  d.items.first.addAll({
    'identification_confirmed': confirmed,
    'special_handling': false,
    'photos': ['booking_photos/booking_test/test-draft/test-item/0.jpg'],
    'length': null,
    'width': null,
    'height': null,
    'weight': null,
  });
  return MemoryBookingStorage(d);
}

void main() {
  testWidgets(
    'price navigation keeps an unconfirmed photo actionable without calling the server',
    (t) async {
      final storage = photoDraft();
      storage.saved!.step = 0;
      final api = TestBookingApi();
      await pumpBooking(
        t,
        storage: storage,
        api: api,
        photoIntakeEnabled: true,
        photoLoader: (_) async => photoBytes,
      );
      await tapBooking(t, 'Voir mon prix');
      expect(storage.saved!.step, 1);
      expect(
        find.byKey(const ValueKey('photo-confirm-test-item')),
        findsOneWidget,
      );
      expect(api.calls, isNot(contains('reviewDeliveryLoad')));
      expect(api.calls, isNot(contains('calculateDeliveryQuote')));
      expect(storage.saved!.quote, isNull);
      expect(t.takeException(), isNull);
      await disposeBooking(t);
    },
  );
  testWidgets(
    'confirm category directly on price step before server review; save and send it',
    (t) async {
      final storage = photoDraft();
      final api = TestBookingApi();
      await pumpBooking(
        t,
        storage: storage,
        api: api,
        photoIntakeEnabled: true,
        photoLoader: (_) async => photoBytes,
      );
      final confirm = find.byKey(const ValueKey('photo-confirm-test-item'));
      expect(confirm, findsOneWidget);
      expect(api.calls, isNot(contains('reviewDeliveryLoad')));
      final category = find.byKey(const ValueKey('photo-category-test-item'));
      await t.ensureVisible(category);
      await t.tap(category);
      await t.pumpAndSettle();
      await t.tap(find.text('Fauteuil').last);
      await t.pumpAndSettle();
      await t.ensureVisible(confirm);
      await t.tap(confirm);
      await t.pumpAndSettle();
      expect(storage.saved!.items.first['identification_confirmed'], true);
      expect(storage.saved!.items.first['category'], 'armchair');
      await disposeBooking(t);
      await pumpBooking(
        t,
        storage: storage,
        api: api,
        photoIntakeEnabled: true,
        photoLoader: (_) async => photoBytes,
      );
      await tapBooking(t, 'Calculer mon devis officiel');
      final payload =
          api.payloads[api.calls.lastIndexOf(
                'calculateDeliveryQuote',
              )]['booking']
              as Map;
      expect(
        (payload['items'] as List).first['identification_confirmed'],
        true,
      );
      expect((payload['items'] as List).first['category'], 'armchair');
      expect((payload['items'] as List).first['weight'], isNull);
      await tapBooking(t, 'Continuer vers mes coordonnées');
      expect(storage.saved!.step, 2);
      expect(t.takeException(), isNull);
      await disposeBooking(t);
    },
  );
  testWidgets(
    'missing capacity configuration cannot prevent price-first calculation',
    (t) async {
      final storage = photoDraft(confirmed: true);
      final api = TestBookingApi()..reasons = [...blocked, ...blocked];
      api.quote = {...testQuote(), 'booking': null, 'assignmentPending': true};
      await pumpBooking(
        t,
        storage: storage,
        api: api,
        photoIntakeEnabled: true,
        photoLoader: (_) async => photoBytes,
      );
      await tapBooking(t, 'Calculer mon devis officiel');
      expect(
        find.textContaining(
          'Le devis en ligne est momentanément indisponible.',
        ),
        findsNothing,
      );
      expect(
        find.textContaining('capacités vérifiées des véhicules'),
        findsNothing,
      );
      expect(find.text('Demander une vérification'), findsNothing);
      expect(find.text('Vérifier à nouveau la disponibilité'), findsNothing);
      expect(
        api.calls.where((n) => n == 'calculateDeliveryQuote'),
        hasLength(1),
      );
      expect(api.calls, isNot(contains('reviewDeliveryLoad')));
      expect(api.calls, isNot(contains('createDeliveryRequest')));
      expect(storage.saved!.quote!['customerTotal'], 123.45);
      expect(find.text('Chauffeur à affecter après le devis'), findsOneWidget);
      expect(t.takeException(), isNull);
      await disposeBooking(t);
    },
  );
  testWidgets(
    'network error can retry real quote operation without losing draft',
    (t) async {
      final storage = photoDraft(confirmed: true);
      final api = TestBookingApi()
        ..quoteError = StateError('simulated network failure');
      await pumpBooking(
        t,
        storage: storage,
        api: api,
        photoIntakeEnabled: true,
        photoLoader: (_) async => photoBytes,
      );
      await tapBooking(t, 'Calculer mon devis officiel');
      expect(storage.saved!.quote, isNull);
      expect(storage.saved!.items.first['category'], 'sofa');
      api.quoteError = null;
      await tapBooking(t, 'Calculer mon devis officiel');
      expect(storage.saved!.quote, isNotNull);
      expect(api.calls, isNot(contains('createDeliveryRequest')));
      expect(t.takeException(), isNull);
      await disposeBooking(t);
    },
  );
  for (final locale in ['fr', 'en', 'es']) {
    for (final width in [375.0, 768.0, 1440.0]) {
      testWidgets('price recovery $locale $width text 200 percent', (t) async {
        t.view.physicalSize = Size(width, 1000);
        t.view.devicePixelRatio = 1;
        t.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        final storage = photoDraft();
        final api = TestBookingApi()..reasons = blocked;
        await pumpBooking(
          t,
          storage: storage,
          api: api,
          locale: locale,
          photoIntakeEnabled: true,
          photoLoader: (_) async => photoBytes,
        );
        final confirm = find.byKey(const ValueKey('photo-confirm-test-item'));
        expect(confirm, findsOneWidget);
        await t.ensureVisible(confirm);
        await t.tap(confirm);
        await t.pumpAndSettle();
        final calculate = {
          'fr': 'Calculer mon devis officiel',
          'en': 'Calculate my official quote',
          'es': 'Calcular mi presupuesto oficial',
        }[locale]!;
        await tapBooking(t, calculate);
        expect(storage.saved!.quote!['customerTotal'], 123.45);
        expect(
          api.calls.where((n) => n == 'calculateDeliveryQuote'),
          hasLength(1),
        );
        expect(api.calls, isNot(contains('reviewDeliveryLoad')));
        final prepare = {
          'fr': 'Continuer vers mes coordonnées',
          'en': 'Continue to my details',
          'es': 'Continuar a mis datos',
        }[locale]!;
        await tapBooking(t, prepare);
        expect(storage.saved!.step, 2);
        expect(t.takeException(), isNull);
        await disposeBooking(t);
      });
    }
  }
}
