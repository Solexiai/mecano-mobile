// Local widget evidence only: the API response and amount below are fixtures.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/services/booking/booking_draft.dart';
import '../helpers/booking_test_harness.dart';

class PriceFirstApi extends TestBookingApi {
  String? refusal;
  bool configurationFails = false;
  bool internalAuthorized = false;
  @override
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> data = const {},
  ]) async {
    if (name == 'reviewDeliveryLoad') {
      throw StateError('Price must not require a capacity review');
    }
    if (name == 'getBookingConfiguration') {
      calls.add(name);
      payloads.add(data);
      if (configurationFails) {
        throw StateError('SIMULATED_CONFIGURATION_UNAVAILABLE');
      }
      return {
        'policy': null,
        'internal_test_request': internalAuthorized,
        'availability': {
          'booking_enabled': false,
          'payment_enabled': false,
          'technical_error': false,
        },
      };
    }
    if (name == 'calculateDeliveryQuote') {
      calls.add(name);
      payloads.add(data);
      if (refusal != null) {
        throw FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'SIMULATED',
          details: {'quote_reason': refusal},
        );
      }
      return quote;
    }
    if (name == 'createDeliveryRequest') {
      calls.add(name);
      payloads.add(data);
      return {'missionId': 'test_mission', 'internalTest': internalAuthorized};
    }
    return super.call(name, data);
  }
}

BookingDraft photoDraft() {
  final draft = testDraft(step: 1);
  draft.data['intake_mode'] = 'photo_assisted';
  draft.items[0] = Map<String, dynamic>.from(draft.items[0] as Map);
  draft.items[0].addAll({
    'length': null,
    'width': null,
    'height': null,
    'weight': null,
    'photos': ['booking_photos/booking_test/${draft.id}/test-item/0.jpg'],
    'identification_confirmed': true,
    'special_handling': false,
  });
  return draft;
}

PriceFirstApi api() =>
    PriceFirstApi()
      ..quote = {...testQuote(), 'booking': null, 'assignmentPending': true};

