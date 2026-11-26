// 2026-11-22 (Daniel) : un visiteur qui demande son prix sans compte arrive
// sur l'écran de connexion. C'est presque toujours un nouveau client : on lui
// présente « Créer un compte » d'emblée, sans le choix client / chauffeur.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/router/delivery_request_intent.dart';
import 'package:movik_connect/screens/auth/auth_screen.dart';

Widget _auth({String? returnTo}) => MultiProvider(
  providers: [
    ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
    ChangeNotifierProvider<FirebaseAuthProvider>(
      create: (_) => FirebaseAuthProvider(backendConfigured: false),
    ),
  ],
  child: MaterialApp.router(
    routerConfig: GoRouter(
      initialLocation: '/fr/connexion',
      routes: [
        GoRoute(
          path: '/fr/connexion',
          builder: (c, s) => AuthScreen(locale: 'fr', returnTo: returnTo),
        ),
      ],
    ),
  ),
);

void main() {
  test('isBookingReturn : seulement la demande de livraison', () {
    expect(DeliveryRequestIntent.isBookingReturn('/fr/livraison/demande', 'fr'), isTrue);
    expect(
      DeliveryRequestIntent.isBookingReturn('/fr/livraison/demande?category=furniture', 'fr'),
      isTrue,
    );
    expect(DeliveryRequestIntent.isBookingReturn('/fr/tableau-de-bord', 'fr'), isFalse);
    expect(DeliveryRequestIntent.isBookingReturn('https://exemple.com/fr/livraison/demande', 'fr'), isFalse);
    expect(DeliveryRequestIntent.isBookingReturn(null, 'fr'), isFalse);
  });

  testWidgets('depuis la demande : « Créer un compte » d’emblée, sans choix de profil', (t) async {
    await t.pumpWidget(_auth(returnTo: '/fr/livraison/demande'));
    await t.pumpAndSettle();
    expect(find.text('Créez votre compte pour voir votre prix'), findsOneWidget);
    expect(find.text('Nom complet'), findsOneWidget);
    expect(find.text('Choisissez votre profil'), findsNothing);
    // La personne qui a déjà un compte peut toujours se connecter.
    expect(find.text('Se connecter'), findsWidgets);
    expect(find.text('Créer un compte'), findsWidgets);
  });

  testWidgets('connexion ordinaire : inchangée', (t) async {
    await t.pumpWidget(_auth());
    await t.pumpAndSettle();
    expect(find.text('Bienvenue sur Movi-k'), findsOneWidget);
    expect(find.text('Choisissez votre profil'), findsOneWidget);
    expect(find.text('Nom complet'), findsNothing);
  });
}
