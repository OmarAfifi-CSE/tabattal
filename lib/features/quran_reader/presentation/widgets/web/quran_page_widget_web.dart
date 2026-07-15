import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../l10n/app_localizations.dart';

import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/utils/arabic_text_utils.dart';
import '../../../data/models/verse_model.dart';
import '../../../bloc/quran/quran_bloc.dart';
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

  @override
  State<QuranPageWidgetWeb> createState() => _QuranPageWidgetWebState();
}

class _QuranPageWidgetWebState extends State<QuranPageWidgetWeb> with SingleTickerProviderStateMixin {
  int? _activeVerseId;
  OverlayEntry? _activeOverlayEntry;
  final GlobalKey _pageColumnKey = GlobalKey();
  bool _isFontLoaded = false;

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
  void didUpdateWidget(QuranPageWidgetWeb oldWidget) {
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
    setState(() => _isFontLoaded = false);
    // On Web, FontLoader.load() blocks the main thread. We delay it slightly
    // so it doesn't drop frames during the PageView swipe animation.
    if (!mounted) return;
    await FontService.loadFontForPage(widget.pageNumber);
    if (mounted) setState(() => _isFontLoaded = true);
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
        child: VerseActionMenuWeb(
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

  Widget _buildEmptyLineWidget(int lineNumber, List<LineData> lines, MushafTheme mushafTheme) {
    // ── Case A: A new Surah starts later on this page ──────────────────────
    final nextSurah = _findNextSurahStartOnPage(lineNumber, lines);
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
        return lineNumber == ayah1Line - 1 ? header : const SizedBox(height: 45);
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
      return const SizedBox(height: 45);
    }

    // ── Case B: Trailing empty lines at end of page ────────────────────────
    // Pages 1 & 2 use these lines as padding for decorative frames.
    if (widget.pageNumber == 1 || widget.pageNumber == 2) {
      return const SizedBox(height: 45);
    }

    final previousSurahId = _findPreviousSurahId(lineNumber, lines);
    if (previousSurahId != null) {
      final upcomingSurahId = previousSurahId + 1;
      if (upcomingSurahId <= 114) {
        final emptyLinesBefore = _countEmptyLinesBefore(lineNumber, lines);
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
    required List<LineData> lines,
  }) {
    final pageStr = widget.pageNumber.toString().padLeft(3, '0');
    final customFontFamily = 'QCF_P$pageStr';
    final displayText = word.codeV1.isNotEmpty ? word.codeV1 : word.textUthmani;

    void handleTap(TapUpDetails details) {
      if (_activeVerseId == verseId) {
        _removeVerseMenu();
      } else {
        _showVerseMenu(context, details.globalPosition, verseId, lines);
      }
    }

    final wordTextStyle = AppTextStyles.quranText.copyWith(
      fontFamily: customFontFamily,
      fontSize: 42,
      height: 1.2,
    );

    final mushafTheme = context.watch<SettingsBloc>().state.effectiveMushafTheme;

    if (isBookmarkHighlighted) {
      return AnimatedBuilder(
        animation: _bookmarkPulseAnimation,
        builder: (context, _) => GestureDetector(
          onTapUp: handleTap,
          onTap: () {},
          onLongPress: () {},
          child: Container(
            color: mushafTheme.goldColor.withValues(alpha: _bookmarkPulseAnimation.value),
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
      textColor = mushafTheme.goldColor;
    }

    return GestureDetector(
      onTapUp: handleTap,
      onTap: () {},
      onLongPress: () {},
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        color: backgroundColor,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          style: wordTextStyle.copyWith(color: textColor),
          child: Text(displayText),
        ),
      ),
    );
  }

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
          final isMenuHighlighted = _activeVerseId == verseId;
          final isAudioHighlighted = playingVerseId == verseId;
          final isBookmarkHighlighted = _bookmarkHighlightVerseId == verseId;
          final isBookmarked = bookmarkState.isBookmarked(word.verseKey);

          final mushafTheme = context.watch<SettingsBloc>().state.effectiveMushafTheme;

          final backgroundColor = (isAudioHighlighted || isMenuHighlighted)
              ? mushafTheme.goldColor.withValues(alpha: 0.2)
              : Colors.transparent;

          Color textColor = mushafTheme.textColor;
          if (isAudioHighlighted) {
            textColor = mushafTheme.goldColor;
          } else if (isBookmarked) {
            textColor = mushafTheme.goldColor;
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
                fontSize: 26,
                color: textColor,
                height: 1.0,
              ),
              child: const Text('1 2 3'),
            ),
          );

          if (isBookmarkHighlighted) {
            final mushafTheme = context.watch<SettingsBloc>().state.effectiveMushafTheme;
            basmala = AnimatedBuilder(
              animation: _bookmarkPulseAnimation,
              builder: (context, _) => Container(
                color: mushafTheme.goldColor.withValues(alpha: _bookmarkPulseAnimation.value),
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
                  _showVerseMenu(context, details.globalPosition, verseId, lines);
                }
              },
              onTap: () {},
              onLongPress: () {},
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: basmala,
              ),
            )
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
      padding: const EdgeInsets.symmetric(vertical: 2.0),
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

    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final surahNumber = ArabicTextUtils.parseVerseKey(firstVerseKey)?.surah ?? 1;
    final surahName = isEn ? "Surah ${QuranMetadata.getSurahNameEnglish(surahNumber)}" : QuranMetadata.getSurahNameWithTashkeel(surahNumber);
    
