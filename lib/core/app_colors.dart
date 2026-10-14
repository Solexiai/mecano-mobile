import 'package:flutter/material.dart';

/// Movi-k brand colors — Style 2: premium colorful with glassmorphism accents.
class AppColors {
  AppColors._();

  // Primary deep blue
  static const Color primary = Color(0xFF0F2A5C);
  static const Color primaryLight = Color(0xFF1E4B94);
  static const Color primaryDark = Color(0xFF081A3D);

  // Secondary green (confirmed / success)
  static const Color success = Color(0xFF1FAE6E);
  static const Color successLight = Color(0xFF34D399);

  // Accent glow colors (glassmorphism)
  static const Color glowBlue = Color(0xFF3B82F6);
  static const Color glowGreen = Color(0xFF22E39A);

  // Neutral
  static const Color background = Color(0xFFF6F8FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF122142);
  static const Color backgroundDark = Color(0xFF081226);

  static const Color textPrimary = Color(0xFF0B1220);
  static const Color textSecondary = Color(0xFF54607A);
  static const Color textOnDark = Color(0xFFF3F6FC);
  static const Color textOnDarkSecondary = Color(0xFFAAB6CE);

  static const Color border = Color(0xFFE3E8F2);
  static const Color borderDark = Color(0xFF223058);

  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFE0473C);
  static const Color info = Color(0xFF3B82F6);

  // Bloc L (Accessibilité MVP, L-6) : `warning` (0xF59E0B) donne un
  // contraste de ~2.15:1 sur fond blanc/clair — sous le seuil WCAG AA
  // (4.5:1 texte normal) et même sous le seuil "large text"/icône (3:1).
  // `warningText` (ambre plus foncé) est réservé aux endroits où la
  // couleur "warning" est utilisée comme couleur de TEXTE lisible (pas
  // un simple badge/pastille décoratif) — contraste ~5.0:1 sur blanc,
  // ~4.7:1 sur `background`. Pour les textes de badges sur un fond
  // légèrement teinté, P2-L-01 utilise les variantes warningBadgeTextLight/
  // warningBadgeTextDark et laisse la couleur warning décorative intacte.
  // Les statuts et leurs correspondances métier restent inchangés.
  static const Color warningText = Color(0xFFB45309);

  // P2-L-01: color of readable warning labels on translucent badge backgrounds.
  // Keep warning itself for the background/border; do not change status maps.
  static const Color warningBadgeTextLight = Color(0xFF92400E);
  static const Color warningBadgeTextDark = Color(0xFFFDE68A);

  static Color statusBadgeTextColor(Color statusColor, Brightness brightness) {
    if (statusColor != warning) return statusColor;
    return brightness == Brightness.dark
        ? warningBadgeTextDark
        : warningBadgeTextLight;
  }

  // The warning badge background is opaque after blending with the themed
  // surface. It remains legible even inside legacy screens that hard-code a
  // different parent surface color in dark mode.
  static Color statusBadgeBackground(
    Color statusColor,
    Brightness brightness, {
    double alpha = 0.12,
  }) {
    if (statusColor != warning) return statusColor.withValues(alpha: alpha);
    return Color.alphaBlend(
      warning.withValues(alpha: alpha),
      brightness == Brightness.dark ? surfaceDark : surface,
    );
  }

  // Gradients
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0B1E44), Color(0xFF14336E), Color(0xFF0F2A5C)],
  );

  static const LinearGradient deliveryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E4B94), Color(0xFF3B82F6)],
  );

  static const LinearGradient mechanicGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF117A54), Color(0xFF22E39A)],
  );

  static const LinearGradient glassOverlay = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x33FFFFFF), Color(0x0DFFFFFF)],
  );
}
