// PAY-12 (2026-10-27) : l'admin relit la version d'essai préremplie,
// change la version, vérifie puis publie les conditions finales.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/screens/dashboard/admin/admin_booking_policy_screen.dart';

Map<String, dynamic> _policy(String version, {bool trial = false}) => {
  'version': version,
  'approval_reference': trial ? 'Essai' : 'Relecture du 2026-11-01',
  'setup_enabled': true,
  'trial': trial,
  'cancellation_text': {'fr': 'Annulation gratuite avant acceptation.'},
  'payment_text': {'fr': 'Carte enregistrée sans débit.'},
  'documents': {
    for (final key in ['booking', 'terms', 'privacy'])
      key: {
        'version': '$version-$key',
        'url': 'https://movi-k.com/fr/legal/$key',
        'content': {'fr': 'Texte $key ($version).'},
      },
  },
};

class FakePolicyApi {
  Map<String, dynamic>? published;
  final actions = <Map<String, dynamic>>[];
  Future<Map<String, dynamic>> call(Map<String, dynamic> data) async {
    actions.add(data);
    switch (data['action']) {
      case 'get':
        return {
          'published': published,
          'starter': published ?? _policy('ESSAI-20261023-1', trial: true),
        };
      case 'preview':
        final policy = data['policy'] as Map<String, dynamic>;
        return {'valid': true, 'version': policy['version'], 'contract_hash': 'h'};
      case 'publish':
        final policy = Map<String, dynamic>.from(data['policy'] as Map);
        published = {...policy, 'trial': false};
        return {'success': true, 'version': policy['version'], 'unchanged': false};
    }
    throw StateError('action inconnue');
  }
}

void main() {
  testWidgets('starts from the trial text, then publishes a re-versioned final policy', (
    t,
  ) async {
    final api = FakePolicyApi();
    await t.pumpWidget(MaterialApp(home: AdminBookingPolicyScreen(api: api.call)));
    await t.pumpAndSettle();

    expect(find.textContaining('Aucune condition publiée'), findsOneWidget);
    // Prérempli avec la version d'essai.
    final version = find.byKey(const ValueKey('policy-version'));
    expect(
      (t.widget<TextField>(version).controller!.text),
      'ESSAI-20261023-1',
    );
    expect(
      t.widget<TextField>(find.byKey(const ValueKey('policy-booking.content.fr'))).controller!.text,
      'Texte booking (ESSAI-20261023-1).',
    );

    await t.enterText(version, '2026-11-01-1');
    await t.enterText(
      find.byKey(const ValueKey('policy-approval_reference')),
      'Relecture juridique du 2026-11-01',
    );

    await t.ensureVisible(find.byKey(const ValueKey('policy-preview')));
    await t.tap(find.byKey(const ValueKey('policy-preview')));
    await t.pumpAndSettle();
    expect(find.textContaining('Projet valide (version 2026-11-01-1)'), findsOneWidget);

    await t.ensureVisible(find.byKey(const ValueKey('policy-publish')));
    await t.tap(find.byKey(const ValueKey('policy-publish')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('policy-publish-confirm')));
    await t.pumpAndSettle();

    expect(find.textContaining('Conditions publiées : version 2026-11-01-1'), findsOneWidget);
    expect(find.textContaining('Publiées : version 2026-11-01-1.'), findsOneWidget);
    final publish = api.actions.firstWhere((a) => a['action'] == 'publish');
    final policy = publish['policy'] as Map<String, dynamic>;
    expect(policy['version'], '2026-11-01-1');
    expect(policy['approval_reference'], 'Relecture juridique du 2026-11-01');
    expect(policy['setup_enabled'], isTrue);
    expect((policy['documents'] as Map)['privacy']['url'], 'https://movi-k.com/fr/legal/privacy');
    expect((policy['cancellation_text'] as Map)['fr'], 'Annulation gratuite avant acceptation.');
    // Traductions vides jamais envoyées.
    expect((policy['cancellation_text'] as Map).containsKey('en'), isFalse);
  });

  testWidgets('a published policy is shown and loaded into the form', (t) async {
    final api = FakePolicyApi()..published = _policy('2026-11-01-1');
    await t.pumpWidget(MaterialApp(home: AdminBookingPolicyScreen(api: api.call)));
    await t.pumpAndSettle();
    expect(find.textContaining('Publiées : version 2026-11-01-1.'), findsOneWidget);
    expect(find.textContaining('à remplacer par la version finale'), findsNothing);
    expect(
      t.widget<TextField>(find.byKey(const ValueKey('policy-terms.url'))).controller!.text,
      'https://movi-k.com/fr/legal/terms',
    );
  });
}
