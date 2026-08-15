import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../l10n/app_localizations.dart';

import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/utils/arabic_text_utils.dart';
import '../../../data/models/verse_model.dart';
import '../../../bloc/quran/quran_bloc.dart';
import '../../../bloc/quran/quran_page_cache.dart';
import '../../../bloc/quran/quran_event.dart';
import '../../../bloc/quran/quran_state.dart';
import '../../../bloc/audio/audio_bloc.dart';
import '../../../bloc/audio/audio_state.dart';
import '../../../bloc/bookmark/bookmark_bloc.dart';
import '../../../bloc/bookmark/bookmark_state.dart';
import '../../../domain/repositories/quran_repository.dart';
import 'quran_page_frame_web.dart';
import 'verse_action_menu_web.dart';
import '../../../../../core/constants/quran_metadata.dart';
import 'surah_header_widget_web.dart';
import '../../../../../core/services/font_service.dart';
import '../../../../settings/bloc/settings_bloc.dart';
import '../../../../../core/theme/mushaf_theme.dart';
import '../../../bloc/hifz/hifz_bloc.dart';
import '../../../bloc/hifz/hifz_event.dart';
import '../../../bloc/hifz/hifz_state.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

// Removed _kBasmalaWidget constant. It is now a method in _QuranPageWidgetWebState.

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

class QuranPageWidgetWeb extends StatefulWidget {
  final int pageNumber;
  final void Function(int page, {String? verseKey})? onNavigateToPage;
  final String? highlightVerseKey;

  const QuranPageWidgetWeb({
    super.key,
    required this.pageNumber,
    this.onNavigateToPage,
    this.highlightVerseKey,
  });

  static VoidCallback? _activeMenuDismissCallback;

  static void dismissActiveMenu() {
    _activeMenuDismissCallback?.call();
  }

  @override
  State<QuranPageWidgetWeb> createState() => _QuranPageWidgetWebState();
}

