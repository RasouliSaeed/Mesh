import 'package:flutter/material.dart';
import 'package:locara_app/theme/mesh_design_tokens.dart';
import 'package:locara_app/widget/design/mesh_app_button.dart';
import 'package:locara_app/widget/design/mesh_glass_card.dart';

class LocaraConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final LocaraButtonVariant confirmVariant;
  final IconData? icon;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;

  const LocaraConfirmationDialog({
    required this.title,
    required this.message,
    required this.onConfirm,
    this.confirmLabel = 'تأیید',
    this.cancelLabel = 'انصراف',
    this.confirmVariant = LocaraButtonVariant.primary,
    this.icon,
    this.onCancel,
    super.key,
  });

  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'تأیید',
    String cancelLabel = 'انصراف',
    LocaraButtonVariant confirmVariant = LocaraButtonVariant.primary,
    IconData? icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (context) => LocaraConfirmationDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        confirmVariant: confirmVariant,
        icon: icon,
        onConfirm: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: LocaraGlassCard(
          borderRadius: LocaraDesignTokens.radiusExtraLarge,
          padding: const EdgeInsets.all(LocaraDesignTokens.spacing24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (icon != null) ...[
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: confirmVariant == LocaraButtonVariant.danger
                          ? LocaraDesignTokens.error.withValues(alpha: 0.15)
                          : LocaraDesignTokens.cardSurfaceLight,
                      border: Border.all(
                        color: confirmVariant == LocaraButtonVariant.danger
                            ? LocaraDesignTokens.error.withValues(alpha: 0.4)
                            : LocaraDesignTokens.cardBorderSubtle,
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: confirmVariant == LocaraButtonVariant.danger
                          ? LocaraDesignTokens.error
                          : LocaraDesignTokens.cyan,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(height: LocaraDesignTokens.spacing16),
              ],
              Text(
                title,
                style: LocaraDesignTokens.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: LocaraDesignTokens.spacing12),
              Text(
                message,
                style: LocaraDesignTokens.bodyRegular,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: LocaraDesignTokens.spacing24),
              Row(
                children: [
                  Expanded(
                    child: LocaraAppButton(
                      label: cancelLabel,
                      variant: LocaraButtonVariant.secondary,
                      onPressed: onCancel ?? () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: LocaraDesignTokens.spacing12),
                  Expanded(
                    child: LocaraAppButton(
                      label: confirmLabel,
                      variant: confirmVariant,
                      onPressed: onConfirm,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mesh confirmation dialog alias
typedef MeshConfirmationDialog = LocaraConfirmationDialog;
