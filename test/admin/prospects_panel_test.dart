// Centre de commande › 7 · Prospects (Daniel, 2026-11-17) : réglage des
// relances et tableau des sources.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/screens/dashboard/admin/command_center/prospects_panel.dart';

void main() {
  testWidgets('relances : sans adresse rien ne part ; l’adresse enregistrée les met en route', (t) async {
    final calls = <Map<String, dynamic>>[];
    var address = '';
    var enabled = true;
    Future<Map<String, dynamic>> api(String fn, Map<String, dynamic> d) async {
      expect(fn, 'adminEmailSettings');
      calls.add(d);
      if (d['action'] == 'save') {
        address = d['postalAddress'] as String;
        enabled = d['followUpsEnabled'] as bool;
      }
      return {
        'postalAddress': address,
        'followUpsEnabled': enabled,
        'ready': enabled && address.length >= 10,
      };
    }

    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: FollowUpSettingsCard(api: api)),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(calls.single, {'action': 'get'});
    expect(find.text('État : aucune relance ne part.'), findsOneWidget);

    await t.enterText(
      find.byKey(const ValueKey('followup-address')),
      ' 123 rue Principale, Granby (Québec) J2G 0A0 ',
    );
    await t.tap(find.byKey(const ValueKey('followup-save')));
    await t.pumpAndSettle();
    expect(calls.last, {
      'action': 'save',
      'postalAddress': '123 rue Principale, Granby (Québec) J2G 0A0',
      'followUpsEnabled': true,
    });
    expect(find.text('État : les relances partent.'), findsOneWidget);
    expect(find.byKey(const ValueKey('followup-saved')), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('followup-enabled')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('followup-save')));
    await t.pumpAndSettle();
    expect(calls.last['followUpsEnabled'], false);
    expect(find.text('État : aucune relance ne part.'), findsOneWidget);
    expect(find.text('Enregistré : les relances sont arrêtées.'), findsOneWidget);
  });

  testWidgets('relances : en lecture seule, pas de bouton', (t) async {
    Future<Map<String, dynamic>> api(String fn, Map<String, dynamic> d) async =>
        {'postalAddress': '', 'followUpsEnabled': true, 'ready': false};
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FollowUpSettingsCard(api: api, canEdit: false),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('followup-save')), findsNothing);
  });

  testWidgets('sources : une ligne par source, avec comptes, prix, réservations et chauffeurs', (t) async {
    t.view.physicalSize = const Size(1280, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final asked = <int>[];
    Future<Map<String, dynamic>> api(String fn, Map<String, dynamic> d) async {
      expect(fn, 'getAcquisitionReport');
      asked.add(d['days'] as int);
      return {
        'days': d['days'],
        'rows': [
          {'channel': 'paid_social', 'label': 'facebook / cpc / nov', 'accounts': 12, 'priced': 7, 'booked': 3, 'drivers': 4},
          {'channel': 'unknown', 'label': '', 'accounts': 0, 'priced': 2, 'booked': 1, 'drivers': 0},
        ],
      };
    }

    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: AcquisitionReportCard(api: api)),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(asked, [30]);
    expect(find.text('Publicité Facebook / Instagram'), findsOneWidget);
    expect(find.text('facebook / cpc / nov'), findsOneWidget);
    expect(find.text('Inconnue (inscrit avant le suivi)'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('sources : période vide et erreur de lecture', (t) async {
    Future<Map<String, dynamic>> empty(String fn, Map<String, dynamic> d) async => {'rows': []};
    await t.pumpWidget(
      MaterialApp(home: Scaffold(body: SingleChildScrollView(child: AcquisitionReportCard(api: empty)))),
    );
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('acquisition-empty')), findsOneWidget);

    Future<Map<String, dynamic>> broken(String fn, Map<String, dynamic> d) async => throw Exception('x');
    await t.pumpWidget(
      MaterialApp(home: Scaffold(body: SingleChildScrollView(child: AcquisitionReportCard(key: UniqueKey(), api: broken)))),
    );
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('acquisition-error')), findsOneWidget);
  });
}
