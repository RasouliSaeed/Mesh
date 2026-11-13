import 'package:flutter/material.dart';
import 'package:locara_app/theme/mesh_cyber_theme.dart';

class LocaraRadarPulseWidget extends StatefulWidget {
  final double size;
  final bool isScanning;

  const LocaraRadarPulseWidget({
    this.size = 56,
    this.isScanning = true,
    super.key,
  });

  @override
  State<LocaraRadarPulseWidget> createState() => _LocaraRadarPulseWidgetState();
}

class _LocaraRadarPulseWidgetState extends State<LocaraRadarPulseWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _RadarPulsePainter(
              progress: widget.isScanning ? _controller.value : 0.0,
              isScanning: widget.isScanning,
            ),
          );
        },
      ),
    );
  }
}

class _RadarPulsePainter extends CustomPainter {
  final double progress;
  final bool isScanning;

  _RadarPulsePainter({
    required this.progress,
    required this.isScanning,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Outer glow boundary
    final bgPaint = Paint()
      ..color = LocaraCyberColors.cardGlassLighter
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, maxRadius, bgPaint);

    final borderPaint = Paint()
      ..color = LocaraCyberColors.auroraCyan.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, maxRadius, borderPaint);

    if (isScanning) {
      // 3 Expanding animated ripple waves
      for (int i = 0; i < 3; i++) {
        final waveProgress = (progress + i * 0.33) % 1.0;
        final currentRadius = 6.0 + (maxRadius - 8.0) * waveProgress;
        final opacity = (1.0 - waveProgress).clamp(0.0, 1.0) * 0.8;

        final wavePaint = Paint()
          ..color = LocaraCyberColors.auroraCyan.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8 - (waveProgress * 0.8);
        canvas.drawCircle(center, currentRadius, wavePaint);
      }
    }

    // Static concentric radar grid
    final gridPaint = Paint()
      ..color = LocaraCyberColors.auroraCyan.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, maxRadius * 0.45, gridPaint);
    canvas.drawCircle(center, maxRadius * 0.75, gridPaint);

    // Center pulse dot
    final centerGlow = Paint()
      ..color = LocaraCyberColors.auroraCyan.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(center, 7, centerGlow);

    final centerDot = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, centerDot);
  }

  @override
  bool shouldRepaint(covariant _RadarPulsePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isScanning != isScanning;
  }
}

/// Mesh radar pulse alias
typedef MeshRadarPulseWidget = LocaraRadarPulseWidget;
