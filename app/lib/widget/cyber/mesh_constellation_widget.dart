import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:locara_app/theme/mesh_design_tokens.dart';

class MeshConstellationWidget extends StatefulWidget {
  final double height;

  const MeshConstellationWidget({
    this.height = 140,
    super.key,
  });

  @override
  State<MeshConstellationWidget> createState() => _MeshConstellationWidgetState();
}

class _MeshConstellationWidgetState extends State<MeshConstellationWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _ConstellationPainter(progress: _controller.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _ConstellationPainter extends CustomPainter {
  final double progress;

  _ConstellationPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final nodes = [
      Offset(size.width * 0.20, size.height * 0.35 + math.sin(progress * math.pi) * 4),
      Offset(size.width * 0.38, size.height * 0.70 + math.cos(progress * math.pi) * 3),
      Offset(size.width * 0.50, size.height * 0.25 - math.sin(progress * math.pi) * 5),
      Offset(size.width * 0.62, size.height * 0.65 + math.sin(progress * math.pi) * 4),
      Offset(size.width * 0.80, size.height * 0.40 - math.cos(progress * math.pi) * 3),
      Offset(size.width * 0.30, size.height * 0.20 + math.cos(progress * math.pi) * 4),
      Offset(size.width * 0.70, size.height * 0.20 - math.sin(progress * math.pi) * 4),
    ];

    // Draw connecting lines
    final linePaint = Paint()
      ..color = LocaraDesignTokens.primaryBlue.withValues(alpha: 0.25 + progress * 0.1)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final connections = [
      [0, 1],
      [0, 2],
      [0, 5],
      [1, 2],
      [1, 3],
      [2, 3],
      [2, 6],
      [3, 4],
      [4, 6],
      [5, 2],
      [6, 3],
    ];

    for (final pair in connections) {
      canvas.drawLine(nodes[pair[0]], nodes[pair[1]], linePaint);
    }

    // Draw glowing node circles
    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final isMajor = i == 2 || i == 0 || i == 4;

      final glowPaint = Paint()
        ..color = (isMajor ? LocaraDesignTokens.cyan : LocaraDesignTokens.purple).withValues(alpha: 0.4 + progress * 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(node, isMajor ? 8 : 6, glowPaint);

      final dotPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(node, isMajor ? 3.5 : 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConstellationPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
