import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'quran_border_painter_mobile.dart';
import '../../../../../core/constants/hizb_data.dart';
import '../../../../../core/utils/arabic_text_utils.dart';
import '../drawer/mobile/quran_index_view_mobile.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../settings/bloc/settings_bloc.dart';
import '../../../../../core/theme/mushaf_theme.dart';

class QuranPageFrameMobile extends StatelessWidget {
  final Widget child;
  final int pageNumber;
  final String surahName;
  final String juzName;

  const QuranPageFrameMobile({
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

  Widget _buildFrameInfoBox({required Widget child, required MushafTheme theme, EdgeInsetsGeometry? margin, EdgeInsetsGeometry? padding}) {
    return Container(
      margin: margin ?? (EdgeInsets.symmetric(horizontal: 6.w)),
      padding: padding ?? (EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h)),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: theme.goldColor.withValues(alpha: 0.6), width: 1.0.w),
        borderRadius: BorderRadius.circular(12.r),
        color: theme.backgroundColor,
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hizbMarkers = HizbData.pageHizbs[pageNumber];
    final isLeftPage = pageNumber % 2 == 0;
    
    final mushafTheme = context.watch<SettingsBloc>().state.effectiveMushafTheme;

    final TextStyle headerStyle = TextStyle(
      fontFamily: 'KFGQPC HAFS Uthmanic Script Regular',
      color: mushafTheme.textColor,
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
                    painter: QuranBorderPainterMobile(
                      pageNumber: pageNumber,
                      hizbCutCenters: hizbMarkers != null
                          ? hizbMarkers
                              .map((m) => calculateHizbMarkerYPosition(m['line'] as int, pageHeight))
                              .toList()
                          : [],
                      goldColor: mushafTheme.goldColor,
                      innerColor: mushafTheme.innerBorderColor,
                      backgroundColor: mushafTheme.backgroundColor,
                      
                    ),
                    size: Size.infinite,
                  ),
                ),

                // ── LAYER 2: Quran text content ─────────────────────────────
                Positioned(
                  top: pageHeight * 0.04,
                  bottom: pageHeight * 0.04,
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
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuranIndexViewMobile(initialIndex: 1))),
                      child: _buildFrameInfoBox(
                        theme: mushafTheme,
                        child: Text(
                          juzName,
                          style: headerStyle.copyWith(fontSize: 10.sp),
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
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuranIndexViewMobile(initialIndex: 0))),
                      child: _buildFrameInfoBox(
                        theme: mushafTheme,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            surahName,
                            style: headerStyle.copyWith(fontSize: 10.sp),
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
                    translation: const Offset(0, -0.5),
                    child: GestureDetector(
                      onTap: () => Scaffold.of(context).openDrawer(),
                      child: _buildFrameInfoBox(
                        theme: mushafTheme,
                        margin: EdgeInsets.symmetric(horizontal: 6.w),
                        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.h),
                        child: Icon(Icons.segment_rounded, color: mushafTheme.goldColor, size: 24.sp),
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
                      theme: mushafTheme,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          pageNumber.toArabicDigits,
                          style: TextStyle(
                            fontFamily: 'Amiri',
                            color: mushafTheme.textColor,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w900,
                            height: 1.1.h,
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
                      left: isLeftPage ? (pageWidth * 0.057) : null,
                      right: !isLeftPage ? (pageWidth * 0.043) : null,
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
                                  fontSize: 65.sp,
                                  color: mushafTheme.goldColor,
                                  height: 1.0.h,
                                ),
                              ),
                            ),
                            // Label text centred inside the ornament
                            Transform.translate(
                              offset: Offset(-3.2.w, 12.h),
                              child: SizedBox(
                                width: pageWidth * 0.06,
                                child: Text.rich(
                                  TextSpan(
                                    children: buildHizbLabelTextSpans(
                                      (marker['text'] as String).toArabicDigits,
                                      TextStyle(
                                        fontFamily: 'KFGQPC HAFS Uthmanic Script Regular',
                                        fontSize: 6.sp,
                                        height: 1.2.h,
                                        color: mushafTheme.textColor,
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






