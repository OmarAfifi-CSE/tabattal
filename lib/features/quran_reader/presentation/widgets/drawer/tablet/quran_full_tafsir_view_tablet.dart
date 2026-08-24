import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../../../l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/utils/arabic_text_utils.dart';
import '../../../../domain/repositories/quran_repository.dart';
import '../../../../data/datasources/quran_local_data_source.dart';
import '../../../../bloc/audio/audio_bloc.dart';
import '../../../../bloc/audio/audio_event.dart';
import '../../../../bloc/audio/audio_state.dart';
import '../../../../../../core/constants/quran_metadata.dart';
import '../../audio_settings_sheet.dart';
import '../../tafsir_selector_menu.dart';
import '../../../../domain/entities/download_state.dart';
import '../../../../../../core/error/failures.dart';
import '../../../../../../core/widgets/mixed_direction_text.dart';

class QuranFullTafsirViewTablet extends StatefulWidget {
  final int pageNumber;
  const QuranFullTafsirViewTablet({super.key, required this.pageNumber});

  @override
  State<QuranFullTafsirViewTablet> createState() =>
      _QuranFullTafsirViewTabletState();
}

class VerseTafsirData {
  final String verseKey;
  final String textUthmani;
  final String tafsirText;
  final int surah;
  final int ayah;
  final int page;
  final int verseId;
  final String? groupVerseRange;
  final bool isGroupContinuation;

  VerseTafsirData({
    required this.verseKey,
    required this.textUthmani,
    required this.tafsirText,
    required this.surah,
    required this.ayah,
    required this.page,
    this.groupVerseRange,
    this.isGroupContinuation = false,
  }) : verseId = surah * 1000 + ayah;
}

class _QuranFullTafsirViewTabletState extends State<QuranFullTafsirViewTablet> {
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
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  final Set<int> _downloadedTafsirs = {
    16,
  }; // Only bundled Muyassar; others checked dynamically

  late String _noTafsirText;

  @override
  void initState() {
    super.initState();
    _repository = context.read<QuranRepository>();
    _localDS = context.read<QuranLocalDataSource>();
    _loadPreferences();

    // Infinite scroll: load next surah when near end
    _itemPositionsListener.itemPositions.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _noTafsirText = AppLocalizations.of(context)!.noTafsirAvailable;
  }

