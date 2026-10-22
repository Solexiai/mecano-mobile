import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/services/booking/booking_photo_analysis.dart';
import 'package:movik_connect/widgets/photo_booking_item.dart';
import '../helpers/booking_test_harness.dart';

const path = 'booking_photos/booking_test/fake-draft/test-item/0.jpg';
Map<String, dynamic> response({
  String category = 'fridge',
  String label = 'Réfrigérateur fictif',
}) => {
  'photoPath': path,
  'requiresConfirmation': true,
  'measurementsVerified': false,
  'quoteAuthorized': false,
  'suggestion': {
    'category': category,
    'label': label,
    'special_handling': false,
    'confidence': 'high',
    'reason': 'ordinary',
  },
};

class AiApi extends TestBookingApi {
  Future<Map<String, dynamic>> Function()? analyze;
  int analyses = 0;
  Map<String, dynamic>? analysisPayload;
  @override
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> data = const {},
  ]) async {
    if (name == 'analyzeBookingPhoto') {
      analyses++;
      analysisPayload = data;
      return analyze == null ? response() : analyze!();
    }
    return super.call(name, data);
  }
}

MemoryBookingStorage storage() {
  final d = testDraft();
  d.items[0] = Map<String, dynamic>.from(d.items.single as Map);
  d.data['intake_mode'] = 'photo_assisted';
  d.items.single['photos'] = <String>[path];
  d.items.single['identification_confirmed'] = false;
  d.items.single['special_handling'] = false;
  for (final k in ['length', 'width', 'height', 'weight']) {
    d.items.single[k] = null;
  }
  return MemoryBookingStorage(d);
}

