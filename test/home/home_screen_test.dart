import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movik_connect/core/app_theme.dart';
import 'package:movik_connect/l10n/home_copy.dart';
import 'package:movik_connect/l10n/app_strings.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/router/delivery_request_intent.dart';
import 'package:movik_connect/screens/home/home_screen.dart';
import 'package:movik_connect/screens/auth/auth_screen.dart';
import 'package:movik_connect/screens/delivery/delivery_request_flow_screen.dart';
import 'package:movik_connect/screens/info/contact_screen.dart';

class HomeTestAuth extends FirebaseAuthProvider {
  HomeTestAuth() : super(backendConfigured: false);
  void completeSignIn() { debugForceSignedIn = true; debugForceUid = 'home-test'; debugForceRoles = [PlatformRole.customer]; notifyListeners(); }
}

Future<(GoRouter, HomeTestAuth)> mountHome(WidgetTester tester, {String locale = 'fr', double width = 390, double scale = 1, bool dark = false, List<PlatformRole>? roles}) async {
  await tester.binding.setSurfaceSize(Size(width, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final auth = HomeTestAuth();
  if (roles != null) { auth.debugForceSignedIn = true; auth.debugForceUid = 'home-test'; auth.debugForceRoles = roles; }
  final router = GoRouter(initialLocation: '/$locale', routes: [
    GoRoute(path: '/$locale', builder: (_, _) => HomeScreen(locale: locale)),
    GoRoute(path: '/$locale/livraison/demande', builder: (_, s) => DeliveryRequestFlowScreen(locale: locale, initialCategory: s.uri.queryParameters['category'])),
    GoRoute(path: '/$locale/connexion', builder: (_, s) => AuthScreen(locale: locale, returnTo: s.uri.queryParameters['returnTo'])),
    GoRoute(path: '/$locale/contact', builder: (_, _) => ContactScreen(locale: locale)),
    for (final path in ['livraison', 'devenir-chauffeur', 'faq', 'tarifs', 'comment-ca-marche', 'admin', 'tableau-de-bord', 'fournisseur/tableau-de-bord', 'legal/cancellation', 'legal/privacy', 'legal/terms', 'securite', 'a-propos'])
      GoRoute(path: '/$locale/$path', builder: (_, _) => Scaffold(body: Text(path))),
  ]);
  addTearDown(router.dispose); addTearDown(auth.dispose);
  await tester.pumpWidget(MultiProvider(providers: [
    ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
    ChangeNotifierProvider<FirebaseAuthProvider>.value(value: auth),
  ], child: MaterialApp.router(theme: dark ? AppTheme.dark() : AppTheme.light(), routerConfig: router,
    builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
  )));
  await tester.pumpAndSettle();
  return (router, auth);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final locale in ['fr', 'en', 'es']) {
    test('homepage copy covers $locale without fallback', () {
      for (final entry in HomeCopy.strings.entries) {
        expect(entry.value[locale]?.isNotEmpty, isTrue, reason: entry.key);
        expect(HomeCopy.text(entry.key, locale), entry.value[locale]);
      }
    });
    for (final width in [320.0, 390.0, 768.0, 1280.0]) {
      testWidgets('full homepage $locale at $width has no overflow', (tester) async {
        await mountHome(tester, locale: locale, width: width);
        expect(find.text(HomeCopy.text('title', locale)), findsOneWidget);
        expect(find.textContaining('3+'), findsNothing);
        expect(find.textContaining('demo drivers'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text(HomeCopy.text('final_title', locale)));
        await tester.pumpAndSettle(); expect(tester.takeException(), isNull);
      });
    }
    for (final dark in [false, true]) {
      testWidgets('homepage $locale text at 200%, 320px, dark=$dark', (tester) async {
        await mountHome(tester, locale: locale, width: 320, scale: 2, dark: dark);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text(HomeCopy.text('final_title', locale)));
        await tester.pumpAndSettle(); expect(tester.takeException(), isNull);
      });
    }
    testWidgets('primary action $locale goes directly to existing request', (tester) async {
      final (router, _) = await mountHome(tester, locale: locale);
      await tester.tap(find.byKey(const Key('home-primary-quote'))); await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/$locale/livraison/demande');
      expect(find.byType(DeliveryRequestFlowScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('category survives authentication without a second request route', (tester) async {
    final (router, auth) = await mountHome(tester);
    final category = find.byKey(const Key('home-category-cat_furniture'));
    await tester.ensureVisible(category); await tester.tap(category); await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.queryParameters['category'], 'cat_furniture');
    final button = find.widgetWithText(ElevatedButton, AppStrings.t('delivery_sign_in_button', 'fr'));
    await tester.ensureVisible(button); await tester.tap(button); await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/fr/connexion');
    expect(DeliveryRequestIntent.safeReturnPath(router.routeInformationProvider.value.uri.queryParameters['returnTo'], 'fr'), '/fr/livraison/demande?category=cat_furniture');
    auth.completeSignIn(); await tester.pumpAndSettle();
    await tester.tap(find.text(HomeCopy.text('resume', 'fr'))); await tester.pumpAndSettle();
    final selected = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).where((chip) => chip.selected);
    expect(selected, hasLength(1)); expect((selected.single.label as Text).data, 'Meubles');
    expect(tester.takeException(), isNull);
  });
  testWidgets('anonymous navigation has no administration entry', (tester) async {
    await mountHome(tester);
    await tester.tap(find.byTooltip('Open navigation menu')); await tester.pumpAndSettle();
    expect(find.text('Administration'), findsNothing);
  });
  testWidgets('driver account menu offers the existing driver space only when eligible', (tester) async {
    await mountHome(tester, roles: [PlatformRole.driver]);
    await tester.tap(find.byKey(const Key('public-account-menu'))); await tester.pumpAndSettle();
    expect(find.text(AppStrings.t('nav_provider_space', 'fr')), findsOneWidget);
    expect(find.text('Administration'), findsNothing);
  });
  testWidgets('contact cannot claim a message was sent or show demo coordinates', (tester) async {
    final (router, _) = await mountHome(tester); router.go('/fr/contact'); await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNothing);
    expect(find.textContaining('support@movi-k.demo'), findsNothing);
    expect(find.textContaining('n’envoie actuellement aucun message'), findsOneWidget);
  });
  test('return intent is local, allowlisted and sanitizes category', () {
    expect(DeliveryRequestIntent.path('fr', category: 'cat_furniture'), '/fr/livraison/demande?category=cat_furniture');
    expect(DeliveryRequestIntent.path('fr', category: 'unknown'), '/fr/livraison/demande');
    for (final bad in ['https://example.org', '//example.org', '/fr/admin', '/en/livraison/demande', '/fr/livraison/demande#fragment', '/fr/livraison/demande?next=/fr/admin', '/fr/livraison/demande?category=a&category=b']) {
      expect(DeliveryRequestIntent.safeReturnPath(bad, 'fr'), isNull, reason: bad);
    }
  });
}
