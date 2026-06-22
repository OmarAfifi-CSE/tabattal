import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../quran_reader/domain/repositories/quran_repository.dart';
import '../../../../quran_reader/data/datasources/quran_local_data_source.dart';
import '../../bloc/audio/audio_bloc.dart';
import '../../bloc/audio/audio_event.dart';
import '../../bloc/audio/audio_state.dart';
import '../quran_metadata.dart';
import '../audio_settings_sheet.dart';

class QuranFullTafsirView extends StatefulWidget {
  final int pageNumber;
  const QuranFullTafsirView({super.key, required this.pageNumber});

  @override
  State<QuranFullTafsirView> createState() => _QuranFullTafsirViewState();
}

class VerseTafsirData {
  final String verseKey;
  final String textUthmani;
  final String tafsirText;
  final int surah;
  final int ayah;
  final int page;
  final int verseId;

  VerseTafsirData({
    required this.verseKey,
    required this.textUthmani,
    required this.tafsirText,
    required this.surah,
    required this.ayah,
    required this.page,
  }) : verseId = surah * 1000 + ayah;
}

class _QuranFullTafsirViewState extends State<QuranFullTafsirView> {
  late final QuranRepository _repository;
  late final QuranLocalDataSource _localDS;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  final List<VerseTafsirData> _tafsirList = [];
  int _currentSurahId = 1;
  int _tafsirResourceId = 16; // Default: Al-Muyassar

  // Track which verseKey the user started from, so we can return to it when popping
  String? _initialVerseKey;

  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();

