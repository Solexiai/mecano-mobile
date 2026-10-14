import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('official Cupertino icon font is declared and bundled', () async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json'))
            as List<dynamic>;
    final cupertinoFamily = manifest
        .whereType<Map<String, dynamic>>()
        .singleWhere(
          (font) => font['family'] == 'packages/cupertino_icons/CupertinoIcons',
        );

    final assets = (cupertinoFamily['fonts'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map((font) => font['asset'])
        .toList();

    expect(
      assets,
      contains('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
    );

    final font = await rootBundle.load(
      'packages/cupertino_icons/assets/CupertinoIcons.ttf',
    );
    expect(font.lengthInBytes, greaterThan(1000));
  });

  testWidgets('Cupertino icon keeps its packaged font identity', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoPageScaffold(
          child: Center(child: Icon(CupertinoIcons.heart_fill)),
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(CupertinoIcons.heart_fill));
    expect(icon.icon?.fontFamily, 'CupertinoIcons');
    expect(icon.icon?.fontPackage, 'cupertino_icons');
    expect(tester.takeException(), isNull);
  });
}
