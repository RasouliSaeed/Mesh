import 'package:flutter/material.dart';
import 'package:locara_app/theme/mesh_cyber_theme.dart';
import 'package:locara_isolates/model/device.dart';

class LocaraNearbyDevicesList extends StatelessWidget {
  final List<Device> devices;
  final VoidCallback onSeeAll;
  final void Function(Device device) onSelectDevice;

  const LocaraNearbyDevicesList({
    required this.devices,
    required this.onSeeAll,
    required this.onSelectDevice,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // "همه دستگاه‌ها ←" Action Button
              InkWell(
                onTap: onSeeAll,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF102144).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: LocaraCyberColors.cardBorderSubtle,
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'همه دستگاه‌ها',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Title with pulsing green dot
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'دستگاه‌های نزدیک',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: LocaraCyberColors.statusGreen,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: LocaraCyberColors.statusGreen,
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Devices List
          if (devices.isEmpty)
            _buildEmptyScanningPlaceholder()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: devices.length > 5 ? 5 : devices.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final device = devices[index];
                return _buildDeviceItem(device);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyScanningPlaceholder() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: LocaraCyberTheme.glassCardDecoration(
        borderRadius: 20,
        borderColor: LocaraCyberColors.cardBorderSubtle,
        fillColor: const Color(0xFF09142A).withValues(alpha: 0.7),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(LocaraCyberColors.auroraCyan),
            ),
          ),
          SizedBox(width: 14),
          Text(
            'در حال جستجوی دستگاه‌های اطراف در شبکه محلی...',
            style: TextStyle(
              color: LocaraCyberColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceItem(Device device) {
    final IconData deviceIcon = _getDeviceIcon(device.deviceType);

    return InkWell(
      onTap: () => onSelectDevice(device),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: LocaraCyberTheme.glassCardDecoration(
          borderRadius: 20,
          borderColor: LocaraCyberColors.cardBorderSubtle,
          fillColor: const Color(0xFF0A1730).withValues(alpha: 0.8),
        ),
        child: Row(
          children: [
            // Circular Glowing Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF132A55).withValues(alpha: 0.9),
                border: Border.all(
                  color: LocaraCyberColors.auroraCyan.withValues(alpha: 0.4),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: LocaraCyberColors.auroraCyan.withValues(alpha: 0.2),
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
            const SizedBox(width: 14),

            // Device Name & Status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    device.alias,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
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
                          color: LocaraCyberColors.statusGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'در دسترس',
                        style: TextStyle(
                          color: LocaraCyberColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Wi-Fi Signal Icon
            const Icon(
              Icons.wifi_rounded,
              color: Colors.white,
              size: 22,
            ),
          ],
        ),
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

/// Mesh nearby devices list alias
typedef MeshNearbyDevicesList = LocaraNearbyDevicesList;
