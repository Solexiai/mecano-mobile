// 2026-11-18 (Daniel : « les chauffeurs voient la map à vol d'oiseau »).
// La carte de suivi dessine l'itinéraire PAR LA ROUTE et ne relie plus deux
// positions GPS éloignées dans le temps par une ligne droite.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:movik_connect/backend/backend_locator.dart';
import 'package:movik_connect/backend/models/driver_location_history_point.dart';
import 'package:movik_connect/backend/models/mission_address.dart';
import 'package:movik_connect/l10n/app_strings.dart';
import 'package:movik_connect/services/mission_route_path_service.dart';
import 'package:movik_connect/widgets/live_tracking_map.dart';
import '../helpers/gps_offline_transport.dart';
import 'live_tracking_identity_test.dart' as gps;

final clock = DateTime.parse('2026-11-18T15:00:00Z');

// Granby → Cowansville, par une route fictive à trois points.
const granby = ll.LatLng(45.4001, -72.7329);
const midway = ll.LatLng(45.35, -72.74);
const cowansville = ll.LatLng(45.2001, -72.7466);
const road = [granby, midway, cowansville];
// Les trois mêmes points, encodés (algorithme « polyline », précision 5).
const roadEncoded = r'sebtGrs|zLbxHjk@zg\fh@';

MissionAddress address(ll.LatLng point, String city) => MissionAddress(
  line1: 'ADRESSE FICTIVE',
  city: city,
  postalCode: '',
  lat: point.latitude,
  lng: point.longitude,
);

DriverLocationHistoryPoint at(
  int secondsAgo,
  double latitude, {
  String mission = 'sim-A',
}) => DriverLocationHistoryPoint(
  deliveryId: mission,
  latitude: latitude,
  longitude: -72.7,
  recordedAt: clock.subtract(Duration(seconds: secondsAgo)),
);

Widget screen({String mission = 'sim-A', bool withAddresses = true}) =>
    MaterialApp(
      home: Scaffold(
        body: LiveTrackingMap(
          driverId: 'sim-driver',
          missionId: mission,
          pickup: withAddresses ? address(granby, 'Granby') : null,
          dropoff: withAddresses ? address(cowansville, 'Cowansville') : null,
          now: () => clock,
          t: (key) => AppStrings.t(key, 'fr'),
        ),
      ),
    );

Future<void> frames(WidgetTester t) async {
  await t.pump();
  await t.pump();
  await t.pump();
}

Future<gps.Locations> start(
  WidgetTester t, {
  MissionRoutePathLoader? loader,
  bool withAddresses = true,
}) async {
  final repo = gps.Locations();
  BackendLocator.locationRepositoryOverride = repo;
  MissionRoutePathService.resetForTest();
  MissionRoutePathService.loaderOverride = loader;
  t.view.physicalSize = const Size(375, 812);
  t.view.devicePixelRatio = 1;
  addTearDown(() async {
    await t.pumpWidget(const SizedBox());
    await frames(t);
    await repo.close();
    BackendLocator.locationRepositoryOverride = null;
    MissionRoutePathService.resetForTest();
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
    expect(t.takeException(), isNull);
  });
  await t.pumpWidget(screen(withAddresses: withAddresses));
  await frames(t);
  repo.position('sim-driver').add(null);
  repo.points('sim-driver', 'sim-A').add([]);
  await frames(t);
  return repo;
}

List<Polyline> lines(WidgetTester t) =>
    t.widget<PolylineLayer>(find.byType(PolylineLayer)).polylines;
Finder get plannedLegend =>
    find.text(AppStrings.t('tracking_planned_route_legend', 'fr'));
Finder get traveledLegend =>
    find.text(AppStrings.t('tracking_route_legend', 'fr'));

