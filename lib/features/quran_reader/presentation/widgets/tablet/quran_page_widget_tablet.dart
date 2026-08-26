import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../l10n/app_localizations.dart';

import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/utils/arabic_text_utils.dart';
import '../../../data/models/verse_model.dart';
import '../../../bloc/quran/quran_bloc.dart';
import '../../../bloc/quran/quran_page_cache.dart';
import '../../../bloc/quran/quran_state.dart';
import '../../../bloc/audio/audio_bloc.dart';
import '../../../bloc/audio/audio_state.dart';
import '../../../bloc/bookmark/bookmark_bloc.dart';
import '../../../bloc/bookmark/bookmark_state.dart';
import '../../../bloc/hifz/hifz_bloc.dart';
import '../../../bloc/hifz/hifz_event.dart';
import '../../../bloc/hifz/hifz_state.dart';
import '../../../domain/repositories/quran_repository.dart';
import 'quran_page_frame_tablet.dart';
import 'verse_action_menu_tablet.dart';
import '../../../../../core/constants/quran_metadata.dart';
import 'surah_header_widget_tablet.dart';
import '../../../../settings/bloc/settings_bloc.dart';
import '../../../../../core/theme/mushaf_theme.dart';

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

class QuranPageWidgetTablet extends StatefulWidget {
  final int pageNumber;
  final void Function(int page, {String? verseKey})? onNavigateToPage;
  final String? highlightVerseKey;
  final int highlightToken;

  const QuranPageWidgetTablet({
    super.key,
    required this.pageNumber,
    this.onNavigateToPage,
    this.highlightVerseKey,
    this.highlightToken = 0,
  });

  static VoidCallback? _activeMenuDismissCallback;

  static void dismissActiveMenu() {
    _activeMenuDismissCallback?.call();
  }

  @override
  State<QuranPageWidgetTablet> createState() => _QuranPageWidgetTabletState();
}

