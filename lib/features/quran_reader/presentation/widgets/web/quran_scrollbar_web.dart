import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/quran_constants.dart';
import '../../../../../core/constants/quran_metadata.dart';
import '../../../../../core/theme/mushaf_theme.dart';
import '../../../../../core/utils/arabic_text_utils.dart';

/// Luxury interactive scrollbar and page scrubber tailored for Web.
class QuranScrollbarWeb extends StatefulWidget {
  final int currentPage;
  final MushafTheme mushafTheme;
  final ValueChanged<int> onPageChanged;

  const QuranScrollbarWeb({
    super.key,
    required this.currentPage,
    required this.mushafTheme,
    required this.onPageChanged,
  });

  @override
  State<QuranScrollbarWeb> createState() => _QuranScrollbarWebState();
}

class _QuranScrollbarWebState extends State<QuranScrollbarWeb> {
  bool _isDragging = false;
  bool _isHovered = false;
  int? _draggedPage;
  int? _targetPage;

  int get _effectivePage => _draggedPage ?? _targetPage ?? widget.currentPage;

  @override
  void didUpdateWidget(covariant QuranScrollbarWeb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_targetPage != null && widget.currentPage == _targetPage) {
      _targetPage = null;
    }
  }

  static int _getSurahForPage(int page) {
    for (int i = QuranMetadata.surahStartPages.length - 1; i >= 0; i--) {
      if (page >= QuranMetadata.surahStartPages[i]) {
        return i + 1;
      }
    }
    return 1;
  }

  static int _getJuzForPage(int page) {
    for (int i = QuranMetadata.juzStartPages.length - 1; i >= 0; i--) {
      if (page >= QuranMetadata.juzStartPages[i]) {
        return i + 1;
      }
    }
    return 1;
  }

  void _handleDrag(double localY, double totalHeight) {
    final usableHeight = totalHeight - 48.h;
    if (usableHeight <= 0) return;
    final clampedY = (localY - 24.h).clamp(0.0, usableHeight);
    final ratio = clampedY / usableHeight;
    final targetPage = (1 + (ratio * (QuranConstants.totalPages - 1)))
        .round()
        .clamp(1, QuranConstants.totalPages);
    if (targetPage != _draggedPage) {
      setState(() => _draggedPage = targetPage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final goldColor = widget.mushafTheme.goldColor;
    final textColor = widget.mushafTheme.textColor;
    final isDark = widget.mushafTheme.isDarkTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalHeight = constraints.maxHeight;
        final usableHeight = (totalHeight - 48.h).clamp(0.0, totalHeight);
        final thumbFraction =
            (_effectivePage - 1) / (QuranConstants.totalPages - 1);
        final thumbY = (thumbFraction * usableHeight).clamp(0.0, usableHeight);

        final displayPage = _effectivePage;
        final surahNumber = _getSurahForPage(displayPage);
        final surahName = QuranMetadata.getSurahName(surahNumber);
        final juzNumber = _getJuzForPage(displayPage);

        final double trackWidth = (_isDragging || _isHovered) ? 14.0.w : 10.0.w;
        final double hitAreaWidth = trackWidth + 20.0.w;

        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: SizedBox(
            width: (_isDragging || _isHovered) ? 180.w : hitAreaWidth,
            height: totalHeight,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topRight,
              children: [
                // ── Interactive Gesture Layer over Track & Thumb ─────────────
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: hitAreaWidth,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragStart: (details) {
                      setState(() => _isDragging = true);
                      _handleDrag(details.localPosition.dy, totalHeight);
                    },
                    onVerticalDragUpdate: (details) {
                      _handleDrag(details.localPosition.dy, totalHeight);
                    },
                    onVerticalDragEnd: (_) {
                      if (_draggedPage != null) {
                        final page = _draggedPage!;
                        _targetPage = page;
                        widget.onPageChanged(page);
                      }
                      setState(() {
                        _isDragging = false;
                        _draggedPage = null;
                      });
                    },
                    onVerticalDragCancel: () {
                      setState(() {
                        _isDragging = false;
                        _draggedPage = null;
                      });
                    },
                    onTapDown: (details) {
                      _handleDrag(details.localPosition.dy, totalHeight);
                      if (_draggedPage != null) {
                        final page = _draggedPage!;
                        _targetPage = page;
                        widget.onPageChanged(page);
                        setState(() => _draggedPage = null);
                      }
                    },
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: trackWidth,
                        decoration: BoxDecoration(
                          color: goldColor.withValues(
                            alpha: isDark ? 0.16 : 0.12,
                          ),
                          borderRadius: BorderRadius.circular(trackWidth / 2),
                          border: Border.all(
                            color: goldColor.withValues(
                              alpha: (_isDragging || _isHovered) ? 0.5 : 0.25,
                            ),
                            width: 1.0.w,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Draggable Thumb (Concentric with Track) ───────────────────
                Positioned(
                  right: (hitAreaWidth - trackWidth) / 2,
                  top: thumbY,
                  child: IgnorePointer(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 80),
                      width: trackWidth,
                      height: 48.h,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            goldColor,
                            goldColor.withValues(alpha: 0.88),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(trackWidth / 2),
                        boxShadow: [
                          BoxShadow(
                            color: goldColor.withValues(
                              alpha: _isDragging ? 0.6 : 0.35,
                            ),
                            blurRadius: _isDragging ? 8.r : 4.r,
                            spreadRadius: _isDragging ? 1.r : 0,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 3.w,
                          height: 16.h,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black45 : Colors.white70,
                            borderRadius: BorderRadius.circular(2.r),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Floating Page Tooltip Badge (Left of Track) ──────────────
                if (_isDragging || _isHovered)
                  Positioned(
                    right: hitAreaWidth + 8.w,
                    top: (thumbY - 10.h).clamp(0.0, totalHeight - 64.h),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: 1.0,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          color: widget.mushafTheme.backgroundColor,
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(
                            color: goldColor.withValues(alpha: 0.65),
                            width: 1.0.w,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 12.r,
                              offset: const Offset(-3, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'سورة $surahName',
                              style: TextStyle(
                                fontFamily:
                                    'KFGQPC HAFS Uthmanic Script Regular',
                                fontSize: 13.sp,
                                fontWeight: FontWeight.normal,
                                color: textColor,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'ص ${displayPage.toArabicDigits}',
                                  style: TextStyle(
                                    fontFamily: 'Amiri',
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600,
                                    color: goldColor,
                                  ),
                                ),
                                SizedBox(width: 6.w),
                                Container(
                                  width: 3.w,
                                  height: 3.w,
                                  decoration: BoxDecoration(
                                    color: goldColor.withValues(alpha: 0.5),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: 6.w),
                                Text(
                                  'ج ${juzNumber.toArabicDigits}',
                                  style: TextStyle(
                                    fontFamily: 'Amiri',
                                    fontSize: 11.sp,
                                    color: textColor.withValues(alpha: 0.75),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
