import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/verse_model.dart';
import '../bloc/quran/quran_bloc.dart';
import '../bloc/quran/quran_event.dart';
import '../bloc/quran/quran_state.dart';
import '../bloc/audio/audio_bloc.dart';
import '../bloc/audio/audio_state.dart';
import '../bloc/bookmark/bookmark_bloc.dart';
import '../../domain/repositories/quran_repository.dart';
import 'quran_page_frame.dart';
import 'verse_action_menu.dart';
import 'quran_metadata.dart';

class QuranPageWidget extends StatefulWidget {
  final int pageNumber;

  const QuranPageWidget({super.key, required this.pageNumber});

  @override
  State<QuranPageWidget> createState() => _QuranPageWidgetState();
}

class _QuranPageWidgetState extends State<QuranPageWidget> {
  int? _activeVerseId;
  OverlayEntry? _overlayEntry;

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
      audioUrl: '',
      words: [],
      juzNumber: 1,
    );

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: quranBloc),
          BlocProvider.value(value: audioBloc),
          BlocProvider.value(value: bookmarkBloc),
        ],
        child: VerseActionMenu(
          position: position,
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
    _overlayEntry = null;
    if (mounted && !keepHighlight) {
      setState(() {
        _activeVerseId = null;
      });
    }
  }

  @override
  void dispose() {
    _removeMenu();
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
            const juzName = '1'; // TODO: Update to real Juz number if added to schema

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
                                  final isActive = isMenuHighlighted || isAudioHighlighted;
                                  final backgroundColor = isActive ? AppColors.accentGold.withValues(alpha: 0.2) : Colors.transparent;

                                  if (word.charTypeName == 'end') {
                                    return GestureDetector(
                                      onTapDown: (details) => _showMenu(context, details.globalPosition, verseId),
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

                                  return GestureDetector(
                                    onTapDown: (details) => _showMenu(context, details.globalPosition, verseId),
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
