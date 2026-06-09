import 'package:flutter/material.dart';
import 'package:paper_scanner_platform_interface/paper_scanner_platform_interface.dart';

/// Paints the detected document outline over the camera preview.
///
/// Corners are normalized (0..1) and mapped onto the painter [Size], so the
/// painter must be laid out over exactly the same box the normalized
/// coordinates refer to (the displayed preview area).
class QuadOverlayPainter extends CustomPainter {
  QuadOverlayPainter({
    required this.quad,
    required this.strokeColor,
    required this.fillColor,
    required this.strokeWidth,
    this.cornerDotRadius = 5.0,
  });

  final Quad? quad;
  final Color strokeColor;
  final Color fillColor;
  final double strokeWidth;
  final double cornerDotRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final q = quad;
    if (q == null) return;

    Offset toOffset(ScanPoint p) => Offset(p.x * size.width, p.y * size.height);
    final tl = toOffset(q.topLeft);
    final tr = toOffset(q.topRight);
    final br = toOffset(q.bottomRight);
    final bl = toOffset(q.bottomLeft);

    final path = Path()
      ..moveTo(tl.dx, tl.dy)
      ..lineTo(tr.dx, tr.dy)
      ..lineTo(br.dx, br.dy)
      ..lineTo(bl.dx, bl.dy)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round,
    );

    final dot = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.fill;
    for (final corner in [tl, tr, br, bl]) {
      canvas.drawCircle(corner, cornerDotRadius, dot);
    }
  }

  @override
  bool shouldRepaint(QuadOverlayPainter old) =>
      old.quad != quad ||
      old.strokeColor != strokeColor ||
      old.fillColor != fillColor ||
      old.strokeWidth != strokeWidth;
}
