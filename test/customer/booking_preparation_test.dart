import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/booking_test_harness.dart';

class PreparationApi extends TestBookingApi {
  bool booking = false, payment = false, configError = false;
  @override
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> data = const {},
  ]) async {
    final result = await super.call(name, data);
    if (name == 'getBookingConfiguration') {
      if (configError) throw StateError('simulated configuration failure');
      return {
        ...result,
        'availability': {
          'booking_enabled': booking,
          'payment_enabled': payment,
          'technical_error': false,
        },
      };
    }
    return result;
  }
}

void main() {
  for (final signed in [false, true]) {
    testWidgets(
      'closed booking permits details and summary without quote signed=$signed',
      (t) async {
        final storage = MemoryBookingStorage(testDraft(step: 1));
        final api = PreparationApi()..configurationAvailable = false;
        await pumpBooking(
          t,
          storage: storage,
          api: api,
          auth: BookingTestAuth(signed: signed),
        );
        expect(find.text('Vérifier à nouveau la disponibilité'), findsNothing);
        expect(
          api.calls.where((n) => n == 'getBookingConfiguration'),
          hasLength(1),
        );
        await tapBooking(t, 'Continuer à préparer ma demande');
        expect(storage.saved!.step, 2);
        await tapBooking(t, 'Consulter le résumé');
        expect(storage.saved!.step, 3);
        expect(
          find.textContaining('Aucune réservation confirmée'),
          findsWidgets,
        );
        expect(
          t
              .widget<FilledButton>(
                find.widgetWithText(
                  FilledButton,
                  'Confirmer ma demande de livraison',
                ),
              )
              .onPressed,
          isNull,
        );
        await tapBooking(t, 'Modifier mes coordonnées');
        expect(storage.saved!.contacts['pickup_phone'], '+15145550100');
        await disposeBooking(t);
        await pumpBooking(
          t,
          storage: storage,
          api: api,
          auth: BookingTestAuth(signed: signed),
        );
        expect(storage.saved!.step, 2);
        expect(find.text('+15145550100'), findsOneWidget);
        for (final n in [
          'startBookingCardSetup',
          'createDeliveryRequest',
          'getBookingCardStatus',
          'calculateDeliveryQuote',
        ]) {
          expect(api.calls, isNot(contains(n)));
        }
        expect(t.takeException(), isNull);
        await disposeBooking(t);
      },
    );
  }
  testWidgets(
    'technical configuration error is distinct and draft remains usable',
    (t) async {
      final api = PreparationApi()..configError = true;
      await pumpBooking(
        t,
        storage: MemoryBookingStorage(testDraft(step: 1)),
        api: api,
      );
      expect(
        find.textContaining('Impossible de vérifier la disponibilité'),
        findsNothing,
      );
      expect(
        find.textContaining('La réservation est indisponible'),
        findsNothing,
      );
      await tapBooking(t, 'Continuer à préparer ma demande');
      expect(find.text('Nom au ramassage'), findsOneWidget);
      expect(
        find.textContaining('Impossible de vérifier la disponibilité'),
        findsOneWidget,
      );
      await disposeBooking(t);
    },
  );
  testWidgets(
    'payment disabled prevents setup and confirmation with ready card and unchanged quote',
    (t) async {
      final api = PreparationApi()..booking = true;
      final storage = MemoryBookingStorage(testDraft(step: 3, quote: true));
      await pumpBooking(t, storage: storage, api: api);
      expect(
        find.textContaining('Le paiement est temporairement indisponible'),
        findsOneWidget,
      );
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(
                FilledButton,
                'Confirmer ma demande de livraison',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(api.calls, isNot(contains('getBookingCardStatus')));
      expect(api.calls, isNot(contains('startBookingCardSetup')));
      expect(api.calls, isNot(contains('createDeliveryRequest')));
      expect(storage.saved!.quote!['customerTotal'], 123.45);
      await disposeBooking(t);
    },
  );
  testWidgets('quote refusal preserves reason and enables draft preparation', (
    t,
  ) async {
    final api = PreparationApi()
      ..quoteError = FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'SIMULATED_ZONE_MISSING',
        details: {'quote_reason': 'service_area_unconfigured'},
      );
    await pumpBooking(
      t,
      storage: MemoryBookingStorage(testDraft(step: 1)),
      api: api,
    );
    await tapBooking(t, 'Calculer mon devis officiel');
    expect(
      find.textContaining('Le devis en ligne est momentanément indisponible.'),
      findsOneWidget,
    );
    expect(api.calls.where((n) => n == 'calculateDeliveryQuote'), hasLength(1));
    expect(api.calls, isNot(contains('reviewDeliveryLoad')));
    await tapBooking(t, 'Continuer à préparer ma demande');
    await tapBooking(t, 'Consulter le résumé');
    expect(api.calls, isNot(contains('createDeliveryRequest')));
    await disposeBooking(t);
  });
  for (final size in [
    const Size(375, 812),
    const Size(430, 932),
    const Size(768, 1024),
    const Size(1440, 900),
  ]) {
    for (final locale in ['fr', 'en', 'es']) {
      testWidgets('preparation layout $size $locale', (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = size;
        t.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        for (final step in [1, 2, 3]) {
          await pumpBooking(
            t,
            storage: MemoryBookingStorage(testDraft(step: step)),
            api: PreparationApi()..configurationAvailable = false,
            locale: locale,
          );
          expect(t.takeException(), isNull);
          await disposeBooking(t);
        }
      });
    }
  }
}
