import 'package:flutter/material.dart';
import 'package:locara_app/theme/mesh_design_tokens.dart';
import 'package:locara_isolates/model/device.dart';

enum MeshDeviceStatus { online, suspected, offline }

class MeshDeviceCard extends StatefulWidget {
  final String alias;
  final String ip;
  final DeviceType deviceType;
  final MeshDeviceStatus status;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onChat;
  final VoidCallback? onSend;

  const MeshDeviceCard({
    required this.alias,
    required this.ip,
    this.deviceType = DeviceType.desktop,
    this.status = MeshDeviceStatus.online,
    this.isSelected = false,
    this.onTap,
    this.onChat,
    this.onSend,
    super.key,
  });

  @override
  State<MeshDeviceCard> createState() => _MeshDeviceCardState();
}

class _MeshDeviceCardState extends State<MeshDeviceCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final isOnline = widget.status == MeshDeviceStatus.online;
    final statusColor = isOnline
        ? const Color(0xFF10B981)
        : (widget.status == MeshDeviceStatus.suspected ? const Color(0xFFF59E0B) : LocaraDesignTokens.mutedText);

    final statusText = isOnline
        ? (isRtl ? 'آنلاین' : 'Online')
        : (widget.status == MeshDeviceStatus.suspected ? (isRtl ? 'مشکوک' : 'Suspected') : (isRtl ? 'آفلاین' : 'Offline'));

    final IconData deviceIcon;
    switch (widget.deviceType) {
      case DeviceType.mobile:
        deviceIcon = Icons.phone_android_rounded;
        break;
      case DeviceType.desktop:
        deviceIcon = widget.alias.toLowerCase().contains('laptop') ? Icons.laptop_rounded : Icons.computer_rounded;
        break;
      default:
        deviceIcon = Icons.devices_rounded;
        break;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? const Color(0xFF162444).withValues(alpha: 0.95)
                : (_isHovered
                    ? const Color(0xFF131D36).withValues(alpha: 0.9)
                    : const Color(0xFF0F172A).withValues(alpha: 0.85)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isSelected
                  ? LocaraDesignTokens.cyan
                  : (_isHovered
                      ? LocaraDesignTokens.cyan.withValues(alpha: 0.5)
                      : const Color(0xFF1E293B)),
              width: widget.isSelected ? 1.5 : 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.isSelected
                    ? LocaraDesignTokens.cyan.withValues(alpha: 0.25)
                    : (_isHovered ? Colors.black.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.2)),
                blurRadius: widget.isSelected ? 16 : (_isHovered ? 12 : 8),
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Circular Glowing Avatar with Status Rim
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      statusColor.withValues(alpha: 0.35),
                      const Color(0xFF0F172A),
                    ],
                  ),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.7),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.35),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    deviceIcon,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Device Alias & Status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.alias,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            widget.ip,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            '•',
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Quick Actions on hover or selection (optional subtle icons)
              if (widget.onChat != null)
                AnimatedOpacity(
                  opacity: _isHovered || widget.isSelected ? 1.0 : 0.6,
                  duration: const Duration(milliseconds: 150),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    icon: const Icon(Icons.chat_rounded, size: 16),
                    color: LocaraDesignTokens.cyan,
                    tooltip: isRtl ? 'گفتگو' : 'Chat',
                    onPressed: widget.onChat,
                  ),
                ),
              if (widget.onSend != null)
                AnimatedOpacity(
                  opacity: _isHovered || widget.isSelected ? 1.0 : 0.6,
                  duration: const Duration(milliseconds: 150),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    icon: const Icon(Icons.send_rounded, size: 16),
                    color: const Color(0xFFA855F7),
                    tooltip: isRtl ? 'ارسال فایل' : 'Send File',
                    onPressed: widget.onSend,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
