// Pourboire au chauffeur (décision Daniel, 2026-11-09) : proposé avec la
// note après la livraison, 10/15/20 % du prix avant taxes ou un montant au
// choix, débité seulement après confirmation, 100 % au chauffeur.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movik_connect/backend/backend_locator.dart';
import 'package:movik_connect/backend/models/delivery_mission.dart';
import 'package:movik_connect/backend/models/mission_rating.dart';
import 'package:movik_connect/backend/repositories/mission_repository.dart';
import 'package:movik_connect/backend/repositories/rating_repository.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/customer/customer_tracking_screen.dart';
import 'package:movik_connect/services/booking/booking_api.dart';

const _customer = 'customer_tip';
const _id = 'mission_tip';

DeliveryMission _mission({int? tipAmountMinor, DateTime? completedAt}) =>
    DeliveryMission(
      id: _id,
      customerId: _customer,
      itemCategoryKey: 'cat_furniture',
      description: 'Divan',
      requiredVehicleCategory: VehicleCategory.pickupTruck,
      status: MissionStatus.completed,
      driverId: 'driver_tip',
      driverDisplayName: 'Marc',
      pricingVersion: 'TEST',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      completedAt: completedAt ?? DateTime.now().subtract(const Duration(hours: 1)),
      driverOfferAmount: 50,
      customerTotal: 72.43,
      tipPreTaxMinor: 6300,
      tipAmountMinor: tipAmountMinor,
    );

class _Missions implements MissionRepository {
  _Missions(this.mission);
  final DeliveryMission mission;
  @override
  Stream<DeliveryMission?> watchMission(String missionId) =>
      Stream.value(mission);
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Ratings implements RatingRepository {
  @override
  Future<MissionRating?> getMyRatingForMission({
    required String missionId,
    required String customerId,
  }) async => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Api implements BookingApi {
  _Api(this.answer);
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>) answer;
  final calls = <(String, Map<String, dynamic>)>[];
  @override
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> data = const {},
  ]) {
    calls.add((name, data));
    return answer(data);
  }

  @override
  Future<Map<String, dynamic>?> profile() async => null;
}

Widget _app(BookingApi api) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LocaleProvider()),
    ChangeNotifierProvider.value(
      value: FirebaseAuthProvider(backendConfigured: false)
        ..debugForceSignedIn = true
        ..debugForceUid = _customer,
    ),
  ],
  child: MaterialApp.router(
    routerConfig: GoRouter(
      initialLocation: '/fr/livraison/suivi/$_id',
      routes: [
        GoRoute(
          path: '/fr/livraison/suivi/:missionId',
          builder: (c, s) => CustomerTrackingScreen(
            missionId: s.pathParameters['missionId']!,
            api: api,
          ),
        ),
      ],
    ),
  ),
);

