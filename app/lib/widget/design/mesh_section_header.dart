import 'package:flutter/material.dart';
import 'package:locara_app/theme/mesh_design_tokens.dart';

class LocaraSectionHeader extends StatelessWidget {
  final String title;
  final bool hasLiveIndicator;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? padding;

  const LocaraSectionHeader({
    required this.title,
    this.hasLiveIndicator = false,
    this.actionLabel,
    this.onAction,
    this.padding,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(vertical: LocaraDesignTokens.spacing8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: LocaraDesignTokens.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (hasLiveIndicator) ...[
                const SizedBox(width: LocaraDesignTokens.spacing8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: LocaraDesignTokens.success,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: LocaraDesignTokens.success,
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (actionLabel != null && onAction != null)
            InkWell(
              onTap: onAction,
              borderRadius: LocaraDesignTokens.borderRadiusLarge,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: LocaraDesignTokens.cardSurfaceLight.withValues(alpha: 0.7),
                  borderRadius: LocaraDesignTokens.borderRadiusLarge,
                  border: Border.all(
                    color: LocaraDesignTokens.cardBorderSubtle,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionLabel!,
                      style: LocaraDesignTokens.labelSmall.copyWith(
                        color: LocaraDesignTokens.primaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_back_rounded,
                      color: LocaraDesignTokens.primaryText,
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Mesh section header alias
typedef MeshSectionHeader = LocaraSectionHeader;
