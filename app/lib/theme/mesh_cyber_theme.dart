import 'dart:ui';
import 'package:flutter/material.dart';

class MeshCyberColors {
  MeshCyberColors._();

  static const Color background = Color(0xFF070B1A);
  static const Color backgroundSurface = Color(0xFF0A1026);
  static const Color backgroundGradientTop = Color(0xFF070B1A);
  static const Color backgroundGradientBottom = Color(0xFF050814);

  // Aurora Ambient Lights
  static const Color auroraCyan = Color(0xFF12D8E8);
  static const Color auroraBlue = Color(0xFF168BFF);
  static const Color auroraPurple = Color(0xFF7838F5);
  static const Color auroraMagenta = Color(0xFFB5179E);

  // Cards and Glass
  static const Color cardGlass = Color(0xCC10172D);
  static const Color cardGlassLighter = Color(0xEE151F3D);
  static const Color cardBorder = Color(0x3812D8E8);
  static const Color cardBorderSubtle = Color(0x2212D8E8);

  // Accents and Status
  static const Color primaryBlue = Color(0xFF168BFF);
  static const Color primaryCyan = Color(0xFF12D8E8);
  static const Color neonPurple = Color(0xFF7838F5);
  static const Color statusGreen = Color(0xFF20D890);
  static const Color statusGreenGlow = Color(0x5520D890);
  static const Color statusAmber = Color(0xFFF5B942);

  // Text
  static const Color textWhite = Color(0xFFF4F6FF);
  static const Color textSecondary = Color(0xFFA8B1CA);
  static const Color textMuted = Color(0xFF6B7A99);

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

class MeshCyberTheme {
  MeshCyberTheme._();

  static BoxDecoration glassCardDecoration({
    double borderRadius = 24,
    Color? borderColor,
    Color? fillColor,
    bool withGlow = false,
  }) {
    return BoxDecoration(
      color: fillColor ?? MeshCyberColors.cardGlass,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? MeshCyberColors.cardBorder,
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
            color: (borderColor ?? MeshCyberColors.auroraCyan).withValues(alpha: 0.15),
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

/// Legacy aliases for backward compatibility
typedef LocaraCyberTheme = MeshCyberTheme;
typedef LocaraCyberColors = MeshCyberColors;
