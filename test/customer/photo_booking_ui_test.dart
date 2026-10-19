import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/widgets/booking_load_summary.dart';
import '../helpers/booking_test_harness.dart';

void main() {
  testWidgets(
    'photo intake hides optional measurements and requires object confirmation',
    (tester) async {
      final draft = testDraft();
      draft.data['intake_mode'] = 'photo_assisted';
      draft.items.first['identification_confirmed'] = false;
      draft.items.first['special_handling'] = false;
      final storage = MemoryBookingStorage(draft);
      await pumpBooking(tester, storage: storage, api: TestBookingApi());
      expect(find.text('Dimensions et précautions (facultatif)'), findsNothing);
      expect(
        find.byKey(const ValueKey('photo-confirm-test-item')),
        findsOneWidget,
      );
      expect(find.text('Longueur'), findsNothing);
      await disposeBooking(tester);
    },
  );
  testWidgets(
    'driver summary explicitly distinguishes photo review from verified fit',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BookingLoadSummary(
                locale: 'fr',
                snapshot: {
                  'vehicle_assessment': 'driver_photo_review',
                  'load': {
                    'items': [],
                    'pickup': {},
                    'dropoff': {},
                    'handlers': 1,
                    'equipment': [],
                  },
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'À évaluer sur photo : les dimensions et le poids peuvent être inconnus. La capacité de chargement n’est pas confirmée.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'photo draft sends its explicit mode without inventing measurements',
    () {
      final draft = testDraft();
      draft.data['intake_mode'] = 'photo_assisted';
      draft.items[0] = Map<String, dynamic>.from(draft.items.first as Map);
      draft.items.first['weight'] = null;
      expect(draft.load['intake_mode'], 'photo_assisted');
      expect((draft.load['items'] as List).first['weight'], isNull);
    },
  );
}
