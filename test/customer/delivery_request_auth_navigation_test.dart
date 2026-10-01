import 'package:flutter_test/flutter_test.dart';
import '../helpers/booking_test_harness.dart';

void main() {
  testWidgets('Guest starts without authentication', (t) async {
    await pumpBooking(
      t,
      storage: MemoryBookingStorage(null),
      api: TestBookingApi(),
      auth: BookingTestAuth(signed: false),
    );
    expect(find.text('Organisez votre livraison'), findsOneWidget);
    expect(find.text('AUTH_SCREEN'), findsNothing);
    await disposeBooking(t);
  });
  testWidgets('Login keeps the complete draft and its step', (t) async {
    final store = MemoryBookingStorage(testDraft(step: 1));
    await pumpBooking(
      t,
      storage: store,
      api: TestBookingApi(),
      auth: BookingTestAuth(signed: false),
    );
    await tapBooking(t, 'Se connecter et obtenir mon prix');
    expect(find.text('AUTH_SCREEN'), findsOneWidget);
    expect(store.handoffs, 1);
    expect(store.saved!.step, 1);
    expect(store.saved!.items.first['length'], 25.4);
    await disposeBooking(t);
  });
}
