import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Existing SDK files only; no download or product theme replacement.
Future<void> loadLocalMaterialFonts() async {
  final configFile = File('.dart_tool/package_config.json');
  final config = jsonDecode(await configFile.readAsString()) as Map;
  final flutter = (config['packages'] as List).cast<Map>().singleWhere(
    (package) => package['name'] == 'flutter',
  );
  final sdk = Directory.fromUri(
    configFile.absolute.uri.resolve(flutter['rootUri'] as String),
  ).parent.parent;
  final fonts = FontLoader('Roboto');
  for (final weight in ['regular', 'medium', 'bold', 'black']) {
    final file = File.fromUri(
      sdk.uri.resolve('bin/cache/artifacts/material_fonts/roboto-$weight.ttf'),
    );
    fonts.addFont(file.readAsBytes().then(ByteData.sublistView));
  }
  await fonts.load();
  // Load actual SDK icons too. TextStyles without an explicit font family
  // can still use Ahem in flutter_tester; captures do not prove Chrome fonts.
  final icons = FontLoader('MaterialIcons');
  icons.addFont(
    File.fromUri(
      sdk.uri.resolve(
        'bin/cache/artifacts/material_fonts/materialicons-regular.otf',
      ),
    ).readAsBytes().then(ByteData.sublistView),
  );
  await icons.load();
}

// Optional real widget raster capture, not a Chrome screenshot.
Future<void> capturePublicViewport(
  WidgetTester tester,
  Finder descendant,
  String name,
  Size size,
) async {
  final output = Platform.environment['MOVIK_U_CAPTURE_DIR'];
  if (output == null) return;
  final finder = find
      .ancestor(of: descendant, matching: find.byType(RepaintBoundary))
      .last;
  final boundary = tester.renderObject<RenderRepaintBoundary>(finder);
  expect(boundary.size, size);
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    expect(Size(image.width.toDouble(), image.height.toDouble()), size);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
