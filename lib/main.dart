import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/url_strategy_stub.dart' if (dart.library.html) 'core/url_strategy_web.dart';

import 'core/app_theme.dart';
import 'providers/locale_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/firebase_auth_provider.dart';
import 'providers/delivery_provider.dart';
import 'providers/mechanic_provider.dart';
import 'providers/review_provider.dart';
import 'router/app_router.dart';
import 'services/storage_service.dart';
import 'backend/backend_bootstrap.dart';
import 'backend/backend_status.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure le routage par chemin réel sur Flutter Web uniquement (voir
  // core/url_strategy_web.dart) ; no-op sur mobile/VM (voir
  // core/url_strategy_stub.dart, sélectionné par l'import conditionnel
  // ci-dessus). Ce détour évite d'importer `flutter_web_plugins`
  // (qui dépend de `dart:ui_web`, absente de la plateforme VM utilisée par
  // `flutter test`) de façon inconditionnelle depuis main.dart, ce qui
  // faisait échouer TOUTE la suite de tests widget (`flutter test`) avec
  // une erreur de compilation "Dart library 'dart:ui_web' is not available
  // on this platform".
  configureUrlStrategy();

  await StorageService.init();

  // Tentative d'initialisation Firebase, sans jamais faire crasher l'app si
  // aucun projet réel n'est encore configuré (voir backend_bootstrap.dart).
  final backendStatus = await BackendBootstrap.initialize();

  runApp(MovikApp(backendStatus: backendStatus));
}

class MovikApp extends StatelessWidget {
  final BackendStatus backendStatus;

  const MovikApp({super.key, required this.backendStatus});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<BackendStatus>.value(value: backendStatus),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(
          create: (_) => FirebaseAuthProvider(
            backendConfigured: backendStatus.isConfigured,
          ),
        ),
        ChangeNotifierProvider(create: (_) => DeliveryProvider()),
        ChangeNotifierProvider(create: (_) => MechanicRequestProvider()),
        ChangeNotifierProvider(create: (_) => ReviewProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp.router(
            title: 'Movi-k',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themeProvider.themeMode,
            routerConfig: AppRouter.router,
          );
        },
      ),
    );
  }
}
