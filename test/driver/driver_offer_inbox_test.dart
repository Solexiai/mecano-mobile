import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movik_connect/backend/models/delivery_mission.dart';
import 'package:movik_connect/backend/models/delivery_offer.dart';
import 'package:movik_connect/backend/models/driver_profile_v2.dart';
import 'package:movik_connect/backend/repositories/mission_repository.dart';
import 'package:movik_connect/backend/repositories/delivery_offer_actions.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/l10n/driver_notification_copy.dart';
import 'package:movik_connect/widgets/driver_offer_inbox.dart';
import 'package:movik_connect/widgets/driver_offer_alert.dart';

class OffersRepo implements MissionRepository, DeliveryOfferActions {
  final offers = StreamController<List<DeliveryOffer>>.broadcast();
  final updates = StreamController<DeliveryMission?>.broadcast();
  final active = StreamController<DeliveryMission?>.broadcast();
  DeliveryMission? initialMission;
  DeliveryMission? initialActive;
  int subscriptions = 0;
  int accepts = 0;
  int declines = 0;
  Completer<AcceptMissionResult>? pending;
  @override
  Stream<List<DeliveryOffer>> watchOffersForDriver(String id) { subscriptions++; return offers.stream; }
  @override
  Stream<DeliveryMission?> watchActiveMissionForDriver(String id) async* { yield initialActive; yield* active.stream; }
  @override
  Stream<DeliveryMission?> watchMission(String id) async* { yield initialMission; yield* updates.stream; }
  @override
  Future<AcceptMissionResult> acceptMission({required String missionId, required String driverId}) async {
    accepts++; if (pending != null) return await pending!.future; return const AcceptMissionResult(success: true);
  }
  @override
  Future<void> declineOffer(String id) async { declines++; }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  Future<void> close() async { await offers.close(); await updates.close(); await active.close(); }
}

