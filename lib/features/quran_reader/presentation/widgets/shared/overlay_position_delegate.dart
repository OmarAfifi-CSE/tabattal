import 'dart:math' as math;
import 'package:flutter/rendering.dart';

class OverlayPositionDelegate extends SingleChildLayoutDelegate {
  final Offset tapPosition;
  final Rect? verseRect;
  final Size menuSize;
  final double topPadding;
  final double bottomPadding;
  final bool centerHorizontally;

  OverlayPositionDelegate({
    required this.tapPosition,
    this.verseRect,
    required this.menuSize,
    this.topPadding = 0.0,
    this.bottomPadding = 0.0,
    this.centerHorizontally = true,
  });

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints(minWidth: menuSize.width, maxWidth: menuSize.width);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final minTop = math.max(topPadding + 10.0, 16.0);
    final maxBottom = size.height - math.max(bottomPadding + 10.0, 16.0);

    double left = centerHorizontally
        ? (tapPosition.dx - (childSize.width / 2))
        : tapPosition.dx;
    double top;

    const double verticalSpacing = 8.0;

    if (verseRect != null && verseRect!.height > 0) {
      // 1. Prefer opening cleanly BELOW the verse if it fits on screen
      if (verseRect!.bottom + verticalSpacing + childSize.height <= maxBottom) {
        top = verseRect!.bottom + verticalSpacing;
      }
      // 2. Otherwise, prefer opening cleanly ABOVE the verse if it fits
      else if (verseRect!.top - childSize.height - verticalSpacing >= minTop) {
        top = verseRect!.top - childSize.height - verticalSpacing;
      }
      // 3. Both above and below overflow (massive multi-line verse taking most of the screen)
      else {
        // Position relative to user's tap point so the menu remains accessible
        if (tapPosition.dy + verticalSpacing + childSize.height <= maxBottom) {
          top = tapPosition.dy + verticalSpacing;
        } else if (tapPosition.dy - childSize.height - verticalSpacing >= minTop) {
          top = tapPosition.dy - childSize.height - verticalSpacing;
        } else {
          top = minTop + (maxBottom - minTop - childSize.height) / 2;
        }
      }
    } else {
      // Fallback relative to tapPosition
      top = tapPosition.dy + verticalSpacing;
      if (top + childSize.height > maxBottom) {
        top = tapPosition.dy - childSize.height - verticalSpacing;
      }
    }

    // Strictly enforce safe top (under status bar/clock) and bottom margins
    top = top.clamp(minTop, math.max(minTop, maxBottom - childSize.height));

    // Horizontal bounds
    if (left + childSize.width > size.width - 16) {
      left = size.width - childSize.width - 16;
    }
    if (left < 16) left = 16;

    return Offset(left, top);
  }

  @override
  bool shouldRelayout(covariant OverlayPositionDelegate oldDelegate) {
    return tapPosition != oldDelegate.tapPosition ||
        verseRect != oldDelegate.verseRect ||
        topPadding != oldDelegate.topPadding ||
        bottomPadding != oldDelegate.bottomPadding ||
        centerHorizontally != oldDelegate.centerHorizontally;
  }
}
