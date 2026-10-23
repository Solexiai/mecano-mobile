// 2026-10-23: the public legal pages show the same published text the
// customer accepts when booking; the hand-written text is only a fallback.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/legal/legal_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/booking_test_harness.dart';

Future<void> pumpLegal(
  WidgetTester t,
  String type,
  LegalPolicyLoader loader,
) async {
  SharedPreferences.setMockInitialValues({});
  final router = GoRouter(
    initialLocation: '/fr/legal/$type',
    routes: [
      GoRoute(
        path: '/fr/legal/:type',
        builder: (_, s) => LegalScreen(
          locale: 'fr',
          type: s.pathParameters['type']!,
          policyLoader: loader,
        ),
      ),
    ],
  );
  await t.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
        ChangeNotifierProvider<FirebaseAuthProvider>.value(
          value: FirebaseAuthProvider(backendConfigured: false),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  for (final (type, key) in [
    ('cancellation', 'booking'),
    ('terms', 'terms'),
    ('privacy', 'privacy'),
  ]) {
    testWidgets('/legal/$type shows the published $key document', (t) async {
      await pumpLegal(t, type, () async => testBookingPolicy());
      expect(find.byKey(const ValueKey('legal-published')), findsOneWidget);
      expect(find.textContaining('SIMULATION $key TEST'), findsOneWidget);
      expect(find.textContaining('Version TEST-$key'), findsOneWidget);
      expect(find.textContaining('en révision'), findsNothing);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('no published policy: the fallback page is shown', (t) async {
    await pumpLegal(t, 'cancellation', () async => null);
    expect(find.byKey(const ValueKey('legal-published')), findsNothing);
    expect(find.textContaining("Politique d'annulation"), findsWidgets);
    expect(t.takeException(), isNull);
  });

  testWidgets('loading error: the fallback page is shown, never a blank page', (
    t,
  ) async {
    await pumpLegal(t, 'terms', () async => throw StateError('offline'));
    expect(find.byKey(const ValueKey('legal-published')), findsNothing);
    expect(find.textContaining("Conditions d'utilisation"), findsWidgets);
    expect(t.takeException(), isNull);
  });
}