void main() {
  testWidgets(
    'only an authorized internal test account can submit the quoted request without payment',
    (tester) async {
      final a = api()..internalAuthorized = true;
      final storage = MemoryBookingStorage(photoDraft());
      await pumpBooking(
        tester,
        storage: storage,
        api: a,
        photoIntakeEnabled: true,
      );
      await tapBooking(tester, 'Calculer mon prix officiel');
      await tapBooking(tester, 'Continuer vers mes coordonnées');
      await tapBooking(tester, 'Consulter le résumé');
      await tapBooking(tester, 'Créer la demande de test — sans paiement');
      expect(
        a.calls.where((name) => name == 'createDeliveryRequest'),
        hasLength(1),
      );
      final sent = a.payloads[a.calls.indexOf('createDeliveryRequest')];
      expect(sent['quoteId'], 'test_quote');
      expect(sent.containsKey('customerTotal'), isFalse);
      expect(a.calls, isNot(contains('startBookingCardSetup')));
      expect(a.calls, isNot(contains('getBookingCardStatus')));
      expect(storage.saved!.data['missionId'], 'test_mission');
      expect(tester.takeException(), isNull);
      await disposeBooking(tester);
    },
  );
  testWidgets(
    'ordinary customer sees the price but no internal-test or active payment shortcut',
    (tester) async {
      final a = api();
      final draft = photoDraft();
      draft.data['quote'] = a.quote;
      draft.step = 3;
      await pumpBooking(
        tester,
        storage: MemoryBookingStorage(draft),
        api: a,
        photoIntakeEnabled: true,
      );
      expect(find.text('Total officiel, taxes comprises'), findsOneWidget);
      expect(
        find.text('Créer la demande de test — sans paiement'),
        findsNothing,
      );
      final confirm = find.widgetWithText(
        FilledButton,
        'Confirmer ma demande de livraison',
      );
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      expect(a.calls, isNot(contains('createDeliveryRequest')));
      expect(a.calls, isNot(contains('startBookingCardSetup')));
      await disposeBooking(tester);
    },
  );
  testWidgets(
    'official price is requested before any capacity/driver review with booking and payment closed',
    (tester) async {
      final a = api();
      final storage = MemoryBookingStorage(photoDraft());
      await pumpBooking(
        tester,
        storage: storage,
        api: a,
        photoIntakeEnabled: true,
      );
      await tapBooking(tester, 'Calculer mon prix officiel');
      expect(a.calls.where((n) => n == 'calculateDeliveryQuote').length, 1);
      expect(a.calls, isNot(contains('reviewDeliveryLoad')));
      expect(a.calls, isNot(contains('startBookingCardSetup')));
      expect(a.calls, isNot(contains('createDeliveryRequest')));
      final request = a.payloads[a.calls.indexOf('calculateDeliveryQuote')];
      expect(request['quotePurpose'], 'price_before_assignment');
      expect((request['booking'] as Map)['items'][0]['weight'], isNull);
      expect(storage.saved!.quote!['customerTotal'], 123.45);
      expect(find.text('Total officiel, taxes comprises'), findsOneWidget);
      expect(find.text('Chauffeur à affecter après le calcul du prix'), findsOneWidget);
      expect(find.textContaining('Véhicule recommandé'), findsNothing);
      expect(
        find.textContaining('La réservation est indisponible'),
        findsNothing,
      );
      await tapBooking(tester, 'Continuer vers mes coordonnées');
      expect(storage.saved!.step, 2);
      await disposeBooking(tester);
    },
  );
  testWidgets('booking configuration failure does not prevent a price', (
    tester,
  ) async {
    final a = api()..configurationFails = true;
    await pumpBooking(
      tester,
      storage: MemoryBookingStorage(photoDraft()),
      api: a,
      photoIntakeEnabled: true,
    );
    await tapBooking(tester, 'Calculer mon prix officiel');
    expect(find.text('Total officiel, taxes comprises'), findsOneWidget);
    expect(a.calls, isNot(contains('reviewDeliveryLoad')));
    await disposeBooking(tester);
  });
  testWidgets(
    'refresh restores the server quote independently of a booking snapshot',
    (tester) async {
      final a = api();
      final storage = MemoryBookingStorage(photoDraft());
      await pumpBooking(
        tester,
        storage: storage,
        api: a,
        photoIntakeEnabled: true,
      );
      await tapBooking(tester, 'Calculer mon prix officiel');
      await disposeBooking(tester);
      await pumpBooking(
        tester,
        storage: storage,
        api: a,
        photoIntakeEnabled: true,
      );
      expect(a.calls, contains('getBookingQuote'));
      expect(find.text('Total officiel, taxes comprises'), findsOneWidget);
      expect(find.text('Chauffeur à affecter après le calcul du prix'), findsOneWidget);
      await disposeBooking(tester);
    },
  );
  testWidgets(
    'real pricing prerequisite is explained without blaming driver availability',
    (tester) async {
      final a = api()..refusal = 'pricing_category_required';
      final storage = MemoryBookingStorage(photoDraft());
      await pumpBooking(
        tester,
        storage: storage,
        api: a,
        photoIntakeEnabled: true,
      );
      await tapBooking(tester, 'Calculer mon prix officiel');
      expect(
        find.textContaining('La grille tarifaire nécessite'),
        findsOneWidget,
      );
      expect(find.textContaining('capacités vérifiées'), findsNothing);
      expect(storage.saved!.quote, isNull);
      expect(find.text('Réessayer le calcul du prix'), findsOneWidget);
      await disposeBooking(tester);
    },
  );
  for (final locale in ['fr', 'en', 'es']) {
    testWidgets('price before driver is rendered at mobile width in $locale', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final a = api();
      await pumpBooking(
        tester,
        storage: MemoryBookingStorage(photoDraft()),
        api: a,
        locale: locale,
        photoIntakeEnabled: true,
      );
      final label = locale == 'fr'
          ? 'Calculer mon prix officiel'
          : locale == 'en'
          ? 'Calculate my official price'
          : 'Calcular mi precio oficial';
      await tapBooking(tester, label);
      expect(tester.takeException(), isNull);
      expect(a.calls.where((n) => n == 'calculateDeliveryQuote').length, 1);
      expect(a.calls, isNot(contains('reviewDeliveryLoad')));
      await disposeBooking(tester);
    });
  }
}
