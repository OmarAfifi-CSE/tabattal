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
import '../../../bloc/quran/quran_event.dart';
import '../../../bloc/quran/quran_page_cache.dart';
import '../../../bloc/quran/quran_state.dart';
import '../../../bloc/audio/audio_bloc.dart';
import '../../../bloc/audio/audio_state.dart';
import '../../../bloc/bookmark/bookmark_bloc.dart';
import '../../../bloc/bookmark/bookmark_state.dart';
import '../../../domain/repositories/quran_repository.dart';
import 'quran_page_frame_mobile.dart';
import '../verse_action_menu.dart';
import '../../../../../core/constants/quran_metadata.dart';
import 'surah_header_widget_mobile.dart';
import '../../../../../core/services/font_service.dart';
import '../../../../settings/bloc/settings_bloc.dart';
import '../../../../../core/theme/mushaf_theme.dart';
import '../../../bloc/hifz/hifz_bloc.dart';
import '../../../bloc/hifz/hifz_event.dart';
import '../../../bloc/hifz/hifz_state.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

// Removed _kBasmalaWidget constant. It is now a method in _QuranPageWidgetState.

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

class QuranPageWidgetMobile extends StatefulWidget {
  final int pageNumber;
  final void Function(int page, {String? verseKey})? onNavigateToPage;
  final String? highlightVerseKey;

  const QuranPageWidgetMobile({
    super.key,
    required this.pageNumber,
    this.onNavigateToPage,
    this.highlightVerseKey,
  });

  static VoidCallback? _activeMenuDismissCallback;

  /// Instantly dismisses any active verse popup menu on drag start without triggering page rebuilds.
  static void dismissActiveMenu() {
    _activeMenuDismissCallback?.call();
  }

  @override
  State<QuranPageWidgetMobile> createState() => _QuranPageWidgetMobileState();
}

