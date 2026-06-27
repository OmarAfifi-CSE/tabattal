import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/arabic_text_utils.dart';
import '../../data/models/verse_model.dart';
import '../bloc/quran/quran_bloc.dart';
import '../bloc/quran/quran_event.dart';
import '../bloc/quran/quran_state.dart';
import '../bloc/audio/audio_bloc.dart';
import '../bloc/audio/audio_state.dart';
import '../bloc/bookmark/bookmark_bloc.dart';
import '../bloc/bookmark/bookmark_state.dart';
import '../../domain/repositories/quran_repository.dart';
import 'quran_page_frame.dart';
import 'verse_action_menu.dart';
import 'quran_metadata.dart';
import 'surah_header_widget.dart';
import '../../../../core/services/font_service.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// The decorative Basmala rendered via QCF_BSML font.
const Widget _kBasmalaWidget = Text(
  '1 2 3',
  style: TextStyle(
    fontFamily: 'QCF_BSML',
    fontSize: 26, // Virtual canvas size — scaled by FittedBox, not screen pixels
    color: AppColors.inkBrown,
    height: 1.0,
  ),
);

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

class QuranPageWidget extends StatefulWidget {
  final int pageNumber;
  final String? highlightVerseKey;

  const QuranPageWidget({
    super.key,
    required this.pageNumber,
    this.highlightVerseKey,
  });

  @override
  State<QuranPageWidget> createState() => _QuranPageWidgetState();
}

class _QuranPageWidgetState extends State<QuranPageWidget> with SingleTickerProviderStateMixin {
  int? _activeVerseId;
  OverlayEntry? _activeOverlayEntry;
  final GlobalKey _pageColumnKey = GlobalKey();