class _QuranPageWidgetWebState extends State<QuranPageWidgetWeb>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  int? _activeVerseId;
  OverlayEntry? _activeOverlayEntry;
  final GlobalKey _pageColumnKey = GlobalKey();
  bool _isFontLoaded = false;

  late final AnimationController _bookmarkPulseController;
  late final Animation<double> _bookmarkPulseAnimation;
  int? _bookmarkHighlightVerseId;
  final GlobalKey _pageRepaintKey = GlobalKey();

  double? _precomputedCanvasWidth;
  double? _cachedMaxLineWidth;
  double _lastComputedAvailH = 0;

  // Cached data for O(1) lookups and avoiding re-parsing per frame
  List<LineData>? _cachedLines;
  Map<int, LineData> _lineMap = {};
  final Map<String, int> _verseKeyToIntIdMap = {};
  final Map<String, ({int surah, int ayah})> _parsedVerseKeys = {};

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  late final QuranBloc _quranBloc;

  @override
  void initState() {
    super.initState();
    _quranBloc = QuranBloc(repository: context.read<QuranRepository>())
      ..add(LoadPage(widget.pageNumber));
    _loadPageFont();
    _bookmarkPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _bookmarkPulseAnimation = Tween<double>(begin: 0.15, end: 0.55).animate(
      CurvedAnimation(
        parent: _bookmarkPulseController,
        curve: Curves.easeInOut,
      ),
    );
    if (widget.highlightVerseKey != null) {
      _activateBookmarkHighlight(widget.highlightVerseKey!);
    }
  }

  @override
  void didUpdateWidget(QuranPageWidgetWeb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pageNumber != oldWidget.pageNumber) {
      _quranBloc.add(LoadPage(widget.pageNumber));
      _loadPageFont();
      _precomputedCanvasWidth = null;
    }
    if (widget.highlightVerseKey != oldWidget.highlightVerseKey) {
      if (widget.highlightVerseKey != null) {
        _activateBookmarkHighlight(widget.highlightVerseKey!);
      } else {
        setState(() => _bookmarkHighlightVerseId = null);
      }
    }
  }

  @override
  void dispose() {
    _quranBloc.close();
    _bookmarkPulseController.dispose();
    _activeOverlayEntry?.remove();
    _activeOverlayEntry?.dispose();
    _activeOverlayEntry = null;
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<void> _loadPageFont() async {
    final pageStr = widget.pageNumber.toString().padLeft(3, '0');
    final fontName = 'QCF_P$pageStr';
    if (FontService.isLoaded(fontName)) {
      if (!_isFontLoaded && mounted) {
        setState(() => _isFontLoaded = true);
      }
      return;
    }
    await FontService.loadFontForPage(widget.pageNumber);
    if (mounted) setState(() => _isFontLoaded = true);
  }

  void _activateBookmarkHighlight(String verseKey) {
    final parsed = ArabicTextUtils.parseVerseKey(verseKey);
    if (parsed == null) return;
    setState(
      () => _bookmarkHighlightVerseId = parsed.surah * 1000 + parsed.ayah,
    );
    // Auto-clear after 5 s so it doesn't stay permanently highlighted
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _bookmarkHighlightVerseId = null);
    });
  }

  // Web widgets must NOT use ScreenUtil. We use 32.0 logical pixels for the
  // font size — matching the value used in the non-web platform widgets.
  double _computeCanvasWidth(double availW, double availH) {
    if (_cachedMaxLineWidth == null) {
      _cachedMaxLineWidth = QuranPageCache.getCachedLineWidth(widget.pageNumber);
      if (_cachedMaxLineWidth == null) {
        final pageStr = widget.pageNumber.toString().padLeft(3, '0');
        final fontFamily = 'QCF_P$pageStr';
        const fontSize = 42.0;
        final style = TextStyle(fontFamily: fontFamily, fontSize: fontSize);
        final tp = TextPainter(textDirection: TextDirection.rtl);
        var maxLW = 0.0;

        for (final lineData in _lineMap.values) {
          if (lineData.words.isEmpty) continue;
          final lineText = lineData.words
              .map((w) => w.code)
              .where((t) => t.isNotEmpty)
              .join();
          if (lineText.isEmpty) continue;
          tp.text = TextSpan(text: lineText, style: style);
          tp.layout();
          if (tp.width > maxLW) maxLW = tp.width;
        }
        tp.dispose();
        maxLW = maxLW + 2.0;
        _cachedMaxLineWidth = maxLW;
        QuranPageCache.cacheLineWidth(widget.pageNumber, maxLW);
      }
    }
    final maxLineWidth = _cachedMaxLineWidth!;

    int textLineCount = 0;
    int surahHeaderCount = 0;
    int spacerCount = 0;

    for (int lineNumber = 1; lineNumber <= 15; lineNumber++) {
      final lineData = _lineMap[lineNumber];
      if (lineData != null && lineData.words.isNotEmpty) {
        textLineCount++;
      } else {
        final nextSurah = _findNextSurahStartOnPage(lineNumber);
        if (nextSurah != null && lineNumber == nextSurah.ayah1Line - 1) {
          surahHeaderCount++;
        } else {
          spacerCount++;
        }
      }
    }

    // No ScreenUtil on web: use raw logical pixels for height estimates.
    const textLineH = 42.0 * 1.5 + 4.0; // approx text row height
    const surahHeaderH = 85.0;
    final totalChildrenH =
        textLineCount * textLineH +
        surahHeaderCount * surahHeaderH +
        spacerCount * ((widget.pageNumber == 1 || widget.pageNumber == 2) ? 0.0 : 45.0);

    const paddingFactor = 1.0 / (1.0 - 0.027 - 0.032);
    final minCanvasWForHeight =
        availW > 0 && availH > 0
            ? totalChildrenH * paddingFactor * availW / availH
            : 0.0;

    final textMeasuredW = maxLineWidth > 0 ? maxLineWidth : 490.0;
    return textMeasuredW > minCanvasWForHeight
        ? textMeasuredW
        : minCanvasWForHeight;
  }

  /// Computes the screen rect occupied by [verseKey] using the page column layout.
  Rect _calculateVerseScreenRect(
    String verseKey,
    Offset fallbackPosition,
  ) {
    int minLine = 16;
    int maxLine = 0;
    for (final line in _cachedLines ?? []) {
      for (final word in line.words) {
        if (word.verseKey == verseKey) {
          if (line.lineNumber < minLine) minLine = line.lineNumber;
          if (line.lineNumber > maxLine) maxLine = line.lineNumber;
        }
      }
    }

    if (minLine > 15) {
      return Rect.fromCenter(center: fallbackPosition, width: 0, height: 0);
    }

    final renderBox =
        _pageColumnKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return Rect.fromCenter(center: fallbackPosition, width: 0, height: 0);
    }

    if (widget.pageNumber == 1 || widget.pageNumber == 2) {
      final flex = renderBox as RenderFlex;
      double canvasTop = 0;
      double canvasBottom = renderBox.size.height;
      RenderBox? child = flex.firstChild;
      int childIndex = 1;
      while (child != null) {
        final childData = child.parentData! as FlexParentData;
        if (childIndex == minLine) canvasTop = childData.offset.dy;
        if (childIndex == maxLine) {
          canvasBottom = childData.offset.dy + child.size.height;
        }
        if (childIndex >= maxLine) break;
        childIndex++;
        child = flex.childAfter(child);
      }
      return Rect.fromLTRB(
        0,
        flex.localToGlobal(Offset(0, canvasTop)).dy,
        MediaQuery.sizeOf(context).width,
        flex.localToGlobal(Offset(0, canvasBottom)).dy,
      );
    }

    final lineHeight = renderBox.size.height / 15;
    final topOffset = renderBox.localToGlobal(
      Offset(0, (minLine - 1) * lineHeight),
    );
    final bottomOffset = renderBox.localToGlobal(
      Offset(0, maxLine * lineHeight),
    );

    return Rect.fromLTRB(
      0,
      topOffset.dy,
      MediaQuery.sizeOf(context).width,
      bottomOffset.dy,
    );
  }

  void _showVerseMenu(
    BuildContext context,
    Offset tapPosition,
    int verseId,
  ) {
    if (_activeOverlayEntry != null) _removeVerseMenu();

    setState(() => _activeVerseId = verseId);

    final verseKey = ArabicTextUtils.verseIdToVerseKey(verseId);
    final verseRect = _calculateVerseScreenRect(verseKey, tapPosition);

    // A partial model carrying only the fields the menu needs (id + verseKey).
    final partialVerseForMenu = VerseModel(
      id: verseId,
      verseNumber: verseId % 1000,
      verseKey: verseKey,
      textUthmani: '',
      words: [],
      juzNumber: 1,
    );

    final blocContext = _pageColumnKey.currentContext;
    if (blocContext == null) return;

    final quranBloc = blocContext.read<QuranBloc>();
    final audioBloc = blocContext.read<AudioBloc>();
    final bookmarkBloc = blocContext.read<BookmarkBloc>();

    _activeOverlayEntry = OverlayEntry(
      builder: (overlayContext) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: quranBloc),
          BlocProvider.value(value: audioBloc),
          BlocProvider.value(value: bookmarkBloc),
        ],
        child: VerseActionMenuWeb(
          position: tapPosition,
          verseRect: verseRect,
          verse: partialVerseForMenu,
          pageRepaintKey: _pageRepaintKey,
          onDismiss: ({bool keepHighlight = false}) =>
              _removeVerseMenu(keepHighlight: keepHighlight),
          onClearHighlight: () {
            if (mounted) setState(() => _activeVerseId = null);
          },
        ),
      ),
    );

    Overlay.of(context).insert(_activeOverlayEntry!);
  }

  void _removeVerseMenu({bool keepHighlight = false}) {
    _activeOverlayEntry?.remove();
    _activeOverlayEntry?.dispose();
    _activeOverlayEntry = null;
    if (mounted && !keepHighlight) setState(() => _activeVerseId = null);
  }

  // ---------------------------------------------------------------------------
  // Empty-line builders (Surah transitions)
  // ---------------------------------------------------------------------------

  /// Scans forward from [lineNumber] to find if a new Surah starts on this page.
  ({int ayah1Line, int surahId})? _findNextSurahStartOnPage(int lineNumber) {
    for (int l = lineNumber + 1; l <= 15; l++) {
      final lineData = _lineMap[l];
      if (lineData != null && lineData.words.isNotEmpty) {
        final vk = lineData.words.first.verseKey;
        final parsed = _parsedVerseKeys[vk];
        if (parsed != null && parsed.ayah == 1) {
          return (ayah1Line: l, surahId: parsed.surah);
        }
        break;
      }
    }
    return null;
  }

  /// Scans backward from [lineNumber] to find the Surah on the line above.
  int? _findPreviousSurahId(int lineNumber) {
    for (int l = lineNumber - 1; l >= 1; l--) {
      final lineData = _lineMap[l];
      if (lineData != null && lineData.words.isNotEmpty) {
        return _parsedVerseKeys[lineData.words.last.verseKey]?.surah;
      }
    }
    return null;
  }

  /// Counts empty lines immediately before [lineNumber].
  int _countEmptyLinesBefore(int lineNumber) {
    int count = 0;
    for (int l = lineNumber - 1; l >= 1; l--) {
      final lineData = _lineMap[l];
      if (lineData == null || lineData.words.isEmpty) {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  Widget _buildEmptyLineWidget(
    int lineNumber,
    MushafTheme mushafTheme,
  ) {
    // ── Case A: A new Surah starts later on this page ──────────────────────
    final nextSurah = _findNextSurahStartOnPage(lineNumber);
    if (nextSurah != null) {
      final (:ayah1Line, :surahId) = nextSurah;
      final header = Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: SurahHeaderWidgetWeb(surahNumber: surahId),
      );
      final basmala = Center(
        child: Text(
          '1 2 3',
          style: TextStyle(
            fontFamily: 'QCF_BSML',
            fontSize: 26,
            color: mushafTheme.textColor,
            height: 1.0,
          ),
        ),
      );

      // Surah 9 (At-Tawbah) has no Basmala
      if (surahId == 9 || surahId == 1) {
        return lineNumber == ayah1Line - 1
            ? header
            : const SizedBox(height: 45);
      }

      // Determine whether the header should appear on this line or one earlier
      final prevPrevLineData = _lineMap[ayah1Line - 2];
      final bool mustSquashBothOnLineMinus1 =
          ayah1Line > 2 && prevPrevLineData != null && prevPrevLineData.words.isNotEmpty ||
          ayah1Line == 2 && widget.pageNumber == 1;

      if (lineNumber == ayah1Line - 1) {
        return mustSquashBothOnLineMinus1
            ? Transform.scale(
                scale: 0.85,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [header, basmala],
                ),
              )
            : basmala;
      } else if (lineNumber == ayah1Line - 2 && !mustSquashBothOnLineMinus1) {
        return header;
      }
      return const SizedBox(height: 45);
    }

    if (widget.pageNumber == 1 || widget.pageNumber == 2) {
      return const SizedBox(height: 0);
    }

    final previousSurahId = _findPreviousSurahId(lineNumber);
    if (previousSurahId != null) {
      final upcomingSurahId = previousSurahId + 1;
      if (upcomingSurahId <= 114) {
        final emptyLinesBefore = _countEmptyLinesBefore(lineNumber);
        final header = Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: SurahHeaderWidgetWeb(surahNumber: upcomingSurahId),
        );
        final basmala = Center(
          child: Text(
            '1 2 3',
            style: TextStyle(
              fontFamily: 'QCF_BSML',
              fontSize: 26,
              color: mushafTheme.textColor,
              height: 1.0,
            ),
          ),
        );

        if (emptyLinesBefore == 0) return header;
        if (emptyLinesBefore == 1 && upcomingSurahId != 9) return basmala;
      }
    }

    return const SizedBox(height: 45);
  }

  // ---------------------------------------------------------------------------
  // Word & row builders
  // ---------------------------------------------------------------------------

  /// Builds a single tappable word widget, applying the appropriate highlight style.
  Widget _buildWordWidget({
    required WordModel word,
    required int verseId,
    required bool isMenuHighlighted,
    required bool isAudioHighlighted,
    required bool isBookmarkHighlighted,
    required bool isPermanentlyBookmarked,
    required AudioState audioState,
    required MushafTheme mushafTheme,
    required HifzState hifzState,
  }) {
    final pageStr = widget.pageNumber.toString().padLeft(3, '0');
    final customFontFamily = 'QCF_P$pageStr';
    final displayText = word.code;
    final wordKey = '${word.verseKey}:${word.id}';

    bool isWordMasked = false;
    if (hifzState.isHifzModeActive && word.charTypeName != 'end') {
      final isVerseRevealed = hifzState.revealedVerseKeys.contains(word.verseKey);
      final isWordRevealed = hifzState.revealedWordKeys.contains(wordKey);

      if (!isVerseRevealed && !isWordRevealed) {
        if (hifzState.maskingType == HifzMaskingType.fullVerse) {
          isWordMasked = true;
        } else if (hifzState.maskingType == HifzMaskingType.verseTail &&
            word.id > 1) {
          isWordMasked = true;
        } else if (hifzState.maskingType == HifzMaskingType.wordByWord) {
          isWordMasked = true;
        }
      }
    }

    void handleTap(TapUpDetails details) {
      if (hifzState.isHifzModeActive && isWordMasked) {
        if (hifzState.maskingType == HifzMaskingType.wordByWord) {
          context.read<HifzBloc>().add(ToggleWordReveal(wordKey));
        } else {
          context.read<HifzBloc>().add(ToggleVerseReveal(word.verseKey));
        }
        return;
      }

      if (_activeVerseId == verseId) {
        _removeVerseMenu();
      } else {
        _showVerseMenu(context, details.globalPosition, verseId);
      }
    }

    final wordTextStyle = AppTextStyles.quranText.copyWith(
      fontFamily: customFontFamily,
      fontSize: 42,
      height: 1.2,
    );

    if (isWordMasked) {
      return GestureDetector(
        onTapUp: handleTap,
        onTap: () {},
        onLongPress: () {},
        child: Container(
          margin: EdgeInsets.zero,
          padding: EdgeInsets.zero,
          decoration: BoxDecoration(
            color: mushafTheme.textColor.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            displayText,
            style: wordTextStyle.copyWith(
              color: Colors.transparent,
            ),
          ),
        ),
      );
    }

    if (isBookmarkHighlighted) {
      return AnimatedBuilder(
        animation: _bookmarkPulseAnimation,
        builder: (context, _) => GestureDetector(
          onTapUp: handleTap,
          onTap: () {},
          onLongPress: () {},
          child: Container(
            color: mushafTheme.goldColor.withValues(
              alpha: _bookmarkPulseAnimation.value,
            ),
            child: Text(
              displayText,
              style: wordTextStyle.copyWith(
                color: mushafTheme.goldColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }

    final backgroundColor = (isAudioHighlighted || isMenuHighlighted)
        ? mushafTheme.goldColor.withValues(alpha: 0.2)
        : Colors.transparent;

    Color textColor = mushafTheme.textColor;
    if (isAudioHighlighted) {
      textColor = mushafTheme.goldColor;
    } else if (isPermanentlyBookmarked && word.charTypeName == 'end') {
      textColor = mushafTheme.bookmarkedMarkerColor;
    }

    return GestureDetector(
      onTapUp: handleTap,
      onTap: () {},
      onLongPress: () {},
      child: ColoredBox(
        color: backgroundColor,
        child: Text(
          displayText,
          style: wordTextStyle.copyWith(color: textColor),
        ),
      ),
    );
  }

  Widget _buildWordRow({
    required List<WordModel> lineWords,
    required int? playingVerseId,
    required AudioState audioState,
    required BookmarkState bookmarkState,
    required MushafTheme mushafTheme,
    required HifzState hifzState,
  }) {
    final List<Widget> wordWidgets = [];
    bool fatihahBasmalaAdded = false;

    final isFullVerseMode = hifzState.isHifzModeActive &&
        hifzState.maskingType == HifzMaskingType.fullVerse;

    int i = 0;
    while (i < lineWords.length) {
      final word = lineWords[i];
      final verseId = _verseKeyToIntIdMap[word.verseKey] ?? 0;

      // Al-Fatiha Basmala: replace individual QCF_P001 glyphs with a single unified widget
      if (word.verseKey == '1:1' && word.charTypeName != 'end') {
        if (!fatihahBasmalaAdded) {
          final isBasmalaMasked = hifzState.isHifzModeActive &&
              !hifzState.revealedVerseKeys.contains('1:1');

          if (isBasmalaMasked) {
            wordWidgets.add(
              GestureDetector(
                onTapUp: (_) {
                  context.read<HifzBloc>().add(const ToggleVerseReveal('1:1'));
                },
                onTap: () {},
                onLongPress: () {},
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Container(
                    margin: EdgeInsets.zero,
                    padding: EdgeInsets.zero,
                    decoration: BoxDecoration(
                      color: mushafTheme.textColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '1 2 3',
                      style: TextStyle(
                        fontFamily: 'QCF_BSML',
                        fontSize: 26,
                        color: Colors.transparent,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
            );
            fatihahBasmalaAdded = true;
            i++;
            continue;
          }

          final isMenuHighlighted = _activeVerseId == verseId;
          final isAudioHighlighted = playingVerseId == verseId;
          final isBookmarkHighlighted = _bookmarkHighlightVerseId == verseId;
          final isBookmarked = bookmarkState.isBookmarked(word.verseKey);

          final backgroundColor = (isAudioHighlighted || isMenuHighlighted)
              ? mushafTheme.goldColor.withValues(alpha: 0.2)
              : Colors.transparent;

          Color textColor = mushafTheme.textColor;
          if (isAudioHighlighted) {
            textColor = mushafTheme.goldColor;
          } else if (isBookmarked) {
            textColor = mushafTheme.bookmarkedMarkerColor;
          }

          Widget basmala = ColoredBox(
            color: backgroundColor,
            child: Text(
              '1 2 3',
              style: TextStyle(
                fontFamily: 'QCF_BSML',
                fontSize: 26,
                color: textColor,
                height: 1.0,
              ),
            ),
          );

          if (isBookmarkHighlighted) {
            basmala = AnimatedBuilder(
              animation: _bookmarkPulseAnimation,
              builder: (context, _) => Container(
                color: mushafTheme.goldColor.withValues(
                  alpha: _bookmarkPulseAnimation.value,
                ),
                child: Text(
                  '1 2 3',
                  style: TextStyle(
                    fontFamily: 'QCF_BSML',
                    fontSize: 26,
                    color: mushafTheme.goldColor,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
              ),
            );
          }

          wordWidgets.add(
            GestureDetector(
              onTapUp: (details) {
                if (_activeVerseId == verseId) {
                  _removeVerseMenu();
                } else {
                  _showVerseMenu(
                    context,
                    details.globalPosition,
                    verseId,
                  );
                }
              },
              onTap: () {},
              onLongPress: () {},
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: basmala,
              ),
            ),
          );
          fatihahBasmalaAdded = true;
        }
        i++;
        continue;
      }

      // Check if this word should be masked in full verse mode
      if (isFullVerseMode && word.charTypeName != 'end') {
        final isVerseRevealed =
            hifzState.revealedVerseKeys.contains(word.verseKey);

        if (!isVerseRevealed) {
          final currentVerseKey = word.verseKey;
          final List<WordModel> maskedRun = [];

          while (i < lineWords.length &&
              lineWords[i].verseKey == currentVerseKey &&
              lineWords[i].charTypeName != 'end') {
            maskedRun.add(lineWords[i]);
            i++;
          }

          final pageStr = widget.pageNumber.toString().padLeft(3, '0');
          final customFontFamily = 'QCF_P$pageStr';
          final wordTextStyle = AppTextStyles.quranText.copyWith(
            fontFamily: customFontFamily,
            fontSize: 42,
            height: 1.2,
          );

          wordWidgets.add(
            GestureDetector(
              onTapUp: (_) {
                context
                    .read<HifzBloc>()
                    .add(ToggleVerseReveal(currentVerseKey));
              },
              onTap: () {},
              onLongPress: () {},
              child: Container(
                margin: EdgeInsets.zero,
                padding: EdgeInsets.zero,
                decoration: BoxDecoration(
                  color: mushafTheme.textColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  textDirection: TextDirection.rtl,
                  children: maskedRun.map((w) {
                    final displayText = w.code;
                    return Text(
                      displayText,
                      style: wordTextStyle.copyWith(
                        color: Colors.transparent,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          );
          continue;
        }
      }

      final isMenuHighlighted = _activeVerseId == verseId;
      final isAudioHighlighted = playingVerseId == verseId;
      final isBookmarkHighlighted = _bookmarkHighlightVerseId == verseId;
      final bool isBookmarked = bookmarkState.isBookmarked(word.verseKey);

      wordWidgets.add(
        _buildWordWidget(
          word: word,
          verseId: verseId,
          isMenuHighlighted: isMenuHighlighted,
          isAudioHighlighted: isAudioHighlighted,
          isBookmarkHighlighted: isBookmarkHighlighted,
          isPermanentlyBookmarked: isBookmarked,
          audioState: audioState,
          mushafTheme: mushafTheme,
          hifzState: hifzState,
        ),
      );
      i++;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          textDirection: TextDirection.rtl,
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: wordWidgets,
        ),
      ),
    );
  }


  /// Builds the full loaded page content with all 15 line slots.
  Widget _buildLoadedPage(QuranLoaded state) {
    final lines = state.lines;
    if (lines.isEmpty) return const SizedBox();

    if (_cachedLines != lines) {
      _cachedLines = lines;
      _cachedMaxLineWidth = null;
      _lineMap = {for (final line in lines) line.lineNumber: line};

      _verseKeyToIntIdMap.clear();
      _parsedVerseKeys.clear();

      for (final line in lines) {
        for (final word in line.words) {
          final vk = word.verseKey;
          if (_parsedVerseKeys.containsKey(vk)) continue;
          final parsed = ArabicTextUtils.parseVerseKey(vk);
          if (parsed != null) {
            _parsedVerseKeys[vk] = parsed;
            _verseKeyToIntIdMap[vk] = parsed.surah * 1000 + parsed.ayah;
          }
        }
      }
    }

    String firstVerseKey = '1:1';
    for (final line in lines) {
      if (line.words.isNotEmpty) {
        firstVerseKey = line.words.first.verseKey;
        break;
      }
    }

    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final surahNumber = _parsedVerseKeys[firstVerseKey]?.surah ?? 1;
    final surahName = isEn
        ? "Surah ${QuranMetadata.getSurahNameEnglish(surahNumber)}"
        : QuranMetadata.getSurahNameWithTashkeel(surahNumber);

    final juzNum = QuranMetadata.getJuzNumberByPage(widget.pageNumber);
    final juzName = isEn
        ? AppLocalizations.of(context)!.juzListItem(juzNum.toString())
        : QuranMetadata.getJuzNameWithTashkeel(juzNum);

    return RepaintBoundary(
      key: _pageRepaintKey,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_activeOverlayEntry != null) {
            _removeVerseMenu();
          }
        },
      child: Center(
        child: QuranPageFrameWeb(
          pageNumber: widget.pageNumber,
          onNavigateToPage: widget.onNavigateToPage,
          surahName: surahName,
          juzName: juzName,
          onHeaderTap: () {
            if (_activeOverlayEntry != null) {
              _removeVerseMenu();
            }
          },
          child: BlocBuilder<BookmarkBloc, BookmarkState>(
            buildWhen: (prev, curr) => prev != curr,
            builder: (context, bookmarkState) {
              return BlocBuilder<AudioBloc, AudioState>(
                buildWhen: (prev, curr) {
                  final prevId = prev is AudioPlaying
                      ? prev.currentVerseId
                      : (prev is AudioPaused ? prev.currentVerseId : null);
                  final currId = curr is AudioPlaying
                      ? curr.currentVerseId
                      : (curr is AudioPaused ? curr.currentVerseId : null);
                  final prevOnPage =
                      prevId != null && _verseKeyToIntIdMap.containsValue(prevId);
                  final currOnPage =
                      currId != null && _verseKeyToIntIdMap.containsValue(currId);
                  return prevOnPage || currOnPage;
                },
                builder: (context, audioState) {
                  final mushafTheme = context
                      .watch<SettingsBloc>()
                      .state
                      .effectiveMushafTheme;
                  int? playingVerseId;
                  final activeAudioVerseId = audioState is AudioPlaying
                      ? audioState.currentVerseId
                      : (audioState is AudioPaused ? audioState.currentVerseId : null);
                  if (activeAudioVerseId != null &&
                      _verseKeyToIntIdMap.containsValue(activeAudioVerseId)) {
                    playingVerseId = activeAudioVerseId;
                  }

                  return MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.noScaling),
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final availW = constraints.maxWidth;
                          final availH = constraints.maxHeight;

                          if (_lineMap.isNotEmpty &&
                              (_precomputedCanvasWidth == null ||
                                  (availH - _lastComputedAvailH).abs() > 1.0)) {
                            _lastComputedAvailH = availH;
                            _precomputedCanvasWidth =
                                _computeCanvasWidth(availW, availH);
                          }

                          final canvasW = _precomputedCanvasWidth ?? 490.0;
                          final canvasH = availH * canvasW / availW;
                          return FittedBox(
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                            child: SizedBox(
                              width: canvasW,
                              height: canvasH,
                              child: Padding(
                                padding: EdgeInsets.only(
                                  top: canvasH * 0.027,
                                  bottom: canvasH * 0.032,
                                ),
                                child: Column(
                                  key: _pageColumnKey,
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: List.generate(15, (index) {
                                    final lineNumber = index + 1;
                                    final lineData = _lineMap[lineNumber];

                                    if (lineData == null || lineData.words.isEmpty) {
                                      return _buildEmptyLineWidget(
                                        lineNumber,
                                        mushafTheme,
                                      );
                                    }

                                    return BlocBuilder<HifzBloc, HifzState>(
                                      builder: (context, hifzState) {
                                        return _buildWordRow(
                                          lineWords: lineData.words,
                                          playingVerseId: playingVerseId,
                                          audioState: audioState,
                                          bookmarkState: bookmarkState,
                                          mushafTheme: mushafTheme,
                                          hifzState: hifzState,
                                        );
                                      },
                                    );
                                  }).toList(),
                                ), // Column
                              ), // Padding
                            ), // SizedBox
                          ); // FittedBox
                        },
                      ), // LayoutBuilder
                    ), // Directionality
                  ); // MediaQuery
                },
              );
            },
          ),
        ),
      ),
    ),
  ); // RepaintBoundary
}

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  Widget _buildEmptyFrame() => QuranPageFrameWeb(
    pageNumber: widget.pageNumber,
    onNavigateToPage: widget.onNavigateToPage,
    surahName: '',
    juzName: '',
    child: const SizedBox(),
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocProvider.value(
      value: _quranBloc,
      child: BlocBuilder<QuranBloc, QuranState>(
        buildWhen: (_, current) =>
            current is QuranLoading ||
            current is QuranLoaded ||
            current is QuranError ||
            current is QuranInitial,
        builder: (context, state) {
          final mushafTheme = context
              .watch<SettingsBloc>()
              .state
              .effectiveMushafTheme;
          if (state is QuranLoading || !_isFontLoaded) {
            return QuranPageFrameWeb(
              pageNumber: widget.pageNumber,
              onNavigateToPage: widget.onNavigateToPage,
              surahName: '',
              juzName: '',
              child: Center(
                child: CupertinoActivityIndicator(
                  color: mushafTheme.goldColor,
                  radius: 14,
                ),
              ),
            );
          }
          if (state is QuranError) {
            return QuranPageFrameWeb(
              pageNumber: widget.pageNumber,
              onNavigateToPage: widget.onNavigateToPage,
              surahName: '',
              juzName: '',
              child: Center(
                child: Text(
                  state.message,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
              ),
            );
          }
          if (state is QuranLoaded) return _buildLoadedPage(state);
          return _buildEmptyFrame();
        },
      ),
    );
  }
}
