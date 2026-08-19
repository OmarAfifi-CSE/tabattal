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
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  int? _activeVerseId;
  OverlayEntry? _activeOverlayEntry;
  final GlobalKey _pageColumnKey = GlobalKey();
  bool _isFontLoaded = false;

  int? _bookmarkHighlightVerseId;
  final GlobalKey _pageRepaintKey = GlobalKey();

  // Prevents the page-level GestureDetector.onTap from dismissing a menu that
  // was just opened by a word in the same pointer-up event cycle.
  bool _tapHandledByWord = false;

  // Pre-computed canvas width: measured synchronously via TextPainter once per page.
  // Replaces the old two-pass postFrameCallback approach that caused the
  // compress → expand animation flash and RenderBox layout assertion.
  double? _precomputedCanvasWidth;
  double _lastComputedAvailH = 0;

  // Cached data for O(1) lookups and avoiding re-parsing per frame
  List<LineData>? _cachedLines;
  Map<int, LineData> _lineMap = {};
  final Map<String, int> _verseKeyToIntIdMap = {};
  final Map<String, ({int surah, int ayah})> _parsedVerseKeys = {};

  // Object pool for TapGestureRecognizers to eliminate ~225 allocations per frame
  // and completely eliminate Dart VM Generational GC pauses during scrolling.
  final Map<String, TapGestureRecognizer> _wordGestureRecognizers = {};

  TapGestureRecognizer _getWordRecognizer({
    required String key,
    VoidCallback? onTap,
    void Function(TapDownDetails)? onTapDown,
  }) {
    var recognizer = _wordGestureRecognizers[key];
    if (recognizer == null) {
      recognizer = TapGestureRecognizer();
      _wordGestureRecognizers[key] = recognizer;
    }
    recognizer.onTap = onTap;
    recognizer.onTapDown = onTapDown;
    return recognizer;
  }

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
    final fontName = 'QCF_P$pageStr';
    _isFontLoaded = FontService.isLoaded(fontName);
    FontService.loadedFontsNotifier.addListener(_onFontsLoaded);
    if (!_isFontLoaded) _loadPageFont();
    if (widget.highlightVerseKey != null) {
      _activateBookmarkHighlight(widget.highlightVerseKey!);
    }
  }

  void _onFontsLoaded() {
    if (!mounted || _isFontLoaded) return;
    final pageStr = widget.pageNumber.toString().padLeft(3, '0');
    final fontName = 'QCF_P$pageStr';
    if (FontService.isLoaded(fontName)) {
      setState(() => _isFontLoaded = true);
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
      }
    }
  }

  @override
  void dispose() {
    FontService.loadedFontsNotifier.removeListener(_onFontsLoaded);
    for (final recognizer in _wordGestureRecognizers.values) {
      recognizer.dispose();
    }
    _wordGestureRecognizers.clear();
    _quranBloc.close();
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
      if (mounted) {
        setState(() => _bookmarkHighlightVerseId = null);
      }
    });
  }

  int _textLineCount = 0;
  int _surahHeaderCount = 0;
  int _spacerCount = 0;

  void _calculateLineTypeCounts() {
    _textLineCount = 0;
    _surahHeaderCount = 0;
    _spacerCount = 0;
    for (int lineNumber = 1; lineNumber <= 15; lineNumber++) {
      final lineData = _lineMap[lineNumber];
      if (lineData != null && lineData.words.isNotEmpty) {
        _textLineCount++;
      } else {
        final nextSurah = _findNextSurahStartOnPage(lineNumber);
        if (nextSurah != null && lineNumber == nextSurah.ayah1Line - 1) {
          _surahHeaderCount++;
        } else {
          _spacerCount++;
        }
      }
    }
  }

  /// Pre-computes the canvas width using fast O(1) arithmetic.
  /// Eliminates TextPainter.layout and loops from the frame layout pass.
  double _computeCanvasWidth(double availW, double availH) {
    final fontSize = 32.sp;
    final maxLineWidth = QuranPageCache.getCachedLineWidth(widget.pageNumber) ?? 480.0.w;

    final textLineH = fontSize * 1.5 + 4.0.h;
    final surahHeaderH = 85.0.h;
    final spacerH =
        (widget.pageNumber == 1 || widget.pageNumber == 2) ? 0.0 : 45.0.h;
    final totalChildrenH =
        _textLineCount * textLineH +
        _surahHeaderCount * surahHeaderH +
        _spacerCount * spacerH;

    const paddingFactor = 1.0 / (1.0 - 0.027 - 0.032); // ≈ 1.063
    final minCanvasWForHeight =
        availW > 0 && availH > 0
            ? totalChildrenH * paddingFactor * availW / availH
            : 0.0;

    return maxLineWidth > minCanvasWForHeight
        ? maxLineWidth
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

  Widget _buildWordRow({
    required List<WordModel> lineWords,
    required int? playingVerseId,
    required AudioState audioState,
    required BookmarkState bookmarkState,
    required MushafTheme mushafTheme,
    required HifzState hifzState,
    required TextStyle baseWordTextStyle,
  }) {
    final List<InlineSpan> spans = [];
    bool fatihahBasmalaAdded = false;

    int i = 0;
    while (i < lineWords.length) {
      final word = lineWords[i];
      final verseId = _verseKeyToIntIdMap[word.verseKey] ?? 0;

      // Al-Fatiha Basmala: replace individual QCF_P001 glyphs with a single unified span
      if (word.verseKey == '1:1' && word.charTypeName != 'end') {
        if (!fatihahBasmalaAdded) {
          final isBasmalaMasked = hifzState.isHifzModeActive &&
              !hifzState.revealedVerseKeys.contains('1:1');

          if (isBasmalaMasked) {
            spans.add(
              TextSpan(
                text: '1 2 3',
                recognizer: _getWordRecognizer(
                  key: 'fatiha_basmala_masked',
                  onTap: () {
                    context.read<HifzBloc>().add(const ToggleVerseReveal('1:1'));
                  },
                ),
                style: TextStyle(
                  fontFamily: 'QCF_BSML',
                  fontSize: 26.sp,
                  color: Colors.transparent,
                  backgroundColor: mushafTheme.textColor.withValues(alpha: 0.18),
                  height: 1.0.h,
                ),
              ),
            );
          } else {
            final isMenuHighlighted = _activeVerseId == verseId;
            final isAudioHighlighted = playingVerseId == verseId;
            final isBookmarked = bookmarkState.isBookmarked(word.verseKey);

            Color textColor = mushafTheme.textColor;
            if (isAudioHighlighted) {
              textColor = mushafTheme.goldColor;
            } else if (isBookmarked) {
              textColor = mushafTheme.bookmarkedMarkerColor;
            }

            final Color? bgColor = (isAudioHighlighted || isMenuHighlighted)
                ? mushafTheme.goldColor.withValues(alpha: 0.2)
                : null;

            spans.add(
              TextSpan(
                text: '1 2 3',
                recognizer: _getWordRecognizer(
                  key: 'fatiha_basmala_revealed',
                  onTapDown: (details) {
                    if (_activeVerseId == verseId) {
                      _removeVerseMenu();
                    } else {
                      _showVerseMenu(context, details.globalPosition, verseId);
                    }
                  },
                ),
                style: TextStyle(
                  fontFamily: 'QCF_BSML',
                  fontSize: 26.sp,
                  color: textColor,
                  backgroundColor: bgColor,
                  height: 1.0.h,
                ),
              ),
            );
          }
          fatihahBasmalaAdded = true;
        }
        i++;
        continue;
      }

      final wordKey = '${word.verseKey}:${word.id}';
      bool isWordMasked = false;
      if (hifzState.isHifzModeActive && word.charTypeName != 'end') {
        final isVerseRevealed =
            hifzState.revealedVerseKeys.contains(word.verseKey);
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

      final wordRecognizer = _getWordRecognizer(
        key: wordKey,
        onTapDown: (details) => handleTap(details.globalPosition),
      );

      final bool isWordByWord = hifzState.isHifzModeActive &&
          hifzState.maskingType == HifzMaskingType.wordByWord;

      if (isWordMasked) {
        spans.add(
          TextSpan(
            text: word.code,
            recognizer: wordRecognizer,
            style: baseWordTextStyle.copyWith(
              color: Colors.transparent,
              backgroundColor: mushafTheme.textColor.withValues(alpha: 0.18),
            ),
          ),
        );
      } else {
        final isMenuHighlighted = _activeVerseId == verseId;
        final isAudioHighlighted = playingVerseId == verseId;
        final bool isBookmarked = bookmarkState.isBookmarked(word.verseKey);

        Color textColor = mushafTheme.textColor;
        if (isAudioHighlighted) {
          textColor = mushafTheme.goldColor;
        } else if (isBookmarked && word.charTypeName == 'end') {
          textColor = mushafTheme.bookmarkedMarkerColor;
        }

        final isBookmarkHighlighted = _bookmarkHighlightVerseId == verseId;
        final Color? backgroundColor =
            ((isAudioHighlighted || isMenuHighlighted || isBookmarkHighlighted)
                ? mushafTheme.goldColor.withValues(alpha: 0.2)
                : null);

        spans.add(
          TextSpan(
            text: word.code,
            recognizer: wordRecognizer,
            style: baseWordTextStyle.copyWith(
              color: textColor,
              backgroundColor: backgroundColor,
            ),
          ),
        );
      }

      // In wordByWord mode, add a consistent gap after every word (except the last on the line)
      // regardless of whether the word is masked or revealed. This ensures 100% stable geometry:
      // words never shift, stretch, or jump when revealed!
      if (isWordByWord && i < lineWords.length - 1) {
        spans.add(
          TextSpan(
            text: ' ',
            style: TextStyle(
              fontSize: 10.sp,
              backgroundColor: Colors.transparent,
            ),
          ),
        );
      }

      i++;
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2.0.h),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text.rich(
          TextSpan(children: spans),
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.center,
          maxLines: 1,
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
      _calculateLineTypeCounts();
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

    final pageStr = widget.pageNumber.toString().padLeft(3, '0');
    final customFontFamily = 'QCF_P$pageStr';
    final baseWordTextStyle = AppTextStyles.quranText.copyWith(
      fontFamily: customFontFamily,
      fontSize: 32.sp,
      height: 1.5.h,
      color: mushafTheme.textColor,
    );

    return Stack(
      children: [
        GestureDetector(
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
              buildWhen: (prev, curr) {
                final hasPrev = _parsedVerseKeys.keys.any((k) => prev.isBookmarked(k));
                final hasCurr = _parsedVerseKeys.keys.any((k) => curr.isBookmarked(k));
                if (hasPrev != hasCurr) return true;
                for (final k in _parsedVerseKeys.keys) {
                  if (prev.isBookmarked(k) != curr.isBookmarked(k)) return true;
                }
                return false;
              },
              builder: (context, bookmarkState) {
                return BlocBuilder<HifzBloc, HifzState>(
                  buildWhen: (prev, curr) {
                    if (prev.isHifzModeActive != curr.isHifzModeActive) return true;
                    if (!curr.isHifzModeActive && !prev.isHifzModeActive) return false;
                    if (prev.maskingType != curr.maskingType) return true;
                    return prev != curr;
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
                        int? playingVerseId;
                        final activeAudioVerseId = audioState is AudioPlaying
                            ? audioState.currentVerseId
                            : (audioState is AudioPaused ? audioState.currentVerseId : null);
                        if (activeAudioVerseId != null &&
                            _verseKeyToIntIdMap.containsValue(activeAudioVerseId)) {
                          playingVerseId = activeAudioVerseId;
                        }

                        return MediaQuery.withNoTextScaling(
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
                                            baseWordTextStyle: baseWordTextStyle,
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
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

          final pageStr = widget.pageNumber.toString().padLeft(3, '0');
          final isFontReady = _isFontLoaded || FontService.isLoaded('QCF_P$pageStr');

          if (displayState is QuranLoading || !isFontReady) {
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
          if (displayState is QuranLoaded) return _buildLoadedPage(displayState, mushafTheme);
          return _buildEmptyFrame();
        },
      ),
    );
  }
}
