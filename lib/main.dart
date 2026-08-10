import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'providers/locale_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/delivery_provider.dart';
import 'providers/mechanic_provider.dart';
import 'providers/review_provider.dart';
import 'router/app_router.dart';
import 'services/storage_service.dart';
import 'backend/backend_bootstrap.dart';
import 'backend/backend_status.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
