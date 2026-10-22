import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/public_render_test_helpers.dart';
import 'package:movik_connect/backend/repositories/driver_agenda_repository.dart';
import 'package:movik_connect/screens/dashboard/provider/tabs/provider_calendar_tab.dart';
import '../customer/loading_help_test.dart' show captureTheme;
import 'provider_agenda_test.dart' as fixtures;
import 'driver_agenda_advanced_test.dart' show CalendarApiFake;
import 'package:movik_connect/widgets/driver_recurrence_editor.dart';
import 'package:movik_connect/widgets/driver_calendars_panel.dart';

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
        await writeTestArtifact(
          'artifacts/driver-agenda-complete-20261020/agenda-${size.width.toInt()}.png',
          bytes!.buffer.asUint8List(),
        );
        img.dispose();
      });
    });
  }

  for (final size in [
    const Size(375, 1000),
    const Size(768, 1000),
    const Size(1440, 1000),
  ]) {
    for (final spec in [('fr', 1.0), ('fr', 2.0), ('en', 2.0), ('es', 2.0)]) {
      final locale = spec.$1, scale = spec.$2;
      testWidgets(
        'expanded availability and calendars ${size.width} $locale scale $scale',
        (t) async {
          t.view.physicalSize = size;
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          await t.pumpWidget(
            MaterialApp(
              theme: captureTheme(),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: Column(
                      children: [
                        DriverRecurrenceEditor(
                          value: {
                            'time_zone': 'America/Toronto',
                            'weekly': [
                              {
                                'day': 1,
                                'start_minute': 480,
                                'end_minute': 1020,
                              },
                            ],
                            'exceptions': [],
                          },
                          locale: locale,
                          onChanged: (_) {},
                        ),
                        DriverCalendarsPanel(
                          api: CalendarApiFake(),
                          locale: locale,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          await t.tap(find.byType(ExpansionTile).first);
          await t.pumpAndSettle();
          await t.ensureVisible(find.byType(ExpansionTile).last);
          await t.tap(find.byType(ExpansionTile).last);
          await t.pumpAndSettle();
          await t.drag(
            find.byType(SingleChildScrollView).first,
            const Offset(0, -200),
          );
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          if (locale == 'fr' && scale == 1) {
            final layer =
                t.binding.renderViews.first.debugLayer! as OffsetLayer;
            await t.runAsync(() async {
              final img = await layer.toImage(Offset.zero & size);
              final data = await img.toByteData(format: ui.ImageByteFormat.png);
              await writeTestArtifact(
                'artifacts/driver-agenda-complete-20261020/settings-${size.width.toInt()}.png',
                data!.buffer.asUint8List(),
              );
              img.dispose();
            });
          }
        },
      );
    }
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
