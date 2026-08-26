import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:ui';

class _BorderPathDataWeb {
  final Path framePath;
  final Path diamondsPath;
  _BorderPathDataWeb(this.framePath, this.diamondsPath);
}

final Map<String, _BorderPathDataWeb> _borderCacheWeb = {};

class QuranBorderPainterWeb extends CustomPainter {
  final int pageNumber;
  final List<double> hizbCutCenters;
  final Color goldColor;
  final Color innerColor;
  final Color backgroundColor;
  final bool isLandscape;

  const QuranBorderPainterWeb({
    required this.pageNumber,
    required this.hizbCutCenters,
    required this.goldColor,
    required this.innerColor,
    required this.backgroundColor,
    this.isLandscape = false,
  });

  static final Paint _bgPaint = Paint();
  static final Paint _outerBoundPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.miter
    ..strokeCap = StrokeCap.round;
  static final Paint _innerFillPaint = Paint()
    ..style = PaintingStyle.stroke
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
        '${W.toStringAsFixed(1)}_${H.toStringAsFixed(1)}_${isLeftPage}_${isLandscape}_${hizbCutCenters.map((c) => c.toStringAsFixed(1)).join(',')}';
    _BorderPathDataWeb? data =
        kDebugMode ? null : _borderCacheWeb[cacheKey];

    if (data == null) {
      // 2. Constants for positioning
      final double left = W * 0.05;
      final double right = W * 0.95;
      final double top = H * 0.035;
      final double bottom = H * 0.965;

      final double cutTop = 118.0.h;
      final double cutBottom = 156.0.h;

      final double diamondRadius = 5.5.r;
      final double diamondStep = 16.0.r;

      // 3. Build the exact continuous wireframe of the border with cuts
      final Path framePath = Path();

      // Path 1: From Juz cut (left), around the left and bottom, to Page Number cut (left)
      framePath.moveTo(W * 0.08, top); // Juz Left Cut
      framePath.lineTo(left, top); // Top Left Corner

      // Left Edge Hizb Cuts (Even Pages)
      if (isLeftPage && hizbCutCenters.isNotEmpty) {
        final sortedCenters = List<double>.from(hizbCutCenters)
          ..sort((a, b) => a.compareTo(b));
        for (final cy in sortedCenters) {
          framePath.lineTo(left, cy - cutTop);
          framePath.moveTo(left, cy + cutBottom);
        }
      }

      framePath.lineTo(left, bottom); // Bottom Left Corner
      framePath.lineTo(W * 0.42, bottom); // Page Number Left Cut

      // Path 2: From Page Number cut (right), around the bottom and right, to Menu cut (right)
      framePath.moveTo(W * 0.58, bottom); // Page Number Right Cut
      framePath.lineTo(right, bottom); // Bottom Right Corner

      // Right Edge Hizb Cuts (Odd Pages)
      if (!isLeftPage && hizbCutCenters.isNotEmpty) {
        final sortedCenters = List<double>.from(hizbCutCenters)
          ..sort((a, b) => b.compareTo(a));
        for (final cy in sortedCenters) {
          framePath.lineTo(right, cy + cutBottom);
          framePath.moveTo(right, cy - cutTop);
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
        int nSegments = (length / diamondStep).round();
        if (nSegments == 0) nSegments = 1;
        double exactStep = length / nSegments;

        for (int i = 0; i <= nSegments; i++) {
          final double dist = i * exactStep;
          final Tangent? tangent = metric.getTangentForOffset(dist);
          if (tangent == null) continue;

          final Offset pos = tangent.position;
          final Offset dir = tangent.vector;
          final Offset normal = Offset(-dir.dy, dir.dx);

          allDiamondsPath.moveTo(pos.dx + dir.dx * diamondRadius, pos.dy + dir.dy * diamondRadius);
          allDiamondsPath.lineTo(pos.dx + normal.dx * diamondRadius, pos.dy + normal.dy * diamondRadius);
          allDiamondsPath.lineTo(pos.dx - dir.dx * diamondRadius, pos.dy - dir.dy * diamondRadius);
          allDiamondsPath.lineTo(pos.dx - normal.dx * diamondRadius, pos.dy - normal.dy * diamondRadius);
          allDiamondsPath.close();
        }
      }

      data = _BorderPathDataWeb(framePath, allDiamondsPath);
      _borderCacheWeb[cacheKey] = data;
    }

    _outerBoundPaint.strokeWidth = 15.0.r;
    _outerBoundPaint.color = goldColor;
    canvas.drawPath(data.framePath, _outerBoundPaint);

    _innerFillPaint.strokeWidth = 12.5.r;
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
  bool shouldRepaint(covariant QuranBorderPainterWeb oldDelegate) {
    if (oldDelegate.pageNumber != pageNumber ||
        oldDelegate.isLandscape != isLandscape ||
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