class _QuranPageWidgetMobileState extends State<QuranPageWidgetMobile>
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

  // Pre-computed canvas width: measured synchronously via TextPainter once per page.
  // Replaces the old two-pass postFrameCallback approach that caused the
  // compress → expand animation flash and RenderBox layout assertion.
  double? _precomputedCanvasWidth;
  double? _cachedMaxLineWidth;
  double _lastComputedAvailH = 0;

  // Cached data for O(1) lookups and avoiding re-parsing per frame
  List<LineData>? _cachedLines;
  Map<int, LineData> _lineMap = {};
  final Map<String, int> _verseKeyToIntIdMap = {};
  final Map<String, ({int surah, int ayah})> _parsedVerseKeys = {};

  // Word tap detection via Listener (no GestureRecognizer — zero arena overhead).
  // Only fires a tap if the pointer barely moved (< kTouchSlop) from down to up.
  Offset? _wordTapStart;

  bool _isWordTap(Offset upPosition) =>
      _wordTapStart != null &&
      (upPosition - _wordTapStart!).distance < kTouchSlop;

  // Prevents the page-level GestureDetector.onTap from dismissing a menu that
  // was just opened by a word Listener in the same pointer-up event cycle.
  bool _tapHandledByWord = false;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  late final QuranBloc _quranBloc;

  @override
  void initState() {
    super.initState();
    _quranBloc = QuranBloc(repository: context.read<QuranRepository>())
      ..add(LoadPage(widget.pageNumber));
    // Synchronously initialize font state — eliminates first-frame flash for cached fonts.
    final pageStr = widget.pageNumber.toString().padLeft(3, '0');
    _isFontLoaded = FontService.isLoaded('QCF_P$pageStr');
    if (!_isFontLoaded) _loadPageFont();
    _bookmarkPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    // NOTE: Do NOT call .repeat() here — the animation only runs when a verse
    // is actively highlighted. Running it always wastes 60fps raster cycles
    // on every page and keeps the GPU from idling between frames.
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
  void didUpdateWidget(QuranPageWidgetMobile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pageNumber != oldWidget.pageNumber) {
      _quranBloc.add(LoadPage(widget.pageNumber));
      // Synchronously update font state for the new page.
      final pageStr = widget.pageNumber.toString().padLeft(3, '0');
      final loaded = FontService.isLoaded('QCF_P$pageStr');
      if (loaded != _isFontLoaded) setState(() => _isFontLoaded = loaded);
      if (!loaded) _loadPageFont();
    }
    if (widget.highlightVerseKey != oldWidget.highlightVerseKey) {
      if (widget.highlightVerseKey != null) {
        _activateBookmarkHighlight(widget.highlightVerseKey!);
      } else {
        setState(() => _bookmarkHighlightVerseId = null);
        _bookmarkPulseController.stop();
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
    // Start the animation only now that a verse is highlighted.
    if (!_bookmarkPulseController.isAnimating) {
      _bookmarkPulseController.repeat(reverse: true);
    }
    // Auto-clear after 5 s so it doesn't stay permanently highlighted
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _bookmarkHighlightVerseId = null);
        _bookmarkPulseController.stop();
      }
    });
  }

  /// Pre-computes the canvas width by:
  /// 1. Measuring the maximum text line width via [TextPainter].
  /// 2. Computing the minimum canvas width needed so that canvasH (= availH × canvasW / availW)
  ///    is tall enough for ALL 15 Column slots — including SurahHeaders (85.h),
  ///    basmala spacers (45.h), and empty-page padding (45.h per slot).
  /// Taking the maximum of both values ensures no Column overflow on any page.
  double _computeCanvasWidth(double availW, double availH) {
    final fontSize = 32.sp;
    if (_cachedMaxLineWidth == null) {
      // Check the static app-level cache first — zero TextPainter work on revisit.
      _cachedMaxLineWidth = QuranPageCache.getCachedLineWidth(widget.pageNumber);

      if (_cachedMaxLineWidth == null) {
        // Per-word measurement (accurate: mirrors the actual Row widget widths).
        // Single TP + TextStyle objects are reused across all words to minimise
        // object allocation and GC pressure.
        final pageStr = widget.pageNumber.toString().padLeft(3, '0');
        final fontFamily = 'QCF_P$pageStr';
        final style = TextStyle(fontFamily: fontFamily, fontSize: fontSize);
        final tp = TextPainter(textDirection: TextDirection.rtl);
        var maxLW = 0.0;

        for (final lineData in _lineMap.values) {
          if (lineData.words.isEmpty) continue;
          final lineText = lineData.words
              .map((w) => w.codeV1.isNotEmpty ? w.codeV1 : w.textUthmani)
              .where((t) => t.isNotEmpty)
              .join();
          if (lineText.isEmpty) continue;
          tp.text = TextSpan(text: lineText, style: style);
          tp.layout();
          if (tp.width > maxLW) maxLW = tp.width;
        }
        tp.dispose();
        // Add 2px tolerance so canvasW absorbs sub-pixel font advance differences between
        // joined string layout and individual word widgets in Row — zero RenderFlex overflow.
        maxLW = maxLW + 2.0;
        _cachedMaxLineWidth = maxLW;
        // Persist across widget recreations for this page.
        QuranPageCache.cacheLineWidth(widget.pageNumber, maxLW);
      }
    }
    final maxLineWidth = _cachedMaxLineWidth!;

    // Count slot types across the 15 Column children.
    int textLineCount = 0;
    int surahHeaderCount = 0; // header = 85.h
    int spacerCount = 0; // empty spacers = 45.h each

    for (int lineNumber = 1; lineNumber <= 15; lineNumber++) {
      final lineData = _lineMap[lineNumber];
      if (lineData != null && lineData.words.isNotEmpty) {
        textLineCount++;
      } else {
        // This is an empty slot — can be a surah header or a spacer.
        // Surah headers appear at most once (first empty line before new surah).
        final nextSurah = _findNextSurahStartOnPage(lineNumber);
        if (nextSurah != null && lineNumber == nextSurah.ayah1Line - 1) {
          surahHeaderCount++;
        } else {
          spacerCount++;
        }
      }
    }

    // Estimate total children height in canvas (unscaled) units.
    // Text line height: fontSize × 1.5 lineHeight + 4.h vertical padding.
    final textLineH = fontSize * 1.5 + 4.0.h;
    final surahHeaderH = 85.0.h;
    // Pages 1 & 2 trailing slots are zero-height (SizedBox(height:0)).
    final spacerH =
        (widget.pageNumber == 1 || widget.pageNumber == 2) ? 0.0 : 45.0.h;
    final totalChildrenH =
        textLineCount * textLineH +
        surahHeaderCount * surahHeaderH +
        spacerCount * spacerH;

    // The Column lives inside Padding(top: canvasH*0.027, bottom: canvasH*0.032),
    // reducing the available height by 5.9%. Account for this so the Column
    // never overflows and has proper breathing room between rows.
    const paddingFactor = 1.0 / (1.0 - 0.027 - 0.032); // ≈ 1.063
    final minCanvasWForHeight =
        availW > 0 && availH > 0
            ? totalChildrenH * paddingFactor * availW / availH
            : 0.0;

    final textMeasuredW = maxLineWidth > 0 ? maxLineWidth : 490.w;
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
      return Rect.fromCenter(center: fallbackPosition, width: 0.w, height: 0.h);
    }

    final renderBox =
        _pageColumnKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return Rect.fromCenter(center: fallbackPosition, width: 0.w, height: 0.h);
    }

    // For pages 1 & 2, the Column children have non-uniform heights
    // (surah header >> basmala > text lines >> zero-height spacers), so the
    // uniform height/15 estimate gives completely wrong screen positions.
    // Walk the RenderFlex render tree to get exact canvas-space child offsets,
    // then convert to screen space via localToGlobal (handles FittedBox scaling).
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

  void _showVerseMenu(BuildContext context, Offset tapPosition, int verseId) {
    // Signal to the page-level GestureDetector that this tap was handled by a
    // word — prevents onTap from immediately dismissing the menu we're opening.
    _tapHandledByWord = true;

    if (_activeOverlayEntry != null) _removeVerseMenu();

    setState(() => _activeVerseId = verseId);

    QuranPageWidgetMobile._activeMenuDismissCallback = () => _removeVerseMenu();

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
        child: VerseActionMenuMobile(
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
    if (QuranPageWidgetMobile._activeMenuDismissCallback != null) {
      QuranPageWidgetMobile._activeMenuDismissCallback = null;
    }
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
      // SurahHeaderWidgetMobile uses FittedBox(fitWidth) which NEEDS tight width
      // constraints to scale properly. Center converts tight→loose constraints,
      // so we omit Center and let the outer Column's CrossAxisAlignment.stretch
      // provide the tight width directly.
      final header = SurahHeaderWidgetMobile(surahNumber: surahId);
      final basmala = Center(
        child: Text(
          '1 2 3',
          style: TextStyle(
            fontFamily: 'QCF_BSML',
            fontSize: 26.sp,
            color: mushafTheme.textColor,
            height: 1.0.h,
          ),
        ),
      );

      // Surah 9 (At-Tawbah) has no Basmala
      if (surahId == 9 || surahId == 1) {
        return lineNumber == ayah1Line - 1 ? header : SizedBox(height: 45.h);
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
                  // stretch so header gets tight width and FittedBox scales correctly
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [header, basmala],
                ),
              )
            : basmala;
      } else if (lineNumber == ayah1Line - 2 && !mustSquashBothOnLineMinus1) {
        return header;
      }
      return SizedBox(height: 45.h);
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
        final header = SurahHeaderWidgetMobile(surahNumber: upcomingSurahId);
        final basmala = Center(
          child: Text(
            '1 2 3',
            style: TextStyle(
              fontFamily: 'QCF_BSML',
              fontSize: 26.sp,
              color: mushafTheme.textColor,
              height: 1.0.h,
            ),
          ),
        );

        if (emptyLinesBefore == 0) return header;
        if (emptyLinesBefore == 1 && upcomingSurahId != 9) return basmala;
      }
    }

    return SizedBox(height: 45.h);
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
    final displayText = word.codeV1.isNotEmpty ? word.codeV1 : word.textUthmani;
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

    void handleTap(Offset globalPosition) {
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
        _showVerseMenu(context, globalPosition, verseId);
      }
    }

    final wordTextStyle = AppTextStyles.quranText.copyWith(
      fontFamily: customFontFamily,
      fontSize: 32.sp,
      height: 1.5.h,
    );

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
          margin: EdgeInsets.zero,
          padding: EdgeInsets.zero,
          decoration: BoxDecoration(
            color: mushafTheme.textColor.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(4.r),
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
        builder: (context, _) => Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) => _wordTapStart = e.position,
          onPointerUp: (e) {
            if (_isWordTap(e.position)) handleTap(e.position);
            _wordTapStart = null;
          },
          onPointerCancel: (_) => _wordTapStart = null,
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

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) => _wordTapStart = e.position,
      onPointerUp: (e) {
        if (_isWordTap(e.position)) handleTap(e.position);
        _wordTapStart = null;
      },
      onPointerCancel: (_) => _wordTapStart = null,
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
              Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (e) => _wordTapStart = e.position,
                onPointerUp: (e) {
                  if (_isWordTap(e.position)) {
                    context.read<HifzBloc>().add(const ToggleVerseReveal('1:1'));
                  }
                  _wordTapStart = null;
                },
                onPointerCancel: (_) => _wordTapStart = null,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.0.w),
                  child: Container(
                    margin: EdgeInsets.zero,
                    padding: EdgeInsets.zero,
                    decoration: BoxDecoration(
                      color: mushafTheme.textColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Text(
                      '1 2 3',
                      style: TextStyle(
                        fontFamily: 'QCF_BSML',
                        fontSize: 26.sp,
                        color: Colors.transparent,
                        height: 1.0.h,
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

          Widget basmala = AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            color: backgroundColor,
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              style: TextStyle(
                fontFamily: 'QCF_BSML',
                fontSize: 26.sp,
                color: textColor,
                height: 1.0.h,
              ),
              child: const Text('1 2 3'),
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
                    fontSize: 26.sp,
                    color: mushafTheme.goldColor,
                    fontWeight: FontWeight.bold,
                    height: 1.0.h,
                  ),
                ),
              ),
            );
          }

          wordWidgets.add(
            Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (e) => _wordTapStart = e.position,
              onPointerUp: (e) {
                if (_isWordTap(e.position)) {
                  if (_activeVerseId == verseId) {
                    _removeVerseMenu();
                  } else {
                    _showVerseMenu(context, e.position, verseId);
                  }
                }
                _wordTapStart = null;
              },
              onPointerCancel: (_) => _wordTapStart = null,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.0.w),
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
            fontSize: 32.sp,
            height: 1.5.h,
          );

          wordWidgets.add(
            Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (e) => _wordTapStart = e.position,
              onPointerUp: (e) {
                if (_isWordTap(e.position)) {
                  context
                      .read<HifzBloc>()
                      .add(ToggleVerseReveal(currentVerseKey));
                }
                _wordTapStart = null;
              },
              onPointerCancel: (_) => _wordTapStart = null,
              child: Container(
                margin: EdgeInsets.zero,
                padding: EdgeInsets.zero,
                decoration: BoxDecoration(
                  color: mushafTheme.textColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  textDirection: TextDirection.rtl,
                  children: maskedRun.map((w) {
                    final displayText =
                        w.codeV1.isNotEmpty ? w.codeV1 : w.textUthmani;
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
      padding: EdgeInsets.symmetric(vertical: 2.0.h),
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
          // If a word Listener already handled this tap (e.g. opened the menu),
          // skip the dismiss-on-tap logic to avoid immediately closing it.
          if (_tapHandledByWord) {
            _tapHandledByWord = false;
            return;
          }
          if (_activeOverlayEntry != null) {
            _removeVerseMenu();
          }
        },
        child: QuranPageFrameMobile(
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
                buildWhen: (prev, curr) => prev != curr,
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

                              // Compute (or recompute) canvas width when:
                              // – first build with data (_precomputedCanvasWidth == null)
                              // – availH changed by more than 1px (audio bar appear/disappear)
                              if (_lineMap.isNotEmpty &&
                                  (_precomputedCanvasWidth == null ||
                                      (availH - _lastComputedAvailH).abs() > 1.0)) {
                                _lastComputedAvailH = availH;
                                _precomputedCanvasWidth =
                                    _computeCanvasWidth(availW, availH);
                              }

                              final canvasW = _precomputedCanvasWidth ?? 490.w;
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
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  Widget _buildEmptyFrame() => QuranPageFrameMobile(
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

          // Optimistically serve cached data on QuranInitial to avoid any
          // single-frame spinner while the event loop processes LoadPage.
          final QuranState displayState = state is QuranInitial
              ? (QuranPageCache.get(widget.pageNumber) ?? state)
              : state;

          if (displayState is QuranLoading || !_isFontLoaded) {
            return QuranPageFrameMobile(
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
          if (displayState is QuranError) {
            return QuranPageFrameMobile(
              pageNumber: widget.pageNumber,
              onNavigateToPage: widget.onNavigateToPage,
              surahName: '',
              juzName: '',
              child: Center(
                child: Text(
                  displayState.message,
                  style: TextStyle(color: Colors.red, fontSize: 14.sp),
                ),
              ),
            );
          }
          if (displayState is QuranLoaded) return _buildLoadedPage(displayState);
          return _buildEmptyFrame();
        },
      ),
    );
  }
}
