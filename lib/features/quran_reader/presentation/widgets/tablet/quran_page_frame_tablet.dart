import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/hizb_data.dart';
import '../../../../../core/theme/mushaf_theme.dart';
import '../../../../../core/utils/arabic_text_utils.dart';
import '../../../../settings/bloc/settings_bloc.dart';
import '../drawer/tablet/quran_index_view_tablet.dart';
import 'quran_border_painter_tablet.dart';

/// Calculates the Y-position of a Hizb marker from its line number (1–15),
/// clamped so the frame cut never overflows the border corners.
double _calculateHizbMarkerYPosition(int lineNumber, double pageHeight) {
  final double topPadding = pageHeight * 0.04;
  final double textHeight = pageHeight * 0.89;
  final double rawY = topPadding + textHeight * ((lineNumber - 0.5) / 15.0);

  final minY = pageHeight * 0.02 + pageHeight * 0.095 + pageHeight * 0.01;
  final maxY = pageHeight * 0.97 - pageHeight * 0.125 - pageHeight * 0.01;
  if (minY >= maxY) return rawY; // Safeguard against small layout constraints
  return rawY.clamp(minY, maxY);
}

/// Builds inline text spans for a Hizb label, making the digit larger and on a new line.
List<TextSpan> _buildHizbLabelTextSpans(String text, TextStyle baseStyle) {
  final digitRegExp = RegExp(r'[0-9٠-٩]+');
  final spans = <TextSpan>[];

  text.splitMapJoin(
    digitRegExp,
    onMatch: (Match match) {
      spans.add(
        TextSpan(
          text: '\n${match.group(0)}',
          style: baseStyle.copyWith(
            fontSize: baseStyle.fontSize! * 1.3,
            fontWeight: FontWeight.w900,
            fontFamily: 'Amiri',
          ),
        ),
      );
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

class QuranPageFrameTablet extends StatelessWidget {
  final Widget child;
  final int pageNumber;
  final void Function(int page, {String? verseKey})? onNavigateToPage;
  final String surahName;
  final String juzName;
  final VoidCallback? onHeaderTap;
  final bool showHeaderMenu;

  const QuranPageFrameTablet({
    super.key,
    required this.child,
    required this.pageNumber,
    this.onNavigateToPage,
    required this.surahName,
    required this.juzName,
    this.onHeaderTap,
    this.showHeaderMenu = true,
  });

  @override
  Widget build(BuildContext context) {
    final hizbMarkers = HizbData.pageHizbs[pageNumber];
    final isLeftPage = pageNumber % 2 == 0;
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    final mushafTheme = context
        .watch<SettingsBloc>()
        .state
        .effectiveMushafTheme;

    final TextStyle headerStyle = TextStyle(
      fontFamily: 'KFGQPC HAFS Uthmanic Script Regular',
      color: mushafTheme.textColor,
      fontWeight: FontWeight.bold,
    );

    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

    return Material(
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
                  isComplex: true,
                  willChange: false,
                  painter: QuranBorderPainterTablet(
                    pageNumber: pageNumber,
                    hizbCutCenters: hizbMarkers != null
                        ? hizbMarkers
                            .map(
                              (m) => _calculateHizbMarkerYPosition(
                                m['line'] as int,
                                pageHeight,
                              ),
                            )
                            .toList()
                        : const [],
                    goldColor: mushafTheme.goldColor,
                    innerColor: mushafTheme.innerBorderColor,
                    backgroundColor: mushafTheme.backgroundColor,
                    isLandscape: isLandscape,
                  ),
                  size: Size.infinite,
                ),
              ),

              // ── LAYER 2: Quran text content ─────────────────────────────
              Positioned(
                top: 0,
                bottom: 0,
                left: pageWidth * 0.09,
                right: pageWidth * 0.09,
                child: child,
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
                    onTap: () async {
                      onHeaderTap?.call();
                      final result = await Navigator.push<dynamic>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const QuranIndexViewTablet(initialIndex: 1),
                        ),
                      );
                      if (result != null && onNavigateToPage != null) {
                        if (result is Map<String, dynamic>) {
                          onNavigateToPage!(
                            result['page'] as int,
                            verseKey: result['verseKey'] as String?,
                          );
                        } else if (result is int) {
                          onNavigateToPage!(result);
                        }
                      }
                    },
                    child: _TabletFrameInfoBox(
                      theme: mushafTheme,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2.5,
                      ),
                      child: Text(
                        juzName,
                        style: headerStyle.copyWith(fontSize: 13.5),
                        textAlign: TextAlign.center,
                        maxLines: 1,
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
                    onTap: () async {
                      onHeaderTap?.call();
                      final result = await Navigator.push<dynamic>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const QuranIndexViewTablet(initialIndex: 0),
                        ),
                      );
                      if (result != null && onNavigateToPage != null) {
                        if (result is Map<String, dynamic>) {
                          onNavigateToPage!(
                            result['page'] as int,
                            verseKey: result['verseKey'] as String?,
                          );
                        } else if (result is int) {
                          onNavigateToPage!(result);
                        }
                      }
                    },
                    child: _TabletFrameInfoBox(
                      theme: mushafTheme,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2.5,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          surahName,
                          style: headerStyle.copyWith(fontSize: 13.5),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Hamburger Menu
              if (showHeaderMenu)
                Positioned(
                  top: pageHeight * 0.02,
                  left: pageWidth * 0.82,
                  width: pageWidth * 0.11,
                  child: FractionalTranslation(
                    translation: const Offset(0, -0.5),
                    child: GestureDetector(
                      onTap: () {
                        onHeaderTap?.call();
                        Scaffold.of(context).openDrawer();
                      },
                      child: _TabletFrameInfoBox(
                        theme: mushafTheme,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 1.5,
                        ),
                        child: Icon(
                          Icons.segment_rounded,
                          color: mushafTheme.goldColor,
                          size: 20.0,
                        ),
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
                  child: _TabletFrameInfoBox(
                    theme: mushafTheme,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        isEn
                            ? pageNumber.toString()
                            : pageNumber.toArabicDigits,
                        style: TextStyle(
                          fontFamily: 'Amiri',
                          color: mushafTheme.textColor,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── LAYER 5: Hizb markers (side margin) ────────────────────
              if (hizbMarkers != null)
                for (final marker in hizbMarkers)
                  _TabletHizbMarker(
                    marker: marker,
                    pageWidth: pageWidth,
                    pageHeight: pageHeight,
                    isLeftPage: isLeftPage,
                    isLandscape: isLandscape,
                    mushafTheme: mushafTheme,
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _TabletFrameInfoBox extends StatelessWidget {
  final Widget child;
  final MushafTheme theme;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  const _TabletFrameInfoBox({
    required this.child,
    required this.theme,
    this.margin,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 3),
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.goldColor.withValues(alpha: 0.6),
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(10),
        color: theme.backgroundColor,
      ),
      child: child,
    );
  }
}

class _TabletHizbMarker extends StatelessWidget {
  final Map<String, dynamic> marker;
  final double pageWidth;
  final double pageHeight;
  final bool isLeftPage;
  final bool isLandscape;
  final MushafTheme mushafTheme;

  const _TabletHizbMarker({
    required this.marker,
    required this.pageWidth,
    required this.pageHeight,
    required this.isLeftPage,
    this.isLandscape = false,
    required this.mushafTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: _calculateHizbMarkerYPosition(
        marker['line'] as int,
        pageHeight,
      ),
      left: isLeftPage ? (pageWidth * (isLandscape ? 0.056 : 0.056)) : null,
      right: !isLeftPage ? (pageWidth * (isLandscape ? 0.044 : 0.044)) : null,
      width: isLandscape ? 56.0 : (pageWidth * 0.085),
      child: FractionalTranslation(
        translation: Offset(isLeftPage ? -0.5 : 0.5, -0.5),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ornament glyph from QCF_BSML
            Transform.scale(
              scaleX: isLandscape ? 0.55 : 0.58,
              scaleY: 1.0,
              child: Text(
                '\u00F5',
                style: TextStyle(
                  fontFamily: 'QCF_BSML',
                  fontSize: isLandscape ? 66.0 : 88.sp,
                  color: mushafTheme.goldColor,
                  height: isLandscape ? 1.0 : 1.0.h,
                ),
              ),
            ),
            // Label text centred inside the ornament
            Transform.translate(
              offset: isLandscape
                  ? const Offset(-4.8, 12.0)
                  : Offset(-4.w, 12.h),
              child: SizedBox(
                width: isLandscape ? 28.0 : (pageWidth * 0.060),
                child: Text.rich(
                  TextSpan(
                    children: _buildHizbLabelTextSpans(
                      (marker['text'] as String).toArabicDigits,
                      TextStyle(
                        fontFamily: 'KFGQPC HAFS Uthmanic Script Regular',
                        fontSize: isLandscape ? 6.8 : 8.sp,
                        height: isLandscape ? 1.18 : 1.h,
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
    );
  }
}
