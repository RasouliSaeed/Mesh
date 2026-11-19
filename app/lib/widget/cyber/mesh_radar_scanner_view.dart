import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:locara_app/theme/mesh_design_tokens.dart';

class MeshRadarScannerView extends StatefulWidget {
  final double size;
  final bool isScanning;

  const MeshRadarScannerView({
    this.size = 280,
    this.isScanning = true,
    super.key,
  });

  @override
  State<MeshRadarScannerView> createState() => _MeshRadarScannerViewState();
}

class _MeshRadarScannerViewState extends State<MeshRadarScannerView> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
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
            painter: _MeshRadarPainter(
              value: widget.isScanning ? _controller.value : 0.0,
              isScanning: widget.isScanning,
            ),
          );
        },
      ),
    );
  }
}

class _MeshRadarPainter extends CustomPainter {
  final double value;
  final bool isScanning;

  _MeshRadarPainter({required this.value, required this.isScanning});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // 1. Background glow
    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          LocaraDesignTokens.cyan.withValues(alpha: 0.12),
          LocaraDesignTokens.darkNavy.withValues(alpha: 0.3),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));
    canvas.drawCircle(center, maxRadius, bgPaint);

    // 2. Cyber wave curves in background
    final wavePaint = Paint()
      ..color = LocaraDesignTokens.primaryBlue.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final path = Path();
    for (double x = 0; x <= size.width; x += 10) {
      final y = center.dy + math.sin((x / size.width * 2 * math.pi) + (value * 2 * math.pi)) * 20;
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, wavePaint);

    // 3. Static Concentric Rings
    final ringPaint = Paint()
      ..color = LocaraDesignTokens.cyan.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, maxRadius * 0.35, ringPaint);
    canvas.drawCircle(center, maxRadius * 0.65, ringPaint);
    canvas.drawCircle(center, maxRadius * 0.95, ringPaint);

    // Crosshairs
    final crosshairPaint = Paint()
      ..color = LocaraDesignTokens.cyan.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(center.dx - maxRadius * 0.95, center.dy), Offset(center.dx + maxRadius * 0.95, center.dy), crosshairPaint);
    canvas.drawLine(Offset(center.dx, center.dy - maxRadius * 0.95), Offset(center.dx, center.dy + maxRadius * 0.95), crosshairPaint);

    // 4. Expanding Animated Ripple Waves
    if (isScanning) {
      for (int i = 0; i < 3; i++) {
        final rippleVal = (value + i * 0.33) % 1.0;
        final rippleRadius = maxRadius * 0.2 + (maxRadius * 0.75) * rippleVal;
        final rippleOpacity = (1.0 - rippleVal).clamp(0.0, 1.0) * 0.6;

        final pulsePaint = Paint()
          ..color = LocaraDesignTokens.cyan.withValues(alpha: rippleOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawCircle(center, rippleRadius, pulsePaint);
      }
    }

    // 5. Center Core Pulse Target
    final glowCore = Paint()
      ..color = LocaraDesignTokens.cyan.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center, 12, glowCore);

    final solidCore = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 5, solidCore);
  }

  @override
  bool shouldRepaint(covariant _MeshRadarPainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.isScanning != isScanning;
  }
}
