import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:studycompete/shared/utils/hunter_rank.dart';

class RadarChartWidget extends StatelessWidget {
  final List<RadarStatPoint> points;
  final Color accentColor;
  final double size;

  const RadarChartWidget({
    super.key,
    required this.points,
    required this.accentColor,
    this.size = 280,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          size: Size(size, size),
          painter: _RadarChartPainter(
            points: points,
            accentColor: accentColor,
            isDark: Theme.of(context).brightness == Brightness.dark,
          ),
        ),
      ),
    );
  }
}

class _RadarChartPainter extends CustomPainter {
  final List<RadarStatPoint> points;
  final Color accentColor;
  final bool isDark;

  _RadarChartPainter({
    required this.points,
    required this.accentColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) * 0.68;
    final int count = points.length;
    final double angleStep = (math.pi * 2) / count;

    // Grid paint
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final axisPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw concentric polygon grid levels (0.25, 0.5, 0.75, 1.0)
    const levels = [0.25, 0.50, 0.75, 1.0];
    for (final lvl in levels) {
      final path = Path();
      for (int i = 0; i < count; i++) {
        final angle = (i * angleStep) - (math.pi / 2);
        final r = radius * lvl;
        final x = center.dx + math.cos(angle) * r;
        final y = center.dy + math.sin(angle) * r;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // Draw axis lines from center to outer radius
    for (int i = 0; i < count; i++) {
      final angle = (i * angleStep) - (math.pi / 2);
      final x = center.dx + math.cos(angle) * radius;
      final y = center.dy + math.sin(angle) * radius;
      canvas.drawLine(center, Offset(x, y), axisPaint);
    }

    // Data polygon
    final dataPath = Path();
    final dataOffsets = <Offset>[];

    for (int i = 0; i < count; i++) {
      final angle = (i * angleStep) - (math.pi / 2);
      final ratio = (points[i].value / points[i].max).clamp(0.10, 1.0);
      final r = radius * ratio;
      final x = center.dx + math.cos(angle) * r;
      final y = center.dy + math.sin(angle) * r;
      final pt = Offset(x, y);
      dataOffsets.add(pt);

      if (i == 0) {
        dataPath.moveTo(x, y);
      } else {
        dataPath.lineTo(x, y);
      }
    }
    dataPath.close();

    // Fill data polygon
    final fillPaint = Paint()
      ..color = accentColor.withOpacity(0.24)
      ..style = PaintingStyle.fill;
    canvas.drawPath(dataPath, fillPaint);

    // Stroke data polygon
    final strokePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawPath(dataPath, strokePaint);

    // Draw vertex dots
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final dotBorderPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final pt in dataOffsets) {
      canvas.drawCircle(pt, 4.0, dotPaint);
      canvas.drawCircle(pt, 4.0, dotBorderPaint);
    }

    // Draw Labels & Values
    for (int i = 0; i < count; i++) {
      final angle = (i * angleStep) - (math.pi / 2);
      final labelRadius = radius + 22.0;
      final x = center.dx + math.cos(angle) * labelRadius;
      final y = center.dy + math.sin(angle) * labelRadius;

      final labelText = points[i].label;
      final valText = points[i].value.toStringAsFixed(0);

      final textSpan = TextSpan(
        children: [
          TextSpan(
            text: '$labelText\n',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black87,
              height: 1.1,
            ),
          ),
          TextSpan(
            text: valText,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: accentColor,
            ),
          ),
        ],
      );

      final tp = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(x - (tp.width / 2), y - (tp.height / 2)));
    }
  }

  @override
  bool shouldRepaint(covariant _RadarChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isDark != isDark;
  }
}
