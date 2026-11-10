// Fiche client du service client (Daniel, 2026-11-10, phase 1).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/screens/dashboard/admin/users/admin_customer_file.dart';

Map<String, dynamic> _file({bool canAct = true}) => {
  'canAct': canAct,
  'masked': !canAct,
  'account': {
    'userId': 'cust_1',
    'fullName': 'Marie Tremblay',
    'email': 'marie@example.test',
    'emailVerified': true,
    'createdAt': '2026-11-01T15:00:00.000Z',
    'lastSignInAt': '2026-11-10T14:00:00.000Z',
    'phone': canAct ? '450 555-1234' : '••• ••• 1234',
    'locale': 'fr',
    'cardOnFile': true,
  },
  'stats': {
    'deliveries': 2,
    'completed': 1,
    'cancelled': 1,
    'spentMinor': 10188,
    'tipsMinor': 945,
    'refundedMinor': 1000,
    'averageRatingGiven': 4.5,
    'quotesNotBooked': 1,
  },
  'badges': ['new', 'watch'],
  'missions': [
    {
      'id': 'm_1',
      'status': 'completed',
      'pickup': '12 rue Principale, Granby',
      'dropoff': '45 boul. Leclerc, Granby',
      'items': '1 × Divan',
      'totalMinor': 7243,
      'createdAt': '2026-11-08T15:00:00.000Z',
      'pickupAt': '2026-11-09T19:00:00.000Z',
      'driverName': 'Marc Caron',
      'depositStatus': 'captured',
      'tipMinor': 945,
    },
  ],
  'quotes': [
    {
      'id': 'q_1',
      'pickup': 'Bromont',
      'dropoff': 'Granby',
      'totalMinor': 9900,
      'createdAt': '2026-11-09T15:00:00.000Z',
    },
  ],
  'payments': [
    {
      'id': 'p_1',
      'kind': 'deposit',
      'status': 'captured',
      'capturedMinor': 2500,
      'refundedMinor': 0,
      'hasReceipt': true,
      'createdAt': '2026-11-08T15:00:00.000Z',
      'stripeUrl': 'https://dashboard.stripe.com/payments/pi_1',
    },
    {
      'id': 'p_2',
      'kind': 'delivery',
      'status': 'capture_failed',
      'authorizedMinor': 4743,
      'capturedMinor': 0,
      'hasReceipt': false,
      'createdAt': '2026-11-09T20:00:00.000Z',
    },
  ],
  'emails': [
    {
      'kind': 'booking_confirmed',
      'status': 'not_configured',
      'createdAt': '2026-11-08T15:00:00.000Z',
    },
  ],
  'notifications': [
    {
      'type': 'pickup_reminder_customer',
      'titleKey': 'notif_pickup_reminder_customer_title',
      'createdAt': '2026-11-09T15:00:00.000Z',
      'read': false,
    },
  ],
  'consents': [
    {
      'missionId': 'm_1',
      'termsVersion': 'V-2026-10',
      'acceptedAt': '2026-11-08T15:00:00.000Z',
      'marketing': true,
    },
  ],
  'notes': [
    {
      'id': 'n_1',
      'text': 'Préfère être appelé',
      'pinned': true,
      'authorName': 'Daniel',
      'createdAt': '2026-11-09T15:00:00.000Z',
    },
  ],
  'staffActions': [
    {
      'action': 'customer_note_added',
      'actorUserId': 'admin_1',
      'createdAt': '2026-11-09T15:00:00.000Z',
    },
  ],
};

class _Calls {
  _Calls(this.file);
  Map<String, dynamic> file;
  final calls = <(String, Map<String, dynamic>)>[];
  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> data,
  ) async {
    calls.add((name, data));
    if (name == 'getAdminCustomerFile') return file;
    return {'outcome': 'sent'};
  }
}

