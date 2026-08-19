import 'package:flutter/material.dart';
import 'dart:ui';

class _BorderPathData {
  final Path framePath;
  final Path diamondsPath;
  _BorderPathData(this.framePath, this.diamondsPath);
}

final Map<String, _BorderPathData> _borderCacheMobile = {};

class QuranBorderPainterMobile extends CustomPainter {
  final int pageNumber;
  final List<double> hizbCutCenters;
  final Color goldColor;
  final Color innerColor;
  final Color backgroundColor;

  const QuranBorderPainterMobile({
    required this.pageNumber,
    required this.hizbCutCenters,
    required this.goldColor,
    required this.innerColor,
    required this.backgroundColor,
  });

  static final Paint _bgPaint = Paint();
  static final Paint _outerBoundPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 12.0
    ..strokeJoin = StrokeJoin.miter
    ..strokeCap = StrokeCap.round;
  static final Paint _innerFillPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 10.0
    ..strokeJoin = StrokeJoin.miter
    ..strokeCap = StrokeCap.round;
  static final Paint _diamondFillPaint = Paint()..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    final W = size.width;
    final H = size.height;

    final bool isLeftPage = pageNumber % 2 == 0;

    // 1. Paint Background
    _drawBackground(canvas, size);

    final String cacheKey =
        '${W.toStringAsFixed(1)}_${H.toStringAsFixed(1)}_${isLeftPage}_${hizbCutCenters.map((c) => c.toStringAsFixed(1)).join(',')}';
    _BorderPathData? data = _borderCacheMobile[cacheKey];

    if (data == null) {
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
        final sortedCenters = List<double>.from(hizbCutCenters)
          ..sort((a, b) => a.compareTo(b));
        for (final cy in sortedCenters) {
          framePath.lineTo(left, cy - H * 0.083);
          framePath.moveTo(left, cy + H * 0.112);
        }
      }

      framePath.lineTo(left, bottom); // Bottom Left Corner
      framePath.lineTo(W * 0.42, bottom); // Page Number Left Cut

      // Path 2: From Page Number cut (right), around the bottom and right, to Menu cut (right)
      framePath.moveTo(W * 0.58, bottom); // Page Number Right Cut
      framePath.lineTo(right, bottom); // Bottom Right Corner

      // Right Edge
      if (!isLeftPage && hizbCutCenters.isNotEmpty) {
        final sortedCenters = List<double>.from(hizbCutCenters)
          ..sort((a, b) => b.compareTo(a));
        for (final cy in sortedCenters) {
          framePath.lineTo(right, cy + H * 0.112);
          framePath.moveTo(right, cy - H * 0.083);
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

      final Path allDiamondsPath = Path();
      for (final metric in framePath.computeMetrics()) {
        final double length = metric.length;
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

          allDiamondsPath.moveTo(pos.dx + dir.dx * 4.5, pos.dy + dir.dy * 4.5);
          allDiamondsPath.lineTo(pos.dx + normal.dx * 4.5, pos.dy + normal.dy * 4.5);
          allDiamondsPath.lineTo(pos.dx - dir.dx * 4.5, pos.dy - dir.dy * 4.5);
          allDiamondsPath.lineTo(pos.dx - normal.dx * 4.5, pos.dy - normal.dy * 4.5);
          allDiamondsPath.close();
        }
      }

      data = _BorderPathData(framePath, allDiamondsPath);
      _borderCacheMobile[cacheKey] = data;
    }

    _outerBoundPaint.color = goldColor;
    canvas.drawPath(data.framePath, _outerBoundPaint);

    _innerFillPaint.color = innerColor;
    canvas.drawPath(data.framePath, _innerFillPaint);

    _diamondFillPaint.color = goldColor;
    canvas.drawPath(data.diamondsPath, _diamondFillPaint);
  }

  void _drawBackground(Canvas canvas, Size size) {
    _bgPaint.color = backgroundColor;
    canvas.drawRect(Offset.zero & size, _bgPaint);
  }

  @override
  bool shouldRepaint(covariant QuranBorderPainterMobile oldDelegate) {
    if (oldDelegate.pageNumber != pageNumber ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.goldColor != goldColor ||
        oldDelegate.innerColor != innerColor ||
        oldDelegate.hizbCutCenters.length != hizbCutCenters.length) {
      return true;
    }
    for (int i = 0; i < hizbCutCenters.length; i++) {
      if ((oldDelegate.hizbCutCenters[i] - hizbCutCenters[i]).abs() > 0.1) {
        return true;
      }
    }
    return false;
  }
}
