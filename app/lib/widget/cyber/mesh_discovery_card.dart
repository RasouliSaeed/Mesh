import 'package:flutter/material.dart';
import 'package:locara_app/theme/mesh_cyber_theme.dart';
import 'package:locara_app/widget/cyber/mesh_radar_pulse.dart';

class MeshDiscoveryCard extends StatefulWidget {
  final VoidCallback? onToggleScan;

  const MeshDiscoveryCard({
    this.onToggleScan,
    super.key,
  });

  @override
  State<MeshDiscoveryCard> createState() => _MeshDiscoveryCardState();
}

class _MeshDiscoveryCardState extends State<MeshDiscoveryCard> {
  bool _isScanning = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1E293B),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Radar pulse animation (compact 40px)
          LocaraRadarPulseWidget(
            size: 40,
            isScanning: _isScanning,
          ),
          const SizedBox(width: 12),

          // Search status text (clean single-line with ellipsis)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isScanning ? 'جستجوی دستگاه‌ها در شبکه...' : 'جستجو متوقف شد',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isScanning ? 'در حال یافتن دستگاه‌های متصل به شبکه محلی' : 'برای یافتن دستگاه‌های جدید، جستجو را آغاز کنید',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Stop / Start Button (compact)
          InkWell(
            onTap: () {
              setState(() {
                _isScanning = !_isScanning;
              });
              widget.onToggleScan?.call();
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: LocaraCyberColors.cardBorder,
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isScanning ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isScanning ? 'توقف' : 'شروع',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
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

/// Backward compatibility alias
typedef LocaraDiscoveryCard = MeshDiscoveryCard;
