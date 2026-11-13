import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:locara_app/theme/mesh_design_tokens.dart';

class LocaraGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? borderColor;
  final Color? fillColor;
  final VoidCallback? onTap;
  final bool withGlow;

  const LocaraGlassCard({
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = LocaraDesignTokens.radiusExtraLarge,
    this.borderColor,
    this.fillColor,
    this.onTap,
    this.withGlow = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor = borderColor ?? LocaraDesignTokens.cardBorderSubtle;
    final effectiveFillColor = fillColor ?? LocaraDesignTokens.cardSurface.withValues(alpha: 0.85);

    Widget card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: effectiveFillColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: effectiveBorderColor,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          if (withGlow)
            BoxShadow(
              color: effectiveBorderColor.withValues(alpha: 0.2),
              blurRadius: 16,
              spreadRadius: 1,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(LocaraDesignTokens.spacing16),
            child: child,
          ),
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: card,
      );
    }

    return card;
  }
}

/// Mesh glass card alias
typedef MeshGlassCard = LocaraGlassCard;
