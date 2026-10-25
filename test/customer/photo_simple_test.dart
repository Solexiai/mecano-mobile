import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/services/booking/booking_photo_analysis.dart';
import 'package:movik_connect/widgets/photo_booking_item.dart';

const hint = {
  'basis': 'typical_object',
  'confidence': 'low',
  'length_cm': {'min': 70, 'max': 110},
  'width_cm': {'min': 70, 'max': 110},
  'height_cm': {'min': 70, 'max': 120},
};
const photo = 'booking_photos/test/test-draft/item/0.jpg';
Map<String, dynamic> result() => {
  'photoPath': photo,
  'requiresConfirmation': true,
  'measurementsVerified': false,
  'quoteAuthorized': false,
  'suggestion': {
    'category': 'armchair',
    'label': 'Fauteuil',
    'confidence': 'high',
    'special_handling': false,
    'reason': 'ordinary',
    'size_estimate': hint,
  },
};
Map<String, dynamic> item() => {
  'id': 'item',
  'category': 'armchair',
  'label': 'Fauteuil',
  'quantity': 1,
  'photos': [photo],
  'dimension_unit': 'cm',
  'weight_unit': 'kg',
  'length': null,
  'width': null,
  'height': null,
  'weight': null,
  'identification_confirmed': false,
  'special_handling': false,
};
void main() {
  test(
    'advisory estimate preserved separately, never fills customer dimensions',
    () {
      final i = item();
      BookingPhotoSuggestion.fromResponse(result(), photo).applyTo(i);
      expect(i['photo_size_hint'], isNotNull);
      for (final k in ['length', 'width', 'height', 'weight']) {
        expect(i[k], isNull);
      }
      expect(i['identification_confirmed'], false);
    },
  );
  test(
    'hint cannot follow a different photo or edited object; measured values preserved',
    () {
      final i = item()
        ..['length'] = 87
        ..['weight'] = 24;
      BookingPhotoSuggestion.fromResponse(result(), photo).applyTo(i);
      expect(i['length'], 87);
      expect(i['weight'], 24);
      expect(BookingPhotoSizeEstimate.forItem(i), isNotNull);
      i['photos'] = ['another-photo'];
      expect(BookingPhotoSizeEstimate.forItem(i), isNull);
      i['photos'] = [photo];
      i['category'] = 'fridge';
      expect(BookingPhotoSizeEstimate.forItem(i), isNull);
      i['category'] = 'armchair';
      i['label'] = 'Different item';
      expect(BookingPhotoSizeEstimate.forItem(i), isNull);
    },
  );
  for (final locale in ['fr', 'en', 'es']) {
    for (final size in [
      const Size(375, 812),
      const Size(430, 932),
      const Size(1440, 900),
    ]) {
      testWidgets('compact photo card $locale $size', (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        await t.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(size.width == 375 ? 2 : 1),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: PhotoBookingItem(
                    item: item(),
                    locale: locale,
                    categories: const [
                      ('armchair', 'Fauteuil'),
                      ('other', 'Autre'),
                    ],
                    photoLoader: (_) async =>
                        File('assets/home/brand_logo.png').readAsBytesSync(),
                    onChanged: () {},
                    onRemove: () {},
                    onAddPhoto: () {},
                    onAnalyzePhoto: () {},
                    suggestion: BookingPhotoSuggestion.fromResponse(
                      result(),
                      photo,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        // Simple card (2026-10-24): the recognized item, then one tap.
        expect(
          find.text({'fr': 'On dirait :', 'en': 'Looks like:', 'es': 'Parece:'}[locale]!),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('photo-guess-item')), findsOneWidget);
        expect(find.byKey(const ValueKey('photo-confirm-item')), findsOneWidget);
        expect(find.byKey(const ValueKey('photo-change-item')), findsOneWidget);
        expect(find.byKey(const ValueKey('photo-label-item')), findsNothing);
        await t.ensureVisible(find.byKey(const ValueKey('photo-change-item')));
        await t.tap(find.byKey(const ValueKey('photo-change-item')));
        await t.pumpAndSettle();
        expect(
          find.text(
            {
              'fr': 'Description courte',
              'en': 'Short description',
              'es': 'Descripción breve',
            }[locale]!,
          ),
          findsOneWidget,
        );
        expect(t.takeException(), isNull);
      });
    }
  }
  testWidgets('several items on one photo: the card asks for type and quantity', (
    t,
  ) async {
    final response = result();
    response['suggestion'] = {
      ...(response['suggestion'] as Map),
      'category': 'washer',
      'label': 'Laveuse et sécheuse',
      'reason': 'multiple_objects',
    };
    final suggestion = BookingPhotoSuggestion.fromResponse(response, photo);
    expect(suggestion.multiple, isTrue);
    expect(suggestion.category, 'other');
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PhotoBookingItem(
              item: item()..['category'] = 'other',
              locale: 'fr',
              categories: const [
                ('washer', 'Laveuse / sécheuse'),
                ('other', 'Autre'),
              ],
              photoLoader: (_) async =>
                  File('assets/home/brand_logo.png').readAsBytesSync(),
              onChanged: () {},
              onRemove: () {},
              onAddPhoto: () {},
              suggestion: suggestion,
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(
      find.textContaining('On voit plusieurs articles sur la photo'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('photo-category-item')), findsOneWidget);
  });
  testWidgets('choosing an ordinary type clears the special flag', (t) async {
    final value = item()
      ..['category'] = 'other'
      ..['special_handling'] = true
      ..['label'] = 'Deux appareils de buanderie';
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (_, update) => PhotoBookingItem(
                item: value,
                locale: 'fr',
                categories: const [
                  ('washer', 'Laveuse / sécheuse'),
                  ('other', 'Autre'),
                ],
                photoLoader: (_) async =>
                    File('assets/home/brand_logo.png').readAsBytesSync(),
                onChanged: () => update(() {}),
                onRemove: () {},
                onAddPhoto: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final change = find.byKey(const ValueKey('photo-change-item'));
    if (change.evaluate().isNotEmpty) {
      await t.tap(change);
      await t.pumpAndSettle();
    }
    await t.tap(find.byKey(const ValueKey('photo-category-item')));
    await t.pumpAndSettle();
    await t.tap(find.text('Laveuse / sécheuse').last);
    await t.pumpAndSettle();
    expect(value['category'], 'washer');
    expect(value['special_handling'], isFalse);
  });
}
