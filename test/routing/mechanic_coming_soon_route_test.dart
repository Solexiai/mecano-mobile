// CLI-07 (2026-10-28) : les adresses de la mécanique mobile affichent la page
// « Bientôt disponible » (FR/EN/ES), plus le formulaire démo.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movik_connect/backend/backend_status.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/router/app_router.dart';

Widget _wrap(FirebaseAuthProvider auth) => MultiProvider(
  providers: [
    Provider<BackendStatus>.value(value: const BackendStatus.notConfigured()),
    ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
    ChangeNotifierProvider<FirebaseAuthProvider>.value(value: auth),
  ],
  child: MaterialApp.router(routerConfig: AppRouter.router),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final (path, title) in [
    ('/fr/mecanique-mobile', 'Bientôt disponible'),
    ('/fr/mecanique-mobile/demande', 'Bientôt disponible'),
    ('/fr/devenir-mecanicien', 'Bientôt disponible'),
    ('/fr/devenir-mecanicien/inscription', 'Bientôt disponible'),
    ('/en/mobile-mechanic', 'Coming soon'),
    ('/en/become-mechanic', 'Coming soon'),
    ('/es/mecanico-movil', 'Próximamente'),
    ('/es/convertirse-mecanico', 'Próximamente'),
  ]) {
    testWidgets('$path -> page « $title »', (tester) async {
      AppRouter.router.go(path);
      await tester.pumpWidget(_wrap(FirebaseAuthProvider(backendConfigured: false)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('coming-soon-mechanic')), findsOneWidget);
      expect(find.text(title), findsWidgets);
      expect(find.byType(TextFormField), findsNothing);
    });
  }
}
