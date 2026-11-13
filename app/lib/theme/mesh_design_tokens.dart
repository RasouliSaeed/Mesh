import 'package:flutter/material.dart';

/// Centralized Design Tokens for Locara
/// Strict adherence to Section 3.2 of the Master Specification.
class LocaraDesignTokens {
  LocaraDesignTokens._();

  // === Color Tokens ===
  static const Color deepNavy = Color(0xFF07142F);
  static const Color darkNavy = Color(0xFF0B1D40);
  static const Color cardSurface = Color(0xFF10244B);
  static const Color cardSurfaceLight = Color(0xFF152D5E);
  static const Color primaryBlue = Color(0xFF087BEE);
  static const Color electricBlue = Color(0xFF176BFF);
  static const Color cyan = Color(0xFF12D8E8);
  static const Color purple = Color(0xFF842CF4);
  static const Color success = Color(0xFF16C784);
  static const Color warning = Color(0xFFF5AD36);
  static const Color error = Color(0xFFF05267);
  static const Color primaryText = Color(0xFFF4F7FF);
  static const Color secondaryText = Color(0xFFA9B9D8);
  static const Color mutedText = Color(0xFF7486A9);

  // Border & Glow Overlay Tokens
  static const Color cardBorder = Color(0x3812D8E8);
  static const Color cardBorderSubtle = Color(0x2212D8E8);
  static const Color cardBorderFocus = Color(0x7712D8E8);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryBlue, purple],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient electricCyanGradient = LinearGradient(
    colors: [primaryBlue, cyan],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [
      Color(0xFF050E24),
      deepNavy,
      Color(0xFF040A1A),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // === Spacing Tokens (4/8pt Grid) ===
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing28 = 28.0;
  static const double spacing32 = 32.0;
  static const double spacing48 = 48.0;

  // === Radius Tokens ===
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusExtraLarge = 24.0;
  static const double radiusPill = 999.0;

  static final BorderRadius borderRadiusSmall = BorderRadius.circular(radiusSmall);
  static final BorderRadius borderRadiusMedium = BorderRadius.circular(radiusMedium);
  static final BorderRadius borderRadiusLarge = BorderRadius.circular(radiusLarge);
  static final BorderRadius borderRadiusExtraLarge = BorderRadius.circular(radiusExtraLarge);
  static final BorderRadius borderRadiusPill = BorderRadius.circular(radiusPill);

  // === Typography Styles ===
  static const TextStyle displayLarge = TextStyle(
    color: primaryText,
    fontSize: 32,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.5,
  );

  static const TextStyle headlineMedium = TextStyle(
    color: primaryText,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  static const TextStyle titleLarge = TextStyle(
    color: primaryText,
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle titleMedium = TextStyle(
    color: primaryText,
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle bodyRegular = TextStyle(
    color: secondaryText,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  static const TextStyle bodySmall = TextStyle(
    color: secondaryText,
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle labelSmall = TextStyle(
    color: mutedText,
    fontSize: 11,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle numericData = TextStyle(
    color: primaryText,
    fontSize: 15,
    fontWeight: FontWeight.bold,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

/// Mesh design tokens alias
typedef MeshDesignTokens = LocaraDesignTokens;
