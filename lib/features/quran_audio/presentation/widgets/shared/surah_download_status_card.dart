import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../bloc/audio_bloc.dart';
import '../../bloc/audio_event.dart';
import '../../../../../core/constants/quran_metadata.dart';
import '../../../../../core/network/audio_download_manager.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/utils/app_snack_bar.dart';
import '../../../../../core/utils/reciter_localization.dart';
import '../../../../../l10n/app_localizations.dart';
export 'reciter_category_badge.dart';

/// A luxury, unified card displaying the download status of a surah
/// (Offline Ready vs Live Streaming) and offering direct 1-tap download with real-time progress.
class SurahDownloadStatusCard extends StatefulWidget {
  final int surahNumber;
  final String category;
  final String reciterKey;
  final AudioDownloadManager? downloadManager;
  final VoidCallback? onDownloadCompleted;

  const SurahDownloadStatusCard({
    super.key,
    required this.surahNumber,
    required this.category,
    required this.reciterKey,
    this.downloadManager,
    this.onDownloadCompleted,
  });

  @override
  State<SurahDownloadStatusCard> createState() => _SurahDownloadStatusCardState();
}

class _SurahDownloadStatusCardState extends State<SurahDownloadStatusCard> {
  late AudioDownloadManager _manager;
  bool _isDownloaded = false;
  bool _isLoadingStatus = true;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  StreamSubscription<double>? _progressSub;

  @override
  void initState() {
    super.initState();
    _manager = widget.downloadManager ?? AudioDownloadManager();
    _checkStatus();
  }

