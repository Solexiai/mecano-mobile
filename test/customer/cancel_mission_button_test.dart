import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/services/booking/booking_api.dart';
import 'package:movik_connect/widgets/cancel_mission_button.dart';

class CancelApi implements BookingApi {
  CancelApi(this.feeMinor);
  final int feeMinor;
  final List<Map<String, dynamic>> payloads = [];
  @override
  Future<Map<String, dynamic>?> profile() async => null;
  @override
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> data = const {},
  ]) async {
    expect(name, 'cancelDeliveryRequest');
    payloads.add(data);
    return {'feeMinor': feeMinor, 'cancelled': data['dryRun'] != true};
  }
}

Future<void> pump(WidgetTester t, CancelApi api, {String locale = 'fr'}) =>
    t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CancelMissionButton(missionId: 'm1', locale: locale, api: api),
        ),
      ),
    );

void main() {
  testWidgets('late cancellation shows the exact fee before confirming', (
    t,
  ) async {
    final api = CancelApi(3000);
    await pump(t, api);
    await t.tap(find.byKey(const ValueKey('cancel-mission')));
    await t.pumpAndSettle();
    expect(api.payloads.single, {'missionId': 'm1', 'dryRun': true});
    expect(find.textContaining('30,00 \$'), findsWidgets);
    // Keeping the request never cancels.
    await t.tap(find.text('Garder ma demande'));
    await t.pumpAndSettle();
    expect(api.payloads, hasLength(1));

    await t.tap(find.byKey(const ValueKey('cancel-mission')));
    await t.pumpAndSettle();
    await t.tap(find.text('Annuler et payer 30,00 \$'));
    await t.pumpAndSettle();
    expect(api.payloads.last, {'missionId': 'm1', 'acceptedFeeMinor': 3000});
  });

  testWidgets('free cancellation says so and sends no fee', (t) async {
    final api = CancelApi(0);
    await pump(t, api, locale: 'en');
    await t.tap(find.byKey(const ValueKey('cancel-mission')));
    await t.pumpAndSettle();
    expect(find.textContaining('Cancellation is free'), findsOneWidget);
    await t.tap(find.text('Cancel the request'));
    await t.pumpAndSettle();
    expect(api.payloads.last, {'missionId': 'm1'});
  });

  test('cancelled mission fee summary', () {
    expect(
      cancellationFeeSummary({
        'kind': 'late_cancellation',
        'status': 'captured',
        'total_minor': 3000,
      }, 'fr'),
      'Frais d’annulation : 30,00 \$ (débités)',
    );
    expect(
      cancellationFeeSummary({
        'kind': 'customer_failed_delivery',
        'status': 'pending',
        'total_minor': 3000,
      }, 'en'),
      'Travel fee: \$30.00 (processing)',
    );
    expect(cancellationFeeSummary(null, 'fr'), isNull);
  });
}
