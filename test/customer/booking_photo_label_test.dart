import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/widgets/photo_booking_item.dart';

void main() {
  testWidgets('empty photo item label is an actionable part of the button', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhotoBookingItem(
            item: {
              'id': 'empty',
              'category': 'other',
              'label': 'Autre objet',
              'quantity': 1,
              'photos': <String>[],
            },
            locale: 'fr',
            categories: const [('other', 'Autre objet')],
            onChanged: () {},
            onRemove: () {},
            onAddPhoto: () => taps++,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Prendre une photo'));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });
}
