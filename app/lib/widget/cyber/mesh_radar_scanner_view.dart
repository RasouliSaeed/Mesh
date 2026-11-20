import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:locara_app/theme/mesh_design_tokens.dart';

class MeshRadarScannerView extends StatefulWidget {
  final double size;
  final bool isScanning;

  const MeshRadarScannerView({
    this.size = 260,
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
      duration: const Duration(milliseconds: 4000),
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

    // 1. Cosmic Deep Space Background
    final bgShader = RadialGradient(
      center: const Alignment(0.0, -0.1),
      colors: [
        const Color(0xFF132B52).withValues(alpha: 0.65),
        const Color(0xFF0B1730).withValues(alpha: 0.85),
        const Color(0xFF060C1B).withValues(alpha: 0.95),
      ],
      stops: const [0.0, 0.65, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

    final bgPaint = Paint()..shader = bgShader;
    canvas.drawCircle(center, maxRadius, bgPaint);

    // Subtle outer border glow
    final borderGlowPaint = Paint()
      ..color = LocaraDesignTokens.cyan.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, maxRadius - 1, borderGlowPaint);

    // 2. Concentric Neon Rings
    final ringRadii = [0.26, 0.50, 0.74, 0.96];
    for (int i = 0; i < ringRadii.length; i++) {
      final r = maxRadius * ringRadii[i];
      final isOuter = i == ringRadii.length - 1;
      final ringPaint = Paint()
        ..color = LocaraDesignTokens.cyan.withValues(alpha: isOuter ? 0.35 : 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isOuter ? 1.2 : 0.9;
      canvas.drawCircle(center, r, ringPaint);
    }

    // Crosshairs with subtle tick marks
    final crosshairPaint = Paint()
      ..color = LocaraDesignTokens.cyan.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;

    canvas.drawLine(
      Offset(center.dx - maxRadius * 0.96, center.dy),
      Offset(center.dx + maxRadius * 0.96, center.dy),
      crosshairPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - maxRadius * 0.96),
      Offset(center.dx, center.dy + maxRadius * 0.96),
      crosshairPaint,
    );

    // 3. Rotating Radar Sweep Beam (Pie sector)
    if (isScanning) {
      final sweepAngle = value * 2 * math.pi;
      final sweepSector = math.pi / 4; // 45 degree beam
      final rect = Rect.fromCircle(center: center, radius: maxRadius * 0.95);

      final sweepShader = SweepGradient(
        center: Alignment.center,
        startAngle: sweepAngle - sweepSector,
        endAngle: sweepAngle,
        colors: [
          Colors.transparent,
          LocaraDesignTokens.cyan.withValues(alpha: 0.05),
          LocaraDesignTokens.cyan.withValues(alpha: 0.32),
        ],
        stops: const [0.0, 0.4, 1.0],
        transform: GradientRotation(0),
      ).createShader(rect);

      final sweepPaint = Paint()
        ..shader = sweepShader
        ..style = PaintingStyle.fill;

      canvas.drawArc(rect, sweepAngle - sweepSector, sweepSector, true, sweepPaint);

      // Leading beam edge line
      final beamX = center.dx + math.cos(sweepAngle) * (maxRadius * 0.95);
      final beamY = center.dy + math.sin(sweepAngle) * (maxRadius * 0.95);
      final beamLinePaint = Paint()
        ..color = LocaraDesignTokens.cyan.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;
      canvas.drawLine(center, Offset(beamX, beamY), beamLinePaint);
    }

    // 4. Multi-Layer Ethereal Cosmic Waves across lower half (matching reference image)
    for (int w = 0; w < 3; w++) {
      final waveColor = w == 0
          ? LocaraDesignTokens.cyan.withValues(alpha: 0.45)
          : (w == 1
              ? const Color(0xFF8B5CF6).withValues(alpha: 0.35)
              : LocaraDesignTokens.primaryBlue.withValues(alpha: 0.30));

      final wavePaint = Paint()
        ..color = waveColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = w == 0 ? 1.5 : 1.1;

      final wavePath = Path();
      final baseOffsetY = center.dy + 15 + (w * 14);
      final freq = 1.5 + w * 0.5;
      final phase = (value * 2 * math.pi) + (w * 1.2);

      bool started = false;
      for (double x = center.dx - maxRadius * 0.92; x <= center.dx + maxRadius * 0.92; x += 4) {
        final relX = (x - (center.dx - maxRadius * 0.92)) / (maxRadius * 1.84);
        final envelope = math.sin(relX * math.pi); // Taper at edges of circle
        final y = baseOffsetY + math.sin((relX * freq * 2 * math.pi) + phase) * (14.0 * envelope);

        // Check if inside circle bounds
        final dist = (Offset(x, y) - center).distance;
        if (dist <= maxRadius * 0.95) {
          if (!started) {
            wavePath.moveTo(x, y);
            started = true;
          } else {
            wavePath.lineTo(x, y);
          }
        }
      }
      canvas.drawPath(wavePath, wavePaint);
    }

    // 5. Expanding Ripple Rings
    if (isScanning) {
      for (int i = 0; i < 3; i++) {
        final rippleVal = (value + i * 0.33) % 1.0;
        final rippleRadius = maxRadius * 0.15 + (maxRadius * 0.8) * rippleVal;
        final rippleOpacity = (1.0 - rippleVal).clamp(0.0, 1.0) * 0.5;

        final pulsePaint = Paint()
          ..color = LocaraDesignTokens.cyan.withValues(alpha: rippleOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
        canvas.drawCircle(center, rippleRadius, pulsePaint);
      }
    }

    // 6. Glowing Center Core (Blue Orb + Solid White Core)
    final outerOrbGlow = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawCircle(center, 18, outerOrbGlow);

    final innerOrbGlow = Paint()
      ..color = const Color(0xFF2563EB).withValues(alpha: 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(center, 10, innerOrbGlow);

    final solidOrb = Paint()
      ..color = const Color(0xFF00F0FF)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 6, solidOrb);

    final whiteCenter = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 2.5, whiteCenter);
  }

  @override
  bool shouldRepaint(covariant _MeshRadarPainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.isScanning != isScanning;
  }
}
