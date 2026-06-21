import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/verse_model.dart';
import '../bloc/quran/quran_bloc.dart';
import '../bloc/quran/quran_state.dart';
import '../bloc/audio/audio_bloc.dart';
import '../bloc/audio/audio_state.dart';
import '../bloc/bookmark/bookmark_bloc.dart';
import '../bloc/bookmark/bookmark_state.dart';
import '../widgets/quran_page_header.dart';
import '../widgets/quran_page_footer.dart';
import '../widgets/verse_action_menu.dart';

class QuranPage extends StatefulWidget {
  const QuranPage({super.key});

  @override
  State<QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends State<QuranPage> {
  int? _activeVerseId;
  OverlayEntry? _overlayEntry;

  void _showMenu(BuildContext context, Offset position, VerseModel verse) {
    if (_overlayEntry != null) {
      _removeMenu();
    }

    setState(() {
      _activeVerseId = verse.id;
    });

    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => VerseActionMenu(
        position: position,
        verse: verse,
        onDismiss: () {
          _removeMenu();
          setState(() {
            _activeVerseId = null;
          });
        },
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  void _removeMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _removeMenu();
    super.dispose();
  }

  String _toArabicNumber(int number) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return number.toString().split('').map((e) => arabicDigits[int.parse(e)]).join();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
          onPressed: () {},
        ),
        actions: [
          BlocBuilder<BookmarkBloc, BookmarkState>(
            builder: (context, state) {
              return IconButton(
                icon: Icon(
                  state.bookmarkedVerseKeys.isNotEmpty ? Icons.bookmark : Icons.bookmark_outline, 
                  color: AppColors.textPrimary,
                ),
                onPressed: () {},
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: BlocConsumer<QuranBloc, QuranState>(
          listener: (context, state) {
            if (state is QuranOverlayError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message)),
              );
            }
          },
          buildWhen: (previous, current) {
            // Only rebuild the main page on loaded/loading/error main states
            return current is QuranLoaded || current is QuranLoading || current is QuranError;
          },
          builder: (context, state) {
            if (state is QuranLoading) {
              return const Center(child: CircularProgressIndicator(color: AppColors.accentGold));
            } else if (state is QuranError) {
              return Center(child: Text(state.message, style: const TextStyle(color: Colors.red)));
            } else if (state is QuranLoaded) {
              final verses = state.verses;
              return Column(
                children: [
                  QuranPageHeader(
                    juzNumber: '١٢', // Hardcoded for mockup, ideally dynamic
                    surahName: state.currentSurahId?.toString() ?? 'يُوسُف', 
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.accentGold.withValues(alpha: 0.3),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.all(16.0),
                        child: BlocBuilder<AudioBloc, AudioState>(
                          builder: (context, audioState) {
                            int? playingVerseId;
                            if (audioState is AudioPlaying) {
                              playingVerseId = audioState.currentVerseId;
                            } else if (audioState is AudioPaused) {
                              playingVerseId = audioState.currentVerseId;
                            }

                            return SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: MediaQuery(
                                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
                                child: Directionality(
                                  textDirection: TextDirection.rtl,
                                  child: Text.rich(
                                    TextSpan(
                                    children: verses.map((verse) {
                                      final isMenuHighlighted = _activeVerseId == verse.id;
                                      final isAudioHighlighted = playingVerseId == verse.id;
                                      final isHighlighted = isMenuHighlighted || isAudioHighlighted;

                                      return TextSpan(
                                        text: '${verse.textUthmani} ',
                                        style: AppTextStyles.quranText.copyWith(
                                          backgroundColor: isHighlighted 
                                              ? AppColors.accentGold.withValues(alpha: 0.2) 
                                              : Colors.transparent,
                                        ),
                                        recognizer: TapGestureRecognizer()
                                          ..onTapDown = (details) {
                                            _showMenu(context, details.globalPosition, verse);
                                          },
                                        children: [
                                          WidgetSpan(
                                            alignment: PlaceholderAlignment.middle,
                                            child: GestureDetector(
                                              onTapDown: (details) {
                                                _showMenu(context, details.globalPosition, verse);
                                              },
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                                                child: Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    const Icon(
                                                      Icons.brightness_7,
                                                      color: AppColors.accentGold,
                                                      size: 32,
                                                    ),
                                                    Text(
                                                      _toArabicNumber(verse.verseNumber),
                                                      style: const TextStyle(
                                                        color: AppColors.textPrimary,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          const TextSpan(text: ' '),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                  textAlign: TextAlign.justify,
                                ),
                              ),
                             ),
                            );
                          }
                        ),
                      ),
                    ),
                  ),
                  const QuranPageFooter(pageNumber: '٢٣٥'),
                ],
              );
            }
            return const SizedBox();
          },
        ),
      ),
    );
  }
}
