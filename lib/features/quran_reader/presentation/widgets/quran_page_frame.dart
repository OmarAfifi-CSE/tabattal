import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'quran_border_painter.dart';
import 'hizb_data.dart';
import '../../../../core/utils/arabic_text_utils.dart';
import 'drawer/quran_index_view.dart';

class QuranPageFrame extends StatelessWidget {
  final Widget child;
  final int pageNumber;
  final String surahName;
  final String juzName;

  const QuranPageFrame({
    super.key,
    required this.child,
    required this.pageNumber,
    required this.surahName,
    required this.juzName,
  });

  /// Builds inline text spans for a Hizb label, making the digit larger and on a new line.
  List<TextSpan> buildHizbLabelTextSpans(String text, TextStyle baseStyle) {
    final digitRegExp = RegExp(r'[0-9٠-٩]+');
    final spans = <TextSpan>[];

    text.splitMapJoin(
      digitRegExp,
      onMatch: (Match match) {
        spans.add(TextSpan(
          text: '\n${match.group(0)}',
          style: baseStyle.copyWith(
            fontSize: baseStyle.fontSize! * 1.25,
            fontWeight: FontWeight.w900,
            fontFamily: 'Amiri',
          ),
        ));
        return '';
      },
      onNonMatch: (String nonMatch) {
        if (nonMatch.trim().isNotEmpty) {
          final replaced = nonMatch.trim().replaceAll(' ', '\n');
          spans.add(TextSpan(text: replaced, style: baseStyle));
        }
        return '';
      },
    );
    return spans;
  }

  /// Calculates the Y-position of a Hizb marker from its line number (1–15),
  /// clamped so the frame cut never overflows the border corners.
  double calculateHizbMarkerYPosition(int lineNumber, double pageHeight) {
    final double topPadding = pageHeight * 0.04;
    final double textHeight = pageHeight * 0.89;
    double rawY = topPadding + textHeight * ((lineNumber - 0.5) / 15.0);

    final minY = pageHeight * 0.02 + pageHeight * 0.095 + pageHeight * 0.01;
    final maxY = pageHeight * 0.97 - pageHeight * 0.125 - pageHeight * 0.01;
    if (minY >= maxY) return rawY; // Safeguard against small layout constraints
    return rawY.clamp(minY, maxY);
  }

