import 'package:flutter/material.dart';
import 'package:locara_app/theme/mesh_design_tokens.dart';

class LocaraTransferProgress extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final String? speed;
  final String? eta;
  final String? statusText;
  final double height;

  const LocaraTransferProgress({
    required this.progress,
    this.speed,
    this.eta,
    this.statusText,
    this.height = 8.0,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    final percentage = (clampedProgress * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top row: status & percentage
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (statusText != null)
              Text(
                statusText!,
                style: LocaraDesignTokens.bodySmall.copyWith(
                  color: LocaraDesignTokens.secondaryText,
                  fontWeight: FontWeight.w500,
                ),
              )
            else
              const SizedBox.shrink(),
            Text(
              '$percentage٪',
              style: LocaraDesignTokens.numericData.copyWith(
                color: LocaraDesignTokens.cyan,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: LocaraDesignTokens.spacing8),

        // Gradient Progress Bar
        Container(
          height: height,
          decoration: BoxDecoration(
            color: LocaraDesignTokens.darkNavy,
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(
              color: LocaraDesignTokens.cardBorderSubtle,
              width: 1,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final fillWidth = constraints.maxWidth * clampedProgress;
              return Stack(
                children: [
                  Container(
                    width: fillWidth,
                    decoration: BoxDecoration(
                      gradient: LocaraDesignTokens.electricCyanGradient,
                      borderRadius: BorderRadius.circular(height / 2),
                      boxShadow: [
                        BoxShadow(
                          color: LocaraDesignTokens.cyan.withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        // Bottom row: speed & ETA (if provided)
        if (speed != null || eta != null) ...[
          const SizedBox(height: LocaraDesignTokens.spacing8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (speed != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.speed_rounded,
                      size: 14,
                      color: LocaraDesignTokens.cyan,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      speed!,
                      style: LocaraDesignTokens.labelSmall.copyWith(
                        color: LocaraDesignTokens.secondaryText,
                      ),
                    ),
                  ],
                )
              else
                const SizedBox.shrink(),
              if (eta != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: LocaraDesignTokens.secondaryText,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      eta!,
                      style: LocaraDesignTokens.labelSmall.copyWith(
                        color: LocaraDesignTokens.secondaryText,
                      ),
                    ),
                  ],
                )
              else
                const SizedBox.shrink(),
            ],
          ),
        ],
      ],
    );
  }
}

/// Mesh transfer progress alias
typedef MeshTransferProgress = LocaraTransferProgress;
