import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/widgets/app_shell.dart';
import '../helpers/gps_offline_transport.dart';

class LogoutAuth extends FirebaseAuthProvider {
  LogoutAuth() : super(backendConfigured: false) {
    debugForceSignedIn = true;
  }
  Completer<void>? pending;
  bool fail = false;
  int calls = 0;
  @override
  Future<void> signOut() async {
    calls++;
    if (pending != null) await pending!.future;
    if (fail) throw StateError('PRIVATE_TEST_ERROR');
    debugForceSignedIn = false;
    notifyListeners();
  }
}

void main() => offlineTests(() {
  for (final locale in ['fr', 'en', 'es']) {
    for (final mobile in [false, true]) {
      for (final fails in [false, true]) {
        offlineWidgetTest('logout $locale mobile=$mobile fails=$fails', (
          t,
        ) async {
          SharedPreferences.setMockInitialValues({});
          t.view.devicePixelRatio = 1;
          t.view.physicalSize = mobile
              ? const Size(375, 812)
              : const Size(1440, 900);
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          final auth = LogoutAuth()..fail = fails;
          auth.pending = Completer<void>();
          final locales = LocaleProvider();
          final router = GoRouter(
            initialLocation: '/$locale/livraison/demande',
            routes: [
              GoRoute(
                path: '/$locale',
                builder: (_, _) => const Scaffold(body: Text('HOME')),
              ),
              GoRoute(
                path: '/$locale/livraison/demande',
                builder: (_, _) => AppShell(
                  locale: locale,
                  showFooter: false,
                  child: const Text('FORM'),
                ),
              ),
            ],
          );
          await t.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<FirebaseAuthProvider>.value(value: auth),
                ChangeNotifierProvider<LocaleProvider>.value(value: locales),
              ],
              child: MaterialApp.router(routerConfig: router),
            ),
          );
          await t.pumpAndSettle();
          if (mobile) {
            await t.tap(find.byKey(const Key('public-navigation-menu')));
          } else {
            await t.tap(find.byKey(const Key('public-account-menu')));
          }
          await t.pumpAndSettle();
          final logout = find.text(locales.t('nav_logout')).last;
          await t.ensureVisible(logout);
          await t.pumpAndSettle();
          await t.tap(logout);
          await t.pumpAndSettle();
          expect(auth.calls, 1);
          expect(
            router.routeInformationProvider.value.uri.path,
            '/$locale/livraison/demande',
          );
          auth.pending!.complete();
          await t.pumpAndSettle();
          if (fails) {
            expect(auth.isSignedIn, isTrue);
            expect(
              router.routeInformationProvider.value.uri.path,
              '/$locale/livraison/demande',
            );
            final message = {
              'fr': 'Déconnexion impossible pour le moment. Réessayez.',
              'en': 'Unable to sign out right now. Please try again.',
              'es': 'No se puede cerrar sesión ahora. Inténtalo de nuevo.',
            }[locale]!;
            expect(find.text(message), findsOneWidget);
            expect(find.textContaining('PRIVATE_TEST_ERROR'), findsNothing);
          } else {
            expect(auth.isSignedIn, isFalse);
            expect(router.routeInformationProvider.value.uri.path, '/$locale');
            expect(find.text('HOME'), findsOneWidget);
            expect(find.byType(Drawer), findsNothing);
          }
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
          await t.pumpAndSettle();
          router.dispose();
          auth.dispose();
          locales.dispose();
        });
      }
    }
  }
});
