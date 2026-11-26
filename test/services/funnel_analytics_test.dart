// Mesure du parcours (2026-11-22) : les événements partent sans données
// personnelles, et une même étape n'est comptée qu'une fois de suite.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:movik_connect/services/funnel/funnel_analytics.dart';

void main() {
  test('booking_step : une fois par changement d’étape', () {
    FunnelAnalytics.sentForTest.clear();
    FunnelAnalytics.bookingStep(101);
    FunnelAnalytics.bookingStep(101);
    FunnelAnalytics.bookingStep(102);
    FunnelAnalytics.event('price_shown');
    expect(
      FunnelAnalytics.sentForTest.map((e) => e.$1),
      ['booking_step', 'booking_step', 'price_shown'],
    );
    expect(FunnelAnalytics.sentForTest.map((e) => e.$2), [
      {'step': 101},
      {'step': 102},
      <String, Object>{},
    ]);
  });

  // Pixel Meta (2026-11-26) : les moments qui comptent pour les publicités.
  group('metaEventFor', () {
    (String, Map<String, Object>)? meta(
      String name, [
      Map<String, Object> params = const {},
    ]) => FunnelAnalytics.metaEventFor(name, params);

    // Un record ne compare pas ses Map par contenu : on compare champ par champ.
    void expectMeta(
      (String, Map<String, Object>)? actual,
      String name,
      Map<String, Object> params,
    ) {
      expect(actual, isNotNull);
      expect(actual!.$1, name);
      expect(actual.$2, params);
    }

    test('the booking funnel maps to Meta standard events', () {
      expectMeta(meta('booking_step', {'step': 1}), 'ViewContent', {
        'content_name': 'delivery_request',
      });
      expectMeta(meta('booking_step', {'step': 2}), 'InitiateCheckout', {});
      expectMeta(
        meta('price_shown', {'value': 59, 'currency': 'CAD'}),
        'Lead',
        {'value': 59, 'currency': 'CAD'},
      );
      expectMeta(meta('price_shown'), 'Lead', {});
      expectMeta(meta('deposit_checkout'), 'AddPaymentInfo', {});
      expectMeta(
        meta('booking_created', {'value': 72.43, 'currency': 'CAD'}),
        'Purchase',
        {'value': 72.43, 'currency': 'CAD'},
      );
      expectMeta(meta('driver_signup_submitted'), 'CompleteRegistration', {
        'content_name': 'driver',
      });
    });

    test('a purchase without an amount is not sent to Meta', () {
      expect(meta('booking_created'), isNull);
      expect(meta('booking_created', {'value': 0}), isNull);
    });

    test('other steps and errors stay out of Meta', () {
      for (final step in [3, 4, 5, 6, 7]) {
        expect(meta('booking_step', {'step': step}), isNull);
      }
      for (final name in [
        'price_wall',
        'sign_up',
        'sign_up_error',
        'driver_signup_started',
      ]) {
        expect(meta(name), isNull);
      }
    });

    test('priceParams keeps only a real amount', () {
      expect(FunnelAnalytics.priceParams(59), {'value': 59, 'currency': 'CAD'});
      expect(FunnelAnalytics.priceParams(null), isEmpty);
      expect(FunnelAnalytics.priceParams('59'), isEmpty);
      expect(FunnelAnalytics.priceParams(0), isEmpty);
    });
  });

  test('web/meta_pixel.js is loaded by the site and ships disabled or valid', () {
    expect(
      File('web/index.html').readAsStringSync(),
      contains('<script src="meta_pixel.js" defer></script>'),
    );
    final id = RegExp(r"var PIXEL_ID = '([^']*)';")
        .firstMatch(File('web/meta_pixel.js').readAsStringSync());
    expect(id, isNotNull);
    expect(id!.group(1), matches(RegExp(r'^(\d{15,16})?$')));
  });
}
