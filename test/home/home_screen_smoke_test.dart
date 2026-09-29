import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movik_connect/core/app_theme.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/home/home_screen.dart';

Widget _app() => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LocaleProvider()),
    ChangeNotifierProvider(
      create: (_) => FirebaseAuthProvider(backendConfigured: false),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    home: const HomeScreen(locale: 'fr'),
  ),
);

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('homepage renders on desktop without layout exception', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1440, 1000));
    await tester.pumpWidget(_app());
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('Faites livrer ce qui ne rentre pas dans votre véhicule.'),
      findsOneWidget,
    );
    expect(find.text('Tout ce que vous pouvez faire livrer'), findsOneWidget);
    expect(find.text('Obtenir mon devis  →'), findsWidgets);
  });

  testWidgets('homepage renders on phone without layout exception', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 844));
    await tester.pumpWidget(_app());
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('Faites livrer ce qui ne rentre pas dans votre véhicule.'),
      findsOneWidget,
    );
    expect(find.text('Devenir chauffeur'), findsWidgets);
  });
}
