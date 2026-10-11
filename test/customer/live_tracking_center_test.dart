import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:movik_connect/backend/backend_bootstrap.dart';
import 'package:movik_connect/backend/backend_locator.dart';
import 'package:movik_connect/backend/models/mission_address.dart';
import 'package:movik_connect/l10n/app_strings.dart';
import 'package:movik_connect/widgets/live_tracking_map.dart';
import '../helpers/gps_offline_transport.dart';
import 'live_tracking_identity_test.dart' as gps;

const clock = '2026-10-11T14:00:00Z';
MissionAddress address(double lat, double lng) => MissionAddress(
  line1: 'FICTITIOUS ADDRESS',
  city: 'Simulation',
  postalCode: '',
  lat: lat,
  lng: lng,
);
Future<void> frames(WidgetTester t) async {
  await t.pump();
  await t.pump();
  await t.pump();
}

Future<gps.Locations> start(
  WidgetTester t, {
  MissionAddress? pickup,
  MissionAddress? dropoff,
  String locale = 'fr',
  String mission = 'sim-A',
}) async {
  expect(BackendBootstrap.status.isConfigured, isFalse);
  expect(Firebase.apps, isEmpty);
  final repo = gps.Locations();
  BackendLocator.locationRepositoryOverride = repo;
  t.view.physicalSize = const Size(375, 812);
  t.view.devicePixelRatio = 1;
  addTearDown(() async {
    await t.pumpWidget(const SizedBox());
    await frames(t);
    await repo.close();
    BackendLocator.locationRepositoryOverride = null;
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
    expect(t.takeException(), isNull);
  });
  await t.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: LiveTrackingMap(
          driverId: 'sim-driver',
          missionId: mission,
          pickup: pickup,
          dropoff: dropoff,
          now: () => DateTime.parse(clock),
          t: (key) => AppStrings.t(key, locale),
        ),
      ),
    ),
  );
  await frames(t);
  repo.position('sim-driver').add(null);
  repo.points('sim-driver', mission).add([]);
  await frames(t);
  return repo;
}

void main() => offlineTests(() {
  offlineTest('P isolation blocks default HTTP', () async {
    expect(() => HttpClient(), throwsStateError);
    expect(Firebase.apps, isEmpty);
  });
  for (final locale in ['fr', 'en', 'es']) {
    offlineWidgetTest('P no coordinates means no invented map $locale', (
      t,
    ) async {
      final count = offlineTileRequests.length;
      await start(t, locale: locale);
      expect(find.byType(FlutterMap), findsNothing);
      expect(find.byType(TileLayer), findsNothing);
      expect(find.byIcon(Icons.local_shipping), findsNothing);
      expect(
        find.text(AppStrings.t('tracking_waiting_for_signal', locale)),
        findsOneWidget,
      );
      expect(offlineTileRequests.length, count);
    });
  }
  for (final item in [
    ('pickup', 45.4, -72.7),
    ('dropoff', 45.5, -72.8),
    ('origin', 0.0, 0.0),
  ]) {
    offlineWidgetTest('P actual address used ${item.$1}', (t) async {
      final a = address(item.$2, item.$3);
      await start(
        t,
        pickup: item.$1 == 'dropoff' ? null : a,
        dropoff: item.$1 == 'dropoff' ? a : null,
      );
      final map = t.widget<FlutterMap>(find.byType(FlutterMap));
      expect(map.options.initialCenter.latitude, item.$2);
      expect(map.options.initialCenter.longitude, item.$3);
      expect(
        t.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
        hasLength(1),
      );
      expect(find.byIcon(Icons.local_shipping), findsNothing);
    });
  }
  for (final a in [
    address(double.nan, 0),
    address(95, 0),
    address(45, double.infinity),
    address(45, -190),
  ]) {
    offlineWidgetTest(
      'P invalid address does not invent center ${a.lat}/${a.lng}',
      (t) async {
        await start(t, pickup: a);
        expect(find.byType(FlutterMap), findsNothing);
        expect(find.byType(TileLayer), findsNothing);
      },
    );
  }
  offlineWidgetTest('P invalid pickup may fall back to valid dropoff', (
    t,
  ) async {
    await start(t, pickup: address(95, 0), dropoff: address(46, -71));
    expect(
      t
          .widget<FlutterMap>(find.byType(FlutterMap))
          .options
          .initialCenter
          .latitude,
      46,
    );
    expect(
      t.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
      hasLength(1),
    );
  });
  offlineWidgetTest(
    'P valid history keeps route without fictitious active marker',
    (t) async {
      final repo = await start(t);
      repo.points('sim-driver', 'sim-A').add([
        gps.point(
          'sim-B',
          46,
          time: DateTime.parse(clock).subtract(const Duration(seconds: 4)),
        ),
        gps.point(
          'sim-A',
          45.6,
          time: DateTime.parse(clock).subtract(const Duration(seconds: 3)),
        ),
        gps.point(
          'sim-A',
          45.7,
          time: DateTime.parse(clock).subtract(const Duration(seconds: 2)),
        ),
      ]);
      await frames(t);
      expect(
        t
            .widget<FlutterMap>(find.byType(FlutterMap))
            .options
            .initialCenter
            .latitude,
        45.7,
      );
      final route = t
          .widget<PolylineLayer>(find.byType(PolylineLayer))
          .polylines
          .single
          .points;
      expect(route.map((p) => p.latitude), [45.6, 45.7]);
      expect(find.byIcon(Icons.local_shipping), findsNothing);
    },
  );
  offlineWidgetTest(
    'P fresh recovery and unavailable transition do not retain arbitrary map',
    (t) async {
      final repo = await start(t);
      repo
          .position('sim-driver')
          .add(gps.location(time: DateTime.parse(clock)));
      await frames(t);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byIcon(Icons.local_shipping), findsOneWidget);
      repo
          .position('sim-driver')
          .add(gps.location(driver: 'foreign', time: DateTime.parse(clock)));
      await frames(t);
      expect(find.byType(FlutterMap), findsNothing);
      repo
          .position('sim-driver')
          .add(gps.location(mission: 'sim-B', time: DateTime.parse(clock)));
      await frames(t);
      expect(find.byType(FlutterMap), findsNothing);
      repo
          .position('sim-driver')
          .add(gps.location(time: DateTime.parse(clock)));
      await frames(t);
      expect(find.byIcon(Icons.local_shipping), findsOneWidget);
    },
  );
  offlineWidgetTest('P expired compatible location remains last known only', (
    t,
  ) async {
    final repo = await start(t);
    repo
        .position('sim-driver')
        .add(
          gps.location(
            time: DateTime.parse(clock).subtract(const Duration(seconds: 61)),
          ),
        );
    await frames(t);
    expect(
      t
          .widget<FlutterMap>(find.byType(FlutterMap))
          .options
          .initialCenter
          .latitude,
      45.4,
    );
    expect(find.byIcon(Icons.local_shipping), findsNothing);
    expect(
      find.textContaining(AppStrings.t('tracking_position_stale', 'fr')),
      findsOneWidget,
    );
  });
});
