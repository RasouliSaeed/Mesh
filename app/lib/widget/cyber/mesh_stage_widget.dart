import 'package:flutter/material.dart';
import 'package:locara_app/theme/mesh_cyber_theme.dart';

class MeshStageWidget extends StatefulWidget {
  final bool isDesktop;
  final int availableDevicesCount;

  const MeshStageWidget({
    required this.isDesktop,
    this.availableDevicesCount = 2,
    super.key,
  });

  @override
  State<MeshStageWidget> createState() => _MeshStageWidgetState();
}

class _MeshStageWidgetState extends State<MeshStageWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isDesktop) {
      return _buildDesktopStage();
    } else {
      return _buildMobileStage();
    }
  }

  Widget _buildDesktopStage() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          height: 48,
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: LocaraCyberColors.cardBorderSubtle,
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Wi-Fi Icon
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF1E293B),
                ),
                child: const Icon(
                  Icons.wifi_rounded,
                  color: LocaraCyberColors.auroraCyan,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),

              // Laptop device indicator
              const Icon(
                Icons.laptop_chromebook_rounded,
                color: Colors.white70,
                size: 16,
              ),
              const SizedBox(width: 6),

              // Desktop device indicator
              const Icon(
                Icons.desktop_windows_rounded,
                color: Colors.white70,
                size: 16,
              ),
              const SizedBox(width: 10),

              // Counter text
              Text(
                '${widget.availableDevicesCount} دستگاه متصل',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileStage() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.only(top: 24, bottom: 20, left: 16, right: 16),
          decoration: LocaraCyberTheme.glassCardDecoration(
            borderRadius: 28,
            borderColor: LocaraCyberColors.cardBorderSubtle,
            fillColor: LocaraCyberColors.cardGlass.withValues(alpha: 0.85),
            withGlow: true,
          ),
          child: Column(
            children: [
              SizedBox(
                height: 160,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Concentric Ellipse Glowing Pedestal
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _MobilePodiumPainter(
                          pulse: _pulseController.value,
                        ),
                      ),
                    ),

                    // Devices Row: Smartphone (left), Laptop (center on pedestal), Monitor (right)
                    Positioned(
                      bottom: 24,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Left: Phone
                          _buildDeviceHalo(
                            icon: Icons.phone_android_rounded,
                            size: 42,
                          ),
                          // Center: Laptop on pedestal
                          _buildDeviceCenterStage(
                            icon: Icons.laptop_mac_rounded,
                            size: 70,
                          ),
                          // Right: Monitor
                          _buildDeviceHalo(
                            icon: Icons.desktop_mac_rounded,
                            size: 42,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),
              // Status text
              Text(
                widget.availableDevicesCount > 0 ? '${widget.availableDevicesCount} دستگاه در دسترس' : 'در حال جستجوی دستگاه‌ها...',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'در شبکه محلی',
                style: TextStyle(
                  color: LocaraCyberColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeviceHalo({required IconData icon, required double size}) {
    return Container(
      width: size + 16,
      height: size + 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF0F2347).withValues(alpha: 0.8),
        border: Border.all(
          color: LocaraCyberColors.auroraCyan.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: LocaraCyberColors.auroraCyan.withValues(alpha: 0.25),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: size - 12,
      ),
    );
  }

  Widget _buildDeviceCenterStage({required IconData icon, required double size}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: LocaraCyberColors.auroraCyan.withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: size,
      ),
    );
  }
}

class _MobilePodiumPainter extends CustomPainter {
  final double pulse;

  _MobilePodiumPainter({required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 35);

    // Glowing pool
    final poolPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          LocaraCyberColors.auroraCyan.withValues(alpha: 0.35 + pulse * 0.1),
          LocaraCyberColors.auroraBlue.withValues(alpha: 0.1),
          Colors.transparent,
        ],
        radius: 0.75,
      ).createShader(Rect.fromCenter(center: center, width: 220, height: 80));

    canvas.drawOval(
      Rect.fromCenter(center: center, width: 220, height: 70),
      poolPaint,
    );

    // Glowing Neon Stage Ellipses
    final ringPaint1 = Paint()
      ..color = LocaraCyberColors.auroraCyan.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final ringPaint2 = Paint()
      ..color = LocaraCyberColors.auroraBlue.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawOval(
      Rect.fromCenter(center: center, width: 170, height: 42),
      ringPaint1,
    );

    canvas.drawOval(
      Rect.fromCenter(center: center.translate(0, 8), width: 210, height: 50),
      ringPaint2,
    );

    // Dashed glowing arcs connecting left and right devices
    final arcPaint = Paint()
      ..color = LocaraCyberColors.auroraCyan.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final pathLeft = Path();
    pathLeft.moveTo(size.width * 0.22, size.height - 40);
    pathLeft.quadraticBezierTo(size.width * 0.35, size.height - 75, size.width * 0.5, size.height - 60);

    final pathRight = Path();
    pathRight.moveTo(size.width * 0.5, size.height - 60);
    pathRight.quadraticBezierTo(size.width * 0.65, size.height - 75, size.width * 0.78, size.height - 40);

    _drawDashedPath(canvas, pathLeft, arcPaint, 4, 4);
    _drawDashedPath(canvas, pathRight, arcPaint, 4, 4);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint, double dashWidth, double dashSpace) {
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final len = (distance + dashWidth < metric.length) ? dashWidth : metric.length - distance;
        canvas.drawPath(metric.extractPath(distance, distance + len), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MobilePodiumPainter oldDelegate) {
    return oldDelegate.pulse != pulse;
  }
}

/// Legacy stage widget alias for backward compatibility
typedef LocaraStageWidget = MeshStageWidget;
