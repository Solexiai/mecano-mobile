import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:movik_connect/core/app_colors.dart';
import 'package:movik_connect/l10n/app_strings.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/dashboard/admin/finance/finance_ui_helpers.dart';
import 'package:movik_connect/widgets/coming_soon_badge.dart';

double _linear(double x) =>
    x <= 0.04045 ? x / 12.92 : math.pow((x + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color color) =>
    0.2126 * _linear(color.r) +
    0.7152 * _linear(color.g) +
    0.0722 * _linear(color.b);

double _contrast(Color a, Color b) {
  final l1 = _luminance(a);
  final l2 = _luminance(b);
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}

void main() {
  test(
    'P2-L-01 warning labels exceed WCAG AA 4.5:1 in light and dark tinted badges',
    () {
      final bgLight = Color.alphaBlend(
        AppColors.warning.withValues(alpha: 0.14),
        AppColors.surface,
      );
      final bgDark = Color.alphaBlend(
        AppColors.warning.withValues(alpha: 0.14),
        AppColors.surfaceDark,
      );
      expect(
        _contrast(AppColors.warningBadgeTextLight, bgLight),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(AppColors.warningBadgeTextDark, bgDark),
        greaterThanOrEqualTo(4.5),
      );
      expect(_contrast(AppColors.warning, bgLight), lessThan(4.5));
      expect(
        AppColors.statusBadgeTextColor(AppColors.success, Brightness.light),
        AppColors.success,
      );
      expect(
        AppColors.statusBadgeTextColor(AppColors.error, Brightness.dark),
        AppColors.error,
      );
    },
  );

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets(
      'StatusBadge warning text adapts to $brightness without changing the tone',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: const Scaffold(
              body: Center(
                child: StatusBadge(label: 'Pending', color: AppColors.warning),
              ),
            ),
          ),
        );
        final text = tester.widget<Text>(find.text('Pending'));
        expect(
          text.style?.color,
          AppColors.statusBadgeTextColor(AppColors.warning, brightness),
        );
        final badge = tester.widget<Container>(
          find
              .ancestor(
                of: find.text('Pending'),
                matching: find.byType(Container),
              )
              .first,
        );
        final fill = (badge.decoration! as BoxDecoration).color!;
        expect(_contrast(text.style!.color!, fill), greaterThanOrEqualTo(4.5));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'ComingSoonBadge has accessible warning text and icon at $brightness',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: ChangeNotifierProvider<LocaleProvider>(
              create: (_) => LocaleProvider(),
              child: const Scaffold(body: Center(child: ComingSoonBadge())),
            ),
          ),
        );
        await tester.pump();
        final label = AppStrings.t('common_coming_soon', 'fr');
        final expected = AppColors.statusBadgeTextColor(
          AppColors.warning,
          brightness,
        );
        expect(tester.widget<Text>(find.text(label)).style?.color, expected);
        expect(
          tester.widget<Icon>(find.byIcon(Icons.access_time_rounded)).color,
          expected,
        );
        final badge = tester.widget<Container>(
          find
              .ancestor(of: find.text(label), matching: find.byType(Container))
              .first,
        );
        final fill = (badge.decoration! as BoxDecoration).color!;
        expect(_contrast(expected, fill), greaterThanOrEqualTo(4.5));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
