import 'dart:math' as math;
import 'package:flutter/rendering.dart';

class OverlayPositionDelegate extends SingleChildLayoutDelegate {
  final Offset tapPosition;
  final Rect? verseRect;
  final Size menuSize;
  final double topPadding;
  final double bottomPadding;

  OverlayPositionDelegate({
    required this.tapPosition,
    this.verseRect,
    required this.menuSize,
    this.topPadding = 0.0,
    this.bottomPadding = 0.0,
  });

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints(minWidth: menuSize.width, maxWidth: menuSize.width);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final minTop = math.max(topPadding + 10.0, 16.0);
    final maxBottom = size.height - math.max(bottomPadding + 10.0, 16.0);

    double left = tapPosition.dx;
    double top;

    // Check if the verse is tall (e.g. Ayat Al-Dayn spanning full page or multi-line block)
    final bool isTallVerse =
        verseRect != null && verseRect!.height > (size.height * 0.35);

    if (isTallVerse) {
      // For massive verses, position intelligently relative to user's tap point
      if (tapPosition.dy + 35 + childSize.height <= maxBottom) {
        top = tapPosition.dy + 35;
      } else if (tapPosition.dy - childSize.height - 35 >= minTop) {
        top = tapPosition.dy - childSize.height - 35;
      } else {
        top = minTop + (maxBottom - minTop - childSize.height) / 2;
      }
    } else if (verseRect != null && verseRect!.height > 0) {
      // Standard verse: prefer opening below the verse bounding box
      top = verseRect!.bottom + 10;
      if (top + childSize.height > maxBottom) {
        // If opening below goes off-screen, try opening above the verse
        top = verseRect!.top - childSize.height - 10;
        if (top < minTop) {
          // If above also overflows, position relative to tap position
          if (tapPosition.dy + 35 + childSize.height <= maxBottom) {
            top = tapPosition.dy + 35;
          } else {
            top = minTop;
          }
        }
      }
    } else {
      // Fallback relative to tapPosition
      top = tapPosition.dy + 35;
      if (top + childSize.height > maxBottom) {
        top = tapPosition.dy - childSize.height - 35;
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
        bottomPadding != oldDelegate.bottomPadding;
  }
}
