import 'package:flutter/material.dart';
import 'package:locara_app/theme/mesh_cyber_theme.dart';

class LocaraStatsBar extends StatelessWidget {
  final bool isDesktop;
  final int transferredFilesCount;
  final String successRate;
  final String speedText;
  final String elapsedTime;

  const LocaraStatsBar({
    required this.isDesktop,
    this.transferredFilesCount = 1248,
    this.successRate = '۹۸٪',
    this.speedText = '۱۲.۵ MB/s',
    this.elapsedTime = '۰۰:۰۱:۲۳',
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (isDesktop) {
      return _buildDesktopLayout();
    } else {
      return _buildMobileLayout();
    }
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(
          child: _buildCapsule(
            icon: Icons.folder_rounded,
            iconColor: const Color(0xFFC77DFF),
            iconBgColor: const Color(0xFF7B2CBF).withValues(alpha: 0.25),
            value: '$transferredFilesCount',
            label: 'فایل منتقل شده',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildCapsule(
            icon: Icons.check_circle_rounded,
            iconColor: LocaraCyberColors.statusGreen,
            iconBgColor: LocaraCyberColors.statusGreen.withValues(alpha: 0.2),
            value: successRate,
            label: 'موفقیت انتقال',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildCapsule(
            icon: Icons.speed_rounded,
            iconColor: LocaraCyberColors.auroraCyan,
            iconBgColor: LocaraCyberColors.auroraCyan.withValues(alpha: 0.2),
            value: speedText,
            label: 'سرعت انتقال',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildCapsule(
            icon: Icons.access_time_rounded,
            iconColor: const Color(0xFF64DFDF),
            iconBgColor: const Color(0xFF0077B6).withValues(alpha: 0.25),
            value: elapsedTime,
            label: 'زمان سپری شده',
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildCapsule(
              icon: Icons.folder_rounded,
              iconColor: const Color(0xFFC77DFF),
              iconBgColor: const Color(0xFF7B2CBF).withValues(alpha: 0.25),
              value: '$transferredFilesCount',
              label: 'فایل منتقل شده',
              isCompact: true,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildCapsule(
              icon: Icons.check_circle_rounded,
              iconColor: LocaraCyberColors.statusGreen,
              iconBgColor: LocaraCyberColors.statusGreen.withValues(alpha: 0.2),
              value: successRate,
              label: 'موفقیت انتقال',
              isCompact: true,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildCapsule(
              icon: Icons.speed_rounded,
              iconColor: LocaraCyberColors.auroraCyan,
              iconBgColor: LocaraCyberColors.auroraCyan.withValues(alpha: 0.2),
              value: speedText,
              label: 'سرعت انتقال',
              isCompact: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapsule({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String value,
    required String label,
    bool isCompact = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 14,
        vertical: isCompact ? 10 : 12,
      ),
      decoration: LocaraCyberTheme.glassCardDecoration(
        borderRadius: 18,
        borderColor: LocaraCyberColors.cardBorderSubtle,
        fillColor: const Color(0xFF0B162E).withValues(alpha: 0.75),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: isCompact ? 18 : 22,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompact ? 13 : 15,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: LocaraCyberColors.textSecondary,
                    fontSize: isCompact ? 10 : 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Mesh stats bar alias
typedef MeshStatsBar = LocaraStatsBar;
