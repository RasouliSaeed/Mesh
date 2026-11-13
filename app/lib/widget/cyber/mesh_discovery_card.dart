import 'package:flutter/material.dart';
import 'package:locara_app/theme/mesh_cyber_theme.dart';
import 'package:locara_app/widget/cyber/mesh_radar_pulse.dart';

class LocaraDiscoveryCard extends StatefulWidget {
  final VoidCallback? onToggleScan;

  const LocaraDiscoveryCard({
    this.onToggleScan,
    super.key,
  });

  @override
  State<LocaraDiscoveryCard> createState() => _LocaraDiscoveryCardState();
}

class _LocaraDiscoveryCardState extends State<LocaraDiscoveryCard> {
  bool _isScanning = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: LocaraCyberTheme.glassCardDecoration(
        borderRadius: 24,
        borderColor: LocaraCyberColors.cardBorder,
        fillColor: const Color(0xFF09142B).withValues(alpha: 0.8),
        withGlow: true,
      ),
      child: Row(
        children: [
          // Radar pulse animation
          LocaraRadarPulseWidget(
            size: 54,
            isScanning: _isScanning,
          ),
          const SizedBox(width: 18),

          // Search status text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isScanning ? 'جستجوی دستگاه‌ها در شبکه...' : 'جستجو متوقف شد',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isScanning ? 'در حال یافتن دستگاه‌های متصل به شبکه محلی' : 'برای یافتن دستگاه‌های جدید، جستجو را آغاز کنید',
                  style: const TextStyle(
                    color: LocaraCyberColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // Stop / Start Button
          InkWell(
            onTap: () {
              setState(() {
                _isScanning = !_isScanning;
              });
              widget.onToggleScan?.call();
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF132342).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: LocaraCyberColors.cardBorder,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isScanning ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isScanning ? 'توقف' : 'شروع',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
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

/// Mesh discovery card alias
typedef MeshDiscoveryCard = LocaraDiscoveryCard;
