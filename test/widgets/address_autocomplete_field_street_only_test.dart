// 2026-11-09 : une suggestion « rue entière » (sans numéro de porte, donc
// sans code postal) ne doit pas passer pour une adresse valide — le champ
// l'explique au lieu de laisser le bouton Suivant gris sans raison claire.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/services/address/address_suggestion.dart';
import 'package:movik_connect/widgets/address_autocomplete_field.dart';
import 'package:provider/provider.dart';

import '../helpers/fake_address_autocomplete_provider.dart';

void main() {
  Future<(List<ResolvedAddress>, List<int>)> pump(WidgetTester tester, FakeAddressAutocompleteProvider places) async {
    final resolved = <ResolvedAddress>[];
    final invalidated = <int>[];
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LocaleProvider(),
        child: MaterialApp(
          home: Scaffold(
            body: AddressAutocompleteField(
              controller: controller,
              label: 'On le livre ici',
              provider: places,
              onResolved: resolved.add,
              onInvalidated: () => invalidated.add(1),
            ),
          ),
        ),
      ),
    );
    return (resolved, invalidated);
  }

  testWidgets('rue sans numéro : erreur explicite, pas de crochet, adresse non transmise', (tester) async {
    final places = FakeAddressAutocompleteProvider()..streetOnly = true;
    final (resolved, invalidated) = await pump(tester, places);
    await typeAndSelectAddress(tester, 0, 'Rue de Candiac Granby');
    expect(resolved, isEmpty);
    expect(invalidated, isNotEmpty);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(find.textContaining('numéro de porte'), findsOneWidget);

    // Le client retape : l'erreur disparaît.
    await tester.enterText(find.byType(TextField), '150 Rue de Candiac');
    await tester.pump();
    expect(find.textContaining('numéro de porte'), findsNothing);
  });

  testWidgets('adresse complète : crochet vert et adresse transmise (inchangé)', (tester) async {
    final places = FakeAddressAutocompleteProvider();
    final (resolved, _) = await pump(tester, places);
    await typeAndSelectAddress(tester, 0, '150 Rue de Candiac Granby');
    expect(resolved, hasLength(1));
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.textContaining('numéro de porte'), findsNothing);
  });
}
