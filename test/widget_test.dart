// Basic smoke test for the Movi-k Flutter application.
import 'package:flutter_test/flutter_test.dart';

import 'package:movik_connect/main.dart';

void main() {
  testWidgets('Movi-k app boots and shows the home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MovikApp());
    await tester.pumpAndSettle();

    // The Movi-k brand name should appear in the app bar / footer.
    expect(find.text('Movi-k'), findsWidgets);
  });
}
