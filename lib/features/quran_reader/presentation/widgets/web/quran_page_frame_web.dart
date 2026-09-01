import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/constants/hizb_data.dart';
import '../../../../../core/theme/mushaf_theme.dart';
import '../../../../../core/utils/arabic_text_utils.dart';
import '../../../../settings/presentation/bloc/settings_bloc.dart';
import '../drawer/web/quran_index_view_web.dart';
import 'quran_border_painter_web.dart';

double _calculateHizbMarkerYPosition(int lineNumber, double pageHeight) {
  final double scale = pageHeight / 864.0;
  final double topPadding = pageHeight * 0.057;
  final double textHeight = pageHeight * 0.89;
  final double rawY = topPadding + textHeight * ((lineNumber - 0.56) / 15.0);

  final double minY = (pageHeight * 0.035) + (100.0 * scale) + (10.0 * scale);
  final double maxY = (pageHeight * 0.965) - (132.0 * scale) - (10.0 * scale);
  if (minY >= maxY) return rawY;
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
            fontSize: baseStyle.fontSize! * 1.25,
            fontWeight: FontWeight.normal,
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

class QuranPageFrameWeb extends StatelessWidget {
  final Widget child;
  final int pageNumber;
  final void Function(int page, {String? verseKey})? onNavigateToPage;
  final String surahName;
  final String juzName;
  final VoidCallback? onHeaderTap;
  final bool showHeaderMenu;

  const QuranPageFrameWeb({
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
      fontWeight: FontWeight.normal,
    );

    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

    return Material(
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double pageWidth = constraints.maxWidth;
          final double pageHeight = constraints.maxHeight;
          final double scale = pageHeight / 864.0;

          return Stack(
            fit: StackFit.expand,
            children: [
              // ── LAYER 1: Procedural border painter ─────────────────────
              RepaintBoundary(
                child: CustomPaint(
                  isComplex: true,
                  willChange: false,
                  painter: QuranBorderPainterWeb(
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
                top: pageHeight * 0.035,
                left: pageWidth * (isLandscape ? 0.088 : 0.088),
                width: pageWidth * (isLandscape ? 0.334 : 0.334),
                child: FractionalTranslation(
                  translation: const Offset(0.0, -0.5),
                  child: GestureDetector(
                    onTap: () async {
                      onHeaderTap?.call();
                      final result = await Navigator.push<dynamic>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const QuranIndexViewWeb(initialIndex: 1),
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
                    child: _WebFrameInfoBox(
                      theme: mushafTheme,
                      scale: scale,
                      isLandscape: isLandscape,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Text(
                          juzName,
                          style: headerStyle.copyWith(
                            fontSize: 13.5 * scale,
                            height: 1.18,
                            leadingDistribution: TextLeadingDistribution.even,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Surah Name
              Positioned(
                top: pageHeight * 0.035,
                left: pageWidth * (isLandscape ? 0.468 : 0.468),
                width: pageWidth * (isLandscape ? 0.314 : 0.314),
                child: FractionalTranslation(
                  translation: const Offset(0.0, -0.5),
                  child: GestureDetector(
                    onTap: () async {
                      onHeaderTap?.call();
                      final result = await Navigator.push<dynamic>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const QuranIndexViewWeb(initialIndex: 0),
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
                    child: _WebFrameInfoBox(
                      theme: mushafTheme,
                      scale: scale,
                      isLandscape: isLandscape,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Text(
                          surahName,
                          style: headerStyle.copyWith(
                            fontSize: 13.5 * scale,
                            height: 1.18,
                            leadingDistribution: TextLeadingDistribution.even,
                          ),
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
                  top: pageHeight * 0.035,
                  left: pageWidth * (isLandscape ? 0.828 : 0.83),
                  width: pageWidth * (isLandscape ? 0.094 : 0.09),
                  child: FractionalTranslation(
                    translation: const Offset(0, -0.5),
                    child: GestureDetector(
                      onTap: () {
                        onHeaderTap?.call();
                        Scaffold.of(context).openDrawer();
                      },
                      child: _WebFrameInfoBox(
                        theme: mushafTheme,
                        scale: scale,
                        isLandscape: isLandscape,
                        margin: EdgeInsets.symmetric(
                          horizontal: (isLandscape ? 1.0 : 1.0) * scale,
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: (isLandscape ? 2.5 : 2.0) * scale,
                          vertical: 1.5 * scale,
                        ),
                        child: Icon(
                          Icons.segment_rounded,
                          color: mushafTheme.goldColor,
                          size: (isLandscape ? 18.0 : 18.0) * scale,
                        ),
                      ),
                    ),
                  ),
                ),

              // ── LAYER 4: Page Number (bottom cut) ──────────────────────
              Positioned(
                bottom: pageHeight * 0.035,
                left: pageWidth * (isLandscape ? 0.43 : 0.43),
                width: pageWidth * (isLandscape ? 0.14 : 0.14),
                child: FractionalTranslation(
                  translation: const Offset(0.0, 0.5),
                  child: _WebFrameInfoBox(
                    theme: mushafTheme,
                    scale: scale,
                    isLandscape: isLandscape,
                    margin: EdgeInsets.symmetric(
                      horizontal: (isLandscape ? 1.0 : 1.0) * scale,
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: (isLandscape ? 4.0 : 4.0) * scale,
                      vertical: (isLandscape ? 1.5 : 1.5) * scale,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Text(
                        isEn
                            ? pageNumber.toString()
                            : pageNumber.toArabicDigits,
                        style: TextStyle(
                          fontFamily: 'Amiri',
                          color: mushafTheme.textColor,
                          fontSize: (isLandscape ? 14.5 : 14.5) * scale,
                          fontWeight: FontWeight.normal,
                          height: 1.18,
                          leadingDistribution: TextLeadingDistribution.even,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),

              // ── LAYER 5: Hizb markers (side margin) ────────────────────
              if (hizbMarkers != null)
                for (final marker in hizbMarkers)
                  _WebHizbMarker(
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

class _WebFrameInfoBox extends StatelessWidget {
  final Widget child;
  final MushafTheme theme;
  final double scale;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final bool isLandscape;

  const _WebFrameInfoBox({
    required this.child,
    required this.theme,
    required this.scale,
    this.margin,
    this.padding,
    this.isLandscape = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ??
          EdgeInsets.symmetric(horizontal: (isLandscape ? 1.0 : 1.0) * scale),
      padding: padding ??
          EdgeInsets.symmetric(
            horizontal: (isLandscape ? 4.0 : 4.0) * scale,
            vertical: (isLandscape ? 1.5 : 1.5) * scale,
          ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.goldColor.withValues(alpha: 0.65),
          width: (1.0 * scale).clamp(0.8, 1.5),
        ),
        borderRadius: BorderRadius.circular((isLandscape ? 8.0 : 8.0) * scale),
        color: theme.backgroundColor,
      ),
      child: child,
    );
  }
}

class _WebHizbMarker extends StatelessWidget {
  final Map<String, dynamic> marker;
  final double pageWidth;
  final double pageHeight;
  final bool isLeftPage;
  final bool isLandscape;
  final MushafTheme mushafTheme;

  const _WebHizbMarker({
    required this.marker,
    required this.pageWidth,
    required this.pageHeight,
    required this.isLeftPage,
    this.isLandscape = false,
    required this.mushafTheme,
  });

  @override
  Widget build(BuildContext context) {
    final double scale = pageHeight / 864.0;

    return Positioned(
      top: _calculateHizbMarkerYPosition(
        marker['line'] as int,
        pageHeight,
      ),
      left: isLeftPage ? (pageWidth * 0.0407) : null,
      right: !isLeftPage ? (pageWidth * 0.0407) : null,
      width: 78.0 * scale,
      child: FractionalTranslation(
        translation: Offset(isLeftPage ? -0.5 : 0.5, -0.5),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ornament glyph from QCF_BSML
            Transform.scale(
              scaleX: isLeftPage ? -0.57 : 0.57,
              scaleY: 1.0,
              child: Text(
                '\u00F5',
                style: TextStyle(
                  fontFamily: 'QCF_BSML',
                  fontSize: 98.0 * scale,
                  color: mushafTheme.goldColor,
                  height: 1.0,
                ),
              ),
            ),
            // Label text centred inside the ornament
            Transform.translate(
              offset: Offset(isLeftPage ? (6 * scale) : (-6 * scale), 21.5 * scale),
              child: SizedBox(
                width: 44.0 * scale,
                child: Text.rich(
                  TextSpan(
                    children: _buildHizbLabelTextSpans(
                      (marker['text'] as String).toArabicDigits,
                      TextStyle(
                        fontFamily: 'KFGQPC HAFS Uthmanic Script Regular',
                        fontSize: 10.8 * scale,
                        height: 1.15,
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
