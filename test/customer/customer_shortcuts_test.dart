// "Ramasser à" (owner mockup 2026-10-25, decided 2026-10-26): one tap opens
// a booking already filled in; the home address is saved from the account.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/dashboard/customer/tabs/customer_overview_tab.dart';
import 'package:movik_connect/services/account/saved_addresses.dart';
import 'package:movik_connect/services/address/address_backend_locator.dart';
import 'package:movik_connect/services/booking/booking_draft.dart';
import 'package:movik_connect/widgets/address_autocomplete_field.dart';

import '../helpers/fake_address_autocomplete_provider.dart';

const _uid = 'customer_shortcuts';
const _home = {
  'line1': '12 rue Fictive',
  'city': 'Granby',
  'postal_code': 'J2G 0A1',
  'lat': 45.4,
  'lng': -72.7,
  'formatted_address': '12 rue Fictive, Granby, QC',
  'place_id': 'fake_home',
};

class _Saved extends SavedAddresses {
  _Saved(this.value);
  Map<String, dynamic>? value;
  int saves = 0;
  @override
  Future<Map<String, dynamic>?> home(String uid) async => value;
  @override
  Future<void> saveHome(String uid, Map<String, dynamic> address) async {
    saves++;
    value = address;
  }
}

Future<void> _pump(WidgetTester t) async {
  SharedPreferences.setMockInitialValues({});
  await t.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => LocaleProvider(),
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/fr/tableau-de-bord',
          routes: [
            GoRoute(
              path: '/fr/tableau-de-bord',
              builder: (_, __) => const Scaffold(
                body: SingleChildScrollView(
                  child: PickupShortcuts(uid: _uid, locale: 'fr'),
                ),
              ),
            ),
            GoRoute(
              path: '/fr/livraison/demande',
              builder: (_, __) => const Scaffold(body: Text('BOOKING')),
            ),
          ],
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  late FakeAddressAutocompleteProvider places;
  setUp(() {
    places = FakeAddressAutocompleteProvider();
    AddressBackendLocator.autocompleteProviderOverride = places;
  });
  tearDown(() {
    SavedAddresses.override = null;
    AddressBackendLocator.autocompleteProviderOverride = null;
  });

  testWidgets('a store fills the pickup search and delivers home', (t) async {
    SavedAddresses.override = _Saved(Map.of(_home));
    await _pump(t);
    expect(find.text('Ramasser à'), findsOneWidget);
    for (final name in ['Maison', 'IKEA', 'Costco', 'Canadian Tire', 'Marketplace']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('shortcut-home-note')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('shortcut-ikea')));
    await t.pumpAndSettle();
    expect(find.text('BOOKING'), findsOneWidget);
    final draft = (await BookingDraftStorage().load(_uid))!;
    expect(draft.data['pickup'], isNull);
    expect(draft.data['pickup_text'], 'IKEA Granby');
    expect(draft.data['pickup_shortcut'], 'ikea');
    expect((draft.data['dropoff'] as Map)['line1'], '12 rue Fictive');
    expect(draft.items, isEmpty);
  });

  testWidgets('"Maison" picks up at home', (t) async {
    SavedAddresses.override = _Saved(Map.of(_home));
    await _pump(t);
    await t.tap(find.byKey(const ValueKey('shortcut-home')));
    await t.pumpAndSettle();
    final draft = (await BookingDraftStorage().load(_uid))!;
    expect((draft.data['pickup'] as Map)['city'], 'Granby');
    expect(draft.data['dropoff'], isNull);
  });

  testWidgets('"Marketplace" asks for the seller address, delivers home', (t) async {
    SavedAddresses.override = _Saved(Map.of(_home));
    await _pump(t);
    await t.tap(find.byKey(const ValueKey('shortcut-marketplace')));
    await t.pumpAndSettle();
    final draft = (await BookingDraftStorage().load(_uid))!;
    expect(draft.data['pickup_shortcut'], 'marketplace');
    expect(draft.data['pickup_text'], isNull);
    expect((draft.data['dropoff'] as Map)['line1'], '12 rue Fictive');
  });

  testWidgets('no home yet: "Maison" asks for it once, then books', (t) async {
    final saved = _Saved(null);
    SavedAddresses.override = saved;
    await _pump(t);
    expect(find.byKey(const ValueKey('shortcut-add-home')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('shortcut-home')));
    await t.pumpAndSettle();
    expect(find.text('Votre adresse (Maison)'), findsOneWidget);
    await typeAndSelectAddress(t, 0, '12 rue Fictive');
    await t.tap(find.byKey(const ValueKey('home-address-save')));
    await t.pumpAndSettle();
    expect(saved.saves, 1);
    expect(saved.value!['city'], 'FakeVille');
    // Saved, then straight to the booking, picked up at home.
    expect(find.text('BOOKING'), findsOneWidget);
    final draft = (await BookingDraftStorage().load(_uid))!;
    expect((draft.data['pickup'] as Map)['city'], 'FakeVille');
  });

  testWidgets('the pre-filled search shows suggestions without typing', (t) async {
    final controller = TextEditingController(text: 'IKEA Granby');
    addTearDown(controller.dispose);
    await t.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LocaleProvider(),
        child: MaterialApp(
          home: Scaffold(
            body: AddressAutocompleteField(
              controller: controller,
              label: 'Ramassage',
              searchInitialText: true,
              onResolved: (_) {},
              onInvalidated: () {},
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(places.searchCallCount, 1);
    expect(find.textContaining('IKEA Granby (adresse résolue)'), findsOneWidget);
  });

  test('a saved home needs a street, a city and coordinates', () {
    expect(SavedAddresses.parseHome({'saved_addresses': {'home': _home}}), isNotNull);
    expect(SavedAddresses.parseHome(null), isNull);
    expect(SavedAddresses.parseHome({'saved_addresses': {'home': {'line1': 'x'}}}), isNull);
  });
}
