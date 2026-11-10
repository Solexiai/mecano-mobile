// 2026-11-09 — écran d'offre « qui sonne » : compte à rebours, expiration,
// sonnerie limitée et arrêtée à la réponse.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/backend/models/delivery_mission.dart';
import 'package:movik_connect/backend/models/mission_address.dart';
import 'package:movik_connect/l10n/app_strings.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/screens/dashboard/provider/widgets/driver_offer_alert.dart';
import 'package:movik_connect/services/driver_offer_alerts.dart';

class _Player implements OfferAlertPlayer {
  int starts = 0, stops = 0;
  @override
  Future<void> start() async => starts++;
  @override
  Future<void> stop() async => stops++;
}

String _t(String key) => AppStrings.t(key, 'fr');

DeliveryMission _mission({DateTime? expiresAt, double amount = 62.4}) => DeliveryMission(
  id: 'm1',
  customerId: 'c1',
  itemCategoryKey: 'cat_furniture',
  description: 'Commode',
  requiredVehicleCategory: VehicleCategory.pickupTruck,
  status: MissionStatus.searchingDriver,
  pricingVersion: 'TEST',
  createdAt: DateTime(2026, 11, 9),
  offerExpiresAt: expiresAt,
  driverOfferAmount: amount,
  distanceKm: 12.3,
  estimatedDurationMinutes: 21,
  pickupAddress: const MissionAddress(line1: '762 Rue Maisonneuve', city: 'Granby', postalCode: 'J2J1S6', lat: 45.4, lng: -72.7),
  dropoffAddress: const MissionAddress(line1: '150 Rue de Candiac', city: 'Granby', postalCode: 'J2H0A1', lat: 45.41, lng: -72.71),
);

void main() {
  late _Player player;
  setUp(() {
    player = _Player();
    DriverOfferAlerts.player = player;
  });
  tearDown(DriverOfferAlerts.resetForTest);

  Future<List<DriverOfferAlertChoice>> open(WidgetTester tester, DeliveryMission m, DateTime Function() now) async {
    final results = <DriverOfferAlertChoice>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(await showDriverOfferAlert(context, mission: m, t: _t, now: now)),
            child: const Text('OPEN'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    return results;
  }

  testWidgets('montant en gros, trajet, compte à rebours ; Accepter arrête la sonnerie', (tester) async {
    var clock = DateTime(2026, 11, 9, 14, 0, 0);
    final results = await open(tester, _mission(expiresAt: clock.add(const Duration(minutes: 2))), () => clock);
    expect(find.text('62.40 \$'), findsOneWidget);
    expect(find.text(_t('driver_offer_alert_for_you')), findsOneWidget);
    expect(find.textContaining('762 Rue Maisonneuve'), findsOneWidget);
    expect(find.text('12.3 km'), findsOneWidget);
    expect(find.text('2:00'), findsOneWidget);
    expect(player.starts, 1);

    clock = clock.add(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('1:55'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('driver-offer-alert-accept')));
    await tester.pumpAndSettle();
    expect(results, [DriverOfferAlertChoice.accept]);
    expect(player.stops, 1);
  });

  testWidgets('offre expirée pendant l’affichage : fermeture automatique', (tester) async {
    var clock = DateTime(2026, 11, 9, 14, 0, 0);
    final results = await open(tester, _mission(expiresAt: clock.add(const Duration(seconds: 3))), () => clock);
    clock = clock.add(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(results, [DriverOfferAlertChoice.expired]);
    expect(find.byKey(const ValueKey('driver-offer-alert')), findsNothing);
    expect(player.stops, 1);
  });

  testWidgets('la sonnerie s’arrête après maxRing même sans réponse ; Refuser rend decline', (tester) async {
    final clock = DateTime(2026, 11, 9, 14, 0, 0);
    final results = await open(tester, _mission(expiresAt: clock.add(const Duration(minutes: 10))), () => clock);
    await tester.pump(DriverOfferAlerts.maxRing + const Duration(seconds: 1));
    expect(player.stops, 1);
    expect(find.byKey(const ValueKey('driver-offer-alert')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('driver-offer-alert-decline')));
    await tester.pumpAndSettle();
    expect(results, [DriverOfferAlertChoice.decline]);
    expect(player.stops, 1);
  });

  testWidgets('montant inconnu et pas d’échéance : texte de repli, pas de compte à rebours', (tester) async {
    await open(tester, _mission(amount: 0), DateTime.now);
    expect(find.text(_t('driver_offer_alert_amount_pending')), findsOneWidget);
    expect(find.byKey(const ValueKey('driver-offer-alert-countdown')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('driver-offer-alert-details')));
    await tester.pumpAndSettle();
  });
}
