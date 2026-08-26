import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../core/constants/quran_metadata.dart';
import '../../../../../core/network/audio_download_manager.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../../core/utils/app_snack_bar.dart';
import '../../../../../core/utils/reciter_localization.dart';
import '../shared/audio_selector_button.dart';

class QuranAudioManagerViewTablet extends StatefulWidget {
  const QuranAudioManagerViewTablet({super.key});

  @override
  State<QuranAudioManagerViewTablet> createState() =>
      _QuranAudioManagerViewTabletState();
}

class _QuranAudioManagerViewTabletState
    extends State<QuranAudioManagerViewTablet> {
  late final AudioDownloadManager _downloadManager;

  String _selectedCategory = AudioDownloadManager.reciterCategories.keys.first;
  late String _selectedReciter;

  // Track download status: 1.0=done, 0.0-0.99=partial/downloading, -1.0=not downloaded
  final Map<int, ValueNotifier<double>> _surahProgress = {};
  final Set<int> _activeDownloads = {};
  final Map<int, CancelToken> _activeCancelTokens = {};
  CancelToken? _batchCancelToken;
  bool _isLoadingStatus = true;
  bool _isDownloadingAll = false;

  @override
  void initState() {
    super.initState();
    _downloadManager = context.read<AudioDownloadManager>();
    _selectedReciter =
        AudioDownloadManager.reciterCategories[_selectedCategory]!.keys.first;
    _initializeProgressTrackers();
  }

  @override
  void dispose() {
    _batchCancelToken?.cancel('View disposed');
    for (final token in _activeCancelTokens.values) {
      token.cancel('View disposed');
    }
    for (final n in _surahProgress.values) {
      n.dispose();
    }
    super.dispose();
  }

  Future<void> _initializeProgressTrackers() async {
    if (!mounted) return;
    setState(() => _isLoadingStatus = true);

    for (int i = 1; i <= 114; i++) {
      _surahProgress[i] ??= ValueNotifier(-1.0);
      _surahProgress[i]!.value = -1.0;
    }

    final futures = <Future<void>>[];
    for (int i = 1; i <= 114; i++) {
      final surah = i;
      final numAyahs = QuranMetadata.surahLengths[surah - 1];
      futures.add(
        _downloadManager
            .getSurahDownloadProgress(
              _selectedCategory,
              _selectedReciter,
              surah,
              numAyahs,
            )
            .then((progress) {
          if (progress > 0 && mounted) {
            _surahProgress[surah]!.value = progress;
          }
        }),
      );
    }
    await Future.wait(futures);

    if (mounted) setState(() => _isLoadingStatus = false);
  }

  void _onReciterChanged(String newReciter) {
    if (_selectedReciter == newReciter) return;
    setState(() => _selectedReciter = newReciter);
    _initializeProgressTrackers();
  }

  Future<bool> _downloadSurah(
    int surah, {
    bool isBatch = false,
    CancelToken? cancelToken,
  }) async {
    if (_activeDownloads.contains(surah)) return true;
    final token = cancelToken ?? CancelToken();
    _activeCancelTokens[surah] = token;

    if (mounted) {
      setState(() => _activeDownloads.add(surah));
    } else {
      _activeDownloads.add(surah);
    }

    final notifier = _surahProgress[surah]!;
    if (notifier.value < 0) {
      notifier.value = 0.0;
    }

    final numAyahs = QuranMetadata.surahLengths[surah - 1];
    bool isSuccess = false;
    try {
      await _downloadManager.downloadSurah(
        _selectedCategory,
        _selectedReciter,
        surah,
        numAyahs,
        cancelToken: token,
        onProgress: (p) {
          if (mounted) {
            notifier.value = p;
          }
        },
      );
      isSuccess = true;
    } catch (e) {
      isSuccess = false;
      final isCancelled =
          token.isCancelled || (e is DioException && CancelToken.isCancel(e));
      if (mounted && !isCancelled) {
        final actualProgress = await _downloadManager.getSurahDownloadProgress(
          _selectedCategory,
          _selectedReciter,
          surah,
          numAyahs,
        );
        notifier.value = actualProgress > 0 ? actualProgress : -1.0;
      }
    } finally {
      _activeCancelTokens.remove(surah);
      if (mounted) {
        setState(() => _activeDownloads.remove(surah));
      } else {
        _activeDownloads.remove(surah);
      }
    }
    return isSuccess;
  }

  void _cancelSurahDownload(int surah) {
    if (_activeCancelTokens.containsKey(surah)) {
      _activeCancelTokens[surah]?.cancel('User cancelled download');
      _activeCancelTokens.remove(surah);
      _activeDownloads.remove(surah);
      if (mounted) setState(() {});
    }
  }

  Future<void> _downloadAll() async {
    final l10n = AppLocalizations.of(context)!;
    if (_isDownloadingAll) {
      _batchCancelToken?.cancel('Batch download cancelled');
      _batchCancelToken = null;
      setState(() => _isDownloadingAll = false);
      AppSnackBar.show(
        context,
        message: l10n.audioDownloadPaused,
        icon: Icons.pause_circle_outline_rounded,
      );
      return;
    }

    setState(() => _isDownloadingAll = true);
    _batchCancelToken = CancelToken();
    AppSnackBar.show(
      context,
      message: l10n.audioDownloadStartingAll,
      icon: Icons.downloading_rounded,
    );

    int failedCount = 0;
    for (int surah = 1; surah <= 114; surah++) {
      if (!mounted || !_isDownloadingAll) break;
      if (_surahProgress[surah]?.value == 1.0) continue;

      final success = await _downloadSurah(
        surah,
        isBatch: true,
        cancelToken: _batchCancelToken,
      );
      if (!success) {
        if (_batchCancelToken?.isCancelled ?? false) break;
        failedCount++;
      }
    }

    if (mounted) {
      setState(() => _isDownloadingAll = false);
      if (!(_batchCancelToken?.isCancelled ?? false)) {
        if (failedCount == 0) {
          AppSnackBar.showSuccess(
            context,
            l10n.audioDownloadAllSuccess,
          );
        } else {
          AppSnackBar.showError(
            context,
            l10n.audioDownloadFailedCount(failedCount),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final categories = AudioDownloadManager.reciterCategories.keys.toList();
    final reciters = AudioDownloadManager.reciterCategories[_selectedCategory]!;
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCream,
        elevation: 0,
        centerTitle: true,
        title: Text(
          l10n.audioManagerTitle,
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
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Directionality(
        textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
                child: Container(
                  padding: EdgeInsets.all(18.r),
                  decoration: BoxDecoration(
                    color: AppColors.cardCream,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: AppColors.accentGold.withValues(alpha: 0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.textPrimary.withValues(alpha: 0.03),
                        blurRadius: 8.r,
                        offset: Offset(0, 2.h),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isLandscape)
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.audioTypeLabel,
                                    style: TextStyle(
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  SizedBox(height: 6.h),
                                  AudioSelectorButton<String>(
                                    icon: Icons.category_rounded,
                                    label: l10n.audioTypeLabel,
                                    value: _selectedCategory,
                                    items: categories,
                                    height: 56.h,
                                    labelFontSize: 14.sp,
                                    valueFontSize: 17.sp,
                                    itemFontSize: 17.sp,
                                    iconSize: 24.sp,
                                    labelBuilder: (c) =>
                                        ReciterLocalization.localize(context, c),
                                    onChanged: (cat) {
                                      setState(() {
                                        _selectedCategory = cat;
                                        _selectedReciter = AudioDownloadManager
                                            .reciterCategories[cat]!
                                            .keys
                                            .first;
                                      });
                                      _initializeProgressTrackers();
                                    },
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.audioReciterLabel,
                                    style: TextStyle(
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  SizedBox(height: 6.h),
                                  AudioSelectorButton<String>(
                                    icon: Icons.person_rounded,
                                    label: l10n.audioReciterLabel,
                                    value: _selectedReciter,
                                    items: reciters.keys.toList(),
                                    height: 56.h,
                                    labelFontSize: 14.sp,
                                    valueFontSize: 17.sp,
                                    itemFontSize: 17.sp,
                                    iconSize: 24.sp,
                                    labelBuilder: (r) =>
                                        ReciterLocalization.localize(context, r),
                                    onChanged: _onReciterChanged,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      else ...[
                        Text(
                          l10n.audioTypeLabel,
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        AudioSelectorButton<String>(
                          icon: Icons.category_rounded,
                          label: l10n.audioTypeLabel,
                          value: _selectedCategory,
                          items: categories,
                          height: 56.h,
                          labelFontSize: 14.sp,
                          valueFontSize: 17.sp,
                          itemFontSize: 17.sp,
                          iconSize: 24.sp,
                          labelBuilder: (c) =>
                              ReciterLocalization.localize(context, c),
                          onChanged: (cat) {
                            setState(() {
                              _selectedCategory = cat;
                              _selectedReciter = AudioDownloadManager
                                  .reciterCategories[cat]!
                                  .keys
                                  .first;
                            });
                            _initializeProgressTrackers();
                          },
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          l10n.audioReciterLabel,
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        AudioSelectorButton<String>(
                          icon: Icons.person_rounded,
                          label: l10n.audioReciterLabel,
                          value: _selectedReciter,
                          items: reciters.keys.toList(),
                          height: 56.h,
                          labelFontSize: 14.sp,
                          valueFontSize: 17.sp,
                          itemFontSize: 17.sp,
                          iconSize: 24.sp,
                          labelBuilder: (r) =>
                              ReciterLocalization.localize(context, r),
                          onChanged: _onReciterChanged,
                        ),
                      ],
                      SizedBox(height: 16.h),
                      SizedBox(
                        height: 56.h,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isDownloadingAll
                                ? Colors.orangeAccent.shade700
                                : AppColors.accentGold,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                            elevation: 0,
                          ),
                          icon: _isDownloadingAll
                              ? Icon(
                                  Icons.pause_circle_outline_rounded,
                                  color: Colors.white,
                                  size: 24.sp,
                                )
                              : Icon(
                                  Icons.download_for_offline_rounded,
                                  color: Colors.white,
                                  size: 24.sp,
                                ),
                          label: Text(
                            _isDownloadingAll
                                ? l10n.audioDownloadPause
                                : l10n.audioDownloadAll,
                            style: TextStyle(
                              fontSize: 18.5.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          onPressed: _isLoadingStatus ? null : _downloadAll,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_isLoadingStatus)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32.r),
                  child: Center(
                    child: CupertinoActivityIndicator(
                      color: AppColors.accentGold,
                      radius: 16.r,
                    ),
                  ),
                ),
              )
            else if (isLandscape)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  16.w,
                  0,
                  16.w,
                  16.h + MediaQuery.paddingOf(context).bottom,
                ),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 4.8,
                    mainAxisSpacing: 8.h,
                    crossAxisSpacing: 16.w,
                  ),
                  itemCount: 114,
                  itemBuilder: (context, index) {
                    final surah = index + 1;
                    return _AudioManagerSurahItemTablet(
                      surah: surah,
                      progressNotifier: _surahProgress[surah]!,
                      isActivelyDownloading: _activeDownloads.contains(surah),
                      onDownload: () => _downloadSurah(surah),
                      onCancel: () => _cancelSurahDownload(surah),
                    );
                  },
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  16.w,
                  0,
                  16.w,
                  16.h + MediaQuery.paddingOf(context).bottom,
                ),
                sliver: SliverList.builder(
                  itemCount: 114,
                  itemBuilder: (context, index) {
                    final surah = index + 1;
                    return _AudioManagerSurahItemTablet(
                      surah: surah,
                      progressNotifier: _surahProgress[surah]!,
                      isActivelyDownloading: _activeDownloads.contains(surah),
                      onDownload: () => _downloadSurah(surah),
                      onCancel: () => _cancelSurahDownload(surah),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AudioManagerSurahItemTablet extends StatelessWidget {
  final int surah;
  final ValueNotifier<double> progressNotifier;
  final bool isActivelyDownloading;
  final VoidCallback onDownload;
  final VoidCallback onCancel;

  const _AudioManagerSurahItemTablet({
    required this.surah,
    required this.progressNotifier,
    required this.isActivelyDownloading,
    required this.onDownload,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final surahName = isEn
        ? QuranMetadata.getSurahNameEnglish(surah)
        : QuranMetadata.getSurahName(surah);

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: AppColors.cardCream,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: AppColors.accentGold.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.02),
            blurRadius: 4.r,
            offset: Offset(0, 1.h),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12.r),
        clipBehavior: Clip.antiAlias,
        child: ValueListenableBuilder<double>(
          valueListenable: progressNotifier,
          builder: (context, progress, _) {
            final isDownloaded = progress >= 1.0;
            final isPartiallyDownloaded =
                progress > 0.0 && progress < 1.0 && !isActivelyDownloading;

            Widget trailingWidget;
            if (isDownloaded) {
              trailingWidget = SizedBox(
                width: 68.w,
                height: 42.h,
                child: Center(
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green,
                    size: 30.sp,
                  ),
                ),
              );
            } else if (isActivelyDownloading) {
              trailingWidget = SizedBox(
                width: 68.w,
                height: 42.h,
                child: Center(
                  child: InkWell(
                    onTap: onCancel,
                    borderRadius: BorderRadius.circular(21.r),
                    child: SizedBox(
                      width: 42.r,
                      height: 42.r,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: progress <= 0.0 ? null : progress,
                            backgroundColor:
                                AppColors.accentGold.withValues(alpha: 0.15),
                            color: AppColors.accentGold,
                            strokeWidth: 3.5.r,
                          ),
                          Icon(
                            Icons.pause_rounded,
                            size: 20.sp,
                            color: AppColors.accentGold,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            } else if (isPartiallyDownloaded) {
              trailingWidget = SizedBox(
                width: 68.w,
                height: 42.h,
                child: InkWell(
                  onTap: onDownload,
                  borderRadius: BorderRadius.circular(21.r),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.accentGold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(21.r),
                      border: Border.all(
                        color: AppColors.accentGold.withValues(alpha: 0.4),
                        width: 1.0.r,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accentGold,
                          ),
                        ),
                        SizedBox(width: 3.w),
                        Icon(
                          Icons.download_rounded,
                          size: 18.sp,
                          color: AppColors.accentGold,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            } else {
              trailingWidget = SizedBox(
                width: 68.w,
                height: 42.h,
                child: Center(
                  child: IconButton(
                    icon: Icon(
                      Icons.download_rounded,
                      size: 26.sp,
                    ),
                    color: AppColors.accentGold,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onDownload,
                  ),
                ),
              );
            }

            return ListTile(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14.w,
                vertical: 4.h,
              ),
              minLeadingWidth: 46.w,
              leading: Container(
                width: 46.r,
                height: 46.r,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accentGold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  '$surah',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: (surah >= 100 ? 15 : 18).sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentGold,
                  ),
                ),
              ),
              title: Text(
                AppLocalizations.of(context)!.surahListItem(surahName),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 19.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              trailing: trailingWidget,
            );
          },
        ),
      ),
    );
  }
}