  @override
  void didUpdateWidget(covariant SurahDownloadStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.surahNumber != widget.surahNumber ||
        oldWidget.category != widget.category ||
        oldWidget.reciterKey != widget.reciterKey) {
      _progressSub?.cancel();
      _checkStatus();
    }
  }

  @override
  void dispose() {
    // Cancel the UI progress stream subscription, but DO NOT abort the active download!
    // The download will continue seamlessly in the background via AudioDownloadManager.
    _progressSub?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    if (kIsWeb) {
      if (mounted) {
        setState(() {
          _isDownloaded = false;
          _isLoadingStatus = false;
        });
      }
      return;
    }

    // 1. Check if this surah is actively downloading in background
    if (_manager.isSurahDownloading(
      widget.category,
      widget.reciterKey,
      widget.surahNumber,
    )) {
      if (mounted) {
        setState(() {
          _isDownloading = true;
          _downloadProgress = _manager.getActiveSurahDownloadProgress(
            widget.category,
            widget.reciterKey,
            widget.surahNumber,
          );
          _isDownloaded = false;
          _isLoadingStatus = false;
        });

        _progressSub?.cancel();
        final stream = _manager.getSurahDownloadProgressStream(
          widget.category,
          widget.reciterKey,
          widget.surahNumber,
        );
        if (stream != null) {
          _progressSub = stream.listen((progress) {
            if (mounted) {
              setState(() {
                _downloadProgress = progress.clamp(0.01, 1.0);
                if (progress >= 1.0) {
                  _isDownloading = false;
                  _isDownloaded = true;
                }
              });
            }
          });
        }
      }
      return;
    }

    setState(() => _isLoadingStatus = true);

    try {
      final numAyahs = QuranMetadata.surahLengthOf(widget.surahNumber);
      final downloaded = await _manager.isSurahDownloaded(
        widget.category,
        widget.reciterKey,
        widget.surahNumber,
        numAyahs,
      );

      if (mounted) {
        setState(() {
          _isDownloaded = downloaded;
          _isLoadingStatus = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingStatus = false);
      }
    }
  }

  void _startDownload() async {
    if (_isDownloading || kIsWeb) return;

    final audioBloc = context.read<AudioBloc>();
    final rootMessenger = ScaffoldMessenger.maybeOf(context);
    final langCode = Localizations.localeOf(context).languageCode;
    final surahName =
        QuranMetadata.getSurahNameForLocale(langCode, widget.surahNumber);
    final l10n = AppLocalizations.of(context)!;
    final successMsg = l10n.audioDownloadSuccess(surahName);

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.01;
    });

    final numAyahs = QuranMetadata.surahLengthOf(widget.surahNumber);

    _progressSub?.cancel();
    final stream = _manager.getSurahDownloadProgressStream(
      widget.category,
      widget.reciterKey,
      widget.surahNumber,
    );
    if (stream != null) {
      _progressSub = stream.listen((progress) {
        if (mounted) {
          setState(() => _downloadProgress = progress.clamp(0.01, 1.0));
        }
      });
    }

    try {
      await _manager.downloadSurah(
        widget.category,
        widget.reciterKey,
        widget.surahNumber,
        numAyahs,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _downloadProgress = progress.clamp(0.01, 1.0);
            });
          }
        },
      );

      // Notify AudioBloc to promote playback seamlessly from live stream to local file
      audioBloc.add(
        SurahDownloadedEvent(
          surahNumber: widget.surahNumber,
          category: widget.category,
          reciterKey: widget.reciterKey,
        ),
      );

      if (mounted) {
        // Bottom sheet is STILL OPEN: reflect state with rich haptic feedback without SnackBar clutter
        setState(() {
          _isDownloading = false;
          _isDownloaded = true;
          _downloadProgress = 1.0;
        });

        HapticFeedback.lightImpact();
        widget.onDownloadCompleted?.call();
      } else {
        // Bottom sheet was CLOSED while downloading: show SnackBar on the main screen!
        if (rootMessenger != null && rootMessenger.mounted) {
          rootMessenger.hideCurrentSnackBar();
          rootMessenger.showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    color: AppColors.accentGold,
                    size: 20.sp,
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      successMsg,
                      style: TextStyle(
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.cardCream,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
                side: BorderSide(
                  color: AppColors.accentGold.withValues(alpha: 0.5),
                  width: 1.2,
                ),
              ),
              margin: EdgeInsets.all(16.r),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });

        AppSnackBar.show(
          context,
          message: l10n.audioDownloadError,
          isError: true,
        );
      }
    }
  }

  void _cancelDownload({bool silent = false}) {
    _manager.cancelSurahDownload(
      widget.category,
      widget.reciterKey,
      widget.surahNumber,
    );
    _progressSub?.cancel();
    if (!silent && mounted) {
      setState(() {
        _isDownloading = false;
        _downloadProgress = 0.0;
      });
    }
  }

  Future<void> _deleteSurah() async {
    context.read<AudioBloc>().add(
      SurahDeletedEvent(
        surahNumber: widget.surahNumber,
        category: widget.category,
        reciterKey: widget.reciterKey,
      ),
    );

    final numAyahs = QuranMetadata.surahLengthOf(widget.surahNumber);
    await _manager.deleteSurah(
      widget.category,
      widget.reciterKey,
      widget.surahNumber,
      numAyahs,
    );

    if (mounted) {
      setState(() => _isDownloaded = false);
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();

    final langCode = Localizations.localeOf(context).languageCode;
    final surahName =
        QuranMetadata.getSurahNameForLocale(langCode, widget.surahNumber);
    final reciterName = ReciterLocalization.localize(context, widget.reciterKey);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 4.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceCream,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: _isDownloaded
              ? AppColors.accentGold.withValues(alpha: 0.6)
              : AppColors.accentGold.withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _isLoadingStatus
            ? SizedBox(
                height: 38.h,
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentGold),
                    ),
                  ),
                ),
              )
            : _isDownloading
                ? _buildDownloadingView(surahName, l10n)
                : _isDownloaded
                    ? _buildDownloadedView(surahName, reciterName, l10n)
                    : _buildStreamingView(surahName, reciterName, l10n),
      ),
    );
  }

  Widget _buildDownloadedView(String surahName, String reciterName, AppLocalizations l10n) {
    return Row(
      key: const ValueKey('downloaded'),
      children: [
        Container(
          width: 34.r,
          height: 34.r,
          decoration: BoxDecoration(
            color: AppColors.accentGold.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.verified_rounded,
            color: AppColors.accentGold,
            size: 20.sp,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.audioSurahDownloadedTitle(surahName),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.menuItemText.copyWith(
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                l10n.audioSurahDownloadedSubtitle,
                style: TextStyle(
                  fontSize: 11.5.sp,
                  color: AppColors.accentGold,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: l10n.audioDeleteFromDeviceTooltip,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(
            Icons.delete_outline_rounded,
            color: AppColors.textSecondary.withValues(alpha: 0.7),
            size: 20.sp,
          ),
          onPressed: _deleteSurah,
        ),
      ],
    );
  }

  Widget _buildStreamingView(String surahName, String reciterName, AppLocalizations l10n) {
    return Column(
      key: const ValueKey('streaming'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 32.r,
              height: 32.r,
              decoration: BoxDecoration(
                color: AppColors.bronzeIcon.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_outlined,
                color: AppColors.bronzeIcon,
                size: 18.sp,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.audioLiveStreamTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.menuItemText.copyWith(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    l10n.audioLiveStreamSubtitle(surahName),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        InkWell(
          onTap: _startDownload,
          borderRadius: BorderRadius.circular(8.r),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 7.h, horizontal: 10.w),
            decoration: BoxDecoration(
              color: AppColors.accentGold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(
                color: AppColors.accentGold.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.download_rounded,
                  size: 16.sp,
                  color: AppColors.accentGold,
                ),
                SizedBox(width: 6.w),
                Flexible(
                  child: Text(
                    l10n.audioDownloadSurahButton(surahName),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentGold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadingView(String surahName, AppLocalizations l10n) {
    final pct = (_downloadProgress * 100).toInt();

    return Column(
      key: const ValueKey('downloading'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14.r,
                  height: 14.r,
                  child: CircularProgressIndicator(
                    value: _downloadProgress,
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentGold),
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  l10n.audioDownloadingProgress(surahName, pct),
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            IconButton(
              tooltip: l10n.audioCancelDownloadTooltip,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                Icons.close_rounded,
                size: 18.sp,
                color: AppColors.textSecondary,
              ),
              onPressed: () => _cancelDownload(),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(4.r),
          child: LinearProgressIndicator(
            value: _downloadProgress,
            minHeight: 5.h,
            backgroundColor: AppColors.accentGold.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentGold),
          ),
        ),
      ],
    );
  }
}

/// A compact visual badge indicating whether the currently selected surah is offline or streaming.
class SurahAudioSourceBadge extends StatelessWidget {
  final int surahNumber;
  final String category;
  final String reciterKey;

  const SurahAudioSourceBadge({
    super.key,
    required this.surahNumber,
    required this.category,
    required this.reciterKey,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();

    AudioDownloadManager manager;
    try {
      manager = context.read<AudioDownloadManager>();
    } catch (_) {
      manager = AudioDownloadManager();
    }

    final numAyahs = QuranMetadata.surahLengthOf(surahNumber);
    final l10n = AppLocalizations.of(context)!;

    return FutureBuilder<bool>(
      future: manager.isSurahDownloaded(category, reciterKey, surahNumber, numAyahs),
      builder: (context, snapshot) {
        final isDownloaded = snapshot.data == true;
        return Tooltip(
          message: isDownloaded ? l10n.audioSourceOfflineTooltip : l10n.audioSourceLiveTooltip,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: isDownloaded
                  ? AppColors.accentGold.withValues(alpha: 0.15)
                  : AppColors.bronzeIcon.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6.r),
              border: Border.all(
                color: isDownloaded
                    ? AppColors.accentGold.withValues(alpha: 0.4)
                    : AppColors.bronzeIcon.withValues(alpha: 0.2),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isDownloaded ? Icons.download_done_rounded : Icons.cloud_outlined,
                  size: 13.sp,
                  color: isDownloaded ? AppColors.accentGold : AppColors.bronzeIcon,
                ),
                SizedBox(width: 3.w),
                Text(
                  isDownloaded ? l10n.audioSourceOffline : l10n.audioSourceLive,
                  style: TextStyle(
                    fontSize: 9.5.sp,
                    fontWeight: FontWeight.w600,
                    color: isDownloaded ? AppColors.accentGold : AppColors.bronzeIcon,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
