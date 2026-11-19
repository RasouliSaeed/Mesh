import 'package:flutter/material.dart';
import 'package:locara_app/theme/mesh_design_tokens.dart';

class MeshFeaturePills extends StatelessWidget {
  final VoidCallback? onSecureTransfer;
  final VoidCallback? onRealTimeChat;
  final VoidCallback? onSmartDiscovery;
  final VoidCallback? onPrivacyFirst;

  const MeshFeaturePills({
    this.onSecureTransfer,
    this.onRealTimeChat,
    this.onSmartDiscovery,
    this.onPrivacyFirst,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        _buildPill(
          context: context,
          icon: Icons.verified_user_rounded,
          iconColor: LocaraDesignTokens.cyan,
          iconBgColor: LocaraDesignTokens.cyan.withValues(alpha: 0.15),
          label: isRtl ? 'انتقال امن' : 'Secure Transfer',
          onTap: onSecureTransfer,
        ),
        _buildPill(
          context: context,
          icon: Icons.chat_bubble_rounded,
          iconColor: LocaraDesignTokens.purple,
          iconBgColor: LocaraDesignTokens.purple.withValues(alpha: 0.15),
          label: isRtl ? 'گفتگوی زنده' : 'Real-time Chat',
          onTap: onRealTimeChat,
        ),
        _buildPill(
          context: context,
          icon: Icons.radar_rounded,
          iconColor: const Color(0xFFE040FB),
          iconBgColor: const Color(0xFFE040FB).withValues(alpha: 0.15),
          label: isRtl ? 'شناسایی هوشمند' : 'Smart Discovery',
          onTap: onSmartDiscovery,
        ),
        _buildPill(
          context: context,
          icon: Icons.privacy_tip_rounded,
          iconColor: const Color(0xFF7C4DFF),
          iconBgColor: const Color(0xFF7C4DFF).withValues(alpha: 0.15),
          label: isRtl ? 'حفظ حریم خصوصی' : 'Privacy First',
          onTap: onPrivacyFirst,
        ),
      ],
    );
  }

  Widget _buildPill({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String label,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: LocaraDesignTokens.cardSurface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: LocaraDesignTokens.cardBorderSubtle,
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconBgColor,
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: LocaraDesignTokens.primaryText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