Future<void> _tap(WidgetTester t, Key key) async {
  final finder = find.byKey(key);
  await t.ensureVisible(finder);
  await t.pumpAndSettle();
  await t.tap(finder);
  await t.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BackendLocator.missionRepositoryOverride = _Missions(_mission());
    BackendLocator.ratingRepositoryOverride = _Ratings();
  });
  tearDown(() {
    BackendLocator.missionRepositoryOverride = null;
    BackendLocator.ratingRepositoryOverride = null;
  });

  testWidgets('10, 15, 20 % du prix avant taxes, débité après confirmation', (
    t,
  ) async {
    final api = _Api((data) async => {'success': true, 'amountMinor': 945});
    await t.pumpWidget(_app(api));
    await t.pumpAndSettle();
    expect(find.text('Un pourboire pour Marc ?'), findsOneWidget);
    expect(find.textContaining('6,30'), findsOneWidget);
    expect(find.textContaining('9,45'), findsOneWidget);
    expect(find.textContaining('12,60'), findsOneWidget);

    await _tap(t, const ValueKey('tip-percent-15'));
    expect(find.textContaining('Donner 9,45'), findsOneWidget);
    await _tap(t, const ValueKey('tip-send'));
    // Rien n'est débité avant la confirmation.
    expect(api.calls, isEmpty);
    await t.tap(find.byKey(const ValueKey('tip-confirm')));
    await t.pumpAndSettle();

    expect(api.calls.single.$1, 'tipDriver');
    expect(api.calls.single.$2, {'missionId': _id, 'percent': 15});
    expect(find.byKey(const ValueKey('tip-thanks')), findsOneWidget);
    expect(find.textContaining('Pourboire envoyé'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('annuler la confirmation ne débite rien', (t) async {
    final api = _Api((data) async => {'success': true});
    await t.pumpWidget(_app(api));
    await t.pumpAndSettle();
    await _tap(t, const ValueKey('tip-percent-10'));
    await _tap(t, const ValueKey('tip-send'));
    await t.tap(find.byKey(const ValueKey('tip-cancel')));
    await t.pumpAndSettle();
    expect(api.calls, isEmpty);
    expect(find.byKey(const ValueKey('tip-card')), findsOneWidget);
  });

  testWidgets('montant au choix envoyé en cents, borné de 1 \$ à 100 \$', (
    t,
  ) async {
    final api = _Api(
      (data) async => {'success': true, 'amountMinor': data['amountMinor']},
    );
    await t.pumpWidget(_app(api));
    await t.pumpAndSettle();
    await _tap(t, const ValueKey('tip-custom'));
    await t.enterText(find.byKey(const ValueKey('tip-custom-amount')), '150');
    await t.pumpAndSettle();
    final send = t.widget<ElevatedButton>(
      find.byKey(const ValueKey('tip-send')),
    );
    expect(send.onPressed, isNull);

    await t.enterText(find.byKey(const ValueKey('tip-custom-amount')), '12,50');
    await t.pumpAndSettle();
    await _tap(t, const ValueKey('tip-send'));
    await t.tap(find.byKey(const ValueKey('tip-confirm')));
    await t.pumpAndSettle();
    expect(api.calls.single.$2, {'missionId': _id, 'amountMinor': 1250});
    expect(find.textContaining('12,50'), findsWidgets);
  });

  testWidgets('refus de la banque : message du serveur, carte toujours là', (
    t,
  ) async {
    final api = _Api(
      (data) async => throw FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'Votre banque a refusé le pourboire. Aucun montant n’a été débité.',
      ),
    );
    await t.pumpWidget(_app(api));
    await t.pumpAndSettle();
    await _tap(t, const ValueKey('tip-percent-20'));
    await _tap(t, const ValueKey('tip-send'));
    await t.tap(find.byKey(const ValueKey('tip-confirm')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('tip-error')), findsOneWidget);
    expect(find.textContaining('Votre banque a refusé'), findsOneWidget);
    expect(find.byKey(const ValueKey('tip-card')), findsOneWidget);
  });

  testWidgets('déjà donné : remerciement seulement, aucun choix', (t) async {
    BackendLocator.missionRepositoryOverride = _Missions(
      _mission(tipAmountMinor: 945),
    );
    await t.pumpWidget(_app(_Api((data) async => {})));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('tip-thanks')), findsOneWidget);
    expect(find.byKey(const ValueKey('tip-card')), findsNothing);
  });

  testWidgets('plus de 30 jours après la livraison : plus proposé', (t) async {
    BackendLocator.missionRepositoryOverride = _Missions(
      _mission(completedAt: DateTime.now().subtract(const Duration(days: 31))),
    );
    await t.pumpWidget(_app(_Api((data) async => {})));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('tip-card')), findsNothing);
  });

  test('base du pourboire : prix payé moins les taxes, comme le serveur', () {
    final m = DeliveryMission.fromJson('m1', {
      'customer_id': 'c',
      'status': 'completed',
      'customer_total': 72.43,
      'customer_total_minor': 7243,
      'quote_breakdown': {'taxAmount': 9.43},
      'tip': {'amount_minor': 945, 'status': 'paid'},
    });
    expect(m.tipBaseMinor, 6300);
    expect(m.tipAmountMinor, 945);
    final noBreakdown = DeliveryMission.fromJson('m2', {
      'customer_id': 'c',
      'status': 'completed',
      'customer_total': 50,
    });
    expect(noBreakdown.tipBaseMinor, 5000);
    expect(noBreakdown.tipAmountMinor, isNull);
  });
}
