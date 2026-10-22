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
        expect(
          find.text(
            {
              'fr': 'Dimensions estimées',
              'en': 'Estimated dimensions',
              'es': 'Dimensiones estimadas',
            }[locale]!,
          ),
          findsOneWidget,
        );
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
}
