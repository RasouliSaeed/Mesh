import 'dart:ui';
import 'package:flutter/material.dart';

class LocaraCyberColors {
  LocaraCyberColors._();

  static const Color background = Color(0xFF030712);
  static const Color backgroundSurface = Color(0xFF060B18);
  static const Color backgroundGradientTop = Color(0xFF050E24);
  static const Color backgroundGradientBottom = Color(0xFF02040A);

  // Aurora Ambient Lights
  static const Color auroraCyan = Color(0xFF00D2FF);
  static const Color auroraBlue = Color(0xFF0066FF);
  static const Color auroraPurple = Color(0xFF8A2BE2);
  static const Color auroraMagenta = Color(0xFFB5179E);

  // Cards and Glass
  static const Color cardGlass = Color(0xCC0B1428);
  static const Color cardGlassLighter = Color(0xEE0E1C38);
  static const Color cardBorder = Color(0x3800D2FF);
  static const Color cardBorderSubtle = Color(0x2200D2FF);

  // Accents and Status
  static const Color primaryBlue = Color(0xFF0066FF);
  static const Color primaryCyan = Color(0xFF00E5FF);
  static const Color neonPurple = Color(0xFF9D4EDD);
  static const Color statusGreen = Color(0xFF00E676);
  static const Color statusGreenGlow = Color(0x5500E676);

  // Text
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8EA2C6);
  static const Color textMuted = Color(0xFF53678A);

  // Gradients
  static const LinearGradient sendButtonGradient = LinearGradient(
    colors: [
      Color(0xFF00B4D8),
      Color(0xFF7209B7),
    ],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient activeTabGradient = LinearGradient(
    colors: [
      Color(0xFF0066FF),
      Color(0xFF00D2FF),
    ],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient backgroundAmbientGradient = LinearGradient(
    colors: [
      Color(0xFF040A1C),
      Color(0xFF08122E),
      Color(0xFF030712),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class LocaraCyberTheme {
  LocaraCyberTheme._();

  static BoxDecoration glassCardDecoration({
    double borderRadius = 24,
    Color? borderColor,
    Color? fillColor,
    bool withGlow = false,
  }) {
    return BoxDecoration(
      color: fillColor ?? LocaraCyberColors.cardGlass,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? LocaraCyberColors.cardBorder,
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
        if (withGlow)
          BoxShadow(
            color: (borderColor ?? LocaraCyberColors.auroraCyan).withValues(alpha: 0.15),
            blurRadius: 18,
            spreadRadius: 1,
          ),
      ],
    );
  }

  static Widget glassContainer({
    required Widget child,
    double borderRadius = 24,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Color? borderColor,
    Color? fillColor,
    bool withGlow = false,
  }) {
    return Container(
      margin: margin,
      decoration: glassCardDecoration(
        borderRadius: borderRadius,
        borderColor: borderColor,
        fillColor: fillColor,
        withGlow: withGlow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Mesh cyber theme and colors aliases
typedef MeshCyberTheme = LocaraCyberTheme;
typedef MeshCyberColors = LocaraCyberColors;
