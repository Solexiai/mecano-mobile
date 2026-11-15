import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../services/booking/item_types.dart';
import '../services/pricing/public_price_table.dart';

String _tr(String locale, String fr, String en, String es) => locale == 'en'
    ? en
    : locale == 'es'
    ? es
    : fr;

/// Loads the public price table once; builds nothing until it is there, and
/// nothing at all when it cannot be loaded.
class _PublicPriceLoader extends StatefulWidget {
  const _PublicPriceLoader({required this.builder, this.loader});
  final PublicPriceTableLoader? loader;
  final Widget Function(BuildContext, PublicPriceTable) builder;

  @override
  State<_PublicPriceLoader> createState() => _PublicPriceLoaderState();
}

class _PublicPriceLoaderState extends State<_PublicPriceLoader> {
  PublicPriceTable? _table;

  @override
  void initState() {
    super.initState();
    (widget.loader ?? PublicPriceTableSource.loader)().then((table) {
      if (mounted && table != null) setState(() => _table = table);
    }, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final table = _table;
    return table == null ? const SizedBox.shrink() : widget.builder(context, table);
  }
}

/// The table itself and its footnote, without any frame or title.
class _PriceGrid extends StatelessWidget {
  const _PriceGrid({required this.table, required this.locale});
  final PublicPriceTable table;
  final String locale;

  String _examples(PublicPriceRow row) {
    final names = <String>[];
    for (final id in row.categories) {
      final type = itemTypes.where((t) => t.id == id).firstOrNull;
      if (type == null) continue;
      final short = type.label(locale).split(' / ').first;
      names.add(names.isEmpty ? short : short.toLowerCase());
      if (names.length == 3) break;
    }
    return names.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    const head = TextStyle(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w700,
      fontSize: 13,
    );
    const price = TextStyle(
      color: AppColors.primaryDark,
      fontWeight: FontWeight.w800,
      fontSize: 16,
    );
    Widget cell(Widget child, {Key? key}) => Padding(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: child,
    );
    Widget fitted(String text, TextStyle style) => FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Text(text, style: style, maxLines: 1),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Table(
          columnWidths: {
            0: const FlexColumnWidth(2.4),
            for (var i = 0; i < table.distancesKm.length; i++)
              i + 1: const FlexColumnWidth(1),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          border: const TableBorder(
            horizontalInside: BorderSide(color: AppColors.border),
          ),
          children: [
            TableRow(
              children: [
                cell(
                  Text(
                    _tr(locale, 'Votre objet', 'Your item', 'Tu objeto'),
                    style: head,
                  ),
                ),
                for (final km in table.distancesKm) cell(fitted('$km km', head)),
              ],
            ),
            for (final row in table.rows)
              TableRow(
                children: [
                  cell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          itemClassLabel(row.itemClass, locale),
                          style: const TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (_examples(row).isNotEmpty)
                          Text(
                            _examples(row),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12.5,
                              height: 1.35,
                            ),
                          ),
                      ],
                    ),
                  ),
                  for (var i = 0; i < row.totalsMinor.length; i++)
                    cell(
                      fitted(publicPriceText(row.totalsMinor[i], locale), price),
                      key: ValueKey(
                        'public-price-${row.itemClass}-${table.distancesKm[i]}',
                      ),
                    ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          _tr(
            locale,
            'Pour un objet, sans escaliers, quand vous donnez un coup de main. Le prix exact s’affiche avec vos adresses, avant de payer.',
            'For one item, no stairs, when you lend a hand. The exact price is shown with your addresses, before you pay.',
            'Para un objeto, sin escaleras, cuando echas una mano. El precio exacto se muestra con tus direcciones, antes de pagar.',
          ),
          style: const TextStyle(
            color: AppColors.textSecondary,
            height: 1.5,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

String _approximateLine(String locale) => _tr(
  locale,
  'Prix approximatifs, taxes comprises, livré à l’intérieur.',
  'Approximate prices, taxes included, delivered inside.',
  'Precios aproximados, impuestos incluidos, entrega en el interior.',
);

/// "Combien ça coûte ?" — approximate prices by item class and distance
/// (owner decision 2026-11-13). Amounts come from the active pricing grid.
class PublicPriceTableCard extends StatelessWidget {
  const PublicPriceTableCard({
    super.key,
    required this.locale,
    this.loader,
    this.wrap,
  });
  final String locale;
  final PublicPriceTableLoader? loader;

  /// Outer spacing, applied only once the table is there: a page that cannot
  /// load the prices keeps no empty gap.
  final Widget Function(Widget card)? wrap;

  @override
  Widget build(BuildContext context) => _PublicPriceLoader(
    loader: loader,
    builder: (context, table) {
      final card = Container(
        key: const ValueKey('public-price-table'),
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _tr(locale, 'Combien ça coûte ?', 'How much does it cost?', '¿Cuánto cuesta?'),
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _approximateLine(locale),
              style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 12),
            _PriceGrid(table: table, locale: locale),
          ],
        ),
      );
      return wrap == null ? card : wrap!(card);
    },
  );
}

/// In the booking flow: one line "Une idée des prix : à partir de 54 $" that
/// opens the table (owner request 2026-11-13: an idea of the prices before
/// filling in the request). Open by default on a wide screen.
class PublicPriceHint extends StatelessWidget {
  const PublicPriceHint({super.key, required this.locale, this.loader});
  final String locale;
  final PublicPriceTableLoader? loader;

  @override
  Widget build(BuildContext context) => _PublicPriceLoader(
    loader: loader,
    builder: (context, table) {
      final amount = publicPriceText(table.fromMinor, locale);
      return Container(
        key: const ValueKey('public-price-hint'),
        margin: const EdgeInsets.only(top: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          initiallyExpanded: MediaQuery.sizeOf(context).width >= 900,
          shape: const Border(),
          collapsedShape: const Border(),
          leading: const Icon(Icons.sell_outlined, color: AppColors.primary),
          title: Text(
            _tr(
              locale,
              'Une idée des prix : à partir de $amount',
              'A price idea: from $amount',
              'Una idea de los precios: desde $amount',
            ),
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(_approximateLine(locale)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [_PriceGrid(table: table, locale: locale)],
        ),
      );
    },
  );
}

/// "À partir de 62 $, taxes comprises" with a link to the prices; nothing
/// when the table cannot be loaded.
class PublicPriceFrom extends StatelessWidget {
  const PublicPriceFrom({
    super.key,
    required this.locale,
    required this.onSeePrices,
    this.loader,
  });
  final String locale;
  final VoidCallback onSeePrices;
  final PublicPriceTableLoader? loader;

  @override
  Widget build(BuildContext context) => _PublicPriceLoader(
    loader: loader,
    builder: (context, table) {
      final amount = publicPriceText(table.fromMinor, locale);
      return Padding(
        key: const ValueKey('public-price-from'),
        padding: const EdgeInsets.only(top: 14),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            Text(
              _tr(
                locale,
                'À partir de $amount, taxes comprises.',
                'From $amount, taxes included.',
                'Desde $amount, impuestos incluidos.',
              ),
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            TextButton(
              key: const ValueKey('public-price-from-link'),
              onPressed: onSeePrices,
              child: Text(
                _tr(locale, 'Voir les prix', 'See prices', 'Ver precios'),
              ),
            ),
          ],
        ),
      );
    },
  );
}
