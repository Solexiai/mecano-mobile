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
