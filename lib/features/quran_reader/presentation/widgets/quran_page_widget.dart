import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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

    // We need a dummy VerseModel just to pass the ID to the menu.
    // In a real app, you would pass the full VerseModel.
    final dummyVerse = VerseModel(
      id: verseId,
      verseNumber: 0,
      verseKey: '',
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
          onDismiss: _removeMenu,
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
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
            final verses = state.verses;
            if (verses.isEmpty) {
              return QuranPageFrame(
                pageNumber: widget.pageNumber, 
                surahName: '',
                juzName: '',
                child: const SizedBox()
              );
            }

            final firstVerse = verses.first;
            final surahNumber = int.tryParse(firstVerse.verseKey.split(':').first) ?? 1;
            final surahName = QuranMetadata.getSurahName(surahNumber);
            final juzName = QuranMetadata.getJuzName(firstVerse.juzNumber);

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

                  // Group words by line number
                  final Map<int, List<WordModel>> lineGroups = {};
                  for (int i = 1; i <= 15; i++) {
                    lineGroups[i] = [];
                  }

                  // A map to find which verse a word belongs to based on verseKey
                  final Map<String, int> verseKeyToId = {};
                  for (var v in verses) {
                    verseKeyToId[v.verseKey] = v.id;
                    for (var w in v.words) {
                      if (lineGroups.containsKey(w.lineNumber)) {
                        lineGroups[w.lineNumber]!.add(w);
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
                          final lineWords = lineGroups[lineNumber] ?? [];

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
                              child: RichText(
                                textAlign: TextAlign.justify,
                                text: TextSpan(
                                  children: lineWords.map((word) {
                                    final verseId = verseKeyToId[word.verseKey] ?? 0;
                                    final isMenuHighlighted = _activeVerseId == verseId;
                                    final isAudioHighlighted = playingVerseId == verseId;
                                    final isActive = isMenuHighlighted || isAudioHighlighted;
                                    final backgroundColor = isActive ? AppColors.accentGold.withValues(alpha: 0.2) : Colors.transparent;

                                    if (word.charTypeName == 'end') {
                                      // Render the gorgeous verse marker
                                      return WidgetSpan(
                                        alignment: PlaceholderAlignment.middle,
                                        child: GestureDetector(
                                          onTapDown: (details) => _showMenu(context, details.globalPosition, verseId),
                                          child: Container(
                                            margin: const EdgeInsets.symmetric(horizontal: 4.0),
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: backgroundColor,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                // Ornate Star Background
                                                Icon(
                                                  Icons.brightness_7_rounded,
                                                  color: isAudioHighlighted ? AppColors.accentGold : const Color(0xFFC7A263).withValues(alpha: 0.8),
                                                  size: 30,
                                                ),
                                                // Inner precise circle
                                                Container(
                                                  width: 18,
                                                  height: 18,
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFAF5EB),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(color: const Color(0xFF5A4033), width: 0.5),
                                                  ),
                                                ),
                                                // Verse Number
                                                Text(
                                                  word.textUthmani,
                                                  style: TextStyle(
                                                    color: isAudioHighlighted ? AppColors.accentGold : const Color(0xFF5A4033),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }

                                    return TextSpan(
                                      text: '${word.textUthmani} ',
                                      style: AppTextStyles.quranText.copyWith(
                                        color: isAudioHighlighted ? AppColors.accentGold : AppColors.textPrimary,
                                        backgroundColor: backgroundColor,
                                      ),
                                      recognizer: TapGestureRecognizer()
                                        ..onTapDown = (details) {
                                          _showMenu(context, details.globalPosition, verseId);
                                        },
                                    );
                                  }).toList(),
                                ),
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
