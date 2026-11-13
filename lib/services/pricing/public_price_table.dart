import 'package:cloud_functions/cloud_functions.dart';

/// Approximate public prices (owner decision 2026-11-13): one row per item
/// class, one column per distance, computed by the server from the active
/// pricing grid (getPublicPriceTable). Customer totals only, taxes included.
class PublicPriceRow {
  const PublicPriceRow({
    required this.itemClass,
    required this.categories,
    required this.totalsMinor,
  });
  final String itemClass;
  final List<String> categories;
  final List<int> totalsMinor;
}

class PublicPriceTable {
  const PublicPriceTable({
    required this.distancesKm,
    required this.rows,
    required this.fromMinor,
  });
  final List<int> distancesKm;
  final List<PublicPriceRow> rows;

  /// The lowest price of the table: "à partir de".
  final int fromMinor;

  /// Null on any unexpected shape: the page then shows no price rather than a
  /// wrong one.
  static PublicPriceTable? fromJson(Object? raw) {
    if (raw is! Map) return null;
    List<int>? ints(Object? value) {
      if (value is! List || value.isEmpty) return null;
      final out = <int>[];
      for (final v in value) {
        if (v is! num || v <= 0 || v != v.roundToDouble()) return null;
        out.add(v.toInt());
      }
      return out;
    }

    final distances = ints(raw['distances_km']);
    final from = raw['from_minor'];
    final rawRows = raw['rows'];
    if (distances == null ||
        from is! num ||
        from <= 0 ||
        rawRows is! List ||
        rawRows.isEmpty) {
      return null;
    }
    final rows = <PublicPriceRow>[];
    for (final r in rawRows) {
      if (r is! Map || r['item_class'] is! String) return null;
      final totals = ints(r['totals_minor']);
      if (totals == null || totals.length != distances.length) return null;
      rows.add(
        PublicPriceRow(
          itemClass: r['item_class'] as String,
          categories: [
            for (final c in (r['categories'] as List? ?? const []))
              if (c is String) c,
          ],
          totalsMinor: totals,
        ),
      );
    }
    return PublicPriceTable(
      distancesKm: distances,
      rows: rows,
      fromMinor: from.toInt(),
    );
  }
}

typedef PublicPriceTableLoader = Future<PublicPriceTable?> Function();

/// Where the public pages read the table. Tests replace [loader].
class PublicPriceTableSource {
  static PublicPriceTableLoader loader = _fromServer;
  static Future<PublicPriceTable?>? _session;

  static void reset() {
    loader = _fromServer;
    _session = null;
  }

  /// One server call per session, shared by the home page and the pricing
  /// page; a failure is not remembered, so the next page tries again.
  static Future<PublicPriceTable?> _fromServer() async {
    final pending = _session;
    if (pending != null) return pending;
    final call = _fetch();
    _session = call;
    final table = await call;
    if (table == null) _session = null;
    return table;
  }

  static Future<PublicPriceTable?> _fetch() async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('getPublicPriceTable')
          .call(<String, dynamic>{});
      return PublicPriceTable.fromJson(result.data);
    } catch (_) {
      // No price is better than a broken page: the pages hide the table.
      return null;
    }
  }
}

/// Whole dollars, rounded: "62 $" (fr, es) or "$62" (en).
String publicPriceText(int minor, String locale) {
  final dollars = (minor / 100).round();
  return locale == 'en' ? '\$$dollars' : '$dollars \$';
}