Future<void> _pump(WidgetTester t, _Calls calls, {Size size = const Size(430, 932), double scale = 1}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
    t.platformDispatcher.clearTextScaleFactorTestValue();
  });
  await t.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AdminCustomerFile(userId: 'cust_1', locale: 'fr', call: calls.call),
          ],
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('en-tête, pastilles et chiffres clés', (t) async {
    final calls = _Calls(_file());
    await _pump(t, calls);
    expect(calls.calls.first, ('getAdminCustomerFile', {'userId': 'cust_1'}));
    expect(find.byKey(const ValueKey('badge-new')), findsOneWidget);
    expect(find.byKey(const ValueKey('badge-watch')), findsOneWidget);
    expect(find.textContaining('450 555-1234'), findsOneWidget);
    expect(find.textContaining('vérifié ✓'), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(const ValueKey('stat-spent')), matching: find.textContaining('101,88')),
      findsOneWidget,
    );
    expect(find.textContaining('4,5 ★'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('livraisons : détail et renvoi de la confirmation', (t) async {
    final calls = _Calls(_file());
    await _pump(t, calls);
    expect(find.text('12 rue Principale, Granby → 45 boul. Leclerc, Granby'), findsOneWidget);
    expect(find.byKey(const ValueKey('customer-quote-q_1')), findsOneWidget);
    await _tap(t, find.text('12 rue Principale, Granby → 45 boul. Leclerc, Granby'));
    expect(find.textContaining('Marc Caron'), findsOneWidget);
    await _tap(t, find.byKey(const ValueKey('resend-confirmation-m_1')));
    expect(
      calls.calls.where((c) => c.$1 == 'resendCustomerEmail').single.$2,
      {'userId': 'cust_1', 'kind': 'booking_confirmed', 'missionId': 'm_1'},
    );
    expect(find.text('Confirmation renvoyée.'), findsOneWidget);
  });

  testWidgets('paiements : statut, reçu renvoyé seulement si encaissé', (t) async {
    final calls = _Calls(_file());
    await _pump(t, calls);
    await _tap(t, find.byKey(const ValueKey('customer-file-tab-payments')));
    expect(find.text('Dépôt'), findsOneWidget);
    expect(find.text('Refusé'), findsOneWidget);
    expect(find.byKey(const ValueKey('resend-receipt-p_1')), findsOneWidget);
    expect(find.byKey(const ValueKey('resend-receipt-p_2')), findsNothing);
    await _tap(t, find.byKey(const ValueKey('resend-receipt-p_1')));
    expect(
      calls.calls.where((c) => c.$1 == 'resendCustomerEmail').single.$2,
      {'userId': 'cust_1', 'kind': 'payment_receipt', 'paymentId': 'p_1'},
    );
  });

  testWidgets('communications : courriels, notifications, conditions acceptées', (t) async {
    await _pump(t, _Calls(_file()));
    await _tap(t, find.byKey(const ValueKey('customer-file-tab-messages')));
    expect(find.text('Réservation confirmée'), findsOneWidget);
    expect(find.textContaining('service de courriel pas configuré'), findsOneWidget);
    expect(find.text('Rappel : votre livraison dans 4 h'), findsOneWidget);
    expect(find.textContaining('V-2026-10'), findsOneWidget);
    expect(find.textContaining('Offres promotionnelles : oui'), findsOneWidget);
  });

  testWidgets('notes internes : ajouter et épingler', (t) async {
    final calls = _Calls(_file());
    await _pump(t, calls);
    await _tap(t, find.byKey(const ValueKey('customer-file-tab-notes')));
    expect(find.text('Préfère être appelé'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('customer-note-input')), 'Client très gentil');
    await _tap(t, find.byKey(const ValueKey('customer-note-add')));
    expect(
      calls.calls.where((c) => c.$1 == 'addCustomerNote').single.$2,
      {'userId': 'cust_1', 'text': 'Client très gentil'},
    );
    await _tap(t, find.byKey(const ValueKey('customer-note-pin-n_1')));
    expect(
      calls.calls.where((c) => c.$1 == 'setCustomerNotePinned').single.$2,
      {'noteId': 'n_1', 'pinned': false},
    );
  });

  testWidgets('analyste : vue masquée, aucune action', (t) async {
    await _pump(t, _Calls(_file(canAct: false)));
    expect(find.textContaining('Vue analyste'), findsOneWidget);
    expect(find.textContaining('••• ••• 1234'), findsOneWidget);
    await _tap(t, find.text('12 rue Principale, Granby → 45 boul. Leclerc, Granby'));
    expect(find.byKey(const ValueKey('resend-confirmation-m_1')), findsNothing);
    await _tap(t, find.byKey(const ValueKey('customer-file-tab-notes')));
    expect(find.byKey(const ValueKey('customer-note-input')), findsNothing);
  });

  testWidgets('téléphone, texte 200 % : aucun débordement', (t) async {
    await _pump(t, _Calls(_file()), size: const Size(375, 812), scale: 2);
    for (final tab in ['payments', 'messages', 'notes']) {
      await _tap(t, find.byKey(ValueKey('customer-file-tab-$tab')));
    }
    expect(t.takeException(), isNull);
  });
}
