import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/link.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/router/app_router.dart';
import '../helpers/gps_offline_transport.dart';
import 'public_launch_pages_test.dart' show wrapPublicPage;

void main() {
  for (final locale in ['fr', 'en', 'es']) {
    for (final scale in [1.0, 2.0]) {
      offlineWidgetTest('official contact $locale scale $scale', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        await tester.binding.setSurfaceSize(const Size(375, 812));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final auth = FirebaseAuthProvider(backendConfigured: false);
        AppRouter.router.go('/$locale/contact');
        await tester.pumpWidget(wrapPublicPage(auth, textScale: scale));
        await tester.pumpAndSettle();
        expect(find.text('info@movi-k.com'), findsOneWidget);
        final links = tester.widgetList<Link>(find.byType(Link));
        expect(
          links.any((link) => link.uri.toString() == 'mailto:info@movi-k.com'),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
