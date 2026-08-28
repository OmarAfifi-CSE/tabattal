import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../../l10n/app_localizations.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/utils/arabic_text_utils.dart';
import '../../../../domain/repositories/quran_repository.dart';
import '../../../../data/datasources/quran_local_data_source.dart';
import '../../../../../quran_audio/presentation/bloc/audio_bloc.dart';
import '../../../../../quran_audio/presentation/bloc/audio_event.dart';
import '../../../../../quran_audio/presentation/bloc/audio_state.dart';
import '../../../../../../core/constants/quran_metadata.dart';
import '../../../../../quran_audio/presentation/widgets/shared/audio_settings_sheet.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class QuranTranslationViewMobile extends StatefulWidget {
  final int pageNumber;
  const QuranTranslationViewMobile({super.key, required this.pageNumber});

  @override
  State<QuranTranslationViewMobile> createState() => _QuranTranslationViewMobileState();
}

class VerseTranslationDataMobile {
  final String verseKey;
  final String textUthmani;
  final String translationText;
  final int surah;
  final int ayah;
  final int page;
  final int verseId;

  VerseTranslationDataMobile({
    required this.verseKey,
    required this.textUthmani,
    required this.translationText,
    required this.surah,
    required this.ayah,
    required this.page,
  }) : verseId = surah * 1000 + ayah;
}

class _QuranTranslationViewMobileState extends State<QuranTranslationViewMobile> {
  late final QuranRepository _repository;
  late final QuranLocalDataSource _localDS;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  final List<VerseTranslationDataMobile> _list = [];
  int _currentSurahId = 1;
  final int _translationResourceId = 20; // Default: Saheeh International
  int _initialScrollIndex = 0;

  String? _initialVerseKey;

  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  late String _noTranslationText;

  @override
  void initState() {
    super.initState();
    _repository = context.read<QuranRepository>();
    _localDS = context.read<QuranLocalDataSource>();
    _initData();
    _itemPositionsListener.itemPositions.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _noTranslationText = AppLocalizations.of(context)!.noLocalTranslation;
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
      if (maxIndex >= _list.length - 8 &&
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
        final index = _list.indexWhere((e) => e.verseKey == _initialVerseKey);
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
          final index = _list.indexWhere((e) => e.verseKey == _initialVerseKey);
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
      final translationRows = await _localDS.getTranslationsBySurah(
        surahId,
        _translationResourceId,
      );

      final Map<String, String> translationMap = {
        for (final row in translationRows)
          row['verse_key'] as String: _cleanHtml(row['text'] as String),
      };

      final newItems = verses
          .map(
            (verse) => VerseTranslationDataMobile(
              verseKey: verse.verseKey,
              textUthmani: verse.textUthmani,
              translationText:
                  translationMap[verse.verseKey] ?? _noTranslationText,
              surah: verse.surah,
              ayah: verse.ayah,
              page: verse.page,
            ),
          )
          .toList();

      if (mounted) {
        setState(() {
          _list.addAll(newItems);
        });
      }
    });
  }

  void _scrollToPlayingVerse(int playingVerseId) {
    final index = _list.indexWhere((e) => e.verseId == playingVerseId);
    if (index != -1 && _itemScrollController.isAttached) {
      _itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.02,
      );
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
            final minIndex = positions
                .map((p) => p.index)
                .reduce((a, b) => a < b ? a : b);
            if (minIndex >= 0 && minIndex < _list.length) {
              final currentVerse = _list[minIndex];
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
              l10n.translationTitle,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 22.sp,
              ),
            ),
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: AppColors.textPrimary,
              ),
              onPressed: () {
                int pageToReturn = widget.pageNumber;
                String? verseKeyToReturn;
                final positions = _itemPositionsListener.itemPositions.value;
                if (positions.isNotEmpty) {
                  final minIndex = positions
                      .map((p) => p.index)
                      .reduce((a, b) => a < b ? a : b);
                  if (minIndex >= 0 && minIndex < _list.length) {
                    final currentVerse = _list[minIndex];
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
          ),
          body: _isLoadingInitial
              ? Center(
                  child: CupertinoActivityIndicator(
                    color: AppColors.accentGold,
                    radius: 14.r,
                  ),
                )
              : _list.isEmpty
              ? Center(
                  child: Text(
                    l10n.noLocalTranslation,
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: AppColors.textPrimary,
                    ),
                  ),
                )
              : ScrollablePositionedList.separated(
                  itemScrollController: _itemScrollController,
                  itemPositionsListener: _itemPositionsListener,
                  initialScrollIndex: _initialScrollIndex,
                  initialAlignment: 0.01,
                  padding: EdgeInsets.all(16.r),
                  itemCount: _list.length + 1,
                  separatorBuilder: (context, index) =>
                      SizedBox(height: 20.h),
                  itemBuilder: (context, index) {
                    if (index == _list.length) {
                      return _isLoadingMore
                          ? Padding(
                              padding: EdgeInsets.all(16.r),
                              child: Center(
                                child: CupertinoActivityIndicator(
                                  color: AppColors.accentGold,
                                  radius: 12.r,
                                ),
                              ),
                            )
                          : const SizedBox.shrink();
                    }

                    final item = _list[index];

                    return Builder(
                      builder: (context) {
                        final audioStatus = context.select<AudioBloc, int>((
                          bloc,
                        ) {
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

                        return GestureDetector(
                          onTap: () => Navigator.pop(context, {
                            'page': item.page,
                            'verseKey': item.verseKey,
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: EdgeInsets.all(16.r),
                            decoration: BoxDecoration(
                              color: isPlaying
                                  ? AppColors.accentGold.withValues(alpha: 0.08)
                                  : AppColors.cardCream,
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(
                                color: isPlaying
                                    ? AppColors.accentGold
                                    : AppColors.borderLight,
                                width: isPlaying ? 2 : 1,
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
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  textDirection: TextDirection.rtl,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10.w,
                                        vertical: 4.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.accentGold.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(8.r),
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
                                              fontSize: 16.sp,
                                            ),
                                          ),
                                          SizedBox(width: 6.w),
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
                                              fontSize: 14.sp,
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
                                            ? Icons.pause_circle_filled_rounded
                                            : Icons.play_circle_fill_rounded,
                                        color: AppColors.accentGold,
                                        size: 32.r,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 14.h),
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text:
                                            '${ArabicTextUtils.removeExtendedUthmaniChars(item.textUthmani)} ',
                                        style: AppTextStyles.quranText.copyWith(
                                          fontSize: 23.sp,
                                          height: 1.9,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      TextSpan(
                                        text: '﴿${item.ayah.toArabicDigits}﴾',
                                        style: AppTextStyles.quranText.copyWith(
                                          fontFamily: 'Amiri',
                                          fontSize: 21.sp,
                                          height: 1.9,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  textAlign: TextAlign.right,
                                  textDirection: TextDirection.rtl,
                                ),
                                SizedBox(height: 12.h),
                                Divider(color: AppColors.divider),
                                SizedBox(height: 10.h),
                                Text(
                                  item.translationText,
                                  textAlign: TextAlign.left,
                                  textDirection: TextDirection.ltr,
                                  style: TextStyle(
                                    fontSize: 17.sp,
                                    height: 1.7,
                                    color: AppColors.textPrimary.withValues(
                                      alpha: 0.82,
                                    ),
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
}