void main() => offlineTests(() {
  group('décodage du tracé encodé', () {
    test('exemple de référence, vers le sud et vers l\'ouest', () {
      final points = decodeRoutePolyline(r'_p~iF~ps|U_ulLnnqC_mqNvxq`@');
      expect(points.map((p) => [p.latitude, p.longitude]).toList(), [
        [38.5, -120.2],
        [40.7, -120.95],
        [43.252, -126.453],
      ]);
    });
    test('Granby → Cowansville', () {
      final points = decodeRoutePolyline(roadEncoded);
      expect(points, hasLength(3));
      expect(points.first.latitude, closeTo(granby.latitude, 1e-9));
      expect(points.first.longitude, closeTo(granby.longitude, 1e-9));
      expect(points.last.latitude, closeTo(cowansville.latitude, 1e-9));
      expect(points.last.longitude, closeTo(cowansville.longitude, 1e-9));
    });
    test('un tracé tronqué ou invalide ne donne aucun point', () {
      expect(decodeRoutePolyline(''), isEmpty);
      // Longitude manquante.
      expect(decodeRoutePolyline('_p~iF'), isEmpty);
      // Dernier morceau coupé.
      expect(decodeRoutePolyline(r'_p~iF~ps|U_ulLnnqC_mqNvxq`'), isEmpty);
      // Caractère hors de l'alphabet du tracé.
      expect(decodeRoutePolyline('_p~iF~ps|U é'), isEmpty);
      // Latitude hors plage (précision 1 : 3 850 000°).
      expect(decodeRoutePolyline('_p~iF~ps|U', precision: 1), isEmpty);
    });
  });

  group('trajet parcouru', () {
    offlineWidgetTest('un trou de suivi coupe le tracé au lieu de le relier', (
      t,
    ) async {
      final repo = await start(t);
      repo.points('sim-driver', 'sim-A').add([
        at(100, 45.40),
        at(92, 45.39),
        // 72 s sans position (app en arrière-plan), puis le suivi reprend.
        at(20, 45.30),
        at(12, 45.29),
        at(4, 45.28),
      ]);
      await frames(t);
      final segments = lines(
        t,
      ).map((line) => line.points.map((p) => p.latitude).toList()).toList();
      expect(segments, [
        [45.40, 45.39],
        [45.30, 45.29, 45.28],
      ]);
      expect(traveledLegend, findsOneWidget);
    });
    offlineWidgetTest('des positions toutes espacées ne tracent aucune ligne', (
      t,
    ) async {
      final repo = await start(t);
      // Une position par minute : les relier couperait à travers champs.
      repo.points('sim-driver', 'sim-A').add([
        at(180, 45.40),
        at(120, 45.36),
        at(60, 45.32),
        at(0, 45.28),
      ]);
      await frames(t);
      expect(find.byType(PolylineLayer), findsNothing);
      expect(traveledLegend, findsNothing);
      // La carte reste affichée, avec ses repères de ramassage et livraison.
      expect(find.byType(FlutterMap), findsOneWidget);
    });
    offlineWidgetTest('30 s d\'écart relient encore, 31 s coupent', (t) async {
      final repo = await start(t);
      repo.points('sim-driver', 'sim-A').add([at(40, 45.40), at(10, 45.39)]);
      await frames(t);
      expect(lines(t).single.points, hasLength(2));
      repo.points('sim-driver', 'sim-A').add([at(41, 45.40), at(10, 45.39)]);
      await frames(t);
      expect(find.byType(PolylineLayer), findsNothing);
    });
  });

  group('itinéraire par la route', () {
    offlineWidgetTest('le tracé routier de la mission est dessiné et cadré', (
      t,
    ) async {
      final asked = <String>[];
      await start(
        t,
        loader: (missionId) async {
          asked.add(missionId);
          return road;
        },
      );
      expect(asked, ['sim-A']);
      expect(lines(t).single.points, road);
      expect(plannedLegend, findsOneWidget);
      expect(traveledLegend, findsNothing);
      // Toute la route est visible, de Granby à Cowansville.
      final camera = t
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!
          .camera;
      expect(camera.visibleBounds.contains(granby), isTrue);
      expect(camera.visibleBounds.contains(cowansville), isTrue);
    });
    offlineWidgetTest('itinéraire dessous, trajet parcouru dessus', (t) async {
      final repo = await start(t, loader: (_) async => road);
      repo.points('sim-driver', 'sim-A').add([at(12, 45.39), at(4, 45.38)]);
      await frames(t);
      final drawn = lines(t);
      expect(drawn, hasLength(2));
      expect(drawn.first.points, road);
      expect(drawn.last.points.map((p) => p.latitude).toList(), [45.39, 45.38]);
      expect(plannedLegend, findsOneWidget);
      expect(traveledLegend, findsOneWidget);
    });
    offlineWidgetTest('sans tracé disponible, la carte s\'affiche sans ligne', (
      t,
    ) async {
      for (final MissionRoutePathLoader loader in [
        (_) async => const <ll.LatLng>[],
        (_) async => const [granby],
        (_) async => throw StateError('service indisponible'),
      ]) {
        await start(t, loader: loader);
        expect(find.byType(FlutterMap), findsOneWidget);
        expect(find.byType(PolylineLayer), findsNothing);
        expect(plannedLegend, findsNothing);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await frames(t);
      }
    });
    offlineWidgetTest('un changement de mission ne garde pas l\'ancien tracé', (
      t,
    ) async {
      final asked = <String>[];
      await start(
        t,
        loader: (missionId) async {
          asked.add(missionId);
          return missionId == 'sim-A' ? road : const <ll.LatLng>[];
        },
      );
      expect(lines(t).single.points, road);
      await t.pumpWidget(screen(mission: 'sim-B'));
      await frames(t);
      expect(asked, ['sim-A', 'sim-B']);
      expect(find.byType(PolylineLayer), findsNothing);
      expect(plannedLegend, findsNothing);
    });
    offlineWidgetTest('le tracé d\'une mission n\'est demandé qu\'une fois', (
      t,
    ) async {
      var calls = 0;
      await start(
        t,
        loader: (_) async {
          calls++;
          return road;
        },
      );
      await t.pumpWidget(const SizedBox());
      await frames(t);
      await t.pumpWidget(screen());
      await frames(t);
      expect(calls, 1);
      expect(lines(t).single.points, road);
    });
  });

  group('mention OpenStreetMap', () {
    offlineWidgetTest('affichée sous la carte, absente sans carte', (t) async {
      await start(t);
      expect(find.text('© OpenStreetMap'), findsOneWidget);
      expect(
        find.text(AppStrings.t('tracking_map_fix_link', 'fr')),
        findsOneWidget,
      );
      await t.pumpWidget(const SizedBox());
      await frames(t);
      await start(t, withAddresses: false);
      expect(find.byType(FlutterMap), findsNothing);
      expect(find.text('© OpenStreetMap'), findsNothing);
    });
  });
});
