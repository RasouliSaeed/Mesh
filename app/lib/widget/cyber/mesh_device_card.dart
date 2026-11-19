import 'package:flutter/material.dart';
import 'package:locara_app/theme/mesh_design_tokens.dart';
import 'package:locara_isolates/model/device.dart';

enum MeshDeviceStatus { online, suspected, offline }

class MeshDeviceCard extends StatelessWidget {
  final String alias;
  final String ip;
  final DeviceType deviceType;
  final MeshDeviceStatus status;
  final VoidCallback? onTap;
  final VoidCallback? onChat;
  final VoidCallback? onSend;

  const MeshDeviceCard({
    required this.alias,
    required this.ip,
    this.deviceType = DeviceType.desktop,
    this.status = MeshDeviceStatus.online,
    this.onTap,
    this.onChat,
    this.onSend,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final isOnline = status == MeshDeviceStatus.online;
    final statusColor = isOnline ? LocaraDesignTokens.success : (status == MeshDeviceStatus.suspected ? LocaraDesignTokens.warning : LocaraDesignTokens.mutedText);
    final statusText = isOnline
        ? (isRtl ? 'آنلاین' : 'Online')
        : (status == MeshDeviceStatus.suspected ? (isRtl ? 'مشکوک' : 'Suspected') : (isRtl ? 'آفلاین' : 'Offline'));

    final IconData deviceIcon;
    switch (deviceType) {
      case DeviceType.mobile:
        deviceIcon = Icons.phone_android_rounded;
        break;
      case DeviceType.desktop:
        deviceIcon = alias.toLowerCase().contains('laptop') ? Icons.laptop_rounded : Icons.computer_rounded;
        break;
      default:
        deviceIcon = Icons.devices_rounded;
        break;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: LocaraDesignTokens.cardSurface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: LocaraDesignTokens.cardBorderSubtle,
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Circular Avatar with Radiant Glow
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    statusColor.withValues(alpha: 0.5),
                    statusColor.withValues(alpha: 0.1),
                  ],
                ),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.6),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.35),
                    blurRadius: 12,
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
            const SizedBox(width: 14),

            // Device Name & Status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    alias,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          ip,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: LocaraDesignTokens.secondaryText,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Quick Actions: Chat & Send
            if (onChat != null)
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.chat_rounded, size: 18),
                color: LocaraDesignTokens.cyan,
                tooltip: isRtl ? 'گفتگو' : 'Chat',
                onPressed: onChat,
              ),
            if (onSend != null)
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.send_rounded, size: 18),
                color: LocaraDesignTokens.purple,
                tooltip: isRtl ? 'ارسال فایل' : 'Send File',
                onPressed: onSend,
              ),
          ],
        ),
      ),
    );
  }
}
