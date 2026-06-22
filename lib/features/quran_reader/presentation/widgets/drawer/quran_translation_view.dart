import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../quran_reader/domain/repositories/quran_repository.dart';
import '../../../../quran_reader/data/datasources/quran_local_data_source.dart';
import '../../bloc/audio/audio_bloc.dart';
import '../../bloc/audio/audio_event.dart';
import '../../bloc/audio/audio_state.dart';
import '../quran_metadata.dart';
import '../audio_settings_sheet.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class QuranTranslationView extends StatefulWidget {
  final int pageNumber;
  const QuranTranslationView({super.key, required this.pageNumber});

  @override
  State<QuranTranslationView> createState() => _QuranTranslationViewState();
}

class VerseTranslationData {
  final String verseKey;
  final String textUthmani;
  final String translationText;
  final int surah;
  final int ayah;
  final int page;
  final int verseId;

  VerseTranslationData({
    required this.verseKey,
    required this.textUthmani,
    required this.translationText,
    required this.surah,
    required this.ayah,
    required this.page,
  }) : verseId = surah * 1000 + ayah;
}

class _QuranTranslationViewState extends State<QuranTranslationView> {
  late final QuranRepository _repository;
  late final QuranLocalDataSource _localDS;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  final List<VerseTranslationData> _list = [];
  int _currentSurahId = 1;
  final int _translationResourceId = 20; // Default: Saheeh International

  String? _initialVerseKey;

  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();

  @override
  void initState() {
    super.initState();
    _repository = context.read<QuranRepository>();
    _localDS = context.read<QuranLocalDataSource>();
    _initData();
    _itemPositionsListener.itemPositions.addListener(_onScroll);
  }