void main() {
  final start = DateTime.utc(2026, 9, 24, 16);
  late DateTime now;
  late OffersRepo repo;
  late StreamController<DriverProfileV2?> profiles;
  late DriverProfileV2 profile;
  int navigations = 0;
  String t(String key) => DriverNotificationCopy.maybeTranslate(key, 'fr') ?? key;
  DeliveryOffer offer({String id='offer-1', String driver='driver-1', int version=2}) => DeliveryOffer(
    id:id,missionId:'mission-1',driverId:driver,offeredAt:start,expiresAt:start.add(const Duration(seconds:45)),status:'pending',dispatchVersion:version);
  setUp(() {
    SharedPreferences.setMockInitialValues({}); now=start; navigations=0;
    profiles=StreamController<DriverProfileV2?>.broadcast(); repo=OffersRepo();
    profile=DriverProfileV2(uid:'driver-1',fullName:'Driver',city:'Test',status:DriverStatus.approved,
      serviceRadiusKm:5,acceptedVehicleCategories:const [VehicleCategory.car],acceptedItemCategoryKeys:const [],
      createdAt:start,documentsAllValid:true,onlineStatus:DriverOnlineStatus.online);
    repo.initialMission=DeliveryMission(id:'mission-1',customerId:'customer-1',itemCategoryKey:'furniture',description:'Table',
      requiredVehicleCategory:VehicleCategory.car,status:MissionStatus.offered,pricingVersion:'TEST',createdAt:start);
  });
  tearDown(() async { await repo.close(); await profiles.close(); });
  Stream<DriverProfileV2?> profileStream() async* { yield profile; yield* profiles.stream; }
  Widget app({String page='Missions', String uid='driver-1'}) => MaterialApp(home:Scaffold(body:DriverOfferInbox(
    key:ValueKey(uid),driverId:uid,profileStream:profileStream(),repository:repo,t:t,now:()=>now,
    onAccepted:(_)=>navigations++,child:Text(page))));
  Future<void> show(WidgetTester tester, {DeliveryOffer? value}) async {
    await tester.pumpWidget(app()); await tester.pump();
    repo.offers.add([value ?? offer()]); await tester.pump(); await tester.pump();
  }
  testWidgets('new offer appears automatically and details do not navigate', (tester) async {
    await show(tester); expect(find.byType(DriverOfferAlert), findsOneWidget);
    await tester.tap(find.text('Voir les détails')); await tester.pump();
    expect(find.text('Table'),findsOneWidget); expect(navigations,0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('tab rebuild and duplicate snapshot do not add a second listener or popup', (tester) async {
    await show(tester); await tester.pumpWidget(app(page:'Revenus')); await tester.pump();
    repo.offers.add([offer(),offer()]); await tester.pump();
    expect(find.byType(DriverOfferAlert),findsOneWidget); expect(repo.subscriptions,1);
    await tester.tap(find.text('Fermer')); await tester.pump();
    repo.offers.add([offer()]); await tester.pump();
    expect(find.byType(DriverOfferAlert),findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('acknowledged offer is not shown again after remount', (tester) async {
    await show(tester); await tester.tap(find.text('Fermer')); await tester.pump();
    await tester.pumpWidget(const SizedBox()); await show(tester);
    expect(find.byType(DriverOfferAlert),findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('expired and foreign offers never appear', (tester) async {
    now=start.add(const Duration(minutes:1)); await show(tester);
    expect(find.byType(DriverOfferAlert),findsNothing);
    now=start; repo.offers.add([offer(driver:'another-driver')]); await tester.pump();
    expect(find.byType(DriverOfferAlert),findsNothing); await tester.pumpWidget(const SizedBox());
  });
  testWidgets('expiry dismisses an already displayed offer', (tester) async {
    await show(tester); now=start.add(const Duration(seconds:46));
    await tester.pump(const Duration(seconds:1));
    expect(find.byType(DriverOfferAlert),findsNothing); expect(repo.accepts,0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('active mission suppresses alerts', (tester) async {
    repo.initialActive=repo.initialMission; await show(tester);
    expect(find.byType(DriverOfferAlert),findsNothing); await tester.pumpWidget(const SizedBox());
  });
  testWidgets('loss of driver availability dismisses the offer', (tester) async {
    await show(tester); profiles.add(null); await tester.pump();
    expect(find.byType(DriverOfferAlert),findsNothing); await tester.pumpWidget(const SizedBox());
  });
  testWidgets('mission removal dismisses the offer', (tester) async {
    await show(tester); repo.updates.add(null); await tester.pump();
    expect(find.byType(DriverOfferAlert),findsNothing); await tester.pumpWidget(const SizedBox());
  });
  testWidgets('accept double tap calls the existing repository once', (tester) async {
    repo.pending=Completer<AcceptMissionResult>(); await show(tester);
    await tester.tap(find.text('Accepter')); await tester.pump();
    expect(repo.accepts,1); expect(find.byType(CircularProgressIndicator),findsOneWidget);
    repo.pending!.complete(const AcceptMissionResult(success:true)); await tester.pump();
    expect(navigations,1); expect(find.byType(DriverOfferAlert),findsNothing); await tester.pumpWidget(const SizedBox());
  });
  testWidgets('decline uses the server action and dismisses', (tester) async {
    await show(tester); await tester.tap(find.text('Refuser')); await tester.pump();
    expect(repo.declines,1); expect(repo.accepts,0); expect(find.byType(DriverOfferAlert),findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('accept error remains visible and retry is available', (tester) async {
    repo.pending=Completer<AcceptMissionResult>(); await show(tester);
    await tester.tap(find.text('Accepter')); await tester.pump();
    repo.pending!.complete(const AcceptMissionResult(success:false,errorCode:'unavailable')); await tester.pump();
    expect(find.text(t('driver_offer_action_error')),findsOneWidget); expect(navigations,0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('background suppresses new alerts until foreground', (tester) async {
    await tester.pumpWidget(app()); await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    repo.offers.add([offer()]); await tester.pump(); expect(find.byType(DriverOfferAlert),findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(); await tester.pump(); expect(find.byType(DriverOfferAlert),findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('small phone has no overflow', (tester) async {
    tester.view.physicalSize=const Size(320,640); tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    await show(tester); expect(find.byType(DriverOfferAlert),findsOneWidget);
    expect(tester.takeException(),isNull); await tester.pumpWidget(const SizedBox());
  });
}
