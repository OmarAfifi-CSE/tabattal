import 'package:flutter/material.dart';

class QuranFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Premium Colors
    final Color outerColor = const Color(0xFFC7A263); // Gold
    final Color innerColor = const Color(0xFF5A4033); // Deep Brown
    
    // Outer Thick Border
    final outerPaint = Paint()
      ..color = outerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeJoin = StrokeJoin.miter;

    // Inner Thin Border
    final innerPaint = Paint()
      ..color = innerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Outer Rect
    final outerRect = Rect.fromLTRB(16, 16, size.width - 16, size.height - 16);
    canvas.drawRect(outerRect, outerPaint);

    // Inner Rect
    final innerRect = Rect.fromLTRB(22, 22, size.width - 22, size.height - 22);
    canvas.drawRect(innerRect, innerPaint);

    // Decorative Corners (Draw intricate diamonds)
    _drawCornerOrnament(canvas, const Offset(16, 16), innerColor, outerColor);
    _drawCornerOrnament(canvas, Offset(size.width - 16, 16), innerColor, outerColor);
    _drawCornerOrnament(canvas, Offset(16, size.height - 16), innerColor, outerColor);
    _drawCornerOrnament(canvas, Offset(size.width - 16, size.height - 16), innerColor, outerColor);
    
    // Header separation line
    canvas.drawLine(
      const Offset(22, 70), 
      Offset(size.width - 22, 70), 
      innerPaint
    );

    // Footer separation line
    canvas.drawLine(
      Offset(22, size.height - 70), 
      Offset(size.width - 22, size.height - 70), 
      innerPaint
    );
  }

  void _drawCornerOrnament(Canvas canvas, Offset center, Color inner, Color outer) {
    // Draw a star/diamond hybrid to act as the corner piece
    final Path path = Path();
    path.moveTo(center.dx, center.dy - 12);
    path.lineTo(center.dx + 4, center.dy - 4);
    path.lineTo(center.dx + 12, center.dy);
    path.lineTo(center.dx + 4, center.dy + 4);
    path.lineTo(center.dx, center.dy + 12);
    path.lineTo(center.dx - 4, center.dy + 4);
    path.lineTo(center.dx - 12, center.dy);
    path.lineTo(center.dx - 4, center.dy - 4);
    path.close();

    final Paint fill = Paint()..color = const Color(0xFFFAF5EB)..style = PaintingStyle.fill;
    final Paint stroke = Paint()..color = inner..style = PaintingStyle.stroke..strokeWidth = 1.5;

    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
    
    // Add inner dot
    canvas.drawCircle(center, 2, Paint()..color = outer..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
