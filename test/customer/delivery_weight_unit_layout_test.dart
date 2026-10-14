import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/booking_test_harness.dart';
import '../helpers/gps_offline_transport.dart';

const weightLabels = {
  'fr': 'Unité de poids',
  'en': 'Weight unit',
  'es': 'Unidad de peso',
};
Finder get unitField => find.byWidgetPredicate(
  (w) =>
      w is DropdownButtonFormField<String> &&
      ['kg', 'lb'].contains(w.initialValue),
);
Future<MemoryBookingStorage> startUnits(
  WidgetTester t, {
  String locale = 'fr',
  Size size = const Size(375, 812),
  double scale = 1,
}) async {
  final storage = MemoryBookingStorage(testDraft());
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() async {
    await t.pumpWidget(const SizedBox());
    await t.pump();
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
    t.platformDispatcher.clearTextScaleFactorTestValue();
    expect(t.takeException(), isNull);
  });
  await pumpBooking(t, storage: storage, api: TestBookingApi(), locale: locale);
  await t.ensureVisible(unitField);
  await t.pumpAndSettle();
  return storage;
}

void main() => offlineTests(() {
  for (final locale in ['fr', 'en', 'es']) {
    for (final viewport in [
      (375.0, 812.0, 1.0),
      (430.0, 932.0, 1.0),
      (1440.0, 900.0, 1.0),
      (375.0, 812.0, 2.0),
    ]) {
      offlineWidgetTest('Q2 full weight label $locale $viewport', (t) async {
        await startUnits(
          t,
          locale: locale,
          size: Size(viewport.$1, viewport.$2),
          scale: viewport.$3,
        );
        final f = find.text(weightLabels[locale]!);
        expect(f, findsOneWidget);
        final p = t.renderObject<RenderParagraph>(f);
        expect(p.didExceedMaxLines, isFalse, reason: weightLabels[locale]);
        final bounds = MatrixUtils.transformRect(
          p.getTransformTo(null),
          p.paintBounds,
        );
        expect(bounds.left, greaterThanOrEqualTo(0));
        expect(bounds.right, lessThanOrEqualTo(viewport.$1));
        expect(find.text('kg'), findsWidgets);
        expect(t.takeException(), isNull);
      });
    }
  }
  offlineWidgetTest(
    'Q2 selecting units preserves existing conversion and entered data',
    (t) async {
      final s = await startUnits(t);
      final before = Map<String, dynamic>.from(s.saved!.items.single);
      await t.tap(unitField);
      await t.pumpAndSettle();
      await t.tap(find.text('lb').last);
      await t.pumpAndSettle();
      await t.pump(const Duration(seconds: 1));
      expect(s.saved!.items.single['weight_unit'], 'lb');
      expect(
        s.saved!.items.single['weight'],
        closeTo((before['weight'] as num) / 0.45359237, 1e-10),
      );
      expect(s.saved!.items.single['length'], before['length']);
      expect(s.saved!.items.single['label'], before['label']);
    },
  );
});
