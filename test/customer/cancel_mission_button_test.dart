import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/services/booking/booking_api.dart';
import 'package:movik_connect/widgets/cancel_mission_button.dart';

class CancelApi implements BookingApi {
  CancelApi(this.feeMinor, {this.depositMinor = 0, this.depositKept = false});
  final int feeMinor;
  // Dépôt de réservation (2026-11-06).
  final int depositMinor;
  final bool depositKept;
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
    return {
      'feeMinor': feeMinor,
      'cancelled': data['dryRun'] != true,
      if (depositMinor > 0) 'depositMinor': depositMinor,
      if (depositMinor > 0) 'depositKept': depositKept,
      if (depositMinor > 0) 'depositRefundMinor': depositKept ? 0 : depositMinor,
    };
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

  testWidgets('dépôt remboursé : annulation gratuite, dépôt annoncé remboursé', (
    t,
  ) async {
    final api = CancelApi(0, depositMinor: 2500);
    await pump(t, api);
    await t.tap(find.byKey(const ValueKey('cancel-mission')));
    await t.pumpAndSettle();
    expect(find.textContaining('dépôt de 25,00 \$ vous sera remboursé'), findsOneWidget);
    await t.tap(find.text('Annuler la demande'));
    await t.pumpAndSettle();
    expect(api.payloads.last, {'missionId': 'm1'});
  });

  testWidgets('dépôt gardé : moins de 48 h, aucun autre montant débité', (
    t,
  ) async {
    final api = CancelApi(0, depositMinor: 2500, depositKept: true);
    await pump(t, api);
    await t.tap(find.byKey(const ValueKey('cancel-mission')));
    await t.pumpAndSettle();
    expect(find.textContaining('dépôt de 25,00 \$ est conservé'), findsOneWidget);
    expect(find.textContaining('Aucun autre montant'), findsOneWidget);
    await t.tap(find.text('Annuler (dépôt conservé)'));
    await t.pumpAndSettle();
    expect(api.payloads.last, {'missionId': 'm1'});
  });
}
