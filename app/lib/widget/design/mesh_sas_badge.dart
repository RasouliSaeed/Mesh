import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:locara_app/gen/strings.g.dart';
import 'package:locara_app/pages/verify_page.dart';
import 'package:locara_app/provider/security_provider.dart';
import 'package:locara_app/theme/mesh_design_tokens.dart';
import 'package:locara_app/widget/design/mesh_glass_card.dart';
import 'package:locara_isolates/model/device.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// Distinct cyber neon colors for SAS fingerprint icons.
const List<Color> _sasColors = [
  LocaraDesignTokens.cyan,
  LocaraDesignTokens.electricBlue,
  LocaraDesignTokens.purple,
  Color(0xFF00E5FF),
];

/// A compact, cyber-styled Short Authentication String (SAS) visual badge.
/// Displays deterministic security icons derived from the cryptographic fingerprints
/// of both devices, allowing users to verify end-to-end identity at a glance.
class LocaraSasBadge extends StatelessWidget {
  final CombinedFingerprint? fingerprint;
  final Device? device;
  final String? peerFingerprint;
  final String? myFingerprint;
  final bool compact;
  final bool showVerificationModalOnTap;
  final VoidCallback? onTap;

  const LocaraSasBadge({
    this.fingerprint,
    this.device,
    this.peerFingerprint,
    this.myFingerprint,
    this.compact = true,
    this.showVerificationModalOnTap = true,
    this.onTap,
    super.key,
  });

  CombinedFingerprint? _resolveFingerprint(BuildContext context) {
    if (fingerprint != null) {
      return fingerprint;
    }

    final targetPeer = peerFingerprint ?? device?.fingerprint;
    if (targetPeer == null || targetPeer.isEmpty) {
      return null;
    }

    String? localFp = myFingerprint;
    if (localFp == null || localFp.isEmpty) {
      try {
        localFp = context.read(securityProvider.select((s) => s.certificateHash));
      } catch (_) {
        localFp = null;
      }
    }

    if (localFp == null || localFp.isEmpty) {
      return null;
    }

    return CombinedFingerprint.fromFingerprints(
      myFingerprint: localFp,
      peerFingerprint: targetPeer,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fp = _resolveFingerprint(context);
    if (fp == null) {
      return const SizedBox.shrink();
    }

    final icons = fp.shortIcons;

    return Tooltip(
      message: 'شناسه بصری امنیتی SAS (تأیید عدم شنود)',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (onTap != null) {
              onTap!();
            } else if (showVerificationModalOnTap) {
              unawaited(
                showLocaraSasVerificationModal(
                  context,
                  fp,
                  deviceAlias: device?.alias,
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: LocaraDesignTokens.cardSurface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: LocaraDesignTokens.cyan.withValues(alpha: 0.35),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: LocaraDesignTokens.cyan.withValues(alpha: 0.12),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.shield_rounded,
                  size: 14,
                  color: LocaraDesignTokens.cyan,
                ),
                const SizedBox(width: 5),
                for (int i = 0; i < icons.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Icon(
                    icons[i],
                    size: 14,
                    color: _sasColors[i % _sasColors.length],
                  ),
                ],
                if (!compact) ...[
                  const SizedBox(width: 6),
                  Text(
                    'SAS',
                    style: LocaraDesignTokens.labelSmall.copyWith(
                      color: LocaraDesignTokens.cyan,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Displays the full 16-icon visual SAS verification dialog / modal.
Future<void> showLocaraSasVerificationModal(
  BuildContext context,
  CombinedFingerprint fingerprint, {
  String? deviceAlias,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: LocaraGlassCard(
            fillColor: LocaraDesignTokens.darkNavy.withValues(alpha: 0.95),
            borderColor: LocaraDesignTokens.cyan.withValues(alpha: 0.4),
            withGlow: true,
            padding: const EdgeInsets.all(LocaraDesignTokens.spacing20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: LocaraDesignTokens.cyan.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: LocaraDesignTokens.cyan.withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                      ),
                      child: const Icon(
                        Icons.verified_user_rounded,
                        color: LocaraDesignTokens.cyan,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'اعتبارسنجی امنیتی هویت (SAS)',
                            style: TextStyle(
                              color: LocaraDesignTokens.primaryText,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (deviceAlias != null)
                            Text(
                              'دستگاه: $deviceAlias',
                              style: const TextStyle(
                                color: LocaraDesignTokens.cyan,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: LocaraDesignTokens.mutedText),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Description
                Text(
                  'جهت اطمینان از برقراری ارتباط مستقیم و عدم وجود نفوذگر (MITM)، مطمئن شوید آیکون‌های زیر با دستگاه مقابل دقیقاً یکسان هستند:',
                  style: LocaraDesignTokens.bodySmall.copyWith(
                    color: LocaraDesignTokens.secondaryText,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),

                // 4x4 Grid of 16 SAS Icons
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: LocaraDesignTokens.cardSurface.withValues(alpha: 0.9),
                    borderRadius: LocaraDesignTokens.borderRadiusLarge,
                    border: Border.all(
                      color: LocaraDesignTokens.cardBorderSubtle,
                      width: 1,
                    ),
                  ),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                    ),
                    itemCount: fingerprint.icons.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      final icon = fingerprint.icons[index];
                      final color = _sasColors[index % _sasColors.length];
                      return Container(
                        decoration: BoxDecoration(
                          color: LocaraDesignTokens.deepNavy.withValues(alpha: 0.8),
                          borderRadius: LocaraDesignTokens.borderRadiusMedium,
                          border: Border.all(
                            color: color.withValues(alpha: 0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.1),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            icon,
                            size: 26,
                            color: color,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Security Note
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: LocaraDesignTokens.success.withValues(alpha: 0.1),
                    borderRadius: LocaraDesignTokens.borderRadiusMedium,
                    border: Border.all(
                      color: LocaraDesignTokens.success.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.lock_rounded,
                        size: 16,
                        color: LocaraDesignTokens.success,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ارتباط از طریق پروتکل امن TLS و رمزنگاری دوطرفه محافظت می‌شود.',
                          style: TextStyle(
                            color: LocaraDesignTokens.success,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: fingerprint.combined));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(t.general.copiedToClipboard),
                              backgroundColor: LocaraDesignTokens.darkNavy,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('کپی هش'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: LocaraDesignTokens.secondaryText,
                        side: const BorderSide(color: LocaraDesignTokens.cardBorderSubtle),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LocaraDesignTokens.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('تأیید و بازگشت'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Mesh SAS badge alias
typedef MeshSasBadge = LocaraSasBadge;
