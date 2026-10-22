import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/widgets/booking_load_summary.dart';

void main() {
  testWidgets(
    'changing photo path hides old image while new image is loading',
    (tester) async {
      final bytes = File('assets/home/brand_logo.png').readAsBytesSync();
      final next = Completer<Uint8List?>();
      Future<Uint8List?> loader(String path) async =>
          path == 'first' ? bytes : next.future;
      await tester.pumpWidget(
        MaterialApp(
          home: BookingPhoto(path: 'first', loader: loader),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(
          home: BookingPhoto(path: 'second', loader: loader),
        ),
      );
      await tester.pump();
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      next.complete(bytes);
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
    },
  );
}