  Widget _buildFrameInfoBox({required Widget child, EdgeInsetsGeometry? margin, EdgeInsetsGeometry? padding}) {
    return Container(
      margin: margin ?? (kIsWeb ? const EdgeInsets.symmetric(horizontal: 6) : EdgeInsets.symmetric(horizontal: 6.w)),
      padding: padding ?? (kIsWeb ? const EdgeInsets.symmetric(horizontal: 4, vertical: 4) : EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h)),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: QuranBorderPainter.gold.withValues(alpha: 0.6), width: 1.0),
        borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.r),
        color: QuranBorderPainter.background,
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hizbMarkers = HizbData.pageHizbs[pageNumber];
    final isLeftPage = pageNumber % 2 == 0;

    const TextStyle headerStyle = TextStyle(
      fontFamily: 'KFGQPC HAFS Uthmanic Script Regular',
      color: QuranBorderPainter.innerColor,
      fontWeight: FontWeight.bold,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarContrastEnforced: false,
        systemStatusBarContrastEnforced: false,
      ),
      child: Material(
        color: Colors.transparent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double pageWidth = constraints.maxWidth;
            final double pageHeight = constraints.maxHeight;

            return Stack(
              fit: StackFit.expand,
              children: [
                // ── LAYER 1: Procedural border painter ─────────────────────
                RepaintBoundary(
                  child: CustomPaint(
                    painter: QuranBorderPainter(
                      pageNumber: pageNumber,
                      hizbCutCenters: hizbMarkers != null
                          ? hizbMarkers
                              .map((m) => calculateHizbMarkerYPosition(m['line'] as int, pageHeight))
                              .toList()
                          : [],
                    ),
                    size: Size.infinite,
                  ),
                ),

                // ── LAYER 2: Quran text content ─────────────────────────────
                Positioned(
                  top: pageHeight * 0.04, // Moved up to match the higher border
                  bottom: pageHeight * 0.05,
                  left: pageWidth * 0.08,
                  right: pageWidth * 0.08,
                  child: RepaintBoundary(child: child),
                ),

                // ── LAYER 3: Header frame cuts ──────────────────────────────

                // Juz Name
                Positioned(
                  top: pageHeight * 0.02,
                  left: pageWidth * 0.08,
                  width: pageWidth * 0.35,
                  child: FractionalTranslation(
                    translation: const Offset(0.0, -0.5),
                    child: GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuranIndexView(initialIndex: 1))),
                      child: _buildFrameInfoBox(
                        child: Text(
                          juzName,
                          style: headerStyle.copyWith(fontSize: kIsWeb ? 12 : 10.sp),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),

                // Surah Name
                Positioned(
                  top: pageHeight * 0.02,
                  left: pageWidth * 0.46,
                  width: pageWidth * 0.33,
                  child: FractionalTranslation(
                    translation: const Offset(0.0, -0.5),
                    child: GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuranIndexView(initialIndex: 0))),
                      child: _buildFrameInfoBox(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            surahName,
                            style: headerStyle.copyWith(fontSize: kIsWeb ? 12 : 10.sp),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Hamburger Menu
                Positioned(
                  top: pageHeight * 0.02,
                  right: pageWidth * 0.07,
                  child: FractionalTranslation(
                    translation: const Offset(0.0, -0.5),
                    child: GestureDetector(
                      onTap: () => Scaffold.of(context).openDrawer(),
                      child: _buildFrameInfoBox(
                        margin: kIsWeb ? const EdgeInsets.symmetric(horizontal: 6) : EdgeInsets.symmetric(horizontal: 6.w),
                        child: Icon(Icons.segment_rounded, color: QuranBorderPainter.gold, size: kIsWeb ? 24 : 24.sp),
                      ),
                    ),
                  ),
                ),

                // ── LAYER 4: Page Number (bottom cut) ──────────────────────
                Positioned(
                  bottom: pageHeight * 0.03,
                  left: pageWidth * 0.42,
                  width: pageWidth * 0.16,
                  child: FractionalTranslation(
                    translation: const Offset(0.0, 0.5),
                    child: _buildFrameInfoBox(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          pageNumber.toArabicDigits,
                          style: TextStyle(
                            fontFamily: 'Amiri',
                            color: QuranBorderPainter.innerColor,
                            fontSize: kIsWeb ? 15 : 15.sp,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── LAYER 5: Hizb markers (side margin) ────────────────────
                // The marker appears on the outer edge (left for even/left pages, right for odd).
                if (hizbMarkers != null)
                  for (final marker in hizbMarkers)
                    Positioned(
                      top: calculateHizbMarkerYPosition(marker['line'] as int, pageHeight),
                      left: isLeftPage ? (kIsWeb ? pageWidth * 0.05 + 8.5 : pageWidth * 0.057) : null,
                      right: !isLeftPage ? (kIsWeb ? pageWidth * 0.05 - 7.8 : pageWidth * 0.043) : null,
                      width: pageWidth * 0.12,
                      child: FractionalTranslation(
                        translation: Offset(isLeftPage ? -0.5 : 0.5, -0.5),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Ornament glyph from QCF_BSML
                            Transform.scale(
                              scaleX: 0.55,
                              scaleY: 1.0,
                              child: Text(
                                '\u00F5',
                                style: TextStyle(
                                  fontFamily: 'QCF_BSML',
                                  fontSize: kIsWeb ? 55 : 65.sp,
                                  color: QuranBorderPainter.gold,
                                  height: 1.0,
                                ),
                              ),
                            ),
                            // Label text centred inside the ornament
                            Transform.translate(
                              offset: kIsWeb ? const Offset(-6, 10) : Offset(-3.2.w, 12.h),
                              child: SizedBox(
                                width: pageWidth * 0.06,
                                child: Text.rich(
                                  TextSpan(
                                    children: buildHizbLabelTextSpans(
                                      (marker['text'] as String).toArabicDigits,
                                      TextStyle(
                                        fontFamily: 'KFGQPC HAFS Uthmanic Script Regular',
                                        fontSize: kIsWeb ? 8 : 6.sp,
                                        height: 1.2,
                                        color: QuranBorderPainter.innerColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  textAlign: TextAlign.center,
                                  textDirection: TextDirection.rtl,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

              ],
            );
          },
        ),
      ),
    );
  }
}
