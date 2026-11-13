import 'package:flutter/material.dart';
import 'package:locara_app/theme/mesh_design_tokens.dart';

enum LocaraButtonVariant {
  primary,
  secondary,
  outline,
  danger,
}

class LocaraAppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final LocaraButtonVariant variant;
  final bool isLoading;
  final double? width;
  final double height;
  final double borderRadius;

  const LocaraAppButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = LocaraButtonVariant.primary,
    this.isLoading = false,
    this.width,
    this.height = 48.0,
    this.borderRadius = LocaraDesignTokens.radiusLarge,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !isLoading;

    Decoration decoration;
    TextStyle textStyle = const TextStyle(
      color: LocaraDesignTokens.primaryText,
      fontSize: 15,
      fontWeight: FontWeight.bold,
    );

    switch (variant) {
      case LocaraButtonVariant.primary:
        decoration = BoxDecoration(
          gradient: isEnabled ? LocaraDesignTokens.primaryGradient : null,
          color: isEnabled ? null : LocaraDesignTokens.cardSurface,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: LocaraDesignTokens.purple.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        );
        break;
      case LocaraButtonVariant.secondary:
        decoration = BoxDecoration(
          color: isEnabled ? LocaraDesignTokens.cardSurface : LocaraDesignTokens.darkNavy,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: LocaraDesignTokens.cardBorder,
            width: 1.2,
          ),
        );
        break;
      case LocaraButtonVariant.outline:
        decoration = BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: isEnabled ? LocaraDesignTokens.cyan : LocaraDesignTokens.mutedText,
            width: 1.2,
          ),
        );
        textStyle = textStyle.copyWith(
          color: isEnabled ? LocaraDesignTokens.cyan : LocaraDesignTokens.mutedText,
        );
        break;
      case LocaraButtonVariant.danger:
        decoration = BoxDecoration(
          color: isEnabled ? LocaraDesignTokens.error : LocaraDesignTokens.cardSurface,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: LocaraDesignTokens.error.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        );
        break;
    }

    Widget content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoading) ...[
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: 10),
        ] else if (icon != null) ...[
          Icon(icon, color: textStyle.color, size: 20),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: textStyle.copyWith(
            color: isEnabled ? textStyle.color : LocaraDesignTokens.mutedText,
          ),
        ),
      ],
    );

    return InkWell(
      onTap: isEnabled ? onPressed : null,
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: decoration,
        alignment: Alignment.center,
        child: content,
      ),
    );
  }
}

/// Mesh button aliases
typedef MeshAppButton = LocaraAppButton;
typedef MeshButtonVariant = LocaraButtonVariant;
