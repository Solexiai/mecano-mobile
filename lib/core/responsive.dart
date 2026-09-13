import 'package:flutter/material.dart';

/// Canonical responsive breakpoints for the Movi-k web experience.
///
/// The product is web-first, but every route must remain usable from a
/// phone or tablet browser. Keep breakpoint decisions centralized here so
/// individual screens do not drift toward incompatible thresholds.
abstract final class AppBreakpoints {
  static const double phone = 600;
  static const double desktop = 1024;
  static const double wide = 1200;
  static const double contentMaxWidth = 1140;

  static bool isPhone(double width) => width < phone;

  static bool isTablet(double width) => width >= phone && width < desktop;

  static bool isDesktop(double width) => width >= desktop;

  static double pageHorizontalPadding(double width) {
    if (width < 360) return 12;
    if (width < phone) return 16;
    if (width < desktop) return 24;
    if (width < wide) return 32;
    return 48;
  }
}

extension ResponsiveContext on BuildContext {
  double get viewportWidth => MediaQuery.sizeOf(this).width;

  bool get isPhoneViewport => AppBreakpoints.isPhone(viewportWidth);

  bool get isTabletViewport => AppBreakpoints.isTablet(viewportWidth);

  bool get isDesktopViewport => AppBreakpoints.isDesktop(viewportWidth);
}
