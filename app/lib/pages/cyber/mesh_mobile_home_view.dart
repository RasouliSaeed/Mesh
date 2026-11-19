import 'package:flutter/material.dart';
import 'package:locara_app/gen/assets.gen.dart';
import 'package:locara_app/pages/changelog_page.dart';
import 'package:locara_app/theme/mesh_cyber_theme.dart';
import 'package:locara_app/theme/mesh_design_tokens.dart';
import 'package:locara_app/widget/cyber/mesh_constellation_widget.dart';
import 'package:locara_app/widget/cyber/mesh_feature_pills.dart';
import 'package:locara_app/widget/cyber/mesh_nearby_devices_list.dart';
import 'package:locara_app/widget/cyber/mesh_stage_widget.dart';
import 'package:locara_app/widget/cyber/mesh_stats_bar.dart';
import 'package:locara_isolates/model/device.dart';
import 'package:routerino/routerino.dart';

class MeshMobileHomeView extends StatelessWidget {
  final List<Device> nearbyDevices;
  final int historyCount;
  final VoidCallback onSendFile;
  final VoidCallback onReceiveFile;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenHistory;
  final VoidCallback onSeeAllDevices;
  final void Function(Device device) onSelectDevice;

  const MeshMobileHomeView({
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

              // 2. Digital Mesh Constellation Graphic (from reference design)
              const MeshConstellationWidget(height: 110),

              const SizedBox(height: LocaraDesignTokens.spacing8),

              // 3. Hero Stage Card
              LocaraStageWidget(
                isDesktop: false,
                availableDevicesCount: nearbyDevices.length,
              ),

              const SizedBox(height: LocaraDesignTokens.spacing16),

              // 4. Primary Call-to-Action & Send/Receive Buttons
              _buildActionButtons(context),

              const SizedBox(height: LocaraDesignTokens.spacing16),

              // 5. Feature Pills (from reference design)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: MeshFeaturePills(
                  onSecureTransfer: onSendFile,
                  onRealTimeChat: onSeeAllDevices,
                  onSmartDiscovery: onSeeAllDevices,
                  onPrivacyFirst: onOpenSettings,
                ),
              ),

              const SizedBox(height: LocaraDesignTokens.spacing16),

              // 6. Quick Stats Bar (3 capsules)
              LocaraStatsBar(
                isDesktop: false,
                transferredFilesCount: historyCount,
                successRate: historyCount > 0 ? '۱۰۰٪' : '--',
                speedText: 'آماده',
              ),

              const SizedBox(height: LocaraDesignTokens.spacing20),

              // 7. Nearby Devices Section
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
          // 0. "Get Started" Gradient Pill Button (Direct from Reference Design)
          InkWell(
            onTap: onSendFile,
            borderRadius: BorderRadius.circular(28),
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7838F5), Color(0xFF168BFF)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7838F5).withValues(alpha: 0.45),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  isRtl ? 'شروع کنید' : 'Get Started',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 1. Send File (Gradient Button)
          InkWell(
            onTap: onSendFile,
            borderRadius: BorderRadius.circular(26),
            child: Container(
              height: 58,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                gradient: LocaraDesignTokens.primaryGradient,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: LocaraDesignTokens.purple.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.near_me_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      isRtl ? 'ارسال فایل' : 'Send File',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 2. Receive File (Glassmorphic Button)
          InkWell(
            onTap: onReceiveFile,
            borderRadius: BorderRadius.circular(26),
            child: Container(
              height: 58,
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
                    size: 24,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      isRtl ? 'دریافت فایل' : 'Receive File',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                    color: Colors.white,
                    size: 26,
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

/// Legacy alias for backward compatibility
typedef LocaraMobileHomeView = MeshMobileHomeView;
