import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movik_connect/l10n/app_strings.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/delivery/delivery_request_flow_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'guest sign-in button opens auth instead of popping to home',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/fr',
        routes: [
          GoRoute(
            path: '/fr',
            builder: (context, state) => Scaffold(
              body: ElevatedButton(
                onPressed: () => context.push('/fr/livraison/demande'),
                child: const Text('OPEN_REQUEST'),
              ),
            ),
          ),
          GoRoute(
            path: '/fr/livraison/demande',
            builder: (context, state) =>
                const DeliveryRequestFlowScreen(locale: 'fr'),
          ),
          GoRoute(
            path: '/fr/connexion',
            builder: (context, state) =>
                const Scaffold(body: Text('AUTH_SCREEN')),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => LocaleProvider()),
            ChangeNotifierProvider(
              create: (_) => FirebaseAuthProvider(backendConfigured: false),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('OPEN_REQUEST'));
      await tester.pumpAndSettle();

      final signIn = find.text(
        AppStrings.t('delivery_sign_in_button', 'fr'),
      );
      expect(signIn, findsOneWidget);

      await tester.tap(signIn);
      await tester.pumpAndSettle();

      expect(find.text('AUTH_SCREEN'), findsOneWidget);
      expect(find.text('OPEN_REQUEST'), findsNothing);
    },
  );
}
