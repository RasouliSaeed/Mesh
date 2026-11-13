import 'package:flutter/material.dart';
import 'package:locara_app/gen/assets.gen.dart';
import 'package:locara_app/pages/changelog_page.dart';
import 'package:locara_app/theme/mesh_cyber_theme.dart';
import 'package:locara_app/theme/mesh_design_tokens.dart';
import 'package:locara_app/widget/cyber/mesh_nearby_devices_list.dart';
import 'package:locara_app/widget/cyber/mesh_stage_widget.dart';
import 'package:locara_app/widget/cyber/mesh_stats_bar.dart';
import 'package:locara_isolates/model/device.dart';
import 'package:routerino/routerino.dart';

class LocaraMobileHomeView extends StatelessWidget {
  final List<Device> nearbyDevices;
  final int historyCount;
  final VoidCallback onSendFile;
  final VoidCallback onReceiveFile;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenHistory;
  final VoidCallback onSeeAllDevices;
  final void Function(Device device) onSelectDevice;

  const LocaraMobileHomeView({
    required this.nearbyDevices,
    required this.historyCount,
    required this.onSendFile,
    required this.onReceiveFile,
    required this.onOpenSettings,
    required this.onOpenHistory,
    required this.onSeeAllDevices,
    required this.onSelectDevice,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LocaraDesignTokens.backgroundGradient,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 120),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Header Bar (Info, Logo, App Title, Settings)
              _buildTopHeader(context),

              const SizedBox(height: LocaraDesignTokens.spacing12),

              // 2. Hero Stage Card
              LocaraStageWidget(
                isDesktop: false,
                availableDevicesCount: nearbyDevices.length,
              ),

              const SizedBox(height: LocaraDesignTokens.spacing16),

              // 3. Two Big Primary Action Buttons
              _buildActionButtons(context),

              const SizedBox(height: LocaraDesignTokens.spacing16),

              // 4. Quick Stats Bar (3 capsules)
              LocaraStatsBar(
                isDesktop: false,
                transferredFilesCount: historyCount > 0 ? historyCount : 1248,
                successRate: '۹۸٪',
                speedText: '۱۲.۵ MB/s',
              ),

              const SizedBox(height: LocaraDesignTokens.spacing20),

              // 5. Nearby Devices Section
              LocaraNearbyDevicesList(
                devices: nearbyDevices,
                onSeeAll: onSeeAllDevices,
                onSelectDevice: onSelectDevice,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Info Button
          InkWell(
            onTap: () => context.push(() => const ChangelogPage()),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: LocaraDesignTokens.cardSurface.withValues(alpha: 0.8),
                border: Border.all(
                  color: LocaraDesignTokens.cardBorderSubtle,
                  width: 1.2,
                ),
              ),
              child: const Icon(
                Icons.info_outline_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),

          // Center: Glowing 3D Locara Logo + Brand Titles
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: LocaraDesignTokens.cyan.withValues(alpha: 0.4),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Assets.img.logo128.image(
                  width: 64,
                  height: 64,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Mesh',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Nearby. Instant. Private',
                style: TextStyle(
                  color: LocaraDesignTokens.secondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          // Right: Settings Button
          InkWell(
            onTap: onOpenSettings,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: LocaraDesignTokens.cardSurface.withValues(alpha: 0.8),
                border: Border.all(
                  color: LocaraDesignTokens.cardBorderSubtle,
                  width: 1.2,
                ),
              ),
              child: const Icon(
                Icons.settings_outlined,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // 1. Send File (Gradient Button)
          InkWell(
            onTap: onSendFile,
            borderRadius: BorderRadius.circular(26),
            child: Container(
              height: 62,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                gradient: LocaraDesignTokens.primaryGradient,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: LocaraDesignTokens.purple.withValues(alpha: 0.45),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.near_me_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'ارسال فایل',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // 2. Receive File (Glassmorphic Button)
          InkWell(
            onTap: onReceiveFile,
            borderRadius: BorderRadius.circular(26),
            child: Container(
              height: 62,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: LocaraCyberTheme.glassCardDecoration(
                borderRadius: 26,
                borderColor: LocaraDesignTokens.cardBorder,
                fillColor: LocaraDesignTokens.cardSurface.withValues(alpha: 0.8),
                withGlow: true,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.file_download_outlined,
                    color: Colors.white,
                    size: 26,
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'دریافت فایل',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                    color: Colors.white,
                    size: 28,
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

/// Backward compatibility and rebranding alias
typedef MeshMobileHomeView = LocaraMobileHomeView;
