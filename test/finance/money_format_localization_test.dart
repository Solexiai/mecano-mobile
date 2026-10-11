import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/finance/presentation/money_format.dart';

void main() {
  test('S legacy consumers retain exact major/minor formatting', () {
    for (final value in [0.0, 1.5, 10.0, 1234.5, -1.5, 1234567.89]) {
      expect(formatMajorAmount(value), '${value.toStringAsFixed(2)} \$');
      expect(
        formatMajorAmount(value, currencySymbol: 'CAD'),
        '${value.toStringAsFixed(2)} CAD',
      );
    }
    expect(formatMinorAmount(150), '1.50 \$');
    expect(formatMinorAmount(-150), '-1.50 \$');
    expect(formatMinorAmount(123450), '1234.50 \$');
  });
  for (final locale in ['fr', 'en', 'es']) {
    test('S unknown/nonfinite display values $locale stay unknown', () {
      for (final value in [
        null,
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        expect(formatMajorAmount(value, locale: locale), '—');
        expect(formatDistanceKm(value, locale: locale), '—');
      }
      expect(formatDistanceKm(-1, locale: locale), '—');
    });
  }
  test('S locale tags and unknown-language fallback match current app', () {
    for (final pair in [
      ('fr-CA', 'fr'),
      ('en-CA', 'en'),
      ('es-MX', 'es'),
      ('unknown', 'fr'),
    ]) {
      expect(
        formatMajorAmount(1234.5, locale: pair.$1),
        formatMajorAmount(1234.5, locale: pair.$2),
      );
      expect(
        formatDistanceKm(1234.5, locale: pair.$1),
        formatDistanceKm(1234.5, locale: pair.$2),
      );
    }
  });
  test('S fractional precision affects strings only, never source values', () {
    const source = {
      'customerTotal': 1234.5,
      'customerTotalMinor': 123450,
      'distanceKm': 10.54,
    };
    final original = Map<String, num>.from(source);
    expect(
      formatMajorAmount(source['customerTotal'], locale: 'fr'),
      '1\u00a0234,50\u00a0\$',
    );
    expect(formatDistanceKm(source['distanceKm'], locale: 'fr'), '10,5 km');
    expect(source, original);
    expect(source['customerTotalMinor'], 123450);
    expect(source['distanceKm'], 10.54);
  });
}
