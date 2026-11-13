import 'package:flutter/material.dart';
import 'package:locara_app/theme/mesh_design_tokens.dart';
import 'package:locara_app/widget/design/mesh_glass_card.dart';
import 'package:locara_app/widget/design/mesh_sas_badge.dart';
import 'package:locara_isolates/model/device.dart';

class LocaraDeviceCard extends StatelessWidget {
  final Device device;
  final VoidCallback? onTap;
  final VoidCallback? onInfoTap;
  final bool isSelected;
  final bool showSas;

  const LocaraDeviceCard({
    required this.device,
    this.onTap,
    this.onInfoTap,
    this.isSelected = false,
    this.showSas = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final IconData deviceIcon = _getDeviceIcon(device.deviceType);

    return LocaraGlassCard(
      onTap: onTap,
      borderRadius: LocaraDesignTokens.radiusLarge,
      borderColor: isSelected ? LocaraDesignTokens.cyan : LocaraDesignTokens.cardBorderSubtle,
      fillColor: isSelected ? LocaraDesignTokens.cardSurfaceLight.withValues(alpha: 0.9) : LocaraDesignTokens.cardSurface.withValues(alpha: 0.8),
      withGlow: isSelected,
      padding: const EdgeInsets.symmetric(
        horizontal: LocaraDesignTokens.spacing16,
        vertical: LocaraDesignTokens.spacing12,
      ),
      child: Row(
        children: [
          // Device Avatar in glowing neon circle
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF132A55).withValues(alpha: 0.9),
              border: Border.all(
                color: isSelected ? LocaraDesignTokens.cyan : LocaraDesignTokens.electricBlue.withValues(alpha: 0.5),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isSelected ? LocaraDesignTokens.cyan : LocaraDesignTokens.primaryBlue).withValues(alpha: 0.25),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(
              deviceIcon,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: LocaraDesignTokens.spacing12),

          // Alias and Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  device.alias,
                  style: LocaraDesignTokens.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: LocaraDesignTokens.success,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: LocaraDesignTokens.success,
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      device.deviceModel ?? 'در دسترس',
                      style: LocaraDesignTokens.bodySmall.copyWith(
                        color: LocaraDesignTokens.secondaryText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Visual SAS Fingerprint Badge
          if (showSas && device.fingerprint.isNotEmpty) ...[
            LocaraSasBadge(
              device: device,
              compact: true,
            ),
            const SizedBox(width: LocaraDesignTokens.spacing8),
          ],

          // Info Button (optional)
          if (onInfoTap != null)
            IconButton(
              icon: const Icon(Icons.info_outline_rounded, size: 20),
              color: LocaraDesignTokens.mutedText,
              onPressed: onInfoTap,
              tooltip: 'جزئیات دستگاه',
            ),

          // Wi-Fi signal icon
          const Icon(
            Icons.wifi_rounded,
            color: Colors.white,
            size: 22,
          ),
        ],
      ),
    );
  }

  IconData _getDeviceIcon(DeviceType type) {
    switch (type) {
      case DeviceType.mobile:
        return Icons.phone_android_rounded;
      case DeviceType.desktop:
        return Icons.laptop_chromebook_rounded;
      case DeviceType.web:
        return Icons.language_rounded;
      case DeviceType.headless:
        return Icons.dns_rounded;
      case DeviceType.server:
        return Icons.cloud_rounded;
    }
  }
}

/// Mesh device card alias
typedef MeshDeviceCard = LocaraDeviceCard;
