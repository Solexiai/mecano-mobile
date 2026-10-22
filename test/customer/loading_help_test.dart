import 'package:flutter/material.dart';
import 'package:movik_connect/core/app_theme.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/services/booking/booking_draft.dart';
import '../helpers/booking_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    const sdk = String.fromEnvironment('FLUTTER_TEST_SDK');
    if (sdk.isNotEmpty) {
      final roboto = FontLoader('Roboto')
        ..addFont(
          File(
            '$sdk/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
          ).readAsBytes().then((b) => b.buffer.asByteData()),
        );
      await roboto.load();
      final fallback = FontLoader('Ahem')
        ..addFont(
          File(
            '$sdk/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
          ).readAsBytes().then((b) => b.buffer.asByteData()),
        );
      await fallback.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          File(
            'build/unit_test_assets/fonts/MaterialIcons-Regular.otf',
          ).readAsBytes().then((b) => b.buffer.asByteData()),
        );
      await icons.load();
    }
  });
  test('new request does not fabricate help or access answers', () {
    final d = BookingDraft();
    for (final key in ['pickup_access', 'dropoff_access']) {
      expect(d.data[key]['help'], isNull);
      expect(d.data[key]['floor'], isNull);
      expect(d.data[key]['stairs'], isNull);
    }
  });
  testWidgets('help choices are outside collapsed access panels', (t) async {
    await pumpBooking(
      t,
      storage: MemoryBookingStorage(testDraft()),
      api: TestBookingApi(),
    );
    expect(find.text('Besoin d’aide pour charger ?'), findsOneWidget);
    expect(find.text('Besoin d’aide pour décharger ?'), findsOneWidget);
    expect(find.text('Accès et aide sur place'), findsNothing);
    await disposeBooking(t);
  });
  for (final size in [const Size(375, 812), const Size(1440, 1000)]) {
    testWidgets('capture access layout ${size.width}', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final draft = testDraft();
      for (final key in ['pickup_access', 'dropoff_access']) {
        draft.data[key] = BookingDraft().data[key];
      }
      await pumpBooking(
        t,
        storage: MemoryBookingStorage(draft),
        api: TestBookingApi(),
        theme: captureTheme(),
      );
      await t.ensureVisible(find.text('Ramassage et livraison'));
      await t.pumpAndSettle();
      final layer = t.binding.renderViews.first.debugLayer! as OffsetLayer;
      await t.runAsync(() async {
        final image = await layer.toImage(Offset.zero & size);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        const phase = String.fromEnvironment(
          'CAPTURE_PHASE',
          defaultValue: 'after',
        );
        await File(
          'artifacts/customer-loading-help-20261019/$phase-${size.width.toInt()}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      expect(t.takeException(), isNull);
      await disposeBooking(t);
    });
  }
}

 // Widget tests use Ahem when a button style has no font family.
 // Keep every production style property; use bundled Roboto for readable evidence.
ThemeData captureTheme() {
  final t=AppTheme.light();
  ButtonStyle font(ButtonStyle? style) => (style ?? const ButtonStyle()).copyWith(
    textStyle:WidgetStateProperty.resolveWith((states)=>
      (style?.textStyle?.resolve(states) ?? const TextStyle()).copyWith(fontFamily:'Roboto')));
  return t.copyWith(
    elevatedButtonTheme:ElevatedButtonThemeData(style:font(t.elevatedButtonTheme.style)),
    outlinedButtonTheme:OutlinedButtonThemeData(style:font(t.outlinedButtonTheme.style)),
    textButtonTheme:TextButtonThemeData(style:font(t.textButtonTheme.style)),
    filledButtonTheme:FilledButtonThemeData(style:font(t.filledButtonTheme.style)),
    chipTheme:t.chipTheme.copyWith(labelStyle:(t.chipTheme.labelStyle ?? t.textTheme.labelLarge)!.copyWith(fontFamily:'Roboto')),
  );
}
