import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/zcolors.dart';

class CircularProgressArc extends StatelessWidget {
  final double percent;
  final List<Color> gradient;
  final double size;
  final double strokeWidth;
  final Widget? center;

  const CircularProgressArc({
    super.key,
    required this.percent,
    required this.gradient,
    this.size = 80,
    this.strokeWidth = 7,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0.0, 100.0) / 100.0;
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: clamped, end: clamped),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (context, v, child) {
          return CustomPaint(
            painter: _ArcPainter(
              progress: v,
              gradient: gradient,
              strokeWidth: strokeWidth,
            ),
            child: child,
          );
        },
        child: Center(child: center),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  final List<Color> gradient;
  final double strokeWidth;

  _ArcPainter({
    required this.progress,
    required this.gradient,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final bgPaint = Paint()
      ..color = ZColors.border.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi, false, bgPaint);

    if (progress <= 0) return;

    final fgPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: [...gradient, gradient.first.withValues(alpha: 0.1)],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, fgPaint);

    // Soft glow at the leading edge
    final angle = -math.pi / 2 + 2 * math.pi * progress;
    final edgeX = center.dx + radius * math.cos(angle);
    final edgeY = center.dy + radius * math.sin(angle);
    final glow = Paint()
      ..color = gradient.last.withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(Offset(edgeX, edgeY), strokeWidth * 0.6, glow);
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.gradient != gradient;
}
