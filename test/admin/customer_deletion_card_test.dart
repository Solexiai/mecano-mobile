// Effacer un client — super-admin (Daniel, 2026-11-10).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/screens/dashboard/admin/users/customer_deletion_card.dart';

class _Calls {
  _Calls(this.preview);
  final Map<String, dynamic> preview;
  final calls = <Map<String, dynamic>>[];
  Future<Map<String, dynamic>> call(String name, Map<String, dynamic> data) async {
    expect(name, 'deleteCustomerAccount');
    calls.add(data);
    if (data['dryRun'] == true) return preview;
    return {...preview, 'deleted': true};
  }
}

Future<int> _pump(WidgetTester t, _Calls calls) async {
  var deleted = 0;
  await t.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CustomerDeletionCard(userId: 'cust_1', locale: 'fr', call: calls.call, onDeleted: () => deleted++),
          ],
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  return deleted;
}

void main() {
  testWidgets('bloqué : les raisons du serveur sont affichées, rien n’est effacé', (t) async {
    final calls = _Calls({
      'mode': 'anonymize',
      'blockers': ["1 livraison(s) en cours : terminez-les ou annulez-les d'abord."],
      'deliveries': 2,
      'payments': 3,
    });
    await _pump(t, calls);
    await t.tap(find.byKey(const ValueKey('delete-customer')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('delete-customer-blocked')), findsOneWidget);
    expect(find.textContaining('livraison(s) en cours'), findsOneWidget);
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    expect(calls.calls.map((c) => c['dryRun']), [true]);
  });

  testWidgets('anonymiser : raison + EFFACER exigés, puis effacement', (t) async {
    final calls = _Calls({'mode': 'anonymize', 'blockers': [], 'deliveries': 2, 'payments': 3});
    var deleted = 0;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomerDeletionCard(userId: 'cust_1', locale: 'fr', call: calls.call, onDeleted: () => deleted++),
        ),
      ),
    );
    await t.tap(find.byKey(const ValueKey('delete-customer')));
    await t.pumpAndSettle();
    expect(find.textContaining('2 livraison(s) et 3 paiement(s)'), findsOneWidget);
    expect(find.textContaining('restent dans les registres'), findsWidgets);

    FilledButton submit() => t.widget<FilledButton>(find.byKey(const ValueKey('delete-customer-submit')));
    expect(submit().onPressed, isNull);
    await t.enterText(find.byKey(const ValueKey('delete-customer-reason')), 'Demande du client');
    await t.pump();
    expect(submit().onPressed, isNull);
    await t.enterText(find.byKey(const ValueKey('delete-customer-confirm')), 'effacer');
    await t.pump();
    expect(submit().onPressed, isNull);
    await t.enterText(find.byKey(const ValueKey('delete-customer-confirm')), 'EFFACER');
    await t.pump();
    expect(submit().onPressed, isNotNull);

    await t.tap(find.byKey(const ValueKey('delete-customer-submit')));
    await t.pumpAndSettle();
    expect(calls.calls.last, {'userId': 'cust_1', 'reason': 'Demande du client'});
    expect(deleted, 1);
    expect(find.text('Client effacé.'), findsOneWidget);
  });

  testWidgets('sans historique : « tout sera effacé » ; annuler ne fait rien', (t) async {
    final calls = _Calls({'mode': 'erase', 'blockers': [], 'deliveries': 0, 'payments': 0});
    final deleted = await _pump(t, calls);
    await t.tap(find.byKey(const ValueKey('delete-customer')));
    await t.pumpAndSettle();
    expect(find.textContaining('tout sera effacé'), findsOneWidget);
    await t.tap(find.text('Annuler'));
    await t.pumpAndSettle();
    expect(calls.calls.length, 1);
    expect(deleted, 0);
  });
}
