// Accueil chauffeur « style Uber » (2026-11-06) : le bouton GO suit l'état
// de service et le statut du dossier, et appelle la même bascule que le
// Switch de l'AppBar.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/backend/models/driver_profile_v2.dart';
import 'package:movik_connect/l10n/app_strings.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/screens/dashboard/provider/widgets/driver_home_hero.dart';

DriverProfileV2 _profile({
  DriverStatus status = DriverStatus.approved,
  DriverOnlineStatus online = DriverOnlineStatus.offline,
}) => DriverProfileV2(
  uid: 'driver-1',
  fullName: 'Chauffeur Test',
  city: 'Granby',
  status: status,
  serviceRadiusKm: 40,
  acceptedVehicleCategories: const [VehicleCategory.pickupTruck],
  acceptedItemCategoryKeys: const ['cat_furniture'],
  createdAt: DateTime(2026, 1, 1),
  onlineStatus: online,
);

String _t(String key) => AppStrings.t(key, 'fr');

Future<List<bool>> _pump(
  WidgetTester tester, {
  required DriverProfileV2? profile,
  bool toggling = false,
}) async {
  final calls = <bool>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DriverHomeHero(
          profile: profile,
          t: _t,
          toggling: toggling,
          onToggle: calls.add,
        ),
      ),
    ),
  );
  await tester.pump();
  return calls;
}

void main() {
  testWidgets('hors service + approuvé : GO actif, passe en service', (
    tester,
  ) async {
    final calls = await _pump(tester, profile: _profile());
    expect(find.text(_t('driver_home_offline_title')), findsOneWidget);
    expect(find.text(_t('driver_home_go')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('driver-home-go-button')));
    expect(calls, [true]);
  });

  testWidgets('dossier non approuvé : GO désactivé, explication affichée', (
    tester,
  ) async {
    final calls = await _pump(
      tester,
      profile: _profile(status: DriverStatus.pendingReview),
    );
    expect(find.text(_t('driver_home_not_approved_subtitle')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('driver-home-go-button')));
    expect(calls, isEmpty);
  });

  testWidgets('en service : pilule « Passer hors service »', (tester) async {
    final calls = await _pump(
      tester,
      profile: _profile(online: DriverOnlineStatus.online),
    );
    expect(find.text(_t('driver_home_online_title')), findsOneWidget);
    expect(find.byKey(const ValueKey('driver-home-go-button')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('driver-home-offline-button')));
    expect(calls, [false]);
  });

  testWidgets('en mission : aucun bouton, message explicite', (tester) async {
    await _pump(tester, profile: _profile(online: DriverOnlineStatus.onMission));
    expect(find.text(_t('driver_home_on_mission_title')), findsOneWidget);
    expect(find.byKey(const ValueKey('driver-home-go-button')), findsNothing);
    expect(find.byKey(const ValueKey('driver-home-offline-button')), findsNothing);
  });

  testWidgets('bascule en cours : GO désactivé (sablier) et ignore le tap', (
    tester,
  ) async {
    final calls = await _pump(tester, profile: _profile(), toggling: true);
    expect(find.byKey(const ValueKey('driver-home-go-busy')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.byKey(const ValueKey('driver-home-go-button')));
    expect(calls, isEmpty);
  });

  testWidgets('profil inconnu : GO désactivé sans erreur', (tester) async {
    final calls = await _pump(tester, profile: null);
    await tester.tap(find.byKey(const ValueKey('driver-home-go-button')));
    expect(calls, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
