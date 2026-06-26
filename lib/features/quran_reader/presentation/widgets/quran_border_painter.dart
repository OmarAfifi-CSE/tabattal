import 'package:flutter/material.dart';
import 'dart:ui';
import '../../../../core/theme/app_colors.dart';

class QuranBorderPainter extends CustomPainter {
  final int pageNumber;
  final List<double> hizbCutCenters;

  QuranBorderPainter({required this.pageNumber, required this.hizbCutCenters});

  static const Color gold = AppColors.verseMarkerGold; 
  static const Color innerColor = AppColors.inkBrown;
  static const Color background = AppColors.background;

  @override
  void paint(Canvas canvas, Size size) {
    final W = size.width;
    final H = size.height;
    
    final bool isLeftPage = pageNumber % 2 == 0;

    // 1. Paint Background
    _drawBackground(canvas, size);

    // 2. Constants for positioning
    final double left = W * 0.05;
    final double right = W * 0.95;
    final double top = H * 0.02;
    final double bottom = H * 0.97;

    // 3. Build the exact continuous wireframe of the border with cuts
    final Path framePath = Path();

    // Path 1: From Juz cut (left), around the left and bottom, to Page Number cut (left)
    framePath.moveTo(W * 0.08, top); // Juz Left Cut
    framePath.lineTo(left, top); // Top Left Corner
    
    // Left Edge
    if (isLeftPage && hizbCutCenters.isNotEmpty) {
      // Sort in descending order of Y to draw from top to bottom
      final sortedCenters = List<double>.from(hizbCutCenters)..sort((a, b) => a.compareTo(b));
      for (final cy in sortedCenters) {
        framePath.lineTo(left, cy - H * 0.083); // Top Cut (smaller gap above)
        framePath.moveTo(left, cy + H * 0.112); // Bottom Cut (larger gap below)
      }
    }
    
    framePath.lineTo(left, bottom); // Bottom Left Corner
    framePath.lineTo(W * 0.42, bottom); // Page Number Left Cut

    // Path 2: From Page Number cut (right), around the bottom and right, to Menu cut (right)
    framePath.moveTo(W * 0.58, bottom); // Page Number Right Cut
    framePath.lineTo(right, bottom); // Bottom Right Corner
    
    // Right Edge
    if (!isLeftPage && hizbCutCenters.isNotEmpty) {
      // For right edge, we draw from bottom to top, so sort in descending order of Y
      final sortedCenters = List<double>.from(hizbCutCenters)..sort((a, b) => b.compareTo(a));
      for (final cy in sortedCenters) {
        framePath.lineTo(right, cy + H * 0.112); // Bottom Cut (larger gap below)
        framePath.moveTo(right, cy - H * 0.083); // Top Cut (smaller gap above)
      }
    }
    
    framePath.lineTo(right, top); // Top Right Corner
    framePath.lineTo(W * 0.93, top); // Menu Right Cut

    // Path 3: From Menu cut (left) to Surah cut (right)
    framePath.moveTo(W * 0.82, top); // Menu Left Cut
    framePath.lineTo(W * 0.79, top); // Surah Right Cut

    // Path 4: From Surah cut (left) to Juz cut (right)
    framePath.moveTo(W * 0.46, top); // Surah Left Cut
    framePath.lineTo(W * 0.43, top); // Juz Right Cut

    // 4. Draw the two bounding parallel lines using the "hollow stroke" technique
    // Outer thick line (gold)
    final Paint outerBound = Paint()
      ..color = gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12.0
      ..strokeJoin = StrokeJoin.miter
      ..strokeCap = StrokeCap.round;
    
    canvas.drawPath(framePath, outerBound);

    // 5. Inner fill (light opaque gold)
    // By drawing this slightly thinner line over the outer bound, it creates two perfect 1px parallel lines!
    final Paint innerFill = Paint()
      ..color = AppColors.borderInnerGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0
      ..strokeJoin = StrokeJoin.miter
      ..strokeCap = StrokeCap.round;
      
    canvas.drawPath(framePath, innerFill);

    // 6. Distribute the large diamonds perfectly evenly along the path
    final Paint diamondFill = Paint()
      ..color = gold
      ..style = PaintingStyle.fill;

    for (final metric in framePath.computeMetrics()) {
      final double length = metric.length;
      // Step size of exactly 14 pixels between diamonds to match the old preferred design
      int nSegments = (length / 14.0).round();
      if (nSegments == 0) nSegments = 1;
      double exactStep = length / nSegments;

      for (int i = 0; i <= nSegments; i++) {
        final double dist = i * exactStep;
        final Tangent? tangent = metric.getTangentForOffset(dist);
        if (tangent == null) continue;

        final Offset pos = tangent.position;
        final Offset dir = tangent.vector;
        final Offset normal = Offset(-dir.dy, dir.dx);

        // Make the diamonds larger again (radius 4.5) to fill the 10px track nicely
        final Path diamond = Path();
        diamond.moveTo(pos.dx + dir.dx * 4.5, pos.dy + dir.dy * 4.5); // Front
        diamond.lineTo(pos.dx + normal.dx * 4.5, pos.dy + normal.dy * 4.5); // Right
        diamond.lineTo(pos.dx - dir.dx * 4.5, pos.dy - dir.dy * 4.5); // Back
        diamond.lineTo(pos.dx - normal.dx * 4.5, pos.dy - normal.dy * 4.5); // Left
        diamond.close();
        
        canvas.drawPath(diamond, diamondFill);
      }
    }
  }

  void _drawBackground(Canvas canvas, Size size) {
    final Paint bgPaint = Paint()..color = background;
    canvas.drawRect(Offset.zero & size, bgPaint);
  }

  @override
  bool shouldRepaint(covariant QuranBorderPainter oldDelegate) {
    return oldDelegate.pageNumber != pageNumber || oldDelegate.hizbCutCenters.toString() != hizbCutCenters.toString();
  }
}
