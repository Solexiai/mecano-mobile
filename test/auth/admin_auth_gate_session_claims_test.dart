import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:movik_connect/backend/backend_status.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/auth/admin_login_screen.dart';

void main() {
  group('BUG-P8-AUTH-01 — PlatformRole claim parsing', () {
    test('fromClaim parse super_admin and legacy superAdmin', () {
      expect(PlatformRoleX.fromClaim('super_admin'), PlatformRole.superAdmin);
      expect(PlatformRoleX.fromClaim('superAdmin'), PlatformRole.superAdmin);
    });

    test('claimValue sérialise superAdmin en super_admin', () {
      expect(PlatformRole.superAdmin.claimValue, 'super_admin');
      expect(PlatformRole.admin.claimValue, 'admin');
      expect(PlatformRole.analyst.claimValue, 'analyst');
    });

    test('tryFromClaim couvre les rôles attendus et échoue sans privilège sur valeur inconnue', () {
      expect(PlatformRoleX.tryFromClaim('customer'), PlatformRole.customer);
      expect(PlatformRoleX.tryFromClaim('driver'), PlatformRole.driver);
      expect(PlatformRoleX.tryFromClaim('mechanic'), PlatformRole.mechanic);
      expect(PlatformRoleX.tryFromClaim('analyst'), PlatformRole.analyst);
      expect(PlatformRoleX.tryFromClaim('admin'), PlatformRole.admin);
      expect(
        PlatformRoleX.tryFromClaim('super_admin'),
        PlatformRole.superAdmin,
      );
      expect(PlatformRoleX.tryFromClaim('unknown_role'), isNull);
    });

    test('super_admin accorde bien les flags isSuperAdmin/isAdminOrAbove/isAnalystOrAbove', () {
      final auth = FirebaseAuthProvider(backendConfigured: false)
        ..debugForceRoles = [PlatformRoleX.fromClaim('super_admin')];

      expect(auth.isSuperAdmin, isTrue);
      expect(auth.isAdminOrAbove, isTrue);
      expect(auth.isAnalystOrAbove, isTrue);
    });

    test(
      'admin, analyst et customer conservent leurs permissions attendues',
      () {
        final analyst = FirebaseAuthProvider(backendConfigured: false)
          ..debugForceRoles = [PlatformRoleX.fromClaim('analyst')];
        expect(analyst.isSuperAdmin, isFalse);
        expect(analyst.isAdminOrAbove, isFalse);
        expect(analyst.isAnalystOrAbove, isTrue);

        final admin = FirebaseAuthProvider(backendConfigured: false)
          ..debugForceRoles = [PlatformRoleX.fromClaim('admin')];
        expect(admin.isSuperAdmin, isFalse);
        expect(admin.isAdminOrAbove, isTrue);
        expect(admin.isAnalystOrAbove, isTrue);

        final customer = FirebaseAuthProvider(backendConfigured: false)
          ..debugForceRoles = [PlatformRoleX.fromClaim('customer')];
        expect(customer.isSuperAdmin, isFalse);
        expect(customer.isAdminOrAbove, isFalse);
        expect(customer.isAnalystOrAbove, isFalse);
      },
    );
  });

  group('BUG-P8-AUTH-01 — AdminAuthGate', () {
    Widget wrap(FirebaseAuthProvider auth) {
      return MultiProvider(
        providers: [
          Provider<BackendStatus>.value(value: const BackendStatus.ready()),
          ChangeNotifierProvider<FirebaseAuthProvider>.value(value: auth),
          ChangeNotifierProvider<LocaleProvider>(
            create: (_) => LocaleProvider(),
          ),
        ],
        child: MaterialApp(
          home: AdminAuthGate(
            child: const Scaffold(body: Text('ADMIN_DASHBOARD_CONTENT')),
          ),
        ),
      );
    }

    testWidgets(
      'un utilisateur avec claim super_admin accède au dashboard admin',
      (tester) async {
        final auth = FirebaseAuthProvider(backendConfigured: false)
          ..debugForceSignedIn = true
          ..debugForceClaimsLoaded = true
          ..debugForceClaimsFetchFailed = false
          ..debugForceRoles = [PlatformRoleX.fromClaim('super_admin')];

        await tester.pumpWidget(wrap(auth));
        await tester.pumpAndSettle();

        expect(find.text('ADMIN_DASHBOARD_CONTENT'), findsOneWidget);
        expect(find.byType(AdminLoginScreen), findsNothing);
        expect(find.byIcon(Icons.logout), findsOneWidget);
      },
    );
  });
}
