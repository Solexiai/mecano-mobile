import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Versioned test fixtures preserve the font metrics used in the local audit.
Future<void> loadRobotoTestFonts() async {
  final fonts = FontLoader('Roboto');
  for (final weight in ['regular', 'medium', 'bold', 'black']) {
    final file = File('test/fixtures/fonts/roboto-$weight.ttf');
    fonts.addFont(file.readAsBytes().then(ByteData.sublistView));
  }
  await fonts.load();
}

// Local test fixtures only; no SDK-cache dependency or network access.
Future<void> loadLocalMaterialFonts() async {
  await loadRobotoTestFonts();
  final icons = FontLoader('MaterialIcons');
  icons.addFont(
    File(
      'test/fixtures/fonts/materialicons-regular.otf',
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

Future<void> capturePublicOverlayViewport(
  WidgetTester tester,
  String name,
  Size size,
) async {
  final output = Platform.environment['MOVIK_U_CAPTURE_DIR'];
  if (output == null) return;
  final view = tester.binding.renderViews.single;
  expect(view.size, size);
  final layer = view.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final image = await layer.toImage(Offset.zero & size, pixelRatio: 1);
    expect(Size(image.width.toDouble(), image.height.toDouble()), size);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
