// Prix avec le courriel seulement (2026-11-26) : un visiteur voit son prix
// exact en laissant son courriel ; le mot de passe n'est demandé qu'à la
// réservation.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/services/funnel/funnel_analytics.dart';

import '../helpers/booking_test_harness.dart';

class _RefusingLeadApi extends TestBookingApi {
  _RefusingLeadApi(this.code);
  final String code;
  @override
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> data = const {},
  ]) async {
    if (name == 'registerQuoteLead') {
      calls.add(name);
      payloads.add(data);
      throw FirebaseFunctionsException(message: 'refused', code: code);
    }
    return super.call(name, data);
  }
}

Finder _key(String key) => find.byKey(ValueKey(key));

Future<void> _tapKey(WidgetTester t, String key) async {
  // A field that just received text scrolls itself into view on the next
  // frame; let that finish before bringing the button on screen.
  await t.pumpAndSettle();
  await t.ensureVisible(_key(key));
  await t.pumpAndSettle();
  await t.tap(_key(key));
  await t.pumpAndSettle();
}

void main() {
  setUp(FunnelAnalytics.sentForTest.clear);

  test('a guest session is not an account anywhere but in the booking flow', () {
    final auth = FirebaseAuthProvider(backendConfigured: false)
      ..debugForceGuest = true
      ..debugForceUid = 'guest-1';
    expect(auth.isGuest, isTrue);
    expect(auth.isSignedIn, isFalse);
    expect(auth.user, isNull);
    expect(auth.effectiveUid, isNull);
    expect(auth.bookingUid, 'guest-1');
    auth.dispose();
  });

  test('without a backend no guest session is opened', () async {
    final auth = FirebaseAuthProvider(backendConfigured: false);
    expect(await auth.ensureGuestSession(), isFalse);
    expect(auth.bookingUid, isNull);
    expect(
      await auth.upgradeGuestAccount(
        email: 'a@exemple.com',
        password: 'motdepasse1',
        fullName: 'A',
      ),
      'other',
    );
    auth.dispose();
  });

  testWidgets('a visitor sees the exact price with the email only', (t) async {
    final store = MemoryBookingStorage(testDraft(step: 1));
    final api = TestBookingApi();
    final auth = BookingTestAuth(signed: false, guestSessionOpens: true);
    await pumpBooking(t, storage: store, api: api, auth: auth);

    expect(auth.isGuest, isTrue);
    expect(find.text('Se connecter et obtenir mon prix'), findsNothing);
    expect(_key('booking-guest-email'), findsOneWidget);
    expect(find.textContaining('Aucun mot de passe'), findsOneWidget);
    // What the visitor had filled in follows them into the guest session.
    expect(store.handoffs, 1);
    expect(store.saved!.items.first['length'], 25.4);
    expect(api.calls, isNot(contains('calculateDeliveryQuote')));

    await t.enterText(_key('booking-guest-email'), 'marie');
    await _tapKey(t, 'booking-guest-email-submit');
    expect(find.textContaining('adresse courriel valide'), findsOneWidget);
    expect(api.calls, isNot(contains('registerQuoteLead')));

    await t.enterText(_key('booking-guest-email'), ' Marie@Exemple.com ');
    await _tapKey(t, 'booking-guest-email-submit');
    final lead = api.payloads[api.calls.indexOf('registerQuoteLead')];
    expect(lead, {'email': 'marie@exemple.com', 'locale': 'fr'});
    expect(
      api.calls.indexOf('calculateDeliveryQuote'),
      greaterThan(api.calls.indexOf('registerQuoteLead')),
    );
    expect(_key('booking-guest-email'), findsNothing);
    expect(_key('booking-price-hero'), findsOneWidget);
    expect(find.textContaining('123,45'), findsWidgets);
    expect(store.saved!.data['guest_email'], 'marie@exemple.com');
    final events = FunnelAnalytics.sentForTest.map((e) => e.$1).toList();
    expect(events, containsAll(['lead_email', 'price_shown']));
    expect(events, isNot(contains('price_wall')));
    expect(find.text('AUTH_SCREEN'), findsNothing);
    await disposeBooking(t);
  });

  testWidgets('a refused guest session keeps the sign-in button', (t) async {
    await pumpBooking(
      t,
      storage: MemoryBookingStorage(testDraft(step: 1)),
      api: TestBookingApi(),
      auth: BookingTestAuth(signed: false),
    );
    expect(find.text('Se connecter et obtenir mon prix'), findsOneWidget);
    expect(_key('booking-guest-email'), findsNothing);
    await disposeBooking(t);
  });

  testWidgets('an email the server cannot save gives no price and says why', (
    t,
  ) async {
    final api = _RefusingLeadApi('resource-exhausted');
    final store = MemoryBookingStorage(testDraft(step: 1));
    await pumpBooking(
      t,
      storage: store,
      api: api,
      auth: BookingTestAuth(guest: true),
    );
    await t.enterText(_key('booking-guest-email'), 'marie@exemple.com');
    await _tapKey(t, 'booking-guest-email-submit');
    expect(
      find.textContaining('Nous ne pouvons pas enregistrer ce courriel'),
      findsOneWidget,
    );
    expect(api.calls, isNot(contains('calculateDeliveryQuote')));
    expect(store.saved!.data['guest_email'], isNull);
    expect(_key('booking-guest-email'), findsOneWidget);
    // A returning customer can still sign in, with the draft kept.
    await _tapKey(t, 'booking-guest-sign-in');
    expect(find.text('AUTH_SCREEN'), findsOneWidget);
    expect(store.handoffs, 1);
    await disposeBooking(t);
  });

  testWidgets('the server asking for the email again reopens the field', (
    t,
  ) async {
    final draft = testDraft(step: 1)..data['guest_email'] = 'marie@exemple.com';
    final api = TestBookingApi()
      ..quoteError = FirebaseFunctionsException(
        message: 'email',
        code: 'failed-precondition',
        details: {'quote_reason': 'guest_email_required'},
      );
    await pumpBooking(
      t,
      storage: MemoryBookingStorage(draft),
      api: api,
      auth: BookingTestAuth(guest: true),
    );
    expect(_key('booking-guest-email'), findsNothing);
    await tapBooking(t, 'Calculer mon prix officiel');
    expect(_key('booking-guest-email'), findsOneWidget);
    await disposeBooking(t);
  });

  testWidgets('a returning guest is not asked for the email again', (t) async {
    final api = TestBookingApi()
      ..profileData = {'contacts': null, 'guest_email': 'marie@exemple.com'};
    final store = MemoryBookingStorage(testDraft(step: 1));
    await pumpBooking(
      t,
      storage: store,
      api: api,
      auth: BookingTestAuth(guest: true),
    );
    expect(_key('booking-guest-email'), findsNothing);
    await tapBooking(t, 'Calculer mon prix officiel');
    expect(api.calls, isNot(contains('registerQuoteLead')));
    expect(api.calls, contains('calculateDeliveryQuote'));
    expect(_key('booking-price-hero'), findsOneWidget);
    await disposeBooking(t);
  });

  testWidgets('a guest is never told to verify an email before booking', (
    t,
  ) async {
    await pumpBooking(
      t,
      storage: MemoryBookingStorage(testDraft()),
      api: TestBookingApi(),
      auth: BookingTestAuth(guest: true, verified: false),
    );
    expect(_key('booking-email-verification'), findsNothing);
    await disposeBooking(t);
  });

  testWidgets('the password is asked at step 6 and creates the account', (
    t,
  ) async {
    final draft = testDraft(step: 2, quote: true)
      ..data['guest_email'] = 'marie@exemple.com';
    final auth = BookingTestAuth(guest: true, verified: false);
    await pumpBooking(
      t,
      storage: MemoryBookingStorage(draft),
      api: TestBookingApi(),
      auth: auth,
    );
    expect(_key('booking-guest-password'), findsOneWidget);
    expect(find.textContaining('marie@exemple.com'), findsOneWidget);
    expect(_key('booking-email-verification'), findsNothing);
    expect(find.text('Créer mon compte et continuer'), findsOneWidget);

    await t.enterText(_key('booking-guest-password'), 'court');
    await _tapKey(t, 'booking-next-details');
    expect(find.text('Au moins 8 caractères.'), findsOneWidget);
    expect(auth.upgrades, isEmpty);

    await t.enterText(_key('booking-guest-password'), 'motdepasse1');
    await _tapKey(t, 'booking-next-details');
    expect(auth.upgrades, [
      {
        'email': 'marie@exemple.com',
        'password': 'motdepasse1',
        'fullName': 'Test Client',
        'locale': 'fr',
      },
    ]);
    expect(auth.isGuest, isFalse);
    // Confirmation screen: the new account verifies its email right there.
    expect(_key('booking-guest-password'), findsNothing);
    expect(_key('booking-email-verification'), findsOneWidget);
    expect(find.text('J’ai vérifié mon courriel'), findsOneWidget);
    await disposeBooking(t);
  });

  testWidgets('an email that already has an account offers to sign in', (
    t,
  ) async {
    final draft = testDraft(step: 2, quote: true)
      ..data['guest_email'] = 'marie@exemple.com';
    final store = MemoryBookingStorage(draft);
    final auth = BookingTestAuth(guest: true, upgradeFailure: 'email-in-use');
    await pumpBooking(t, storage: store, api: TestBookingApi(), auth: auth);
    await t.enterText(_key('booking-guest-password'), 'motdepasse1');
    await _tapKey(t, 'booking-next-details');
    expect(auth.upgrades, hasLength(1));
    expect(find.textContaining('Un compte existe déjà'), findsOneWidget);
    expect(_key('booking-guest-password'), findsOneWidget);
    await tapBooking(t, 'Me connecter pour réserver');
    expect(find.text('AUTH_SCREEN'), findsOneWidget);
    expect(store.handoffs, 1);
    expect(store.saved!.step, 2);
    await disposeBooking(t);
  });
}
