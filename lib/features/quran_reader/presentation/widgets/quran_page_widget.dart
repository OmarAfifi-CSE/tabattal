import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/verse_model.dart';
import '../bloc/quran/quran_bloc.dart';
import '../bloc/quran/quran_event.dart';
import '../bloc/quran/quran_state.dart';
import '../bloc/audio/audio_bloc.dart';
import '../bloc/audio/audio_event.dart';
import '../bloc/audio/audio_state.dart';
import '../bloc/bookmark/bookmark_bloc.dart';
import '../../domain/repositories/quran_repository.dart';
import 'quran_page_frame.dart';
import 'verse_action_menu.dart';
import 'quran_metadata.dart';
import 'surah_header_widget.dart';

class QuranPageWidget extends StatefulWidget {
  final int pageNumber;
  final String? highlightVerseKey; // verseKey to highlight (from bookmarks navigation)

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
  OverlayEntry? _overlayEntry;
  final GlobalKey _columnKey = GlobalKey();

  // For bookmark highlight pulse animation
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  int? _bookmarkHighlightId; // verseId derived from widget.highlightVerseKey

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.15, end: 0.55).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.highlightVerseKey != null) {
      _setBookmarkHighlight(widget.highlightVerseKey!);
    }
  }

  @override
  void didUpdateWidget(QuranPageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlightVerseKey != oldWidget.highlightVerseKey) {
      if (widget.highlightVerseKey != null) {
        _setBookmarkHighlight(widget.highlightVerseKey!);
      } else {
        setState(() => _bookmarkHighlightId = null);
      }
    }
  }

  void _setBookmarkHighlight(String verseKey) {
    final parts = verseKey.split(':');
    if (parts.length == 2) {
      final surah = int.tryParse(parts[0]) ?? 0;
      final ayah = int.tryParse(parts[1]) ?? 0;
      setState(() => _bookmarkHighlightId = surah * 1000 + ayah);
      // Auto-clear after 5 seconds so it doesn't stay permanently
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) setState(() => _bookmarkHighlightId = null);
      });
    }
  }

  void _showMenu(BuildContext context, Offset position, int verseId) {
    if (_overlayEntry != null) {
      _removeMenu();
    }

    setState(() {
      _activeVerseId = verseId;
    });

    final quranBloc = context.read<QuranBloc>();
    final audioBloc = context.read<AudioBloc>();
    final bookmarkBloc = context.read<BookmarkBloc>();

    final surahNum = verseId ~/ 1000;
    final ayahNum = verseId % 1000;
    final generatedVerseKey = '$surahNum:$ayahNum';

    // We need a dummy VerseModel just to pass the ID and verseKey to the menu.
    // In a real app, you would pass the full VerseModel.
    final dummyVerse = VerseModel(
      id: verseId,
      verseNumber: ayahNum,
      verseKey: generatedVerseKey,
      textUthmani: '',
      words: [],
      juzNumber: 1,
    );

    Rect verseRect = Rect.fromCenter(center: position, width: 0, height: 0);
    if (quranBloc.state is QuranLoaded) {
      final state = quranBloc.state as QuranLoaded;
      int minLine = 16;
      int maxLine = 0;
      for (var line in state.lines) {
        for (var word in line.words) {
          if (word.verseKey == generatedVerseKey) {
            if (line.lineNumber < minLine) minLine = line.lineNumber;
            if (line.lineNumber > maxLine) maxLine = line.lineNumber;
          }
        }
      }

      if (minLine <= 15) {
        final renderBox = _columnKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          final columnTop = renderBox.localToGlobal(Offset.zero).dy;
          final columnHeight = renderBox.size.height;
          final lineHeight = columnHeight / 15;
          final topY = columnTop + (minLine - 1) * lineHeight;
          final bottomY = columnTop + maxLine * lineHeight;
          verseRect = Rect.fromLTRB(0, topY, MediaQuery.of(context).size.width, bottomY);
        }
      }
    }

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: quranBloc),
          BlocProvider.value(value: audioBloc),
          BlocProvider.value(value: bookmarkBloc),
        ],
        child: VerseActionMenu(
          position: position,
          verseRect: verseRect,
          verse: dummyVerse,
          onDismiss: ({bool keepHighlight = false}) => _removeMenu(keepHighlight: keepHighlight),
          onClearHighlight: () {
            if (mounted) {
              setState(() {
                _activeVerseId = null;
              });
            }
          },
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeMenu({bool keepHighlight = false}) {
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;
    // Only call setState if the widget is still alive
    if (mounted && !keepHighlight) {
      setState(() {
        _activeVerseId = null;
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    // Remove overlay entry without calling setState (widget is being disposed)
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => QuranBloc(repository: context.read<QuranRepository>())..add(LoadPage(widget.pageNumber)),
      child: BlocBuilder<QuranBloc, QuranState>(
        buildWhen: (previous, current) {
          return current is QuranLoading || current is QuranLoaded || current is QuranError || current is QuranInitial;
        },
        builder: (context, state) {
          if (state is QuranLoading && state is! QuranLoaded) {
            return QuranPageFrame(
              pageNumber: widget.pageNumber,
              surahName: '',
              juzName: '',
              child: const Center(child: CircularProgressIndicator(color: AppColors.accentGold)),
            );
          } else if (state is QuranError) {
            return QuranPageFrame(
              pageNumber: widget.pageNumber,
              surahName: '',
              juzName: '',
              child: Center(
                child: Text(
                  state.message,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          } else if (state is QuranLoaded) {
            final lines = state.lines;
            if (lines.isEmpty) {
              return QuranPageFrame(
                pageNumber: widget.pageNumber, 
                surahName: '',
                juzName: '',
                child: const SizedBox()
              );
            }

            // Extract metadata from the first word of the page
            String firstVerseKey = '1:1';
            for (var line in lines) {
              if (line.words.isNotEmpty) {
                firstVerseKey = line.words.first.verseKey;
                // Currently our DB doesn't have juz_number in WordModel, we can extract from metadata or add it.
                // For now, let's just default to '1' or use a hardcoded value since we dropped juz from WordModel.
                // Wait, we didn't add juz to WordModel. Let's just use 1.
                break;
              }
            }

            final surahNumber = int.tryParse(firstVerseKey.split(':').first) ?? 1;
            final surahName = QuranMetadata.getSurahName(surahNumber);
            final juzNum = QuranMetadata.getJuzNumberByPage(widget.pageNumber);
            final juzName = QuranMetadata.getJuzName(juzNum);

            return QuranPageFrame(
              pageNumber: widget.pageNumber,
              surahName: surahName,
              juzName: juzName,
              child: BlocBuilder<AudioBloc, AudioState>(
                builder: (context, audioState) {
                  int? playingVerseId;
                  if (audioState is AudioPlaying) {
                    playingVerseId = audioState.currentVerseId;
                  } else if (audioState is AudioPaused) {
                    playingVerseId = audioState.currentVerseId;
                  }

                  // A map to find which verse a word belongs to based on verseKey
                  final Map<String, int> verseKeyToId = {};
                  for (var line in lines) {
                    for (var w in line.words) {
                      final parts = w.verseKey.split(':');
                      if (parts.length == 2) {
                        final surah = int.tryParse(parts[0]) ?? 1;
                        final ayah = int.tryParse(parts[1]) ?? 1;
                        verseKeyToId[w.verseKey] = surah * 1000 + ayah;
                      } else {
                        verseKeyToId[w.verseKey] = 0;
                      }
                    }
                  }

                  return MediaQuery(
                    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Column(
                        key: _columnKey,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: List.generate(15, (index) {
                          final lineNumber = index + 1;
                          // Find the LineData for this line number
                          final lineData = lines.firstWhere(
                            (l) => l.lineNumber == lineNumber,
                            orElse: () => LineData(lineNumber: lineNumber, words: []),
                          );
                          final lineWords = lineData.words;

                          if (lineWords.isEmpty) {
                            // Find which Surah is starting!
                            // Look at subsequent lines to find the next verseKey
                            int? nextSurahId;
                            for (int nextLine = lineNumber + 1; nextLine <= 15; nextLine++) {
                              final nl = lines.firstWhere((l) => l.lineNumber == nextLine, orElse: () => LineData(lineNumber: nextLine, words: []));
                              if (nl.words.isNotEmpty) {
                                final vk = nl.words.first.verseKey;
                                nextSurahId = int.tryParse(vk.split(':').first);
                                break;
                              }
                            }

                            // Check if the previous line was also empty to avoid duplicating the header
                            bool isFirstEmpty = true;
                            if (lineNumber > 1) {
                              final prevLine = lines.firstWhere((l) => l.lineNumber == lineNumber - 1, orElse: () => LineData(lineNumber: lineNumber - 1, words: []));
                              if (prevLine.words.isEmpty) {
                                isFirstEmpty = false;
                              }
                            }

                            if (isFirstEmpty && nextSurahId != null) {
                              final surahName = QuranMetadata.getSurahName(nextSurahId);
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2.0),
                                child: SurahHeaderWidget(surahName: surahName, surahNumber: nextSurahId),
                              );
                            }

                            return const Expanded(child: SizedBox());
                          }

                          // If it's not a full line (like the end of a Surah), it might not need justification.
                          // But to match exactly, usually all lines except the last line of a Surah are justified.
                          // We will justify all lines. If it looks weird, we can check if it's the last line.
                          
                          return Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.center,
                              child: Row(
                                textDirection: TextDirection.rtl,
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: lineWords.map((word) {
                                  final verseId = verseKeyToId[word.verseKey] ?? 0;
                                  final isMenuHighlighted = _activeVerseId == verseId;
                                  final isAudioHighlighted = playingVerseId == verseId;
                                  final isBookmarkHighlighted = _bookmarkHighlightId == verseId;

                                  Color backgroundColor;
                                  if (isAudioHighlighted || isMenuHighlighted) {
                                    backgroundColor = AppColors.accentGold.withValues(alpha: 0.2);
                                  } else {
                                    backgroundColor = Colors.transparent;
                                  }

                                    if (word.charTypeName == 'end') {
                                      return GestureDetector(
                                        onTapDown: (details) {
                                          if (audioState is AudioPlaying || audioState is AudioPaused) {
                                            context.read<AudioBloc>().add(PlayVerse('', verseId));
                                          } else {
                                            _showMenu(context, details.globalPosition, verseId);
                                          }
                                        },
                                        child: Container(
                                        // Push the marker down slightly to match the Arabic text's visual baseline
                                        margin: const EdgeInsets.only(top: 12.0, left: 3.0, right: 3.0),
                                        width: 35,
                                        height: 35,
                                        decoration: BoxDecoration(
                                          color: backgroundColor,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Icon(
                                              Icons.brightness_7_rounded,
                                              color: isAudioHighlighted ? AppColors.accentGold : const Color(0xFFC7A263).withValues(alpha: 0.8),
                                              size: 35,
                                            ),
                                            Container(
                                              width: 20,
                                              height: 20,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFAF5EB),
                                                shape: BoxShape.circle,
                                                border: Border.all(color: const Color(0xFF5A4033), width: 0.5),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2.0), // center number in the circle
                                              child: Text(
                                                word.textUthmani,
                                                style: TextStyle(
                                                  color: isAudioHighlighted ? AppColors.accentGold : const Color(0xFF5A4033),
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }

                                  // Build the word widget with optional pulse animation
                                  if (isBookmarkHighlighted) {
                                    return AnimatedBuilder(
                                      animation: _pulseAnimation,
                                      builder: (context, _) {
                                      return GestureDetector(
                                        onTapDown: (details) {
                                          if (audioState is AudioPlaying || audioState is AudioPaused) {
                                            context.read<AudioBloc>().add(PlayVerse('', verseId));
                                          } else {
                                            _showMenu(context, details.globalPosition, verseId);
                                          }
                                        },
                                        child: Container(
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFB59A53).withValues(alpha: _pulseAnimation.value),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '${word.textUthmani} ',
                                              style: AppTextStyles.quranText.copyWith(
                                                color: AppColors.accentGoldDark,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  }

                                  return GestureDetector(
                                    onTapDown: (details) {
                                      if (audioState is AudioPlaying || audioState is AudioPaused) {
                                        context.read<AudioBloc>().add(PlayVerse('', verseId));
                                      } else {
                                        _showMenu(context, details.globalPosition, verseId);
                                      }
                                    },
                                    child: Container(
                                      color: backgroundColor,
                                      child: Text(
                                        '${word.textUthmani} ',
                                        style: AppTextStyles.quranText.copyWith(
                                          color: isAudioHighlighted ? AppColors.accentGold : AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  );
                },
              ),
            );
          }
          return QuranPageFrame(
            pageNumber: widget.pageNumber, 
            surahName: '',
            juzName: '',
            child: const SizedBox()
          );
        },
      ),
    );
  }
}
