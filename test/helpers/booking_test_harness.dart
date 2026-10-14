import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/delivery/delivery_request_flow_screen.dart';
import 'package:movik_connect/services/booking/booking_api.dart';
import 'package:movik_connect/services/booking/booking_draft.dart';

class TestUser extends Fake implements fb.User {
  TestUser(this.verified);
  final bool verified;
  @override
  bool get emailVerified => verified;
  @override
  Future<void> reload() async {}
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async => 'test';
  @override
  Future<void> sendEmailVerification([
    fb.ActionCodeSettings? actionCodeSettings,
  ]) async {}
}

class BookingTestAuth extends FirebaseAuthProvider {
  BookingTestAuth({bool signed = true, this.verified = true})
    : super(backendConfigured: false) {
    debugForceSignedIn = signed;
    debugForceUid = signed ? 'booking_test' : null;
    debugForceDisplayName = 'Test Client';
    debugForceEmail = 'test@example.invalid';
  }
  final bool verified;
  @override
  fb.User? get user => debugForceSignedIn ? TestUser(verified) : null;
}

class MemoryBookingStorage extends BookingDraftStorage {
  MemoryBookingStorage(this.saved);
  BookingDraft? saved;
  int handoffs = 0;
  @override
  Future<BookingDraft?> load(String? uid) async =>
      saved == null ? null : BookingDraft.fromJson(saved!.data);
  @override
  Future<void> save(BookingDraft draft, String? uid) async {
    saved = BookingDraft.fromJson(draft.data);
  }

  @override
  Future<void> handoff() async {
    handoffs++;
  }
}

Map<String, dynamic> testQuote() => {
  'quoteId': 'test_quote',
  'customerTotal': 123.45,
  'vehicleCategory': 'cargo_van',
  'distanceKm': 10.0,
  'estimatedDurationMinutes': 20.0,
  'expiresAtMillis': DateTime.now()
      .add(const Duration(minutes: 15))
      .millisecondsSinceEpoch,
  'breakdown': {
    'missionBaseValue': 100.0,
    'customerServiceFee': 5.0,
    'taxAmount': 18.45,
  },
  'booking': {
    'load': {
      'items': [],
      'pickup': {},
      'dropoff': {},
      'handlers': 1,
      'equipment': [],
    },
  },
};
BookingDraft testDraft({int step = 0, bool quote = false}) {
  final d = BookingDraft(category: 'cat_furniture');
  d.step = step;
  d.items.add({
    'id': 'test-item',
    'category': 'sofa',
    'label': 'Canapé de test',
    'quantity': 1,
    'length': 25.4,
    'width': 50,
    'height': 60,
    'weight': 20,
    'dimension_unit': 'cm',
    'weight_unit': 'kg',
    'approximate': false,
    'upright': true,
    'photos': <String>[],
  });
  d.data['requested_at'] = '2099-01-01T12:00:00Z';
  d.data['pickup'] = {
    'line1': 'Test pickup',
    'city': 'Granby',
    'postal_code': 'J2G1A1',
    'formatted_address': 'Test pickup, Granby, J2G1A1',
    'place_id': 'test-pickup',
    'lat': 45.4,
    'lng': -72.7,
  };
  d.data['dropoff'] = {
    'line1': 'Test dropoff',
    'city': 'Granby',
    'postal_code': 'J2G1A2',
    'formatted_address': 'Test dropoff, Granby, J2G1A2',
    'place_id': 'test-dropoff',
    'lat': 45.41,
    'lng': -72.71,
  };
  d.data['contacts'] = {
    'pickup_name': 'Test Client',
    'pickup_phone': '+15145550100',
    'dropoff_name': 'Test Recipient',
    'dropoff_phone': '+15145550101',
    'instructions': '',
  };
  if (quote) {
    d.data['quote'] = testQuote();
    d.data['accepted'] = true;
  }
  return d;
}

class TestBookingApi implements BookingApi {
  final List<String> calls = [];
  final List<Map<String, dynamic>> payloads = [];
  Object? quoteError, createError;
  Duration delay = Duration.zero;
  bool cardReady = true;
  bool configurationAvailable = true;
  List<String> reasons = [];
  Map<String, dynamic> quote = testQuote();
  @override
  Future<Map<String, dynamic>?> profile() async => null;
  @override
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> data = const {},
  ]) async {
    calls.add(name);
    payloads.add(data);
    switch (name) {
      case 'getBookingConfiguration':
        if (!configurationAvailable) return {'policy': null};
        return {
          'policy': {
            'approved': true,
            'version': 'TEST',
            'terms_url': 'https://example.invalid/terms',
            'privacy_url': 'https://example.invalid/privacy',
            'cancellation_text': {'fr': 'TEST: politique'},
            'payment_text': {'fr': 'TEST: paiement'},
            'setup_enabled': true,
          },
        };
      case 'getBookingDraft':
        return {'draft': null};
      case 'getBookingQuote':
        return quote;
      case 'getBookingCardStatus':
        return {'ready': cardReady};
      case 'reviewDeliveryLoad':
        return {
          'status': reasons.isEmpty ? 'ready' : 'review_required',
          'reasons': reasons,
        };
      case 'calculateDeliveryQuote':
        if (quoteError != null) throw quoteError!;
        return quote;
      case 'createDeliveryRequest':
        await Future<void>.delayed(delay);
        if (createError != null) throw createError!;
        return {'missionId': 'test_mission'};
      default:
        return {'saved': true};
    }
  }
}

Future<void> pumpBooking(
  WidgetTester tester, {
  required MemoryBookingStorage storage,
  required TestBookingApi api,
  BookingTestAuth? auth,
  String locale = 'fr',
}) async {
  SharedPreferences.setMockInitialValues({});
  final provider = auth ?? BookingTestAuth();
  final router = GoRouter(
    initialLocation: '/$locale/livraison/demande',
    routes: [
      GoRoute(
        path: '/$locale/livraison/demande',
        builder: (_, __) => DeliveryRequestFlowScreen(
          locale: locale,
          api: api,
          storage: storage,
        ),
      ),
      GoRoute(
        path: '/$locale/connexion',
        builder: (_, __) => const Scaffold(body: Text('AUTH_SCREEN')),
      ),
    ],
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
        ChangeNotifierProvider<FirebaseAuthProvider>.value(value: provider),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapBooking(WidgetTester t, String label) async {
  final f = find.text(label).last;
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> disposeBooking(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pumpAndSettle();
}
