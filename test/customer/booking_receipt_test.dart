import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/delivery/booking_receipt_screen.dart';
import '../helpers/booking_test_harness.dart';

class ReceiptApi extends TestBookingApi {
  bool refused = false;
  @override
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> data = const {},
  ]) async {
    if (name != 'getBookingReceipt') {
      throw StateError('Unexpected receipt operation');
    }
    calls.add(name);
    if (refused) throw StateError('Simulated access refusal');
    return {
      'missionId': data['missionId'],
      'quoteId': 'test_quote',
      'customerTotalMinor': 12345,
      'contract': testBookingPolicy(version: 'ORIGINAL'),
      'acceptance': {'acceptedAtMillis': 1000},
      'booking': {
        'load': {
          'handlers': 2,
          'items': [],
          'equipment': ['straps'],
          'pickup': {'stairs': true, 'floor': 2, 'help': true},
          'dropoff': {},
        },
      },
      'pickup': {'line1': 'Test pickup'},
      'dropoff': {'line1': 'Test delivery'},
      'breakdown': {'taxAmount': 18.45},
    };
  }
}

Future<void> startReceipt(
  WidgetTester t,
  ReceiptApi api, {
  bool signed = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  final router = GoRouter(
    initialLocation: '/fr/livraison/conditions/test_mission',
    routes: [
      GoRoute(
        path: '/fr/livraison/conditions/:missionId',
        builder: (_, s) => BookingReceiptScreen(
          missionId: s.pathParameters['missionId']!,
          locale: 'fr',
          api: api,
        ),
      ),
      GoRoute(
        path: '/fr/livraison/suivi/:missionId',
        builder: (_, __) => const Scaffold(body: Text('TRACKING')),
      ),
    ],
  );
  await t.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<FirebaseAuthProvider>(
          create: (_) => BookingTestAuth(signed: signed),
        ),
        ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets('navigation to another reservation reloads its own archive', (
    t,
  ) async {
    final api = ReceiptApi();
    await startReceipt(t, api);
    final context = t.element(find.byType(BookingReceiptScreen));
    GoRouter.of(context).go('/fr/livraison/conditions/second_mission');
    await t.pumpAndSettle();
    expect(find.textContaining('Référence: second_mission'), findsOneWidget);
    expect(find.textContaining('Référence: test_mission'), findsNothing);
    expect(api.calls, ['getBookingReceipt', 'getBookingReceipt']);
    await disposeBooking(t);
  });
  testWidgets(
    'past reservation displays archived text and returns to tracking',
    (t) async {
      final api = ReceiptApi();
      await startReceipt(t, api);
      expect(find.textContaining('ORIGINAL-booking'), findsOneWidget);
      expect(find.textContaining('123,45'), findsOneWidget);
      expect(api.calls, ['getBookingReceipt']);
      await t.tap(find.text('Retour à la livraison'));
      await t.pumpAndSettle();
      expect(find.text('TRACKING'), findsOneWidget);
      await disposeBooking(t);
    },
  );
  testWidgets('signed-out or refused receipt never displays another booking', (
    t,
  ) async {
    final api = ReceiptApi();
    await startReceipt(t, api, signed: false);
    expect(api.calls, isEmpty);
    expect(find.textContaining('Connectez-vous'), findsOneWidget);
    await disposeBooking(t);
    api.refused = true;
    await startReceipt(t, api);
    expect(find.textContaining('Récapitulatif indisponible'), findsOneWidget);
    expect(find.byType(SelectableText), findsNothing);
    await disposeBooking(t);
  });
}
