import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/widgets/photo_booking_item.dart';

void main() {
  for (final locale in ['fr', 'en', 'es']) {
    for (final size in [
      const Size(375, 812),
      const Size(430, 932),
      const Size(1440, 900),
    ]) {
      testWidgets(
        'automatic sofa identification $locale $size with mobile enlarged text',
        (t) async {
          t.view.physicalSize = size;
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          final item = <String, dynamic>{
            'id': 'sofa',
            'category': 'sofa',
            'label': {
              'fr': 'Divan sectionnel en tissu gris',
              'en': 'Grey fabric sectional sofa',
              'es': 'Sofá seccional de tela gris',
            }[locale],
            'photos': ['test.jpg'],
            'quantity': 1,
            'dimension_unit': 'cm',
            'weight_unit': 'kg',
            'identification_confirmed': false,
            'special_handling': false,
          };
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
                      item: item,
                      locale: locale,
                      categories: [
                        (
                          'sofa',
                          {
                            'fr': 'Divan / sofa / sectionnel',
                            'en': 'Sofa / sectional',
                            'es': 'Sofá / seccional',
                          }[locale]!,
                        ),
                        ('other', 'Other'),
                      ],
                      photoLoader: (_) async =>
                          File('assets/home/brand_logo.png').readAsBytesSync(),
                      onChanged: () {},
                      onRemove: () {},
                      onAddPhoto: () {},
                      onAnalyzePhoto: () {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          // Simple card (2026-10-24): the guess first, the fields on « Non, changer ».
          final change = find.byKey(const ValueKey('photo-change-sofa'));
          if (change.evaluate().isNotEmpty) {
            await t.ensureVisible(change);
            await t.pumpAndSettle();
            await t.tap(change);
            await t.pumpAndSettle();
          }
          expect(
            find.byKey(const ValueKey('photo-label-sofa')),
            findsOneWidget,
          );
          expect(find.text(item['label'] as String), findsOneWidget);
          expect(
            find.text(
              {
                'fr': 'Divan / sofa / sectionnel',
                'en': 'Sofa / sectional',
                'es': 'Sofá / seccional',
              }[locale]!,
            ),
            findsWidgets,
          );
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
          await t.pumpAndSettle();
        },
      );
    }
  }
}
