import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/widgets/photo_booking_item.dart';
import 'package:movik_connect/widgets/booking_load_summary.dart';
import 'package:movik_connect/services/booking/booking_draft.dart';
import '../helpers/booking_test_harness.dart';

void main() {
  final bytes = File(
    'assets/home/brand_logo.png',
  ).readAsBytesSync(); // Local rendering fixture only, not an object/AI proof.
  final labels = {
    'fr': 'Dimensions et précautions (facultatif)',
    'en': 'Dimensions and handling (optional)',
    'es': 'Dimensiones y cuidados (opcional)',
  };
  Map<String, dynamic> item() => {
    ...Map<String, dynamic>.from(testDraft().items.first as Map),
    'length': null,
    'width': null,
    'height': null,
    'weight': null,
    'photos': <String>['local-fixture'],
    'identification_confirmed': false,
    'special_handling': false,
  };
  Future<Uint8List?> loader(String path) async => bytes;
  for (final locale in ['fr', 'en', 'es']) {
    for (final size in [
      const Size(375, 812),
      const Size(430, 932),
      const Size(1440, 900),
    ]) {
      for (final scale in [1.0, if (size.width == 375) 2.0]) {
        testWidgets(
          'photo editor and driver summary $locale ${size.width} text $scale',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final value = item();
            var changes = 0;
            await tester.pumpWidget(
              MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: Scaffold(
                    body: SingleChildScrollView(
                      child: StatefulBuilder(
                        builder: (context, setState) => Column(
                          children: [
                            PhotoBookingItem(
                              item: value,
                              locale: locale,
                              categories: [
                                ('sofa', locale == 'fr' ? 'Canapé' : 'Sofa'),
                                ('other', 'Other'),
                              ],
                              photoLoader: loader,
                              onChanged: () {
                                changes++;
                                setState(() {});
                              },
                              onRemove: () {},
                              onAddPhoto: () {},
                            ),
                            BookingLoadSummary(
                              locale: locale,
                              photoLoader: loader,
                              snapshot: {
                                'vehicle_assessment': 'driver_photo_review',
                                'load': {
                                  'items': [
                                    {
                                      ...value,
                                      'length_cm': null,
                                      'width_cm': null,
                                      'height_cm': null,
                                      'weight_kg': null,
                                    },
                                  ],
                                  'pickup': {'floor': 0},
                                  'dropoff': {'floor': 0},
                                  'handlers': 1,
                                  'equipment': [],
                                },
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.byType(Image), findsWidgets);
            expect(find.text(labels[locale]!), findsNothing);
            final confirmation = find.byKey(
              const ValueKey('photo-confirm-test-item'),
            );
            await tester.ensureVisible(confirmation);
            await tester.tap(confirmation);
            await tester.pumpAndSettle();
            expect(value['identification_confirmed'], isTrue);
            expect(changes, 1);
            expect(
              find.byKey(const ValueKey('photo-test-item-length')),
              findsNothing,
            );
            expect(value['length'], isNull);
            await tester.ensureVisible(find.byType(BookingLoadSummary));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
            await tester.pumpAndSettle();
          },
        );
      }
    }
  }
  testWidgets('photo loader refreshes when path changes without Firebase', (
    tester,
  ) async {
    final requested = <String>[];
    Future<Uint8List?> fake(String path) async {
      requested.add(path);
      return bytes;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: BookingPhoto(path: 'first', loader: fake),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      MaterialApp(
        home: BookingPhoto(path: 'second', loader: fake),
      ),
    );
    await tester.pumpAndSettle();
    expect(requested, ['first', 'second']);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'photo failure is displayed as broken image, never fabricated success',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BookingPhoto(
            path: 'missing',
            loader: (_) async => throw StateError('synthetic'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    },
  );
  test(
    'photo metadata and unknown measurements survive draft recreation; edits invalidate quote',
    () {
      final draft = testDraft(quote: true);
      draft.data['intake_mode'] = 'photo_assisted';
      draft.items[0] = item();
      final restored = BookingDraft.fromJson(draft.data);
      expect(restored.load, draft.load);
      expect(restored.items.first['weight'], isNull);
      restored.items.first['quantity'] = 2;
      restored.changed();
      expect(restored.quote, isNull);
      expect(restored.data['accepted'], isFalse);
      expect(draft.items.first['quantity'], 1);
      expect(draft.quote, isNotNull);
    },
  );
  // Owner decision 2026-10-25: details are optional and folded away.
  testWidgets('special item offers optional driver notes, no measurement asked', (
    tester,
  ) async {
    final value = item()..['special_handling'] = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PhotoBookingItem(
              item: value,
              locale: 'fr',
              categories: const [('sofa', 'Canapé'), ('other', 'Autre')],
              photoLoader: loader,
              onChanged: () {},
              onRemove: () {},
              onAddPhoto: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final tile = find.text('Précisions pour le chauffeur (facultatif)');
    expect(tile, findsOneWidget);
    expect(
      find.byKey(const ValueKey('photo-test-item-length')),
      findsNothing,
    );
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('photo-test-item-length')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Facultatif. Le chauffeur voit vos photos et juge lui-même si ça entre dans son véhicule.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
