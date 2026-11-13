// 2026-11-13 (propriétaire) : la page « Devenir chauffeur » s'ouvre sur le
// gain (fourchette annoncée aux recrues), montre les étapes de l'inscription
// et garde « Aucun revenu n'est garanti ».
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/router/app_router.dart';
import '../helpers/gps_offline_transport.dart';
import 'public_launch_pages_test.dart' show wrapPublicPage;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    expect(Firebase.apps, isEmpty);
  });
  tearDown(() => expect(Firebase.apps, isEmpty));

  for (final view in [
    (375.0, 812.0, 1.0),
    (375.0, 812.0, 2.0),
    (1440.0, 900.0, 1.0),
  ]) {
    offlineWidgetTest('driver page opens on earnings $view', (tester) async {
      await tester.binding.setSurfaceSize(Size(view.$1, view.$2));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final auth = FirebaseAuthProvider(backendConfigured: false);
      AppRouter.router.go('/fr/devenir-chauffeur');
      await tester.pumpWidget(wrapPublicPage(auth, textScale: view.$3));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Gagnez environ 80 \$ à 120 \$ par livraison avec votre pick-up ou votre fourgon.',
        ),
        findsOneWidget,
      );
      expect(find.text('Ce que vous gagnez'), findsOneWidget);
      expect(find.text('100 % des pourboires'), findsOneWidget);
      expect(find.text('Activez vos paiements avec Stripe'), findsOneWidget);
      for (var step = 1; step <= 4; step++) {
        expect(
          find.byKey(ValueKey('driver-landing-step-$step')),
          findsOneWidget,
        );
      }
      expect(find.textContaining('Aucun revenu n’est garanti'), findsOneWidget);
      expect(find.textContaining('configuration'), findsNothing);
      expect(find.textContaining('dossier chauffeur'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