  @override
  void initState() {
    super.initState();
    _repository = context.read<QuranRepository>();
    _localDS = context.read<QuranLocalDataSource>();
    _loadPreferences();

    // Infinite scroll: load next surah when near end
    _itemPositionsListener.itemPositions.addListener(_onScroll);
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _tafsirResourceId = prefs.getInt('tafsir_id') ?? 16;
      });
      _initData();
    }
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
      if (maxIndex >= _tafsirList.length - 8 && !_isLoadingMore && _currentSurahId < 114) {
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

      // Find the index of the verse and scroll to it
      if (_initialVerseKey != null) {
        final index = _tafsirList.indexWhere((e) => e.verseKey == _initialVerseKey);
        if (index != -1) {
          // Delay briefly to allow the list to build and attach
          Future.delayed(const Duration(milliseconds: 100), () {
            if (_itemScrollController.isAttached) {
              _itemScrollController.jumpTo(index: index, alignment: 0.1);
            }
          });
        }
      }
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
      // Both fetched from local DB — no network calls!
      final verses = await _repository.getVersesBySurah(surahId);
      final tafsirRows = await _localDS.getTafsirsBySurah(surahId, _tafsirResourceId);

      // Map verseKey -> tafsir text
      final Map<String, String> tafsirMap = {
        for (final row in tafsirRows)
          row['verse_key'] as String: _cleanHtml(row['text'] as String)
      };

      final newItems = verses.map((verse) => VerseTafsirData(
        verseKey: verse.verseKey,
        textUthmani: verse.textUthmani,
        tafsirText: tafsirMap[verse.verseKey] ?? 'لا يوجد تفسير متاح',
        surah: verse.surah,
        ayah: verse.ayah,
        page: verse.page,
      )).toList();

      _tafsirList.addAll(newItems);
    } catch (e) {
      debugPrint('Error loading tafsir for surah $surahId: $e');
    }
  }

  /// Auto-scroll to the item matching the currently playing verse, with padding so it's not under the AppBar
  void _scrollToPlayingVerse(int playingVerseId) {
    final index = _tafsirList.indexWhere((e) => e.verseId == playingVerseId);
    if (index != -1 && _itemScrollController.isAttached) {
      _itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.15, // 15% from top = clear of AppBar
      );
    }
  }

  /// Change tafsir source and reload data at the CURRENT visible position (not the beginning)
  void _changeTafsir(int resourceId) async {
    if (_tafsirResourceId == resourceId) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('tafsir_id', resourceId);

    // Remember which verse is currently at the top of the visible area
    String? currentVerseKey;
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isNotEmpty) {
      final minIndex = positions.map((p) => p.index).reduce((a, b) => a < b ? a : b);
      if (minIndex < _tafsirList.length) {
        currentVerseKey = _tafsirList[minIndex].verseKey;
      }
    }
    currentVerseKey ??= _initialVerseKey;

    final targetSurah = int.tryParse(currentVerseKey?.split(':').first ?? '1') ?? 1;

    setState(() {
      _tafsirResourceId = resourceId;
      _tafsirList.clear();
      _currentSurahId = targetSurah;
      _isLoadingInitial = true;
    });

    _loadSurahData(targetSurah).then((_) {
      setState(() => _isLoadingInitial = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (currentVerseKey != null) {
          final index = _tafsirList.indexWhere((e) => e.verseKey == currentVerseKey);
          if (index != -1 && _itemScrollController.isAttached) {
            _itemScrollController.jumpTo(index: index);
          }
        }
      });
    });
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
        if (state is AudioPlaying) {
          _scrollToPlayingVerse(state.currentVerseId);
        }
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
            if (minIndex >= 0 && minIndex < _tafsirList.length) {
              final currentVerse = _tafsirList[minIndex];
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
            'التفسير الشامل',
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
                if (minIndex >= 0 && minIndex < _tafsirList.length) {
                  final currentVerse = _tafsirList[minIndex];
                  pageToReturn = currentVerse.page;
                  verseKeyToReturn = currentVerse.verseKey;
                }
              }
              Navigator.pop(context, {'page': pageToReturn, 'verseKey': verseKeyToReturn});
            },
          ),
          actions: [
            // Tafsir source picker
            PopupMenuButton<int>(
              position: PopupMenuPosition.under,
              color: Colors.white,
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              icon: const Icon(Icons.tune_rounded, color: AppColors.accentGold),
              onSelected: _changeTafsir,
              itemBuilder: (context) => [
                _tafsirOption(16, 'الميسر'),
                _tafsirOption(14, 'ابن كثير'),
                _tafsirOption(91, 'السعدي'),
              ],
            ),
          ],
        ),
        body: _isLoadingInitial
            ? const Center(child: CircularProgressIndicator(color: AppColors.accentGold))
            : _tafsirList.isEmpty
                ? const Center(child: Text('لا يوجد بيانات في قاعدة البيانات المحلية', style: TextStyle(fontSize: 16, color: AppColors.textPrimary)))
                : BlocBuilder<AudioBloc, AudioState>(
                    builder: (context, audioState) {
                      int? playingVerseId;
                      if (audioState is AudioPlaying) playingVerseId = audioState.currentVerseId;
                      if (audioState is AudioPaused) playingVerseId = audioState.currentVerseId;

                      return ScrollablePositionedList.separated(
                        itemScrollController: _itemScrollController,
                        itemPositionsListener: _itemPositionsListener,
                        padding: const EdgeInsets.all(16),
                        itemCount: _tafsirList.length + 1,
                        separatorBuilder: (context, index) => const SizedBox(height: 20),
                        itemBuilder: (context, index) {
                          if (index == _tafsirList.length) {
                            return _isLoadingMore
                                ? const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(child: CircularProgressIndicator(color: AppColors.accentGold)),
                                  )
                                : const SizedBox.shrink();
                          }

                          final item = _tafsirList[index];
                          final isPlaying = playingVerseId == item.verseId;
                          final isActive = isPlaying;

                          return GestureDetector(
                            onTap: () {
                              // Navigate back to this verse in the Quran
                              Navigator.pop(context, {'page': item.page, 'verseKey': item.verseKey});
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isActive ? AppColors.accentGold.withValues(alpha: 0.08) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isActive ? AppColors.accentGold : const Color(0xFFEFE8DA),
                                  width: isActive ? 2 : 1,
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
                                  // Header row: surah name, ayah number, play button
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
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.accentGold,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '﴿${item.ayah}﴾',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.accentGold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Spacer(),
                                      // Play button → opens audio settings sheet
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
                                  // Quranic text
                                  Text(
                                    '${item.textUthmani} ﴿${item.ayah}﴾',
                                    textAlign: TextAlign.right,
                                    textDirection: TextDirection.rtl,
                                    style: AppTextStyles.quranText.copyWith(
                                      fontSize: 23,
                                      height: 1.9,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(color: AppColors.divider),
                                  const SizedBox(height: 10),
                                  // Tafsir text
                                  Text(
                                    item.tafsirText,
                                    textAlign: TextAlign.right,
                                    textDirection: TextDirection.rtl,
                                    style: TextStyle(
                                      fontSize: 17,
                                      height: 1.7,
                                      color: AppColors.textPrimary.withValues(alpha: 0.82),
                                    ),
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

  PopupMenuItem<int> _tafsirOption(int id, String label) {
    return PopupMenuItem<int>(
      value: id,
      height: 40,
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.centerRight,
        color: _tafsirResourceId == id ? AppColors.accentGold.withValues(alpha: 0.1) : Colors.transparent,
        child: Text(
          label,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
            fontWeight: _tafsirResourceId == id ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