    final juzNum = QuranMetadata.getJuzNumberByPage(widget.pageNumber);
    final juzName = isEn ? AppLocalizations.of(context)!.juzListItem(juzNum.toString()) : QuranMetadata.getJuzNameWithTashkeel(juzNum);

    return GestureDetector(
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
          builder: (context, bookmarkState) {
            return BlocBuilder<AudioBloc, AudioState>(
              builder: (context, audioState) {
            final mushafTheme = context.watch<SettingsBloc>().state.effectiveMushafTheme;
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
                  child: SizedBox(
                  // Use a fixed virtual canvas size instead of expensive IntrinsicWidth
                  // Increased width from 460 to 490 to prevent horizontal overflow on dense lines like page 453
                  width: 650, 
                  height: 950,
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
                          return _buildEmptyLineWidget(lineNumber, lines, mushafTheme);
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
                    ), // Column
                  ), // SizedBox
                ), // FittedBox
              ), // Directionality
            ); // MediaQuery
          },
        ); // BlocBuilder
          },
        ), // BlocBuilder
      ), // QuranPageFrameWeb
      ), // Center
    ); // GestureDetector
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
    return BlocProvider(
      create: (context) =>
          QuranBloc(repository: context.read<QuranRepository>())..add(LoadPage(widget.pageNumber)),
      child: BlocBuilder<QuranBloc, QuranState>(
        buildWhen: (_, current) =>
            current is QuranLoading || current is QuranLoaded || current is QuranError || current is QuranInitial,
        builder: (context, state) {
          final mushafTheme = context.watch<SettingsBloc>().state.effectiveMushafTheme;
          if (state is QuranLoading || !_isFontLoaded) {
            return QuranPageFrameWeb(
              pageNumber: widget.pageNumber,
      onNavigateToPage: widget.onNavigateToPage,
              surahName: '',
              juzName: '',
              child: Center(child: CircularProgressIndicator(color: mushafTheme.goldColor)),
            );
          }
          if (state is QuranError) {
            return QuranPageFrameWeb(
              pageNumber: widget.pageNumber,
      onNavigateToPage: widget.onNavigateToPage,
              surahName: '',
              juzName: '',
              child: Center(
                child: Text(state.message, style: const TextStyle(color: Colors.red, fontSize: 14)),
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








