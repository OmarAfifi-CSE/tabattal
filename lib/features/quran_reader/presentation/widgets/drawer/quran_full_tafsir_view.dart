import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../../l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/utils/arabic_text_utils.dart';
import '../../../../quran_reader/domain/repositories/quran_repository.dart';
import '../../../../quran_reader/data/datasources/quran_local_data_source.dart';
import '../../bloc/audio/audio_bloc.dart';
import '../../bloc/audio/audio_event.dart';
import '../../bloc/audio/audio_state.dart';
import '../quran_metadata.dart';
import '../audio_settings_sheet.dart';
import '../../../domain/entities/download_state.dart';

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
  int _initialScrollIndex = 0;

  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _downloadError;

  // Track which verseKey the user started from, so we can return to it when popping
  String? _initialVerseKey;

  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();

  final Set<int> _downloadedTafsirs = {16}; // Only bundled Muyassar; others checked dynamically

  late String _noTafsirText;

  @override
  void initState() {
    super.initState();
    _repository = context.read<QuranRepository>();
    _localDS = context.read<QuranLocalDataSource>();
    _loadPreferences();
    _checkDownloadedTafsirs();

    // Infinite scroll: load next surah when near end
    _itemPositionsListener.itemPositions.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _noTafsirText = AppLocalizations.of(context)!.noTafsirAvailable;
  }

  Future<void> _checkDownloadedTafsirs() async {
    final toCheck = [14, 91, 15, 90, 93, 94]; // Include newly-downloadable tafsir 14 & 91
    for (int id in toCheck) {
      final progressResult = await _repository.getTafsirDownloadProgress(id);
      progressResult.fold(
        (f) => null,
        (progress) {
          if (progress == 1.0 && mounted) {
            setState(() {
              _downloadedTafsirs.add(id);
            });
          }
        },
      );
    }
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
    final audioState = context.read<AudioBloc>().state;
    int? playingVerseId;
    if (audioState is AudioPlaying) playingVerseId = audioState.currentVerseId;
    if (audioState is AudioPaused) playingVerseId = audioState.currentVerseId;

    if (playingVerseId != null) {
      final surah = playingVerseId ~/ 1000;
      final ayah = playingVerseId % 1000;
      _currentSurahId = surah;
      _initialVerseKey = '$surah:$ayah';

      await _loadSurahData(_currentSurahId);

      if (_initialVerseKey != null) {
        final index = _tafsirList.indexWhere((e) => e.verseKey == _initialVerseKey);
        if (index != -1) {
          _initialScrollIndex = index;
        }
      }

      if (mounted) {
        setState(() => _isLoadingInitial = false);
      }
      return;
    }

    final linesResult = await _repository.getLinesByPage(widget.pageNumber);
    linesResult.fold(
      (f) {
        if (mounted) setState(() => _isLoadingInitial = false);
      },
      (lines) async {
        if (lines.isNotEmpty && lines.first.words.isNotEmpty) {
          final firstVerseKey = lines.first.words.first.verseKey;
          final parts = firstVerseKey.split(':');
          _currentSurahId = int.tryParse(parts[0]) ?? 1;
          _initialVerseKey = firstVerseKey;
        }

        await _loadSurahData(_currentSurahId);

        if (_initialVerseKey != null) {
          final index = _tafsirList.indexWhere((e) => e.verseKey == _initialVerseKey);
          if (index != -1) {
            _initialScrollIndex = index;
          }
        }

        if (mounted) {
          setState(() => _isLoadingInitial = false);
        }
      },
    );
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
    final versesResult = await _repository.getVersesBySurah(surahId);
    await versesResult.fold(
      (f) async => null,
      (verses) async {
        final tafsirRows = await _localDS.getTafsirsBySurah(surahId, _tafsirResourceId);
        final Map<String, String> tafsirMap = {
          for (final row in tafsirRows)
            row['verse_key'] as String: _cleanHtml(row['text'] as String)
        };

        final newItems = verses.map((verse) => VerseTafsirData(
          verseKey: verse.verseKey,
          textUthmani: verse.textUthmani,
          tafsirText: tafsirMap[verse.verseKey] ?? _noTafsirText,
          surah: verse.surah,
          ayah: verse.ayah,
          page: verse.page,
        )).toList();

        if (mounted) {
          setState(() {
            _tafsirList.addAll(newItems);
          });
        }
      },
    );
  }

  /// Auto-scroll to the item matching the currently playing verse, with padding so it's not under the AppBar
  void _scrollToPlayingVerse(int playingVerseId) {
    final index = _tafsirList.indexWhere((e) => e.verseId == playingVerseId);
    if (index != -1 && _itemScrollController.isAttached) {
      _itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.02,
      );
    }
  }

  /// Change tafsir source and reload data at the CURRENT visible position (not the beginning)
  void _changeTafsir(int resourceId) async {
    if (_tafsirResourceId == resourceId) return;

    if (!_downloadedTafsirs.contains(resourceId)) {
      _startDownload(resourceId);
      return;
    }

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
      if (mounted) {
        setState(() => _isLoadingInitial = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (currentVerseKey != null) {
            final index = _tafsirList.indexWhere((e) => e.verseKey == currentVerseKey);
            if (index != -1 && _itemScrollController.isAttached) {
              // EDIT THIS VALUE: 0.0 means exactly at the top.
              _itemScrollController.jumpTo(index: index, alignment: 0.0);
            }
          }
        });
      }
    });
  }

  Future<void> _startDownload(int resourceId) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadError = null;
    });

    try {
      await for (final state in _repository.downloadTafsir(resourceId)) {
        if (!mounted) return;
        switch (state) {
          case Progressing(:final progress):
            setState(() {
              _downloadProgress = progress;
            });
          case Completed():
            setState(() {
              _isDownloading = false;
              _downloadedTafsirs.add(resourceId);
            });
            _changeTafsir(resourceId);
            return;
          case Failed(:final failure):
            setState(() {
              _isDownloading = false;
              _downloadError = failure.message;
            });
            return;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadError = l10n.downloadFailedInternet;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
          backgroundColor: AppColors.surfaceCream,
          appBar: AppBar(
          backgroundColor: AppColors.surfaceCream,
          elevation: 0,
          centerTitle: true,
          title: Text(
            l10n.fullTafsirTitle,
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 22),
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
            PopupMenuButton<int>(
              splashRadius: 0,
              position: PopupMenuPosition.under,
              color: Colors.white,
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              icon: const Icon(Icons.tune_rounded, color: AppColors.accentGold),
              onSelected: _changeTafsir,
              itemBuilder: (context) {
                final options = [
                  (16, 'الميسر'),
                  (14, 'ابن كثير'),
                  (91, 'السعدي'),
                  (15, 'الطبري'),
                  (90, 'القرطبي'),
                  (93, 'الوسيط'),
                  (94, 'البغوي'),
                ];
                return options.map((option) {
                  final isSelected = option.$1 == _tafsirResourceId;
                  final isDownloaded = _downloadedTafsirs.contains(option.$1);
                  return PopupMenuItem<int>(
                    value: option.$1,
                    height: 36,
                    padding: EdgeInsets.zero,
                    child: Container(
                      width: double.infinity,
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.centerRight,
                      color: isSelected ? AppColors.accentGold.withValues(alpha: 0.1) : Colors.transparent,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (!isDownloaded)
                            Icon(Icons.download_rounded, size: 16, color: AppColors.accentGold.withValues(alpha: 0.7))
                          else
                            const SizedBox.shrink(),
                          Text(
                            option.$2,
                            style: AppTextStyles.menuItemText.copyWith(
                              fontSize: 14,
                              color: isSelected ? AppColors.accentGold : AppColors.textPrimary,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList();
              },
            ),
          ],
        ),
        body: Column(
          children: [
            if (_isDownloading || _downloadError != null)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _downloadError != null ? Colors.red.withValues(alpha: 0.1) : AppColors.accentGold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    if (_isDownloading)
                      SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, value: _downloadProgress, color: AppColors.accentGold),
                      )
                    else
                      const Icon(Icons.error_outline, size: 16, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isDownloading
                            ? l10n.downloadingTafsir((_downloadProgress * 100).toInt())
                            : _downloadError!,
                        style: AppTextStyles.menuItemText.copyWith(
                          fontSize: 12,
                          color: _downloadError != null ? Colors.red : AppColors.accentGold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _isLoadingInitial
                  ? const Center(child: CircularProgressIndicator(color: AppColors.accentGold))
                  : _tafsirList.isEmpty
                      ? Center(child: Text(l10n.noLocalData, style: const TextStyle(fontSize: 16, color: AppColors.textPrimary)))
                      : BlocBuilder<AudioBloc, AudioState>(
                          builder: (context, audioState) {
                      int? playingVerseId;
                      if (audioState is AudioPlaying) playingVerseId = audioState.currentVerseId;
                      if (audioState is AudioPaused) playingVerseId = audioState.currentVerseId;

                      return ScrollablePositionedList.separated(
                        itemScrollController: _itemScrollController,
                        itemPositionsListener: _itemPositionsListener,
                        initialScrollIndex: _initialScrollIndex,
                        initialAlignment: 0.01,
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
                                  color: isActive ? AppColors.accentGold : AppColors.borderLight,
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
                                              Localizations.localeOf(context).languageCode == 'en' ? QuranMetadata.getSurahNameEnglish(item.surah) : QuranMetadata.getSurahNameWithTashkeel(item.surah),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.accentGold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              Localizations.localeOf(context).languageCode == 'en' ? '(${item.ayah})' : '﴿${item.ayah.toArabicDigits}﴾',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.accentGold,
                                                fontSize: 14,
                                                fontFamily: 'Amiri',
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
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '${ArabicTextUtils.removeExtendedUthmaniChars(item.textUthmani)} ',
                                          style: AppTextStyles.quranText.copyWith(
                                            fontSize: 23,
                                            height: 1.9,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        TextSpan(
                                          text: '﴿${item.ayah.toArabicDigits}﴾',
                                          style: AppTextStyles.quranText.copyWith(
                                            fontFamily: 'Amiri',
                                            fontSize: 21,
                                            height: 1.9,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    textAlign: TextAlign.right,
                                    textDirection: TextDirection.rtl,
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
          ],
        ),
      ),
      ),
    );
  }
}
