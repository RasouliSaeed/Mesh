import 'package:flutter/material.dart';
import 'package:locara_app/theme/mesh_design_tokens.dart';
import 'package:locara_app/widget/design/mesh_app_button.dart';
import 'package:locara_app/widget/design/mesh_glass_card.dart';

class LocaraEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const LocaraEmptyState({
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(LocaraDesignTokens.spacing24),
        child: LocaraGlassCard(
          borderRadius: LocaraDesignTokens.radiusExtraLarge,
          padding: const EdgeInsets.symmetric(
            horizontal: LocaraDesignTokens.spacing24,
            vertical: LocaraDesignTokens.spacing32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: LocaraDesignTokens.cardSurfaceLight.withValues(alpha: 0.8),
                  border: Border.all(
                    color: LocaraDesignTokens.cardBorderSubtle,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: LocaraDesignTokens.secondaryText,
                ),
              ),
              const SizedBox(height: LocaraDesignTokens.spacing16),
              Text(
                title,
                style: LocaraDesignTokens.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: LocaraDesignTokens.spacing8),
              Text(
                description,
                style: LocaraDesignTokens.bodyRegular,
                textAlign: TextAlign.center,
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: LocaraDesignTokens.spacing20),
                LocaraAppButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  variant: LocaraButtonVariant.secondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class LocaraErrorState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  const LocaraErrorState({
    required this.title,
    required this.message,
    this.onRetry,
    this.retryLabel = 'تلاش مجدد',
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(LocaraDesignTokens.spacing24),
        child: LocaraGlassCard(
          borderRadius: LocaraDesignTokens.radiusExtraLarge,
          borderColor: LocaraDesignTokens.error.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(
            horizontal: LocaraDesignTokens.spacing24,
            vertical: LocaraDesignTokens.spacing32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: LocaraDesignTokens.error.withValues(alpha: 0.15),
                  border: Border.all(
                    color: LocaraDesignTokens.error.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 32,
                  color: LocaraDesignTokens.error,
                ),
              ),
              const SizedBox(height: LocaraDesignTokens.spacing16),
              Text(
                title,
                style: LocaraDesignTokens.titleLarge.copyWith(
                  color: LocaraDesignTokens.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: LocaraDesignTokens.spacing8),
              Text(
                message,
                style: LocaraDesignTokens.bodyRegular,
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: LocaraDesignTokens.spacing20),
                LocaraAppButton(
                  label: retryLabel,
                  onPressed: onRetry,
                  variant: LocaraButtonVariant.outline,
                  icon: Icons.refresh_rounded,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class LocaraLoadingState extends StatelessWidget {
  final String message;

  const LocaraLoadingState({
    this.message = 'در حال بارگذاری...',
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(LocaraDesignTokens.cyan),
            ),
          ),
          const SizedBox(height: LocaraDesignTokens.spacing16),
          Text(
            message,
            style: LocaraDesignTokens.bodyRegular.copyWith(
              color: LocaraDesignTokens.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mesh state views aliases
typedef MeshEmptyState = LocaraEmptyState;
typedef MeshErrorState = LocaraErrorState;
typedef MeshLoadingState = LocaraLoadingState;
