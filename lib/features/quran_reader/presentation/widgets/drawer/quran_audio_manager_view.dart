import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/network/audio_download_manager.dart';
import '../../../../../../l10n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/constants/quran_metadata.dart';
import '../../../../../core/utils/reciter_localization.dart';
import '../../../../../core/utils/app_snack_bar.dart';
import '../audio_selector_button.dart';

class QuranAudioManagerView extends StatefulWidget {
  const QuranAudioManagerView({super.key});

  @override
  State<QuranAudioManagerView> createState() => _QuranAudioManagerViewState();
}

class _QuranAudioManagerViewState extends State<QuranAudioManagerView> {
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
        if (!mounted) return false;
        notifier.value = actualProgress > 0 ? actualProgress : -1.0;
        if (!isBatch) {
          final isEn = Localizations.localeOf(context).languageCode == 'en';
          final surahName = isEn
              ? QuranMetadata.getSurahNameEnglish(surah)
              : QuranMetadata.getSurahName(surah);
          AppSnackBar.showError(
            context,
            AppLocalizations.of(context)!.downloadFailed(surahName),
          );
        }
      }
    } finally {
      _activeCancelTokens.remove(surah);
      _activeDownloads.remove(surah);
      if (mounted) {
        final finalProgress = await _downloadManager.getSurahDownloadProgress(
          _selectedCategory,
          _selectedReciter,
          surah,
          numAyahs,
        );
        notifier.value = finalProgress >= 1.0
            ? 1.0
            : (finalProgress > 0 ? finalProgress : -1.0);
        setState(() {});
      }
    }
    return isSuccess;
  }

  Future<void> _downloadAll() async {
    if (_isDownloadingAll) {
      _isDownloadingAll = false;
      _batchCancelToken?.cancel('User paused download');
      _batchCancelToken = null;
      for (final token in _activeCancelTokens.values) {
        token.cancel('User paused download');
      }
      _activeCancelTokens.clear();
      if (mounted) {
        setState(() {});
        final isEn = Localizations.localeOf(context).languageCode == 'en';
        AppSnackBar.showInfo(
          context,
          isEn ? 'Download paused' : 'تم إيقاف التحميل مؤقتًا',
        );
      }
      return;
    }

    _batchCancelToken = CancelToken();
    setState(() => _isDownloadingAll = true);
    bool hadError = false;
    try {
      for (int i = 1; i <= 114; i++) {
        if (!mounted ||
            !_isDownloadingAll ||
            _batchCancelToken?.isCancelled == true) {
          break;
        }
        final currentProgress = _surahProgress[i]?.value ?? -1.0;
        if (currentProgress < 1.0) {
          final success = await _downloadSurah(
            i,
            isBatch: true,
            cancelToken: _batchCancelToken,
          );
          if (_batchCancelToken?.isCancelled == true || !_isDownloadingAll) {
            break;
          }
          if (!success) {
            hadError = true;
            break;
          }
        }
      }
    } finally {
      _batchCancelToken = null;
      if (mounted) {
        setState(() => _isDownloadingAll = false);
        final isEn = Localizations.localeOf(context).languageCode == 'en';
        if (hadError) {
          AppSnackBar.showError(
            context,
            isEn
                ? 'Download stopped. Please check your internet connection.'
                : 'تم إيقاف التحميل. يرجى التحقق من اتصالك بالإنترنت.',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final categories = AudioDownloadManager.reciterCategories.keys.toList();
    final reciters = AudioDownloadManager
        .reciterCategories[_selectedCategory]!
        .keys
        .toList();

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCream,
        elevation: 0,
        centerTitle: true,
        title: Text(
          AppLocalizations.of(context)!.audioManagerTitle,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        // RTL: leading icon is on the right side naturally
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            sliver: SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: AppColors.cardCream,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textPrimary.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Category Selector
                    AudioSelectorButton<String>(
                      icon: Icons.category_rounded,
                      label: AppLocalizations.of(context)!.audioTypeLabel,
                      value: _selectedCategory,
                      items: categories,
                      itemHeight: 42,
                      onChanged: (val) {
                        setState(() {
                          _selectedCategory = val;
                          _selectedReciter = AudioDownloadManager
                              .reciterCategories[val]!
                              .keys
                              .first;
                        });
                        _initializeProgressTrackers();
                      },
                      labelBuilder: (item) =>
                          ReciterLocalization.localizeByLang(isEn, item),
                    ),
                    const SizedBox(height: 10),

                    // Reciter Selector
                    AudioSelectorButton<String>(
                      icon: Icons.mic_rounded,
                      label: AppLocalizations.of(context)!.audioReciterLabel,
                      value: _selectedReciter,
                      items: reciters,
                      itemHeight: 42,
                      maxHeight: 210,
                      onChanged: (val) => _onReciterChanged(val),
                      labelBuilder: (item) =>
                          ReciterLocalization.localizeByLang(isEn, item),
                    ),
                    const SizedBox(height: 14),

                    // Download All button
                    SizedBox(
                      width: MediaQuery.sizeOf(context).width,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentGold,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        icon: _isDownloadingAll
                            ? const Icon(
                                Icons.pause_circle_outline_rounded,
                                color: Colors.white,
                              )
                            : const Icon(
                                Icons.download_for_offline_rounded,
                                color: Colors.white,
                              ),
                        label: Text(
                          _isDownloadingAll
                              ? (isEn ? 'Pause Download' : 'إيقاف التحميل')
                              : AppLocalizations.of(context)!.audioDownloadAll,
                          style: const TextStyle(
                            fontSize: 16,
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
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: CupertinoActivityIndicator(
                    color: AppColors.accentGold,
                    radius: 14,
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList.builder(
                itemCount: 114,
                itemBuilder: (context, index) => _buildSurahItem(index + 1),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSurahItem(int surah) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final surahName = isEn
        ? QuranMetadata.getSurahNameEnglish(surah)
        : QuranMetadata.getSurahName(surah);
    final notifier = _surahProgress[surah]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.cardCream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: ValueListenableBuilder<double>(
        valueListenable: notifier,
        builder: (context, progress, _) {
          final isDownloaded = progress >= 1.0;
          final isDownloading = progress >= 0.0 && progress < 1.0;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.accentGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '$surah',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentGold,
                  ),
                ),
              ),
            ),
            title: Text(
              AppLocalizations.of(context)!.surahListItem(surahName),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            trailing: isDownloaded
                ? const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green,
                    size: 28,
                  )
                : isDownloading
                ? SizedBox(
                    width: 42,
                    height: 42,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey.shade200,
                          color: AppColors.accentGold,
                          strokeWidth: 3,
                        ),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.download_rounded),
                    color: AppColors.accentGold,
                    onPressed: () => _downloadSurah(surah),
                  ),
          );
        },
      ),
    );
  }
}
