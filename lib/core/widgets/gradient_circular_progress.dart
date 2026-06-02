import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class GradientCircularProgress extends StatelessWidget {
  final double value;
  final double radius;
  final double strokeWidth;
  final Color backgroundColor;
  final List<Color> gradientColors;
  final Color? shadowColor;
  final double shadowBlurRadius;
  final Offset shadowOffset;

  const GradientCircularProgress({
    super.key,
    required this.value,
    required this.radius,
    this.strokeWidth = 4.0,
    this.backgroundColor = const Color(0xFFEDF1F4),
    this.gradientColors = const [Colors.white, Colors.white],
    this.shadowColor,
    this.shadowBlurRadius = 4.0,
    this.shadowOffset = const Offset(0, 2),
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.fromRadius(radius),
      painter: GradientCircularProgressPainter(
        radius: radius,
        value: value,
        strokeWidth: strokeWidth,
        backgroundColor: backgroundColor,
        gradientColors: gradientColors,
        shadowColor: shadowColor,
        shadowBlurRadius: shadowBlurRadius,
        shadowOffset: shadowOffset,
      ),
    );
  }
}

class GradientCircularProgressPainter extends CustomPainter {
  final double radius;
  final double value;
  final double strokeWidth;
  final Color backgroundColor;
  final List<Color> gradientColors;
  final Color? shadowColor;
  final double shadowBlurRadius;
  final Offset shadowOffset;

  GradientCircularProgressPainter({
    required this.radius,
    required this.value,
    required this.strokeWidth,
    required this.backgroundColor,
    required this.gradientColors,
    this.shadowColor,
    this.shadowBlurRadius = 4.0,
    this.shadowOffset = const Offset(0, 2),
  });

  @override
  void paint(Canvas canvas, Size size) {
    size = Size.fromRadius(radius);
    double offset = strokeWidth / 2;
    Rect rect = Offset(offset, offset) &
        Size(size.width - strokeWidth, size.height - strokeWidth);

    final startAngle = -90 * math.pi / 180; // Start from top (12 o'clock)
    final clampedValue = value.clamp(0.0, 1.0);
    final sweepAngle = 2 * math.pi * clampedValue;

    // Draw full background circle first (static, always visible behind progress)
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(rect, 0.0, 2 * math.pi, false, backgroundPaint);

    // Draw progress arc with gradient on top of background
    if (clampedValue > 0) {
      // Draw shadow first if shadowColor is provided
      if (shadowColor != null) {
        // Save layer for shadow blur effect
        canvas.saveLayer(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Paint(),
        );

        // Draw shadow with blur - offset the entire arc
        final shadowPaint = Paint()
          ..color = shadowColor!
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, shadowBlurRadius);

        // Draw shadow arc offset in the shadow direction
        final shadowRect = Rect.fromLTWH(
          rect.left + shadowOffset.dx,
          rect.top + shadowOffset.dy,
          rect.width,
          rect.height,
        );

        canvas.drawArc(shadowRect, startAngle, sweepAngle, false, shadowPaint);

        canvas.restore();
      }

      // Create gradient shader - follow the same pattern as reference code
      var progressPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      // Use the same SweepGradient pattern as reference: startAngle: 0.0, endAngle: 2 * pi
      progressPaint.shader = SweepGradient(
        colors: gradientColors,
        startAngle: 0.0,
        endAngle: 2 * math.pi,
      ).createShader(rect);

      // Draw the progress arc on top of the background and shadow
      canvas.drawArc(rect, startAngle, sweepAngle, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    if (oldDelegate is GradientCircularProgressPainter) {
      return oldDelegate.value != value ||
          oldDelegate.strokeWidth != strokeWidth ||
          oldDelegate.backgroundColor != backgroundColor ||
          oldDelegate.gradientColors != gradientColors ||
          oldDelegate.shadowColor != shadowColor ||
          oldDelegate.shadowBlurRadius != shadowBlurRadius ||
          oldDelegate.shadowOffset != shadowOffset ||
          oldDelegate.radius != radius;
    }
    return true;
  }
}

