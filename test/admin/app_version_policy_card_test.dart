// Mise à jour dans l'app (2026-11-06) : la carte « Mise à jour de
// l'application Android » du Centre de commande (6 · Interrupteurs).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/screens/dashboard/admin/command_center/app_version_policy_card.dart';

void main() {
  testWidgets('lecture, installation affichée, enregistrement confirmé quand on monte le minimum', (t) async {
    final calls = <Map<String, dynamic>>[];
    var min = 0;
    Future<Map<String, dynamic>> api(Map<String, dynamic> d) async {
      calls.add(d);
      if (d['action'] == 'save') min = d['android_min_build'] as int;
      return {'android_min_build': min, 'note': d['note'] ?? ''};
    }

    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AppVersionPolicyCard(api: api, installedVersion: () async => '1.0.0 (10)'),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-version-installed')), findsOneWidget);
    expect(find.text('Cette installation : 1.0.0 (10)'), findsOneWidget);
    expect(calls.single['action'], 'get');

    await t.enterText(find.byKey(const ValueKey('app-version-min')), '10');
    await t.enterText(find.byKey(const ValueKey('app-version-note')), 'dépôt 25 \$');
    await t.tap(find.byKey(const ValueKey('app-version-save')));
    await t.pumpAndSettle();
    // Monter le minimum demande une confirmation explicite.
    expect(find.byKey(const ValueKey('app-version-confirm')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('app-version-confirm')));
    await t.pumpAndSettle();
    expect(calls.last, {'action': 'save', 'android_min_build': 10, 'note': 'dépôt 25 \$'});
    expect(find.byKey(const ValueKey('app-version-saved')), findsOneWidget);
    expect(find.textContaining('la version 10 est exigée'), findsOneWidget);

    // Baisser (ou remettre à 0) n'exige pas de confirmation.
    await t.enterText(find.byKey(const ValueKey('app-version-min')), '0');
    await t.tap(find.byKey(const ValueKey('app-version-save')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-version-confirm')), findsNothing);
    expect(calls.last['android_min_build'], 0);
    expect(find.textContaining('aucune version minimale'), findsOneWidget);
  });

  testWidgets('valeur vide refusée sans appel ; lecture seule sans bouton', (t) async {
    var saves = 0;
    Future<Map<String, dynamic>> api(Map<String, dynamic> d) async {
      if (d['action'] == 'save') saves++;
      return {'android_min_build': 3, 'note': ''};
    }

    await t.pumpWidget(
      MaterialApp(home: Scaffold(body: AppVersionPolicyCard(api: api, installedVersion: () async => null))),
    );
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-version-installed')), findsNothing);
    await t.enterText(find.byKey(const ValueKey('app-version-min')), '');
    await t.tap(find.byKey(const ValueKey('app-version-save')));
    await t.pumpAndSettle();
    expect(saves, 0);
    expect(find.byKey(const ValueKey('app-version-error')), findsOneWidget);

    await t.pumpWidget(
      MaterialApp(home: Scaffold(body: AppVersionPolicyCard(api: api, canEdit: false, installedVersion: () async => null))),
    );
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-version-save')), findsNothing);
  });
}