class _QuranPageWidgetTabletState extends State<QuranPageWidgetTablet>
    with SingleTickerProviderStateMixin {
  int? _activeVerseId;
  OverlayEntry? _activeOverlayEntry;
  final GlobalKey _pageColumnKey = GlobalKey();

  late final AnimationController _bookmarkFadeController;
  late final Animation<double> _bookmarkFadeAnimation;
  int? _bookmarkHighlightVerseId;
  int _lastConsumedToken = 0;
  final GlobalKey _pageRepaintKey = GlobalKey();

  // Prevents the page-level GestureDetector.onTap from dismissing a menu that
  // was just opened by a word in the same pointer-up event cycle.
  bool _tapHandledByWord = false;

  static const double _kCanvasWidth = 480.0;
  static const double _kCanvasFontSize = 32.0;

  // Cached data for O(1) lookups and avoiding re-parsing per frame
  List<LineData>? _cachedLines;
  Map<int, LineData> _lineMap = {};
  final Map<String, int> _verseKeyToIntIdMap = {};
  final Map<String, ({int surah, int ayah})> _parsedVerseKeys = {};

  // Word tap detection via Listener (no GestureRecognizer — zero arena overhead).
  Offset? _wordTapStart;

  bool _isWordTap(Offset upPosition) =>
      _wordTapStart != null &&
      (upPosition - _wordTapStart!).distance < kTouchSlop;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _bookmarkFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _bookmarkFadeAnimation = Tween<double>(begin: 0.04, end: 0.24).animate(
      CurvedAnimation(
        parent: _bookmarkFadeController,
        curve: Curves.easeInOut,
      ),
    );
    final cached = QuranPageCache.get(widget.pageNumber);
    if (cached == null) {
      _loadPageDataFallback();
    }
    if (widget.highlightVerseKey != null && widget.highlightToken > 0) {
      _lastConsumedToken = widget.highlightToken;
      _activateBookmarkHighlight(widget.highlightVerseKey!);
    }
  }

  Future<void> _loadPageDataFallback() async {
    try {
      final result = await context.read<QuranRepository>().getLinesByPage(
        widget.pageNumber,
      );
      result.fold((_) {}, (lines) {
        final loaded = QuranLoaded(
          lines: lines,
          currentPage: widget.pageNumber,
        );
        QuranPageCache.put(widget.pageNumber, loaded);
        if (mounted) setState(() {});
      });
    } catch (_) {}
  }

  @override
  void didUpdateWidget(QuranPageWidgetTablet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pageNumber != oldWidget.pageNumber) {
      final cached = QuranPageCache.get(widget.pageNumber);
      if (cached == null) _loadPageDataFallback();
    }
    if (widget.highlightVerseKey != null &&
        widget.highlightToken > 0 &&
        widget.highlightToken != _lastConsumedToken) {
      _lastConsumedToken = widget.highlightToken;
      _activateBookmarkHighlight(widget.highlightVerseKey!);
    } else if (widget.highlightVerseKey == null &&
        oldWidget.highlightVerseKey != null) {
      _bookmarkFadeController.stop();
      setState(() => _bookmarkHighlightVerseId = null);
    }
  }

  @override
  void dispose() {
    _bookmarkFadeController.dispose();
    _activeOverlayEntry?.remove();
    _activeOverlayEntry?.dispose();
    _activeOverlayEntry = null;
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _activateBookmarkHighlight(String verseKey) {
    final parsed = ArabicTextUtils.parseVerseKey(verseKey);
    if (parsed == null) return;
    final verseId = parsed.surah * 1000 + parsed.ayah;
    setState(() => _bookmarkHighlightVerseId = verseId);
    if (!_bookmarkFadeController.isAnimating) {
      _bookmarkFadeController.repeat(reverse: true);
    }
    // Auto-clear after 4 seconds so it doesn't stay permanently highlighted
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _bookmarkHighlightVerseId == verseId) {
        _bookmarkFadeController.stop();
        setState(() => _bookmarkHighlightVerseId = null);
      }
    });
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
    _tapHandledByWord = true;
    if (_activeOverlayEntry != null) _removeVerseMenu();

    QuranPageWidgetTablet._activeMenuDismissCallback = () => _removeVerseMenu();
    setState(() => _activeVerseId = verseId);

    final verseKey = ArabicTextUtils.verseIdToVerseKey(verseId);
    final verseRect = _calculateVerseScreenRect(verseKey, tapPosition);

    final pageLines = QuranPageCache.get(widget.pageNumber)?.lines ?? const [];
    final verseWords = pageLines
        .expand((line) => line.words)
        .where((word) => word.verseKey == verseKey)
        .toList();
    final verseText = verseWords
        .where((w) => w.charTypeName == 'word')
        .map((w) => w.textUthmani)
        .join(' ');

    // A model carrying the verse details, text, and words for the menu.
    final partialVerseForMenu = VerseModel(
      id: verseId,
      verseNumber: verseId % 1000,
      verseKey: verseKey,
      textUthmani: verseText,
      words: verseWords,
      juzNumber: 1,
    );

    final blocContext = _pageColumnKey.currentContext;
    if (blocContext == null) return;

    final quranBloc = blocContext.read<QuranBloc>();
    final audioBloc = blocContext.read<AudioBloc>();
    final bookmarkBloc = blocContext.read<BookmarkBloc>();
    final hifzBloc = blocContext.read<HifzBloc>();

    _activeOverlayEntry = OverlayEntry(
      builder: (overlayContext) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: quranBloc),
          BlocProvider.value(value: audioBloc),
          BlocProvider.value(value: bookmarkBloc),
          BlocProvider.value(value: hifzBloc),
        ],
        child: VerseActionMenuTablet(
          position: tapPosition,
          verseRect: verseRect,
          verse: partialVerseForMenu,
          pageRepaintKey: _pageRepaintKey,
          pageNumber: widget.pageNumber,
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
    QuranPageWidgetTablet._activeMenuDismissCallback = null;
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
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: SurahHeaderWidgetTablet(surahNumber: surahId),
      );
      final basmala = Center(
        child: Text(
          '1 2 3',
          style: TextStyle(
            fontFamily: 'QCF_BSML',
            fontSize: 26.0,
            color: mushafTheme.textColor,
            height: 1.0,
          ),
        ),
      );

      // Surah 9 (At-Tawbah) has no Basmala
      if (surahId == 9 || surahId == 1) {
        return lineNumber == ayah1Line - 1
            ? header
            : const SizedBox(height: 45.0);
      }

      // Determine whether the header should appear on this line or one earlier
      final prevPrevLineData = _lineMap[ayah1Line - 2];
      final bool mustSquashBothOnLineMinus1 =
          ayah1Line > 2 &&
              prevPrevLineData != null &&
              prevPrevLineData.words.isNotEmpty ||
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
      return const SizedBox(height: 45.0);
    }

    // ── Case B: Trailing empty lines at end of page ────────────────────────
    if (widget.pageNumber == 1 || widget.pageNumber == 2) {
      return const SizedBox(height: 0);
    }

    final previousSurahId = _findPreviousSurahId(lineNumber);
    if (previousSurahId != null) {
      final upcomingSurahId = previousSurahId + 1;
      if (upcomingSurahId <= 114) {
        final emptyLinesBefore = _countEmptyLinesBefore(lineNumber);
        final header = Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: SurahHeaderWidgetTablet(surahNumber: upcomingSurahId),
        );
        final basmala = Center(
          child: Text(
            '1 2 3',
            style: TextStyle(
              fontFamily: 'QCF_BSML',
              fontSize: 26.0,
              color: mushafTheme.textColor,
              height: 1.0,
            ),
          ),
        );

        if (emptyLinesBefore == 0) return header;
        if (emptyLinesBefore == 1 && upcomingSurahId != 9) return basmala;
      }
    }

    return const SizedBox(height: 45.0);
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
    required TextStyle wordTextStyle,
    required TextStyle transparentWordStyle,
    required BoxDecoration maskDecoration,
  }) {
    final displayText = word.code;
    final wordKey = word.wordKey;

    bool isWordMasked = false;
    if (hifzState.isHifzModeActive && word.charTypeName != 'end') {
      final isVerseRevealed = hifzState.revealedVerseKeys.contains(word.verseKey);
      final isWordRevealed = hifzState.revealedWordKeys.contains(wordKey);

      if (!isVerseRevealed && !isWordRevealed) {
        if (hifzState.maskingType == HifzMaskingType.fullVerse) {
          isWordMasked = true;
        } else if (hifzState.maskingType == HifzMaskingType.wordByWord) {
          isWordMasked = true;
        }
      }
    }

    void handleTap(Offset globalPosition) {
      if (hifzState.isHifzModeActive && isWordMasked) {
        if (hifzState.maskingType == HifzMaskingType.wordByWord) {
          context.read<HifzBloc>().add(ToggleWordReveal(wordKey));
        } else {
          context.read<HifzBloc>().add(ToggleVerseReveal(word.verseKey));
        }
        return;
      }

      _tapHandledByWord = true;
      if (_activeVerseId == verseId) {
        _removeVerseMenu();
      } else {
        _showVerseMenu(context, globalPosition, verseId);
      }
    }

    final wordMargin = (hifzState.isHifzModeActive &&
            hifzState.maskingType != HifzMaskingType.fullVerse)
        ? EdgeInsets.symmetric(horizontal: 2.0.w)
        : EdgeInsets.zero;

    if (isWordMasked) {
      return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (e) => _wordTapStart = e.position,
        onPointerUp: (e) {
          if (_isWordTap(e.position)) handleTap(e.position);
          _wordTapStart = null;
        },
        onPointerCancel: (_) => _wordTapStart = null,
        child: Container(
          margin: wordMargin,
          decoration: maskDecoration,
          child: Text(
            displayText,
            style: transparentWordStyle,
          ),
        ),
      );
    }

    Color textColor = mushafTheme.textColor;
    if (isAudioHighlighted) {
      textColor = mushafTheme.goldColor;
    } else if (isPermanentlyBookmarked && word.charTypeName == 'end') {
      textColor = mushafTheme.bookmarkedMarkerColor;
    }

    if (isBookmarkHighlighted) {
      return AnimatedBuilder(
        animation: _bookmarkFadeAnimation,
        builder: (context, _) => Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) => _wordTapStart = e.position,
          onPointerUp: (e) {
            if (_isWordTap(e.position)) handleTap(e.position);
            _wordTapStart = null;
          },
          onPointerCancel: (_) => _wordTapStart = null,
          child: Container(
            margin: wordMargin,
            color: mushafTheme.goldColor.withValues(
              alpha: _bookmarkFadeAnimation.value,
            ),
            child: Text(
              displayText,
              style: wordTextStyle.copyWith(color: textColor),
            ),
          ),
        ),
      );
    }

    final backgroundColor = (isAudioHighlighted || isMenuHighlighted)
        ? mushafTheme.goldColor.withValues(alpha: 0.2)
        : Colors.transparent;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) => _wordTapStart = e.position,
      onPointerUp: (e) {
        if (_isWordTap(e.position)) handleTap(e.position);
        _wordTapStart = null;
      },
      onPointerCancel: (_) => _wordTapStart = null,
      child: Container(
        margin: wordMargin,
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

    final pageStr = widget.pageNumber.toString().padLeft(3, '0');
    final customFontFamily = 'QCF_P$pageStr';
    final wordTextStyle = AppTextStyles.quranText.copyWith(
      fontFamily: customFontFamily,
      fontSize: _kCanvasFontSize,
      height: 1.45,
    );
    final transparentWordStyle = wordTextStyle.copyWith(
      color: Colors.transparent,
    );
    final maskDecoration = BoxDecoration(
      color: mushafTheme.textColor.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(4.0),
    );

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
                    decoration: maskDecoration,
                    child: const Text(
                      '1 2 3',
                      style: TextStyle(
                        fontFamily: 'QCF_BSML',
                        fontSize: 26.0,
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

          Color textColor = mushafTheme.textColor;
          if (isAudioHighlighted) {
            textColor = mushafTheme.goldColor;
          } else if (isBookmarked) {
            textColor = mushafTheme.bookmarkedMarkerColor;
          }

          Widget basmala;
          if (isBookmarkHighlighted) {
            basmala = AnimatedBuilder(
              animation: _bookmarkFadeAnimation,
              builder: (context, _) => ColoredBox(
                color: mushafTheme.goldColor.withValues(
                  alpha: _bookmarkFadeAnimation.value,
                ),
                child: Text(
                  '1 2 3',
                  style: TextStyle(
                    fontFamily: 'QCF_BSML',
                    fontSize: 26.0,
                    color: textColor,
                    height: 1.0,
                  ),
                ),
              ),
            );
          } else {
            final backgroundColor = (isAudioHighlighted || isMenuHighlighted)
                ? mushafTheme.goldColor.withValues(alpha: 0.2)
                : Colors.transparent;

            basmala = ColoredBox(
              color: backgroundColor,
              child: Text(
                '1 2 3',
                style: TextStyle(
                  fontFamily: 'QCF_BSML',
                  fontSize: 26.0,
                  color: textColor,
                  height: 1.0,
                ),
              ),
            );
          }

          wordWidgets.add(
            GestureDetector(
              onTapUp: (details) {
                _tapHandledByWord = true;
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

          wordWidgets.add(
            Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (e) => _wordTapStart = e.position,
              onPointerUp: (e) {
                if (_isWordTap(e.position)) {
                  _tapHandledByWord = true;
                  context.read<HifzBloc>().add(
                        ToggleVerseReveal(currentVerseKey),
                      );
                }
                _wordTapStart = null;
              },
              onPointerCancel: (_) => _wordTapStart = null,
              child: Container(
                margin: EdgeInsets.zero,
                padding: EdgeInsets.zero,
                decoration: maskDecoration,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  textDirection: TextDirection.rtl,
                  children: maskedRun.map((w) {
                    final displayText = w.code;
                    return Text(
                      displayText,
                      style: transparentWordStyle,
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
          wordTextStyle: wordTextStyle,
          transparentWordStyle: transparentWordStyle,
          maskDecoration: maskDecoration,
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
  Widget _buildLoadedPage(QuranLoaded state, MushafTheme mushafTheme) {
    final lines = state.lines;
    if (lines.isEmpty) return const SizedBox();

    if (_cachedLines != lines) {
      _cachedLines = lines;
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
          if (_tapHandledByWord) {
            _tapHandledByWord = false;
            return;
          }
          if (_activeOverlayEntry != null) {
            _removeVerseMenu();
          }
        },
        child: QuranPageFrameTablet(
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
            return BlocBuilder<HifzBloc, HifzState>(
              buildWhen: (prev, curr) {
                if (prev.isHifzModeActive != curr.isHifzModeActive) return true;
                if (!curr.isHifzModeActive && !prev.isHifzModeActive) return false;
                if (prev.maskingType != curr.maskingType) return true;
                if (prev.revealedVerseKeys != curr.revealedVerseKeys) {
                  final diff = prev.revealedVerseKeys
                      .difference(curr.revealedVerseKeys)
                      .union(curr.revealedVerseKeys.difference(prev.revealedVerseKeys));
                  if (diff.any((k) => _parsedVerseKeys.containsKey(k))) return true;
                }
                if (prev.revealedWordKeys != curr.revealedWordKeys) {
                  final diff = prev.revealedWordKeys
                      .difference(curr.revealedWordKeys)
                      .union(curr.revealedWordKeys.difference(prev.revealedWordKeys));
                  if (diff.any((k) {
                    final colonIdx = k.indexOf(':');
                    final vKey = colonIdx != -1 && k.indexOf(':', colonIdx + 1) != -1
                        ? k.substring(0, k.lastIndexOf(':'))
                        : k;
                    return _parsedVerseKeys.containsKey(vKey);
                  })) {
                    return true;
                  }
                }
                return false;
              },
              builder: (context, hifzState) {
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

                            const canvasW = _kCanvasWidth;
                            final canvasH = availW > 0
                                ? (availH * canvasW / availW)
                                : 800.0;

                            return FittedBox(
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                              child: SizedBox(
                                width: canvasW,
                                height: canvasH,
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    top: canvasH * 0.042,
                                    bottom: canvasH * 0.048,
                                  ),
                                  child: Column(
                                    key: _pageColumnKey,
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: List.generate(15, (index) {
                                      final lineNumber = index + 1;
                                      final lineData = _lineMap[lineNumber];

                                      if (lineData == null ||
                                          lineData.words.isEmpty) {
                                        return _buildEmptyLineWidget(
                                          lineNumber,
                                          mushafTheme,
                                        );
                                      }

                                      return _buildWordRow(
                                        lineWords: lineData.words,
                                        playingVerseId: playingVerseId,
                                        audioState: audioState,
                                        bookmarkState: bookmarkState,
                                        mushafTheme: mushafTheme,
                                        hifzState: hifzState,
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
            );
          },
        ),
      ), // Center
    ),
  ); // RepaintBoundary
}

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final mushafTheme = context
        .watch<SettingsBloc>()
        .state
        .effectiveMushafTheme;

    final displayState = QuranPageCache.get(widget.pageNumber);

    if (displayState == null) {
      return QuranPageFrameTablet(
        pageNumber: widget.pageNumber,
        onNavigateToPage: widget.onNavigateToPage,
        surahName: '',
        juzName: '',
        child: Center(
          child: CupertinoActivityIndicator(
            color: mushafTheme.goldColor,
            radius: 14.r,
          ),
        ),
      );
    }

    return _buildLoadedPage(displayState, mushafTheme);
  }
}
