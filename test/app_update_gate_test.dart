// Mise à jour dans l'app (2026-11-06) : le widget qui enveloppe l'app.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/services/app_update/app_update_checker.dart';
import 'package:movik_connect/services/app_update/app_version_policy.dart';
import 'package:movik_connect/widgets/app_update_gate.dart';

class _Checker implements AppUpdateChecker {
  _Checker(this.availability, {this.immediateResult = AppUpdateLaunch.success});
  AppUpdateAvailability availability;
  AppUpdateLaunch immediateResult;
  final steps = StreamController<AppUpdateInstallStep>.broadcast();
  int checks = 0, immediates = 0, flexibles = 0, completes = 0;

  @override
  Future<AppUpdateAvailability> check() async {
    checks++;
    return availability;
  }

  @override
  Future<AppUpdateLaunch> startImmediate() async {
    immediates++;
    return immediateResult;
  }

  @override
  Future<AppUpdateLaunch> startFlexible() async {
    flexibles++;
    return AppUpdateLaunch.success;
  }

  @override
  Future<void> completeFlexible() async => completes++;

  @override
  Stream<AppUpdateInstallStep> get installSteps => steps.stream;
}

const _newer = AppUpdateAvailability(
  available: true,
  immediateAllowed: true,
  flexibleAllowed: true,
  availableBuild: 11,
);

Widget _app(AppUpdateChecker? checker, {int minBuild = 0, int? installed = 10}) => MaterialApp(
  home: AppUpdateGate(
    // Clé unique : un second pumpWidget dans le même test doit recréer l'état.
    key: ValueKey(checker),
    checker: checker,
    loadPolicy: () async => AppVersionPolicy(androidMinBuild: minBuild),
    installedBuild: () async => installed,
    child: const Scaffold(body: Text('APP')),
  ),
);

void main() {
  testWidgets('sans checker (web, tests) : rien ne change', (t) async {
    await t.pumpWidget(_app(null, minBuild: 99));
    await t.pumpAndSettle();
    expect(find.text('APP'), findsOneWidget);
    expect(find.byKey(const ValueKey('app-update-required')), findsNothing);
  });

  testWidgets('aucune mise à jour sur Play : rien ne change', (t) async {
    final c = _Checker(AppUpdateAvailability.none);
    await t.pumpWidget(_app(c, minBuild: 99));
    await t.pumpAndSettle();
    expect(c.checks, 1);
    expect(c.immediates, 0);
    expect(c.flexibles, 0);
    expect(find.byKey(const ValueKey('app-update-required')), findsNothing);
  });

  testWidgets('version plus récente, build au-dessus du minimum : téléchargement souple puis bandeau Redémarrer', (t) async {
    final c = _Checker(_newer);
    await t.pumpWidget(_app(c, minBuild: 9, installed: 10));
    await t.pumpAndSettle();
    expect(c.flexibles, 1);
    expect(c.immediates, 0);
    expect(find.byKey(const ValueKey('app-update-banner')), findsNothing);
    // L'évènement est livré dans une microtâche : deux pumps (livraison, puis image).
    c.steps.add(AppUpdateInstallStep.downloading);
    await t.pump();
    await t.pump();
    expect(find.byKey(const ValueKey('app-update-banner')), findsNothing);
    c.steps.add(AppUpdateInstallStep.downloaded);
    await t.pump();
    await t.pump();
    expect(find.byKey(const ValueKey('app-update-banner')), findsOneWidget);
    expect(find.text('Une nouvelle version de Movi-K est prête.'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('app-update-restart')));
    await t.pump();
    expect(c.completes, 1);
    await t.tap(find.byKey(const ValueKey('app-update-later')));
    await t.pump();
    expect(find.byKey(const ValueKey('app-update-banner')), findsNothing);
    expect(find.text('APP'), findsOneWidget);
  });

  testWidgets('build sous le minimum : mise à jour immédiate ; refusée => écran bloquant, puis réessai', (t) async {
    final c = _Checker(_newer, immediateResult: AppUpdateLaunch.userDenied);
    await t.pumpWidget(_app(c, minBuild: 11, installed: 10));
    await t.pumpAndSettle();
    expect(c.immediates, 1);
    expect(c.flexibles, 0);
    expect(find.byKey(const ValueKey('app-update-required')), findsOneWidget);
    expect(find.text('Mise à jour requise'), findsOneWidget);
    // Le bouton relance l'écran Google ; accepté => l'app redémarre (pas de blocage).
    c.immediateResult = AppUpdateLaunch.success;
    await t.tap(find.byKey(const ValueKey('app-update-required-button')));
    await t.pumpAndSettle();
    expect(c.immediates, 2);
    expect(find.byKey(const ValueKey('app-update-required')), findsNothing);
  });

  testWidgets('build sous le minimum mais immédiat interdit par Play : écran bloquant sans appel', (t) async {
    final c = _Checker(
      const AppUpdateAvailability(available: true, immediateAllowed: false, flexibleAllowed: true, availableBuild: 11),
    );
    await t.pumpWidget(_app(c, minBuild: 11, installed: 10));
    await t.pumpAndSettle();
    expect(c.immediates, 0);
    expect(find.byKey(const ValueKey('app-update-required')), findsOneWidget);
  });

  testWidgets('build inconnu ou minimum à 0 : jamais de blocage', (t) async {
    final a = _Checker(_newer, immediateResult: AppUpdateLaunch.userDenied);
    await t.pumpWidget(_app(a, minBuild: 11, installed: null));
    await t.pumpAndSettle();
    expect(a.immediates, 0);
    expect(a.flexibles, 1);
    final b = _Checker(_newer, immediateResult: AppUpdateLaunch.userDenied);
    await t.pumpWidget(_app(b, minBuild: 0, installed: 1));
    await t.pumpAndSettle();
    expect(b.immediates, 0);
    expect(b.flexibles, 1);
    expect(find.byKey(const ValueKey('app-update-required')), findsNothing);
  });

  testWidgets('Play injoignable : l’app démarre normalement', (t) async {
    final c = _Checker(_newer);
    await t.pumpWidget(
      MaterialApp(
        home: AppUpdateGate(
          checker: _Throwing(),
          loadPolicy: () async => const AppVersionPolicy(androidMinBuild: 99),
          installedBuild: () async => 1,
          child: const Scaffold(body: Text('APP')),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(c.immediates, 0);
    expect(find.text('APP'), findsOneWidget);
    expect(find.byKey(const ValueKey('app-update-required')), findsNothing);
  });
}

class _Throwing implements AppUpdateChecker {
  @override
  Future<AppUpdateAvailability> check() async => throw StateError('no play');
  @override
  Future<AppUpdateLaunch> startImmediate() async => throw StateError('no play');
  @override
  Future<AppUpdateLaunch> startFlexible() async => throw StateError('no play');
  @override
  Future<void> completeFlexible() async {}
  @override
  Stream<AppUpdateInstallStep> get installSteps => const Stream.empty();
}
