// 2026-11-13 : tableau de prix public (page Tarifs) et « à partir de »
// (accueil). Les montants viennent du serveur (grille active) ; sans réponse
// valide, rien ne s'affiche.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/services/pricing/public_price_table.dart';
import 'package:movik_connect/widgets/public_price_table_card.dart';

Map<String, dynamic> serverTable() => {
  'currency': 'CAD',
  'distances_km': [5, 10, 20, 40],
  'rows': [
    {
      'item_class': 'light',
      'categories': ['chairs', 'tv', 'sport', 'boxes'],
      'totals_minor': [5249, 6100, 8000, 12000],
    },
    {
      'item_class': 'heavy',
      'categories': ['sofa', 'bed', 'fridge', 'freezer'],
      'totals_minor': [6749, 7600, 9500, 13551],
    },
  ],
  'from_minor': 5249,
  'taxes_included': true,
};

Future<void> pump(
  WidgetTester t,
  Widget child, {
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
    t.platformDispatcher.clearTextScaleFactorTestValue();
  });
  await t.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  test('reads the server table and refuses a broken one', () {
    final table = PublicPriceTable.fromJson(serverTable())!;
    expect(table.distancesKm, [5, 10, 20, 40]);
    expect(table.rows.map((r) => r.itemClass), ['light', 'heavy']);
    expect(table.rows.last.totalsMinor.last, 13551);
    expect(table.fromMinor, 5249);

    expect(PublicPriceTable.fromJson(null), isNull);
    expect(PublicPriceTable.fromJson({...serverTable(), 'rows': []}), isNull);
    expect(
      PublicPriceTable.fromJson({...serverTable(), 'from_minor': 0}),
      isNull,
    );
    final short = serverTable();
    (short['rows'] as List).first['totals_minor'] = [5249, 6100];
    expect(PublicPriceTable.fromJson(short), isNull);
  });

  test('whole dollars in each language', () {
    expect(publicPriceText(5249, 'fr'), '52 \$');
    expect(publicPriceText(5250, 'fr'), '53 \$');
    expect(publicPriceText(13551, 'en'), '\$136');
    expect(publicPriceText(6749, 'es'), '67 \$');
  });

  for (final view in [
    (const Size(320, 700), 1.0),
    (const Size(390, 844), 2.0),
    (const Size(1440, 900), 1.0),
  ]) {
    testWidgets('the price table fits $view', (t) async {
      await pump(
        t,
        PublicPriceTableCard(
          locale: 'fr',
          loader: () async => PublicPriceTable.fromJson(serverTable()),
        ),
        size: view.$1,
        scale: view.$2,
      );
      expect(find.byKey(const ValueKey('public-price-table')), findsOneWidget);
      expect(find.text('Combien ça coûte ?'), findsOneWidget);
      expect(find.text('Léger'), findsOneWidget);
      expect(find.text('Lourd'), findsOneWidget);
      expect(find.text('Divan, lit, réfrigérateur'), findsOneWidget);
      expect(find.text('20 km'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('public-price-heavy-40')),
          matching: find.text('136 \$'),
        ),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('no table when the prices cannot be loaded', (t) async {
    await pump(
      t,
      PublicPriceTableCard(locale: 'fr', loader: () async => null),
    );
    expect(find.byKey(const ValueKey('public-price-table')), findsNothing);
    expect(find.textContaining('\$'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('no empty gap around the card when prices are missing', (
    t,
  ) async {
    Widget framed(PublicPriceTableLoader loader) => PublicPriceTableCard(
      locale: 'fr',
      loader: loader,
      wrap: (card) => Padding(
        key: const ValueKey('price-gap'),
        padding: const EdgeInsets.all(40),
        child: card,
      ),
    );
    await pump(t, framed(() async => null));
    expect(find.byKey(const ValueKey('price-gap')), findsNothing);
    await pump(
      t,
      KeyedSubtree(
        key: const ValueKey('loaded'),
        child: framed(() async => PublicPriceTable.fromJson(serverTable())),
      ),
    );
    expect(find.byKey(const ValueKey('price-gap')), findsOneWidget);
    expect(find.byKey(const ValueKey('public-price-table')), findsOneWidget);
  });

  testWidgets('booking hint: one line on a phone, opens the table on tap', (
    t,
  ) async {
    await pump(
      t,
      PublicPriceHint(
        locale: 'fr',
        loader: () async => PublicPriceTable.fromJson(serverTable()),
      ),
      size: const Size(375, 812),
    );
    expect(
      find.text('Une idée des prix : à partir de 52\u00A0\$'),
      findsOneWidget,
    );
    expect(find.text('20 km'), findsNothing);
    await t.tap(find.byKey(const ValueKey('public-price-hint')));
    await t.pumpAndSettle();
    expect(find.text('20 km'), findsOneWidget);
    expect(find.text('Lourd'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('booking hint: already open on a wide screen', (t) async {
    await pump(
      t,
      PublicPriceHint(
        locale: 'en',
        loader: () async => PublicPriceTable.fromJson(serverTable()),
      ),
      size: const Size(1440, 900),
    );
    expect(find.text('A price idea: from \$52'), findsOneWidget);
    expect(find.text('20 km'), findsOneWidget);
    expect(find.text('Heavy'), findsOneWidget);
  });

  testWidgets('no booking hint without prices', (t) async {
    await pump(t, PublicPriceHint(locale: 'fr', loader: () async => null));
    expect(find.byKey(const ValueKey('public-price-hint')), findsNothing);
  });

  testWidgets('the home teaser shows the lowest price and opens the prices', (
    t,
  ) async {
    var opened = 0;
    await pump(
      t,
      PublicPriceFrom(
        locale: 'fr',
        onSeePrices: () => opened++,
        loader: () async => PublicPriceTable.fromJson(serverTable()),
      ),
    );
    expect(
      find.text('À partir de 52 \$, taxes comprises.'),
      findsOneWidget,
    );
    await t.tap(find.byKey(const ValueKey('public-price-from-link')));
    expect(opened, 1);
  });

  testWidgets('no teaser without prices', (t) async {
    await pump(
      t,
      PublicPriceFrom(
        locale: 'en',
        onSeePrices: () {},
        loader: () async => null,
      ),
    );
    expect(find.byKey(const ValueKey('public-price-from')), findsNothing);
  });
}
