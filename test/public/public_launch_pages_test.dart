import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movik_connect/backend/backend_status.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/router/app_router.dart';

Widget _wrap(FirebaseAuthProvider auth, {double textScale = 1}) =>
    MultiProvider(
      providers: [
        Provider<BackendStatus>.value(value: BackendStatus.notConfigured()),
        ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
        ChangeNotifierProvider<FirebaseAuthProvider>.value(value: auth),
      ],
      child: MaterialApp.router(
        routerConfig: AppRouter.router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  for (final locale in ['fr', 'en', 'es']) {
    testWidgets('Granby QR route renders in $locale without overflow', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final auth = FirebaseAuthProvider(backendConfigured: false);
      AppRouter.router.go('/$locale/granby');
      await tester.pumpWidget(_wrap(auth));
      await tester.pumpAndSettle();

      expect(find.textContaining('Granby'), findsWidgets);
      expect(find.byType(ElevatedButton), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  for (final locale in ['fr', 'en', 'es']) {
    testWidgets('public launch pages render in $locale', (tester) async {
      final auth = FirebaseAuthProvider(backendConfigured: false);
      await tester.pumpWidget(_wrap(auth));

      for (final suffix in [
        'livraison',
        'devenir-chauffeur',
        'tarifs',
        'comment-ca-marche',
        'securite',
        'faq',
        'a-propos',
        'granby',
      ]) {
        AppRouter.router.go('/$locale/$suffix');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '/$locale/$suffix');
      }
    });
  }

  testWidgets('public launch information pages render without stale claims', (
    tester,
  ) async {
    final auth = FirebaseAuthProvider(backendConfigured: false);
    await tester.pumpWidget(_wrap(auth));

    for (final path in [
      '/fr/livraison',
      '/fr/devenir-chauffeur',
      '/fr/tarifs',
      '/fr/comment-ca-marche',
      '/fr/securite',
      '/fr/faq',
      '/fr/contact',
      '/fr/a-propos',
      '/fr/legal/privacy',
      '/fr/legal/terms',
      '/fr/legal/cancellation',
      '/fr/legal/dispute',
      '/fr/granby',
    ]) {
      AppRouter.router.go(path);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: path);
    }

    AppRouter.router.go('/fr/tarifs');
    await tester.pumpAndSettle();
    expect(find.textContaining('8%'), findsNothing);
    expect(
      find.textContaining('modalités de paiement en production'),
      findsOneWidget,
    );
    final pricingAction = find.byKey(const Key('pricing-start-request'));
    await tester.ensureVisible(pricingAction);
    await tester.tap(pricingAction);
    await tester.pumpAndSettle();
    expect(
      AppRouter.router.routeInformationProvider.value.uri.path,
      '/fr/livraison/demande',
    );
    expect(find.text('Organisez votre livraison'), findsOneWidget);

    AppRouter.router.go('/fr/faq');
    await tester.pumpAndSettle();
    final timeQuestion = find.text('Puis-je choisir une heure ou un créneau ?');
    await tester.ensureVisible(timeQuestion);
    await tester.tap(timeQuestion);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('ne propose pas encore de programmation'),
      findsNothing,
    );
    expect(
      find.textContaining('une date et une heure souhaitées'),
      findsOneWidget,
    );

    AppRouter.router.go('/fr/comment-ca-marche');
    await tester.pumpAndSettle();
    expect(find.textContaining('comparer les chauffeurs'), findsNothing);
    expect(find.textContaining('Un chauffeur accepte'), findsOneWidget);

    AppRouter.router.go('/fr/devenir-chauffeur');
    await tester.pumpAndSettle();
    expect(find.textContaining('Fixez vos tarifs'), findsNothing);
    expect(find.textContaining('Aucun revenu n’est garanti'), findsOneWidget);

    AppRouter.router.go('/fr/a-propos');
    await tester.pumpAndSettle();
    expect(find.textContaining('en quelques minutes'), findsNothing);
    expect(find.textContaining('Québec et du Canada'), findsNothing);
    expect(find.textContaining('Lancement prévu à Granby'), findsOneWidget);

    AppRouter.router.go('/fr/legal/cancellation');
    await tester.pumpAndSettle();
    expect(find.textContaining('2 heures'), findsNothing);
    expect(find.textContaining('Politique en révision'), findsOneWidget);

    AppRouter.router.go('/fr/legal/terms');
    await tester.pumpAndSettle();
    expect(find.textContaining('mécaniciens mobiles'), findsNothing);
    expect(find.textContaining('lancement à Granby'), findsOneWidget);

    AppRouter.router.go('/fr/legal/dispute');
    await tester.pumpAndSettle();
    expect(find.textContaining('Contactez le soutien'), findsNothing);
    expect(find.textContaining('encore en préparation'), findsOneWidget);
    expect(find.textContaining('remboursement partiel'), findsNothing);
  });

  final localizedPublicPaths = <String, List<String>>{
    'fr': [
      'livraison',
      'devenir-chauffeur',
      'tarifs',
      'comment-ca-marche',
      'securite',
      'faq',
      'contact',
      'legal/privacy',
      'legal/terms',
      'legal/cancellation',
    ],
    'en': [
      'delivery',
      'become-driver',
      'pricing',
      'how-it-works',
      'safety',
      'faq',
      'contact',
      'legal/privacy',
      'legal/terms',
      'legal/cancellation',
    ],
    'es': [
      'entrega',
      'convertirse-conductor',
      'precios',
      'como-funciona',
      'seguridad',
      'faq',
      'contacto',
      'legal/privacy',
      'legal/terms',
      'legal/cancellation',
    ],
  };

  for (final entry in localizedPublicPaths.entries) {
    for (final width in [320.0, 390.0, 768.0, 1280.0]) {
      testWidgets('public navigation pages render in ${entry.key} at $width', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final auth = FirebaseAuthProvider(backendConfigured: false);
        await tester.pumpWidget(_wrap(auth, textScale: width == 320 ? 2 : 1));

        for (final path in entry.value) {
          AppRouter.router.go('/${entry.key}/$path');
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '/${entry.key}/$path');
        }
      });
    }
  }

  for (final width in [320.0, 390.0, 768.0, 1280.0]) {
    testWidgets('Granby QR route has no overflow at $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final auth = FirebaseAuthProvider(backendConfigured: false);
      AppRouter.router.go('/fr/granby');
      await tester.pumpWidget(_wrap(auth));
      await tester.pumpAndSettle();
      expect(find.textContaining('Granby'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Granby QR route supports 200% text on phone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = FirebaseAuthProvider(backendConfigured: false);
    AppRouter.router.go('/fr/granby');
    await tester.pumpWidget(_wrap(auth, textScale: 2));
    await tester.pumpAndSettle();
    expect(find.textContaining('Granby'), findsWidgets);
    final launchText = tester.element(find.textContaining('Granby').first);
    expect(MediaQuery.textScalerOf(launchText).scale(16), 32);
    expect(tester.takeException(), isNull);
  });
}
