// Mesure du parcours (2026-11-22) : les événements partent sans données
// personnelles, et une même étape n'est comptée qu'une fois de suite.
import 'package:flutter_test/flutter_test.dart';

import 'package:movik_connect/services/funnel/funnel_analytics.dart';

void main() {
  test('booking_step : une fois par changement d’étape', () {
    FunnelAnalytics.sentForTest.clear();
    FunnelAnalytics.bookingStep(101);
    FunnelAnalytics.bookingStep(101);
    FunnelAnalytics.bookingStep(102);
    FunnelAnalytics.event('price_shown');
    expect(FunnelAnalytics.sentForTest, [
      ('booking_step', {'step': 101}),
      ('booking_step', {'step': 102}),
      ('price_shown', <String, Object>{}),
    ]);
  });
}
