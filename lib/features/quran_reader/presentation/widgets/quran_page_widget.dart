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
import '../../../../core/services/font_service.dart';

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
    _loadPageFont();
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
    if (widget.pageNumber != oldWidget.pageNumber) {
      _loadPageFont();
    }
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

  Future<void> _loadPageFont() async {
    await FontService.loadFontForPage(widget.pageNumber);
    if (mounted) setState(() {});
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

  Widget _buildEmptyLineWidget(int lineNumber, List<LineData> lines) {
    // Scan forward to find if a Surah starts on this page after this line
    int? ayah1Line;
    int? nextSurahId;
    for (int l = lineNumber + 1; l <= 15; l++) {
      final lineData = lines.firstWhere((element) => element.lineNumber == l, orElse: () => LineData(lineNumber: l, words: []));
      if (lineData.words.isNotEmpty) {
        final vk = lineData.words.first.verseKey;
        final parts = vk.split(':');
        if (parts.length == 2 && parts[1] == '1') {
          ayah1Line = l;
          nextSurahId = int.tryParse(parts[0]);
        }
        break;
      }
    }

    if (ayah1Line != null && nextSurahId != null) {
      final header = Padding(padding: const EdgeInsets.symmetric(vertical: 2.0), child: SurahHeaderWidget(surahNumber: nextSurahId));
      const basmala = Center(child: Text('1 2 3', style: TextStyle(fontFamily: 'QCF_BSML', fontSize: 26, color: Color(0xFF2C2520), height: 1.0)));

      if (nextSurahId == 9) {
        if (lineNumber == ayah1Line - 1) return header;
        return const SizedBox(height: 45);
      }

      if (nextSurahId == 1) {
        // Al-Fatihah's Basmala is verse 1, so no separate decorative Basmala is needed
        if (lineNumber == ayah1Line - 1) return header;
        return const SizedBox(height: 45);
      }

      bool needsHeaderHere = false;
      if (ayah1Line == 2 && widget.pageNumber == 1) {
        needsHeaderHere = true;
      } else if (ayah1Line > 2) {
        final prevLine = lines.firstWhere((l) => l.lineNumber == ayah1Line! - 2, orElse: () => LineData(lineNumber: ayah1Line! - 2, words: []));
        if (prevLine.words.isNotEmpty) {
          needsHeaderHere = true;
        }
      }

      if (lineNumber == ayah1Line - 1) {
        if (needsHeaderHere) {
          return Column(mainAxisSize: MainAxisSize.min, children: [header, basmala]);
        }
        return basmala;
      } else if (lineNumber == ayah1Line - 2 && !needsHeaderHere) {
        return header;
      }
      return const SizedBox(height: 45);
    }

    // Scan backward to see if this is a trailing empty line for a Surah starting on the NEXT page
    // For pages 1 and 2, the bottom empty lines are just padding for the large decorative frames.
    if (widget.pageNumber == 1 || widget.pageNumber == 2) {
      return const SizedBox(height: 45);
    }

    int? lastSurahId;
    for (int l = lineNumber - 1; l >= 1; l--) {
      final lineData = lines.firstWhere((element) => element.lineNumber == l, orElse: () => LineData(lineNumber: l, words: []));
      if (lineData.words.isNotEmpty) {
        final vk = lineData.words.last.verseKey;
        lastSurahId = int.tryParse(vk.split(':').first);
        break;
      }
    }

    if (lastSurahId != null) {
      int upcomingSurahId = lastSurahId + 1;
      if (upcomingSurahId <= 114) {
        int emptyLinesBefore = 0;
        for (int l = lineNumber - 1; l >= 1; l--) {
          final lineData = lines.firstWhere((element) => element.lineNumber == l, orElse: () => LineData(lineNumber: l, words: []));
          if (lineData.words.isEmpty) {
            emptyLinesBefore++;
          } else {
            break;
          }
        }

        final header = Padding(padding: const EdgeInsets.symmetric(vertical: 2.0), child: SurahHeaderWidget(surahNumber: upcomingSurahId));
        const basmala = Center(child: Text('1 2 3', style: TextStyle(fontFamily: 'QCF_BSML', fontSize: 26, color: Color(0xFF2C2520), height: 1.0)));

        if (emptyLinesBefore == 0) return header;
        if (emptyLinesBefore == 1 && upcomingSurahId != 9) return basmala;
      }
    }

    return const SizedBox(height: 45);
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
            final surahName = QuranMetadata.getSurahNameWithTashkeel(surahNumber);
            final juzNum = QuranMetadata.getJuzNumberByPage(widget.pageNumber);
            final juzName = QuranMetadata.getJuzNameWithTashkeel(juzNum);

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
                      child: FittedBox(
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                        child: IntrinsicWidth(
                          child: ConstrainedBox(
                            // Adding minWidth: 460 forces the intrinsic aspect ratio to always trigger 
                            // scale-by-width (or proportional scale) in the FittedBox. This mathematically
                            // ensures that stretched elements (like Surah Frames) will have EXACTLY the same
                            // visual height on Page 1 as they do on dense pages like Page 76.
                            constraints: const BoxConstraints(minWidth: 460, minHeight: 1020),
                          child: Column(
                            key: _columnKey,
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                            return _buildEmptyLineWidget(lineNumber, lines);
                          }

                          // The King Fahd text layout handles word spacing naturally, so we just use center alignment.

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Row(
                              textDirection: TextDirection.rtl,
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                                children: () {
                                  final List<Widget> widgets = [];
                                  bool fatihahBasmalaAdded = false;

                                  for (final word in lineWords) {
                                    final verseId = verseKeyToId[word.verseKey] ?? 0;
                                    
                                    if (word.verseKey == '1:1' && word.charTypeName != 'end') {
                                      if (!fatihahBasmalaAdded) {
                                        widgets.add(
                                          GestureDetector(
                                            onTapDown: (details) {
                                              if (audioState is AudioPlaying || audioState is AudioPaused) {
                                                context.read<AudioBloc>().add(PlayVerse('', verseId));
                                              } else {
                                                _showMenu(context, details.globalPosition, verseId);
                                              }
                                            },
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(horizontal: 4.0),
                                              child: Text(
                                                '1 2 3',
                                                style: TextStyle(
                                                  fontFamily: 'QCF_BSML',
                                                  fontSize: 26,
                                                  color: Color(0xFF2C2520),
                                                  height: 1.0,
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                        fatihahBasmalaAdded = true;
                                      }
                                      continue; // Skip the individual QCF_P001 words
                                    }

                                    final isMenuHighlighted = _activeVerseId == verseId;
                                    final isAudioHighlighted = playingVerseId == verseId;
                                    final isBookmarkHighlighted = _bookmarkHighlightId == verseId;

                                    Color backgroundColor;
                                    if (isAudioHighlighted || isMenuHighlighted) {
                                      backgroundColor = AppColors.accentGold.withValues(alpha: 0.2);
                                    } else {
                                      backgroundColor = Colors.transparent;
                                    }

                                    final pageStr = widget.pageNumber.toString().padLeft(3, '0');
                                    final customFontFamily = 'QCF_P$pageStr';
                                    final displayText = word.codeV1.isNotEmpty ? word.codeV1 : word.textUthmani;

                                    if (isBookmarkHighlighted) {
                                      widgets.add(
                                        AnimatedBuilder(
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
                                                  displayText,
                                                  style: AppTextStyles.quranText.copyWith(
                                                    fontFamily: customFontFamily,
                                                    fontSize: 32,
                                                    height: 1.5,
                                                    color: AppColors.accentGoldDark,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        )
                                      );
                                    } else {
                                      widgets.add(
                                        GestureDetector(
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
                                              displayText,
                                              style: AppTextStyles.quranText.copyWith(
                                                fontFamily: customFontFamily,
                                                fontSize: 32,
                                                height: 1.5,
                                                color: isAudioHighlighted ? AppColors.accentGold : AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                        )
                                      );
                                    }
                                  }
                                  return widgets;
                                }(),
                              ),
                            );
                          }),
                          ), // Column
                          ), // ConstrainedBox
                        ), // IntrinsicWidth
                      ), // FittedBox
                    ), // Directionality
                  ); // MediaQuery
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