  late final AnimationController _bookmarkPulseController;
  late final Animation<double> _bookmarkPulseAnimation;
  int? _bookmarkHighlightVerseId;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _loadPageFont();
    _bookmarkPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _bookmarkPulseAnimation = Tween<double>(begin: 0.15, end: 0.55).animate(
      CurvedAnimation(parent: _bookmarkPulseController, curve: Curves.easeInOut),
    );
    if (widget.highlightVerseKey != null) {
      _activateBookmarkHighlight(widget.highlightVerseKey!);
    }
  }

  @override
  void didUpdateWidget(QuranPageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pageNumber != oldWidget.pageNumber) _loadPageFont();
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
    await FontService.loadFontForPage(widget.pageNumber);
    if (mounted) setState(() {});
  }

  void _activateBookmarkHighlight(String verseKey) {
    final parsed = ArabicTextUtils.parseVerseKey(verseKey);
    if (parsed == null) return;
    setState(() => _bookmarkHighlightVerseId = parsed.surah * 1000 + parsed.ayah);
    // Auto-clear after 5 s so it doesn't stay permanently highlighted
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _bookmarkHighlightVerseId = null);
    });
  }

  /// Computes the screen rect occupied by [verseKey] using the page column layout.
  Rect _calculateVerseScreenRect(String verseKey, List<LineData> lines, Offset fallbackPosition) {
    int minLine = 16;
    int maxLine = 0;
    for (final line in lines) {
      for (final word in line.words) {
        if (word.verseKey == verseKey) {
          if (line.lineNumber < minLine) minLine = line.lineNumber;
          if (line.lineNumber > maxLine) maxLine = line.lineNumber;
        }
      }
    }

    if (minLine > 15) return Rect.fromCenter(center: fallbackPosition, width: 0, height: 0);

    final renderBox = _pageColumnKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return Rect.fromCenter(center: fallbackPosition, width: 0, height: 0);

    final lineHeight = renderBox.size.height / 15;
    final topOffset = renderBox.localToGlobal(Offset(0, (minLine - 1) * lineHeight));
    final bottomOffset = renderBox.localToGlobal(Offset(0, maxLine * lineHeight));

    return Rect.fromLTRB(
      0,
      topOffset.dy,
      MediaQuery.sizeOf(context).width,
      bottomOffset.dy,
    );
  }

  void _showVerseMenu(BuildContext context, Offset tapPosition, int verseId, List<LineData> lines) {
    if (_activeOverlayEntry != null) _removeVerseMenu();

    setState(() => _activeVerseId = verseId);

    final verseKey = ArabicTextUtils.verseIdToVerseKey(verseId);
    final verseRect = _calculateVerseScreenRect(verseKey, lines, tapPosition);

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
        child: VerseActionMenu(
          position: tapPosition,
          verseRect: verseRect,
          verse: partialVerseForMenu,
          onDismiss: ({bool keepHighlight = false}) => _removeVerseMenu(keepHighlight: keepHighlight),
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
  ({int ayah1Line, int surahId})? _findNextSurahStartOnPage(int lineNumber, List<LineData> lines) {
    for (int l = lineNumber + 1; l <= 15; l++) {
      final lineData = lines.firstWhere((e) => e.lineNumber == l, orElse: () => LineData(lineNumber: l, words: []));
      if (lineData.words.isNotEmpty) {
        final vk = lineData.words.first.verseKey;
        final parsed = ArabicTextUtils.parseVerseKey(vk);
        if (parsed != null && parsed.ayah == 1) {
          return (ayah1Line: l, surahId: parsed.surah);
        }
        break;
      }
    }
    return null;
  }

  /// Scans backward from [lineNumber] to find the Surah on the line above.
  int? _findPreviousSurahId(int lineNumber, List<LineData> lines) {
    for (int l = lineNumber - 1; l >= 1; l--) {
      final lineData = lines.firstWhere((e) => e.lineNumber == l, orElse: () => LineData(lineNumber: l, words: []));
      if (lineData.words.isNotEmpty) {
        return ArabicTextUtils.parseVerseKey(lineData.words.last.verseKey)?.surah;
      }
    }
    return null;
  }

  /// Counts empty lines immediately before [lineNumber].
  int _countEmptyLinesBefore(int lineNumber, List<LineData> lines) {
    int count = 0;
    for (int l = lineNumber - 1; l >= 1; l--) {
      final lineData = lines.firstWhere((e) => e.lineNumber == l, orElse: () => LineData(lineNumber: l, words: []));
      if (lineData.words.isEmpty) { count++; } else { break; }
    }
    return count;
  }

  Widget _buildEmptyLineWidget(int lineNumber, List<LineData> lines) {
    // ── Case A: A new Surah starts later on this page ──────────────────────
    final nextSurah = _findNextSurahStartOnPage(lineNumber, lines);
    if (nextSurah != null) {
      final (:ayah1Line, :surahId) = nextSurah;
      final header = Padding(
        padding: EdgeInsets.symmetric(vertical: 2.h),
        child: SurahHeaderWidget(surahNumber: surahId),
      );
      const basmala = Center(child: _kBasmalaWidget);

      // Surah 9 (At-Tawbah) has no Basmala
      if (surahId == 9 || surahId == 1) {
        return lineNumber == ayah1Line - 1 ? header : SizedBox(height: 45.h);
      }

      // Determine whether the header should appear on this line or one earlier
      final prevPrevLineData = lines.firstWhere(
        (l) => l.lineNumber == ayah1Line - 2,
        orElse: () => LineData(lineNumber: ayah1Line - 2, words: []),
      );
      final bool mustSquashBothOnLineMinus1 =
          ayah1Line > 2 && prevPrevLineData.words.isNotEmpty ||
          ayah1Line == 2 && widget.pageNumber == 1;

      if (lineNumber == ayah1Line - 1) {
        return mustSquashBothOnLineMinus1 ? Column(mainAxisSize: MainAxisSize.min, children: [header, basmala]) : basmala;
      } else if (lineNumber == ayah1Line - 2 && !mustSquashBothOnLineMinus1) {
        return header;
      }
      return SizedBox(height: 45.h);
    }

    // ── Case B: Trailing empty lines at end of page ────────────────────────
    // Pages 1 & 2 use these lines as padding for decorative frames.
    if (widget.pageNumber == 1 || widget.pageNumber == 2) {
      return SizedBox(height: 45.h);
    }

    final previousSurahId = _findPreviousSurahId(lineNumber, lines);
    if (previousSurahId != null) {
      final upcomingSurahId = previousSurahId + 1;
      if (upcomingSurahId <= 114) {
        final emptyLinesBefore = _countEmptyLinesBefore(lineNumber, lines);
        final header = Padding(
          padding: EdgeInsets.symmetric(vertical: 2.h),
          child: SurahHeaderWidget(surahNumber: upcomingSurahId),
        );
        const basmala = Center(child: _kBasmalaWidget);

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
    required List<LineData> lines,
  }) {
    final pageStr = widget.pageNumber.toString().padLeft(3, '0');
    final customFontFamily = 'QCF_P$pageStr';
    final displayText = word.codeV1.isNotEmpty ? word.codeV1 : word.textUthmani;

    void handleTap(TapDownDetails details) {
      _showVerseMenu(context, details.globalPosition, verseId, lines);
    }

    final wordTextStyle = AppTextStyles.quranText.copyWith(
      fontFamily: customFontFamily,
      fontSize: 32, // Virtual canvas size — scaled by FittedBox
      height: 1.5,
    );

    if (isBookmarkHighlighted) {
      return AnimatedBuilder(
        animation: _bookmarkPulseAnimation,
        builder: (context, _) => GestureDetector(
          onTapDown: handleTap,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.accentGold.withValues(alpha: _bookmarkPulseAnimation.value),
              borderRadius: BorderRadius.circular(4.r),
            ),
            child: Text(
              displayText,
              style: wordTextStyle.copyWith(
                color: AppColors.accentGoldDark,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }

    final backgroundColor = (isAudioHighlighted || isMenuHighlighted)
        ? AppColors.accentGold.withValues(alpha: 0.2)
        : Colors.transparent;

    Color textColor = AppColors.textPrimary;
    if (isAudioHighlighted) {
      textColor = AppColors.accentGold;
    } else if (isPermanentlyBookmarked && word.charTypeName == 'end') {
      textColor = AppColors.accentGold;
    }

    return GestureDetector(
      onTapDown: handleTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        color: backgroundColor,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          style: wordTextStyle.copyWith(
            color: textColor,
          ),
          child: Text(displayText),
        ),
      ),
    );
  }

  /// Builds one row of words for a Quran line.
  Widget _buildWordRow({
    required List<WordModel> lineWords,
    required int? playingVerseId,
    required Map<String, int> verseKeyToIntIdMap,
    required AudioState audioState,
    required BookmarkState bookmarkState,
    required List<LineData> lines,
  }) {
    final List<Widget> wordWidgets = [];
    bool fatihahBasmalaAdded = false;

    for (final word in lineWords) {
      final verseId = verseKeyToIntIdMap[word.verseKey] ?? 0;

      // Al-Fatiha Basmala: replace individual QCF_P001 glyphs with a single unified widget
      if (word.verseKey == '1:1' && word.charTypeName != 'end') {
        if (!fatihahBasmalaAdded) {
          wordWidgets.add(
            GestureDetector(
              onTapDown: (details) {
                _showVerseMenu(context, details.globalPosition, verseId, lines);
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.0),
                child: _kBasmalaWidget,
              ),
            ),
          );
          fatihahBasmalaAdded = true;
        }
        continue;
      }

      final bool isBookmarked = bookmarkState.isBookmarked(word.verseKey);

      wordWidgets.add(_buildWordWidget(
        word: word,
        verseId: verseId,
        isMenuHighlighted: _activeVerseId == verseId,
        isAudioHighlighted: playingVerseId == verseId,
        isBookmarkHighlighted: _bookmarkHighlightVerseId == verseId,
        isPermanentlyBookmarked: isBookmarked,
        audioState: audioState,
        lines: lines,
      ));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0), // Virtual canvas padding
      child: Row(
        textDirection: TextDirection.rtl,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: wordWidgets,
      ),
    );
  }

  /// Builds the full loaded page content with all 15 line slots.
  Widget _buildLoadedPage(QuranLoaded state) {
    final lines = state.lines;
    if (lines.isEmpty) return const SizedBox();

    String firstVerseKey = '1:1';
    for (final line in lines) {
      if (line.words.isNotEmpty) {
        firstVerseKey = line.words.first.verseKey;
        break;
      }
    }

    final surahNumber = ArabicTextUtils.parseVerseKey(firstVerseKey)?.surah ?? 1;
    final surahName = QuranMetadata.getSurahNameWithTashkeel(surahNumber);
    final juzNum = QuranMetadata.getJuzNumberByPage(widget.pageNumber);
    final juzName = QuranMetadata.getJuzNameWithTashkeel(juzNum);

    return QuranPageFrame(
      pageNumber: widget.pageNumber,
      surahName: surahName,
      juzName: juzName,
      child: BlocBuilder<BookmarkBloc, BookmarkState>(
        builder: (context, bookmarkState) {
          return BlocBuilder<AudioBloc, AudioState>(
            builder: (context, audioState) {
          int? playingVerseId;
          if (audioState is AudioPlaying) playingVerseId = audioState.currentVerseId;
          if (audioState is AudioPaused) playingVerseId = audioState.currentVerseId;

          // Pre-compute the verse key → integer ID mapping for fast lookup per word
          final verseKeyToIntIdMap = <String, int>{
            for (final line in lines)
              for (final word in line.words)
                if (ArabicTextUtils.parseVerseKey(word.verseKey) != null)
                  word.verseKey: ArabicTextUtils.verseKeyToVerseId(word.verseKey),
          };

          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: FittedBox(
                fit: BoxFit.contain,
                alignment: Alignment.center,
                child: IntrinsicWidth(
                  child: ConstrainedBox(
                    // These are VIRTUAL CANVAS coordinates, not screen pixels.
                    // They must NOT use ScreenUtil — they define the intrinsic aspect ratio
                    // for the FittedBox to scale correctly on all screen sizes.
                    constraints: const BoxConstraints(minWidth: 460, minHeight: 1020),
                    child: Column(
                      key: _pageColumnKey,
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: List.generate(15, (index) {
                        final lineNumber = index + 1;
                        final lineData = lines.firstWhere(
                          (l) => l.lineNumber == lineNumber,
                          orElse: () => LineData(lineNumber: lineNumber, words: []),
                        );

                        if (lineData.words.isEmpty) {
                          return _buildEmptyLineWidget(lineNumber, lines);
                        }

                        return _buildWordRow(
                          lineWords: lineData.words,
                          playingVerseId: playingVerseId,
                          verseKeyToIntIdMap: verseKeyToIntIdMap,
                          audioState: audioState,
                          bookmarkState: bookmarkState,
                          lines: lines,
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  Widget _buildEmptyFrame() => QuranPageFrame(
        pageNumber: widget.pageNumber,
        surahName: '',
        juzName: '',
        child: const SizedBox(),
      );

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          QuranBloc(repository: context.read<QuranRepository>())..add(LoadPage(widget.pageNumber)),
      child: BlocBuilder<QuranBloc, QuranState>(
        buildWhen: (_, current) =>
            current is QuranLoading || current is QuranLoaded || current is QuranError || current is QuranInitial,
        builder: (context, state) {
          if (state is QuranLoading) {
            return QuranPageFrame(
              pageNumber: widget.pageNumber,
              surahName: '',
              juzName: '',
              child: const Center(child: CircularProgressIndicator(color: AppColors.accentGold)),
            );
          }
          if (state is QuranError) {
            return QuranPageFrame(
              pageNumber: widget.pageNumber,
              surahName: '',
              juzName: '',
              child: Center(
                child: Text(state.message, style: TextStyle(color: Colors.red, fontSize: 14.sp)),
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
