import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/backend/repositories/driver_agenda_repository.dart';
import 'package:movik_connect/screens/dashboard/provider/tabs/provider_calendar_tab.dart';
import '../customer/loading_help_test.dart' show captureTheme;
import 'provider_agenda_test.dart' as fixtures;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    const sdk = String.fromEnvironment('FLUTTER_TEST_SDK');
    if (sdk.isEmpty) return;
    for (final family in ['Roboto', 'Ahem']) {
      await (FontLoader(family)..addFont(
            File(
              '$sdk/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
            ).readAsBytes().then((b) => b.buffer.asByteData()),
          ))
          .load();
    }
    await (FontLoader('MaterialIcons')..addFont(
          File(
            'build/unit_test_assets/fonts/MaterialIcons-Regular.otf',
          ).readAsBytes().then((b) => b.buffer.asByteData()),
        ))
        .load();
  });
  for (final size in [const Size(375, 1000), const Size(1440, 1000)]) {
    testWidgets('agenda rendering ${size.width}', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final repo = fixtures.AgendaFake();
      addTearDown(repo.missions.close);
      repo.agenda = DriverAgenda(
        configured: true,
        revision: 1,
        windows: [
          AgendaInterval(
            DateTime.now(),
            DateTime.now().add(const Duration(hours: 4)),
          ),
        ],
      );
      await t.pumpWidget(
        MaterialApp(
          theme: captureTheme(),
          home: Scaffold(
            body: ProviderCalendarTab(repository: repo, locale: 'fr'),
          ),
        ),
      );
      repo.missions.add([
        fixtures.mission('synthetic', 'assigned', DateTime.now()),
      ]);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      final layer = t.binding.renderViews.first.debugLayer! as OffsetLayer;
      await t.runAsync(() async {
        final img = await layer.toImage(Offset.zero & size);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'artifacts/driver-agenda-20261020/agenda-${size.width.toInt()}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        img.dispose();
      });
    });
  }
  for (final locale in ['fr', 'en', 'es']) {
    testWidgets('200 percent text mobile $locale', (t) async {
      t.view.physicalSize = const Size(375, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final repo = fixtures.AgendaFake();
      addTearDown(repo.missions.close);
      await t.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: ProviderCalendarTab(repository: repo, locale: locale),
            ),
          ),
        ),
      );
      repo.missions.add([]);
      await t.pumpAndSettle();
      await t.drag(find.byType(SingleChildScrollView), const Offset(0, -700));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }
}