  @override
  void dispose() {
    _itemPositionsListener.itemPositions.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isNotEmpty) {
      final maxIndex = positions.map((p) => p.index).reduce((a, b) => a > b ? a : b);
      if (maxIndex >= _list.length - 8 && !_isLoadingMore && _currentSurahId < 114) {
        _loadNextSurah();
      }
    }
  }

  Future<void> _initData() async {
    try {
      final lines = await _repository.getLinesByPage(widget.pageNumber);
      if (lines.isNotEmpty && lines.first.words.isNotEmpty) {
        final firstVerseKey = lines.first.words.first.verseKey;
        final parts = firstVerseKey.split(':');
        _currentSurahId = int.tryParse(parts[0]) ?? 1;
        _initialVerseKey = firstVerseKey;
      }

      await _loadSurahData(_currentSurahId);
      setState(() => _isLoadingInitial = false);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_initialVerseKey != null) {
          final index = _list.indexWhere((e) => e.verseKey == _initialVerseKey);
          if (index != -1) {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (_itemScrollController.isAttached) {
                _itemScrollController.jumpTo(index: index, alignment: 0.1);
              }
            });
          }
        }
      });
    } catch (e) {
      setState(() => _isLoadingInitial = false);
    }
  }

  Future<void> _loadNextSurah() async {
    if (_currentSurahId >= 114 || _isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    _currentSurahId++;
    await _loadSurahData(_currentSurahId);
    setState(() => _isLoadingMore = false);
  }

  String _cleanHtml(String text) {
    text = text.replaceAll(RegExp(r'<sup[^>]*>.*?<\/sup>', multiLine: true, caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'</p>|</li>|<br\s*/?>', caseSensitive: false), '\n\n');
    text = text.replaceAll(RegExp(r'<[^>]*>', multiLine: true, caseSensitive: false), '');
    // Remove printed page number annotations from digitized texts e.g. < 1-599 > or &lt; 1-599 &gt;
    text = text.replaceAll(RegExp(r'(<|&lt;)\s*\d+-\d+\s*(>|&gt;)', caseSensitive: false), '');
    text = text.replaceAll('&nbsp;', ' ').replaceAll('&quot;', '"').replaceAll('&#39;', "'").replaceAll('&amp;', '&').replaceAll('&lt;', '<').replaceAll('&gt;', '>');
    text = text.replaceAll('\\"', '"').replaceAll("\\'", "'");
    // Remove invisible unicode characters and fix non-breaking spaces
    text = text.replaceAll('\u200d', '').replaceAll('\u200c', '').replaceAll('\u200f', '').replaceAll('\u200e', '').replaceAll('\xa0', ' ');
    return text.replaceAll(RegExp(r' {3,}'), '  •  ').trim();
  }

  Future<void> _loadSurahData(int surahId) async {
    try {
      // Both from local DB — no network calls!
      final verses = await _repository.getVersesBySurah(surahId);
      final translationRows = await _localDS.getTranslationsBySurah(surahId, _translationResourceId);

      final Map<String, String> translationMap = {
        for (final row in translationRows)
          row['verse_key'] as String: _cleanHtml(row['text'] as String)
      };

      final newItems = verses.map((verse) => VerseTranslationData(
        verseKey: verse.verseKey,
        textUthmani: verse.textUthmani,
        translationText: translationMap[verse.verseKey] ?? 'Translation not available in local database.',
        surah: verse.surah,
        ayah: verse.ayah,
        page: verse.page,
      )).toList();

      _list.addAll(newItems);
    } catch (e) {
      debugPrint('Error loading translation for surah $surahId: $e');
    }
  }

  void _scrollToPlayingVerse(int playingVerseId) {
    final index = _list.indexWhere((e) => e.verseId == playingVerseId);
    if (index != -1 && _itemScrollController.isAttached) {
      _itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.15, // 15% from top = clear of AppBar
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AudioBloc, AudioState>(
      listenWhen: (prev, curr) {
        if (curr is! AudioPlaying) return false;
        if (prev is! AudioPlaying) return true;
        return prev.currentVerseId != curr.currentVerseId;
      },
      listener: (context, state) {
        if (state is AudioPlaying) _scrollToPlayingVerse(state.currentVerseId);
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, dynamic result) {
          if (didPop) return;
          int pageToReturn = widget.pageNumber;
          String? verseKeyToReturn;
          final positions = _itemPositionsListener.itemPositions.value;
          if (positions.isNotEmpty) {
            final minIndex = positions.map((p) => p.index).reduce((a, b) => a < b ? a : b);
            if (minIndex >= 0 && minIndex < _list.length) {
              final currentVerse = _list[minIndex];
              pageToReturn = currentVerse.page;
              verseKeyToReturn = currentVerse.verseKey;
            }
          }
          Navigator.pop(context, {'page': pageToReturn, 'verseKey': verseKeyToReturn});
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFFAF5EB),
          appBar: AppBar(
          backgroundColor: const Color(0xFFFAF5EB),
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'الترجمة الإنجليزية',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 22),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
            onPressed: () {
              int pageToReturn = widget.pageNumber;
              String? verseKeyToReturn;
              final positions = _itemPositionsListener.itemPositions.value;
              if (positions.isNotEmpty) {
                final minIndex = positions.map((p) => p.index).reduce((a, b) => a < b ? a : b);
                if (minIndex >= 0 && minIndex < _list.length) {
                  final currentVerse = _list[minIndex];
                  pageToReturn = currentVerse.page;
                  verseKeyToReturn = currentVerse.verseKey;
                }
              }
              Navigator.pop(context, {'page': pageToReturn, 'verseKey': verseKeyToReturn});
            },
          ),
        ),
        body: _isLoadingInitial
            ? const Center(child: CircularProgressIndicator(color: AppColors.accentGold))
            : _list.isEmpty
                ? const Center(child: Text('لا يوجد ترجمة في قاعدة البيانات المحلية', style: TextStyle(fontSize: 16, color: AppColors.textPrimary)))
                : BlocBuilder<AudioBloc, AudioState>(
                    builder: (context, audioState) {
                      int? playingVerseId;
                      if (audioState is AudioPlaying) playingVerseId = audioState.currentVerseId;
                      if (audioState is AudioPaused) playingVerseId = audioState.currentVerseId;

                      return ScrollablePositionedList.separated(
                        itemScrollController: _itemScrollController,
                        itemPositionsListener: _itemPositionsListener,
                        padding: const EdgeInsets.all(16),
                        itemCount: _list.length + 1,
                        separatorBuilder: (context, index) => const SizedBox(height: 20),
                        itemBuilder: (context, index) {
                          if (index == _list.length) {
                            return _isLoadingMore
                                ? const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(child: CircularProgressIndicator(color: AppColors.accentGold)),
                                  )
                                : const SizedBox.shrink();
                          }

                          final item = _list[index];
                          final isPlaying = playingVerseId == item.verseId;

                          return GestureDetector(
                            onTap: () => Navigator.pop(context, {'page': item.page, 'verseKey': item.verseKey}),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isPlaying ? AppColors.accentGold.withValues(alpha: 0.08) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isPlaying ? AppColors.accentGold : const Color(0xFFEFE8DA),
                                  width: isPlaying ? 2 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  )
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    textDirection: TextDirection.rtl,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.accentGold.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'سورة ${QuranMetadata.getSurahName(item.surah)}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accentGold, fontSize: 13),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '﴿${item.ayah}﴾',
                                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accentGold, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Spacer(),
                                      GestureDetector(
                                        onTap: () {
                                          if (isPlaying && audioState is AudioPlaying) {
                                            context.read<AudioBloc>().add(const PauseAudio());
                                          } else if (isPlaying && audioState is AudioPaused) {
                                            context.read<AudioBloc>().add(const ResumeAudio());
                                          } else {
                                             showAudioSettingsSheet(context, verseId: item.verseId);
                                          }
                                        },
                                        child: Icon(
                                          isPlaying && audioState is AudioPlaying
                                              ? Icons.pause_circle_filled_rounded
                                              : Icons.play_circle_fill_rounded,
                                          color: AppColors.accentGold,
                                          size: 32,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    '${item.textUthmani} ﴿${item.ayah}﴾',
                                    textAlign: TextAlign.right,
                                    textDirection: TextDirection.rtl,
                                    style: AppTextStyles.quranText.copyWith(fontSize: 23, height: 1.9, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(color: AppColors.divider),
                                  const SizedBox(height: 10),
                                  Text(
                                    item.translationText,
                                    textAlign: TextAlign.left,
                                    textDirection: TextDirection.ltr,
                                    style: TextStyle(fontSize: 17, height: 1.7, color: AppColors.textPrimary.withValues(alpha: 0.82)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
        ),
      ),
    );
  }
}