void main() {
  final bytes = File('assets/home/brand_logo.png').readAsBytesSync();
  testWidgets(
    'restored photo is not resent; explicit reanalysis autofills but requires customer confirmation',
    (t) async {
      final s = storage(), api = AiApi();
      await pumpBooking(
        t,
        storage: s,
        api: api,
        photoIntakeEnabled: true,
        photoLoader: (_) async => bytes,
      );
      expect(api.analyses, 0);
      await tapBooking(t, 'Analyser la photo');
      expect(api.analyses, 1);
      expect(api.analysisPayload!['consent'], true);
      expect(api.analysisPayload!['photoPath'], path);
      expect(find.text('Suggestion IA : Réfrigérateur fictif'), findsOneWidget);
      expect(find.text('Utiliser cette suggestion'), findsNothing);
      expect(s.saved!.items.single['category'], 'fridge');
      expect(s.saved!.items.single['label'], 'Réfrigérateur fictif');
      expect(s.saved!.items.single['identification_confirmed'], false);
      for (final k in ['length', 'width', 'height', 'weight']) {
        expect(s.saved!.items.single[k], isNull);
      }
      final label = find.descendant(
        of: find.byKey(const ValueKey('photo-label-test-item')),
        matching: find.byType(EditableText),
      );
      expect(
        t.widget<EditableText>(label).controller.text,
        'Réfrigérateur fictif',
      );
      final confirm = find.byKey(const ValueKey('photo-confirm-test-item'));
      await t.ensureVisible(confirm);
      await t.tap(confirm);
      await t.pumpAndSettle();
      await tapBooking(t, 'Voir mon prix');
      expect(s.saved!.quote!['customerTotal'], 123.45);
      expect(api.calls, isNot(contains('createDeliveryRequest')));
      expect(t.takeException(), isNull);
      await disposeBooking(t);
    },
  );
  testWidgets(
    'failure preserves data and explicit retry recovers without duplicate',
    (t) async {
      final s = storage(),
          api = AiApi()..analyze = () => Future.error(Exception('RAW SECRET'));
      await pumpBooking(
        t,
        storage: s,
        api: api,
        photoIntakeEnabled: true,
        photoLoader: (_) async => bytes,
      );
      await tapBooking(t, 'Analyser la photo');
      expect(find.textContaining('Analyse indisponible.'), findsOneWidget);
      expect(find.textContaining('RAW SECRET'), findsNothing);
      expect(s.saved!.items.single['category'], 'sofa');
      api.analyze = () async => response();
      await tapBooking(t, 'Analyser la photo');
      expect(api.analyses, 2);
      expect(find.textContaining('Suggestion IA'), findsOneWidget);
      expect(find.textContaining('Analyse indisponible.'), findsNothing);
      await disposeBooking(t);
    },
  );
  testWidgets(
    'pending analysis disables repeat; edited item ignores late result',
    (t) async {
      final pending = Completer<Map<String, dynamic>>(),
          s = storage(),
          api = AiApi()..analyze = () => pending.future;
      await pumpBooking(
        t,
        storage: s,
        api: api,
        photoIntakeEnabled: true,
        photoLoader: (_) async => bytes,
      );
      await tapBooking(t, 'Dimensions et précautions (facultatif)');
      final f = find.byKey(const ValueKey('photo-analyze-test-item'));
      await t.ensureVisible(f);
      await t.tap(f);
      await t.pump(const Duration(milliseconds: 800));
      expect(t.widget<TextButton>(f).onPressed, isNull);
      expect(api.analyses, 1);
      final label = find.byKey(const ValueKey('photo-label-test-item'));
      await t.ensureVisible(label);
      await t.enterText(label, 'Objet corrigé');
      await t.pump(const Duration(milliseconds: 800));
      pending.complete(response());
      await t.pumpAndSettle();
      expect(find.textContaining('Suggestion IA'), findsNothing);
      expect(s.saved!.items.single['label'], 'Objet corrigé');
      await disposeBooking(t);
    },
  );
  testWidgets('late result after disposal does not mutate draft', (t) async {
    final pending = Completer<Map<String, dynamic>>(),
        s = storage(),
        api = AiApi()..analyze = () => pending.future;
    await pumpBooking(
      t,
      storage: s,
      api: api,
      photoIntakeEnabled: true,
      photoLoader: (_) async => bytes,
    );
    final f = find.byKey(const ValueKey('photo-analyze-test-item'));
    await t.ensureVisible(f);
    await t.tap(f);
    await t.pump(const Duration(milliseconds: 800));
    await t.pumpWidget(const SizedBox());
    pending.complete(response());
    await t.pumpAndSettle();
    expect(s.saved!.items.single['category'], 'sofa');
    expect(t.takeException(), isNull);
  });
  test('untrusted response cannot authorize price or inject foreign photo', () {
    for (final patch in [
      {'photoPath': 'other'},
      {'quoteAuthorized': true},
      {'measurementsVerified': true},
    ]) {
      expect(
        () => BookingPhotoSuggestion.fromResponse({
          ...response(),
          ...patch,
        }, path),
        throwsFormatException,
      );
    }
  });
  test(
    'low confidence, special and ambiguous remain special; manual measurements retained',
    () {
      final r = response();
      (r['suggestion'] as Map)['confidence'] = 'low';
      final suggestion = BookingPhotoSuggestion.fromResponse(r, path);
      final item = <String, dynamic>{
        'weight': 42,
        'length': 80,
        'quantity': 2,
        'identification_confirmed': true,
      };
      suggestion.applyTo(item);
      expect(item['category'], 'other');
      expect(item['special_handling'], true);
      expect(item['weight'], 42);
      expect(item['length'], 80);
      expect(item['quantity'], 2);
      expect(item['identification_confirmed'], false);
    },
  );
  for (final locale in ['fr', 'en', 'es']) {
    for (final size in [
      const Size(375, 812),
      const Size(430, 932),
      const Size(1440, 900),
    ]) {
      testWidgets('AI messages $locale ${size.width} mobile text 200 percent', (
        t,
      ) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final item = storage().saved!.items.single;
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
                    categories: const [('sofa', 'Sofa'), ('other', 'Other')],
                    photoLoader: (_) async => bytes,
                    onChanged: () {},
                    onRemove: () {},
                    onAddPhoto: () {},
                    onAnalyzePhoto: () {},
                    suggestion: const BookingPhotoSuggestion(
                      category: 'other',
                      label: 'Objet fictif',
                      special: true,
                      uncertain: true,
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
              'fr': 'Analyser la photo',
              'en': 'Analyze photo',
              'es': 'Analizar foto',
            }[locale]!,
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            {
              'fr': 'Utiliser cette suggestion',
              'en': 'Use this suggestion',
              'es': 'Usar esta sugerencia',
            }[locale]!,
          ),
          findsNothing,
        );
        expect(t.takeException(), isNull);
        await disposeBooking(t);
      });
    }
  }
}