  Future<void> _checkDownloadedTafsirs() async {
    const toCheck = [
      14,
      91,
      15,
      90,
      93,
      94,
      169,
      168,
      817,
    ]; // Include downloadable tafsirs
    final results = await Future.wait(
      toCheck.map((id) async {
        final progressResult = await _repository.getTafsirDownloadProgress(id);
        return progressResult.fold(
          (f) => null,
          (progress) => progress == 1.0 ? id : null,
        );
      }),
    );
    if (mounted) {
      final downloaded = results.whereType<int>();
      if (downloaded.isNotEmpty) {
        setState(() {
          _downloadedTafsirs.addAll(downloaded);
        });
      }
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final savedId = prefs.getInt('tafsir_id');
    int effectiveId;

    if (isEn) {
      if (savedId == null || ![169, 168, 817].contains(savedId)) {
        effectiveId = 169;
        await prefs.setInt('tafsir_id', 169);
      } else {
        effectiveId = savedId;
      }
    } else {
      if (savedId == null || [169, 168, 817].contains(savedId)) {
        effectiveId = 16;
        await prefs.setInt('tafsir_id', 16);
      } else {
        effectiveId = savedId;
      }
    }

    if (mounted) {
      setState(() {
        _tafsirResourceId = effectiveId;
      });
    }

    await _checkDownloadedTafsirs();
    if (!mounted) return;

    if (!_downloadedTafsirs.contains(effectiveId)) {
      if (mounted) {
        setState(() {
          _isLoadingInitial = false;
        });
      }
      _startDownload(effectiveId);
    } else {
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
      final maxIndex = positions
          .map((p) => p.index)
          .reduce((a, b) => a > b ? a : b);
      if (maxIndex >= _tafsirList.length - 8 &&
          !_isLoadingMore &&
          _currentSurahId < 114) {
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
        final index = _tafsirList.indexWhere(
          (e) => e.verseKey == _initialVerseKey,
        );
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
          final index = _tafsirList.indexWhere(
            (e) => e.verseKey == _initialVerseKey,
          );
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
    return ArabicTextUtils.cleanTafsirOrHtml(text);
  }

  Future<void> _loadSurahData(int surahId) async {
    final versesResult = await _repository.getVersesBySurah(surahId);
    await versesResult.fold((f) async => null, (verses) async {
      final tafsirRows = await _localDS.getTafsirsBySurah(
        surahId,
        _tafsirResourceId,
      );
      final Map<String, String> tafsirMap = {
        for (final row in tafsirRows)
          if ((row['text'] as String?)?.trim().isNotEmpty == true)
            row['verse_key'] as String: _cleanHtml(row['text'] as String),
      };

      final directAyahs = verses
          .where((v) => tafsirMap.containsKey(v.verseKey))
          .map((v) => v.ayah)
          .toList()
        ..sort();

      final List<VerseTafsirData> newItems = [];

      for (final verse in verses) {
        final rootAyah = directAyahs.lastWhere(
          (a) => a <= verse.ayah,
          orElse: () => verse.ayah,
        );

        final nextRootIndex = directAyahs.indexWhere((a) => a > rootAyah);
        final endAyah = nextRootIndex != -1
            ? directAyahs[nextRootIndex] - 1
            : (verses.isNotEmpty ? verses.last.ayah : rootAyah);

        String? groupRange;
        bool isContinuation = false;
        if (endAyah > rootAyah) {
          groupRange = '$rootAyah - $endAyah';
          isContinuation = verse.ayah > rootAyah;
        }

        String resolvedText = tafsirMap['$surahId:$rootAyah'] ?? _noTafsirText;

        newItems.add(
          VerseTafsirData(
            verseKey: verse.verseKey,
            textUthmani: verse.textUthmani,
            tafsirText: resolvedText,
            surah: verse.surah,
            ayah: verse.ayah,
            page: verse.page,
            groupVerseRange: groupRange,
            isGroupContinuation: isContinuation,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _tafsirList.addAll(newItems);
        });
      }
    });
  }

  /// Auto-scroll to the item matching the currently playing verse
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

  /// Change tafsir source and reload data at the CURRENT visible position
  void _changeTafsir(int resourceId) async {
    if (_tafsirResourceId == resourceId && _tafsirList.isNotEmpty) return;

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
      final minIndex = positions
          .map((p) => p.index)
          .reduce((a, b) => a < b ? a : b);
      if (minIndex < _tafsirList.length) {
        currentVerseKey = _tafsirList[minIndex].verseKey;
      }
    }
    currentVerseKey ??= _initialVerseKey;

    final targetSurah =
        int.tryParse(currentVerseKey?.split(':').first ?? '1') ?? 1;

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
            final index = _tafsirList.indexWhere(
              (e) => e.verseKey == currentVerseKey,
            );
            if (index != -1 && _itemScrollController.isAttached) {
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
            if (_tafsirList.isEmpty) {
              _initData();
            } else {
              _changeTafsir(resourceId);
            }
            return;
          case Failed(:final failure):
            setState(() {
              _isDownloading = false;
              if (failure is NetworkFailure) {
                _downloadError = l10n.downloadFailedInternet;
              } else {
                _downloadError =
                    'Failed to fetch content from the server. Please try again later.';
              }
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
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
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
            final minIndex = positions
                .map((p) => p.index)
                .reduce((a, b) => a < b ? a : b);
            if (minIndex >= 0 && minIndex < _tafsirList.length) {
              final currentVerse = _tafsirList[minIndex];
              pageToReturn = currentVerse.page;
              verseKeyToReturn = currentVerse.verseKey;
            }
          }
          Navigator.pop(context, {
            'page': pageToReturn,
            'verseKey': verseKeyToReturn,
          });
        },
        child: Scaffold(
          backgroundColor: AppColors.surfaceCream,
          appBar: AppBar(
            backgroundColor: AppColors.surfaceCream,
            elevation: 0,
            centerTitle: true,
            title: Text(
              l10n.fullTafsirTitle,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 24.sp,
              ),
            ),
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: AppColors.textPrimary,
                size: 26.sp,
              ),
              onPressed: () {
                int pageToReturn = widget.pageNumber;
                String? verseKeyToReturn;
                final positions = _itemPositionsListener.itemPositions.value;
                if (positions.isNotEmpty) {
                  final minIndex = positions
                      .map((p) => p.index)
                      .reduce((a, b) => a < b ? a : b);
                  if (minIndex >= 0 && minIndex < _tafsirList.length) {
                    final currentVerse = _tafsirList[minIndex];
                    pageToReturn = currentVerse.page;
                    verseKeyToReturn = currentVerse.verseKey;
                  }
                }
                Navigator.pop(context, {
                  'page': pageToReturn,
                  'verseKey': verseKeyToReturn,
                });
              },
            ),
            actions: [
              TafsirSelectorMenu(
                selectedId: _tafsirResourceId,
                options: TafsirOption.getLocalizedOptions(
                  context,
                  downloadedIds: _downloadedTafsirs,
                  activeDownloadingId:
                      _isDownloading ? _tafsirResourceId : null,
                  activeDownloadProgress: _downloadProgress,
                ),
                onSelected: _changeTafsir,
                itemHeight: 46.h,
                itemFontSize: 17.sp,
              ),
              SizedBox(width: 8.w),
            ],
          ),
          body: Column(
            children: [
              if ((_isDownloading || _downloadError != null) &&
                  _tafsirList.isNotEmpty)
                Container(
                  margin: EdgeInsets.all(16.r),
                  padding: EdgeInsets.all(14.r),
                  decoration: BoxDecoration(
                    color: _downloadError != null
                        ? Colors.red.withValues(alpha: 0.1)
                        : AppColors.accentGold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Row(
                    children: [
                      if (_isDownloading)
                        CupertinoActivityIndicator(
                          radius: 10.r,
                          color: AppColors.accentGold,
                        )
                      else
                        Icon(
                          Icons.error_outline,
                          size: 20.sp,
                          color: Colors.red,
                        ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          _isDownloading
                              ? l10n.downloadingTafsir(
                                  (_downloadProgress * 100).toInt(),
                                )
                              : _downloadError!,
                          style: AppTextStyles.menuItemText.copyWith(
                            fontSize: 15.sp,
                            color: _downloadError != null
                                ? Colors.red
                                : AppColors.accentGold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: _isLoadingInitial
                    ? Center(
                        child: CupertinoActivityIndicator(
                          color: AppColors.accentGold,
                          radius: 18.r,
                        ),
                      )
                    : _tafsirList.isEmpty
                    ? Center(
                        child: _isDownloading
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CupertinoActivityIndicator(
                                    color: AppColors.accentGold,
                                    radius: 20.r,
                                  ),
                                  SizedBox(height: 16.h),
                                  Text(
                                    l10n.downloadingTafsir(
                                      (_downloadProgress * 100).toInt(),
                                    ),
                                    style: AppTextStyles.menuItemText.copyWith(
                                      color: AppColors.textPrimary,
                                      fontSize: 18.sp,
                                    ),
                                  ),
                                ],
                              )
                            : (_downloadError != null
                                ? Padding(
                                    padding: EdgeInsets.all(24.r),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          size: 44.sp,
                                          color: Colors.red,
                                        ),
                                        SizedBox(height: 14.h),
                                        Text(
                                          _downloadError!,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 17.sp,
                                            color: Colors.red,
                                          ),
                                        ),
                                        SizedBox(height: 20.h),
                                        ElevatedButton(
                                          onPressed: () =>
                                              _startDownload(_tafsirResourceId),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                AppColors.accentGold,
                                            foregroundColor: Colors.white,
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 24.w,
                                              vertical: 12.h,
                                            ),
                                          ),
                                          child: Text(
                                            l10n.retry,
                                            style: TextStyle(fontSize: 16.sp),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : Text(
                                    l10n.noLocalData,
                                    style: TextStyle(
                                      fontSize: 18.sp,
                                      color: AppColors.textPrimary,
                                    ),
                                  )),
                      )
                    : ScrollablePositionedList.separated(
                        itemScrollController: _itemScrollController,
                        itemPositionsListener: _itemPositionsListener,
                        initialScrollIndex: _initialScrollIndex,
                        initialAlignment: 0.01,
                        padding: EdgeInsets.all(18.r),
                        itemCount: _tafsirList.length + 1,
                        separatorBuilder: (context, index) =>
                            SizedBox(height: 20.h),
                        itemBuilder: (context, index) {
                          if (index == _tafsirList.length) {
                            return _isLoadingMore
                                ? Padding(
                                    padding: EdgeInsets.all(16.r),
                                    child: Center(
                                      child: CupertinoActivityIndicator(
                                        color: AppColors.accentGold,
                                        radius: 14.r,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink();
                          }

                          final item = _tafsirList[index];

                          return Builder(
                            builder: (context) {
                              final audioStatus = context
                                  .select<AudioBloc, int>((bloc) {
                                    final state = bloc.state;
                                    if (state is AudioPlaying &&
                                        state.currentVerseId == item.verseId) {
                                      return 1;
                                    }
                                    if (state is AudioPaused &&
                                        state.currentVerseId == item.verseId) {
                                      return 2;
                                    }
                                    return 0;
                                  });
                              final isPlaying = audioStatus != 0;
                              final isActive = isPlaying;

                              return GestureDetector(
                                onTap: () {
                                  // Navigate back to this verse in the Quran
                                  Navigator.pop(context, {
                                    'page': item.page,
                                    'verseKey': item.verseKey,
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  padding: EdgeInsets.all(18.r),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? AppColors.accentGold.withValues(
                                            alpha: 0.08,
                                          )
                                        : AppColors.cardCream,
                                    borderRadius: BorderRadius.circular(18.r),
                                    border: Border.all(
                                      color: isActive
                                          ? AppColors.accentGold
                                          : AppColors.borderLight,
                                      width: isActive ? 2 : 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.textPrimary.withValues(
                                          alpha: 0.04,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      // Header row: surah name, ayah number, play button
                                      Row(
                                        textDirection: TextDirection.rtl,
                                        children: [
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 14.w,
                                              vertical: 6.h,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.accentGold
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(10.r),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  Localizations.localeOf(
                                                            context,
                                                          ).languageCode ==
                                                          'en'
                                                      ? QuranMetadata.getSurahNameEnglish(
                                                          item.surah,
                                                        )
                                                      : QuranMetadata.getSurahNameWithTashkeel(
                                                          item.surah,
                                                        ),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.accentGold,
                                                    fontSize: 20.sp,
                                                  ),
                                                ),
                                                SizedBox(width: 8.w),
                                                Text(
                                                  Localizations.localeOf(
                                                            context,
                                                          ).languageCode ==
                                                          'en'
                                                      ? '(${item.ayah})'
                                                      : '﴿${item.ayah.toArabicDigits}﴾',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.accentGold,
                                                    fontSize: 18.sp,
                                                    fontFamily: 'Amiri',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Spacer(),
                                          GestureDetector(
                                            onTap: () {
                                              if (audioStatus == 1) {
                                                context.read<AudioBloc>().add(
                                                  const PauseAudio(),
                                                );
                                              } else if (audioStatus == 2) {
                                                context.read<AudioBloc>().add(
                                                  const ResumeAudio(),
                                                );
                                              } else {
                                                showAudioSettingsSheet(
                                                  context,
                                                  verseId: item.verseId,
                                                );
                                              }
                                            },
                                            child: Icon(
                                              audioStatus == 1
                                                  ? Icons
                                                        .pause_circle_filled_rounded
                                                  : Icons
                                                        .play_circle_fill_rounded,
                                              color: AppColors.accentGold,
                                              size: 36.sp,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 16.h),
                                      // Quranic text
                                      Text.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(
                                              text:
                                                  '${ArabicTextUtils.removeExtendedUthmaniChars(item.textUthmani)} ',
                                              style: AppTextStyles.quranText
                                                  .copyWith(
                                                    fontSize: 28.sp,
                                                    height: 1.95.h,
                                                    color:
                                                        AppColors.textPrimary,
                                                  ),
                                            ),
                                            TextSpan(
                                              text:
                                                  '﴿${item.ayah.toArabicDigits}﴾',
                                              style: AppTextStyles.quranText
                                                  .copyWith(
                                                    fontFamily: 'Amiri',
                                                    fontSize: 26.sp,
                                                    height: 1.95.h,
                                                    color:
                                                        AppColors.textPrimary,
                                                  ),
                                            ),
                                          ],
                                        ),
                                        textAlign: TextAlign.right,
                                        textDirection: TextDirection.rtl,
                                      ),
                                      SizedBox(height: 14.h),
                                      Divider(color: AppColors.divider),
                                      SizedBox(height: 12.h),
                                      if (item.groupVerseRange != null) ...[
                                        Align(
                                          alignment: isAr
                                              ? Alignment.centerRight
                                              : Alignment.centerLeft,
                                          child: Container(
                                            margin: EdgeInsets.only(
                                              bottom: 12.h,
                                            ),
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 12.w,
                                              vertical: 6.h,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.accentGold
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(22.r),
                                              border: Border.all(
                                                color: AppColors.accentGold
                                                    .withValues(alpha: 0.3),
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  item.isGroupContinuation
                                                      ? Icons.link_rounded
                                                      : Icons
                                                          .collections_bookmark_rounded,
                                                  size: 17.sp,
                                                  color: AppColors.accentGold,
                                                ),
                                                SizedBox(width: 8.w),
                                                Text(
                                                  item.isGroupContinuation
                                                      ? (isAr
                                                          ? 'تابع تفسير الآيات (${ArabicTextUtils.convertEnglishToArabicDigits(item.groupVerseRange!)})'
                                                          : 'Continuation of Tafsir for Verses (${item.groupVerseRange})')
                                                      : (isAr
                                                          ? 'تفسير الآيات (${ArabicTextUtils.convertEnglishToArabicDigits(item.groupVerseRange!)})'
                                                          : 'Tafsir of Verses (${item.groupVerseRange})'),
                                                  style: TextStyle(
                                                    fontSize: 15.sp,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.accentGold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                      // Tafsir text
                                      MixedDirectionText(
                                        text: item.tafsirText,
                                        style: TextStyle(
                                          fontSize: 21.sp,
                                          height: 1.85.h,
                                          color: AppColors.textPrimary
                                              .withValues(alpha: 0.88),
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
