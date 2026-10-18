import 'dart:async';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../domain/entities/video_render_progress.dart';
import '../../utils/video_studio_error_helper.dart';

class VideoExportProgressDialog extends StatefulWidget {
  final VideoRenderProgress progress;
  final VoidCallback onCancel;
  final VoidCallback onDismiss;

  const VideoExportProgressDialog({
    super.key,
    required this.progress,
    required this.onCancel,
    required this.onDismiss,
  });

  @override
  State<VideoExportProgressDialog> createState() => _VideoExportProgressDialogState();
}

class _VideoExportProgressDialogState extends State<VideoExportProgressDialog> {
  double? _smoothedRemainingSeconds;
  DateTime? _lastEtaUpdateTime;
  double _lastRenderedSeconds = 0.0;
  double _lastTotalSeconds = 0.0;
  double _lastProgress = 0.0;
  Timer? _countdownTicker;

  @override
  void initState() {
    super.initState();
    if (widget.progress.progress > 0) {
      _lastProgress = widget.progress.progress;
    }
    if (widget.progress.renderedSeconds != null && widget.progress.renderedSeconds! > 0) {
      _lastRenderedSeconds = widget.progress.renderedSeconds!;
    }
    if (widget.progress.totalSeconds != null && widget.progress.totalSeconds! > 0) {
      _lastTotalSeconds = widget.progress.totalSeconds!;
    }
    _countdownTicker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted &&
          widget.progress.isRendering &&
          _smoothedRemainingSeconds != null &&
          _smoothedRemainingSeconds! > 0) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _countdownTicker?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant VideoExportProgressDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.progress.progress > _lastProgress) {
      _lastProgress = widget.progress.progress;
    }
    if (widget.progress.renderedSeconds != null &&
        widget.progress.renderedSeconds! > _lastRenderedSeconds) {
      _lastRenderedSeconds = widget.progress.renderedSeconds!;
    }
    if (widget.progress.totalSeconds != null &&
        widget.progress.totalSeconds! > _lastTotalSeconds) {
      _lastTotalSeconds = widget.progress.totalSeconds!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isIndeterminate = widget.progress.progress < 0.0;
    final displayProgress = max(_lastProgress, widget.progress.progress).clamp(0.0, 1.0);
    final displayRenderedSec = widget.progress.renderedSeconds != null
        ? max(_lastRenderedSeconds, widget.progress.renderedSeconds!)
        : _lastRenderedSeconds;
    final displayTotalSec = (widget.progress.totalSeconds != null && widget.progress.totalSeconds! > 0)
        ? max(_lastTotalSeconds, widget.progress.totalSeconds!)
        : _lastTotalSeconds;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && widget.progress.isRendering && !widget.progress.isCompleted) {
          widget.onCancel();
        }
      },
      child: Dialog(
        backgroundColor: AppColors.cardCream,
        insetPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
          side: BorderSide(
            color: AppColors.accentGold.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 360.w,
            minWidth: 260.w,
          ),
          child: Padding(
            padding: EdgeInsets.all(22.r),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon Status Indicator
                if (widget.progress.isCompleted)
                  Container(
                    padding: EdgeInsets.all(12.r),
                    decoration: BoxDecoration(
                      color: AppColors.accentGold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check_circle_rounded, color: AppColors.accentGold, size: 36.sp),
                  )
                else if (widget.progress.isFailed)
                  Container(
                    padding: EdgeInsets.all(12.r),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.error_outline_rounded, color: Colors.red, size: 36.sp),
                  )
                else if (isIndeterminate)
                  SizedBox(
                    width: 44.r,
                    height: 44.r,
                    child: Center(
                      child: CupertinoActivityIndicator(
                        radius: 16.r,
                        color: AppColors.accentGold,
                      ),
                    ),
                  )
                else
                  Container(
                    width: 52.r,
                    height: 52.r,
                    padding: EdgeInsets.all(4.r),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accentGold.withValues(alpha: 0.08),
                      border: Border.all(
                        color: AppColors.accentGold.withValues(alpha: 0.18),
                        width: 1.0,
                      ),
                    ),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: displayProgress),
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      builder: (context, animValue, _) {
                        return CircularProgressIndicator(
                          value: animValue > 0 ? animValue : null,
                          strokeWidth: 3.5,
                          color: AppColors.accentGold,
                          backgroundColor: AppColors.accentGold.withValues(alpha: 0.12),
                        );
                      },
                    ),
                  ),

                SizedBox(height: 14.h),

                Text(
                  widget.progress.isCompleted
                      ? l10n.videoStudioProgressCompleted
                      : widget.progress.isFailed
                          ? l10n.videoStudioProgressFailed
                          : l10n.videoStudioProgressTitle,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontFamily: 'Amiri',
                  ),
                ),

                SizedBox(height: 6.h),

                Text(
                  _getLocalizedStatusMessage(context, widget.progress),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),

                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: Builder(
                    builder: (context) {
                      final eta = _getLocalizedEtaMessage(
                        context,
                        widget.progress,
                        displayRenderedSec,
                        displayTotalSec,
                      );
                      if (eta == null) return const SizedBox.shrink();
                      return Padding(
                        padding: EdgeInsets.only(top: 6.h),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: AppColors.accentGold.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: AppColors.accentGold.withValues(alpha: 0.22),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.hourglass_top_rounded,
                                size: 12.sp,
                                color: AppColors.accentGold,
                              ),
                              SizedBox(width: 5.w),
                              Text(
                                eta,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11.5.sp,
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Amiri',
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                if (widget.progress.isRendering) ...[
                  SizedBox(height: 14.h),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: displayProgress),
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    builder: (context, animValue, _) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8.r),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accentGold.withValues(alpha: 0.12),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8.r),
                              child: LinearProgressIndicator(
                                value: isIndeterminate ? null : animValue,
                                minHeight: 7.h,
                                color: AppColors.accentGold,
                                backgroundColor: AppColors.accentGold.withValues(alpha: 0.15),
                              ),
                            ),
                          ),
                          if (!isIndeterminate) ...[
                            SizedBox(height: 8.h),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                SizedBox(
                                  width: 48.w,
                                  child: Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: Text(
                                      '${(animValue * 100).toInt()}%',
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.accentGold,
                                        fontFamily: 'Outfit',
                                        fontFeatures: const [FontFeature.tabularFigures()],
                                      ),
                                    ),
                                  ),
                                ),
                                if (displayTotalSec > 0 && displayRenderedSec > 0)
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentGold.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(6.r),
                                      border: Border.all(
                                        color: AppColors.accentGold.withValues(alpha: 0.20),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.movie_creation_outlined,
                                          size: 13.sp,
                                          color: AppColors.accentGold.withValues(alpha: 0.9),
                                        ),
                                        SizedBox(width: 5.w),
                                        Directionality(
                                          textDirection: TextDirection.ltr,
                                          child: Text(
                                            l10n.videoStudioEncodingProgress(
                                              _formatTime(displayRenderedSec),
                                              _formatTime(displayTotalSec),
                                            ),
                                            style: TextStyle(
                                              fontSize: 11.5.sp,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                              fontFamily: 'Outfit',
                                              fontFeatures: const [FontFeature.tabularFigures()],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  SizedBox(height: 18.h),
                  SizedBox(
                    height: 38.h,
                    child: TextButton.icon(
                      onPressed: widget.onCancel,
                      icon: Icon(
                        Icons.close_rounded,
                        size: 16.sp,
                        color: Colors.red.shade400,
                      ),
                      label: Text(
                        l10n.videoStudioCancelExport,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade400,
                          fontFamily: 'Amiri',
                        ),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.red.shade500.withValues(alpha: 0.10),
                        foregroundColor: Colors.red.shade400,
                        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          side: BorderSide(
                            color: Colors.red.shade400.withValues(alpha: 0.30),
                            width: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ] else if (widget.progress.isFailed) ...[
                  SizedBox(height: 18.h),
                  SizedBox(
                    height: 38.h,
                    child: ElevatedButton.icon(
                      onPressed: widget.onDismiss,
                      icon: Icon(Icons.close_rounded, size: 16.sp, color: AppColors.cardCream),
                      label: Text(
                        l10n.videoStudioClose,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Amiri',
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentGold,
                        foregroundColor: AppColors.cardCream,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 6.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatTime(double totalSec) {
    final int sec = totalSec.round();
    final int minutes = sec ~/ 60;
    final int remainingSeconds = sec % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String? _getLocalizedEtaMessage(
      BuildContext context, VideoRenderProgress progress, double renderedSec, double totalSec) {
    final l10n = AppLocalizations.of(context)!;
    if (progress.step == VideoProgressStep.preparingDownload) {
      return l10n.videoStudioEtaMoments;
    }
    if (progress.step != VideoProgressStep.serverEncoding) return null;
    if (totalSec <= 0 || renderedSec <= 0.0) return null;
    final remainingVideoSec = (totalSec - renderedSec).clamp(0.0, totalSec);

    if (remainingVideoSec <= 0.5) {
      return l10n.videoStudioEtaMoments;
    }

    final speed = (progress.speed != null && progress.speed! > 0.05) ? progress.speed! : 3.5;
    final now = DateTime.now();
    final instantClockSec = remainingVideoSec / speed;

    if (_smoothedRemainingSeconds == null) {
      _smoothedRemainingSeconds = instantClockSec;
      _lastEtaUpdateTime = now;
    } else {
      final elapsedSinceLastUpdate = _lastEtaUpdateTime != null
          ? (now.difference(_lastEtaUpdateTime!).inMilliseconds / 1000.0).clamp(0.0, 5.0)
          : 0.0;
      _lastEtaUpdateTime = now;

      // Natural wall-clock countdown (ticking down in real-time)
      final wallDecayed = max(0.0, _smoothedRemainingSeconds! - elapsedSinceLastUpdate);

      // Smoothly blend with live hardware speed measurement (EMA)
      _smoothedRemainingSeconds = (wallDecayed * 0.70) + (instantClockSec * 0.30);
    }

    final displaySec = _smoothedRemainingSeconds!.ceil().clamp(1, 9999);

    if (displaySec <= 1) {
      return l10n.videoStudioEtaOneSecond;
    } else if (displaySec == 2) {
      return l10n.videoStudioEtaTwoSeconds;
    } else if (displaySec <= 10) {
      return l10n.videoStudioEtaFewSeconds(displaySec);
    } else {
      return l10n.videoStudioEtaManySeconds(displaySec);
    }
  }

  String _getLocalizedStatusMessage(
      BuildContext context, VideoRenderProgress progress) {
    final l10n = AppLocalizations.of(context)!;
    if (progress.isFailed) {
      return VideoStudioErrorHelper.getLocalizedError(
        context,
        progress.errorMessage ?? progress.statusMessage,
      );
    }

    switch (progress.step) {
      case VideoProgressStep.readingTimings:
        return l10n.videoStudioProgressReadingTimings(progress.ayahNumber ?? 1);
      case VideoProgressStep.creatingBaseFrame:
        return l10n.videoStudioProgressCreatingBaseFrame;
      case VideoProgressStep.renderingLine:
        if (progress.totalAyahsCount != null && progress.totalAyahsCount! > 1 && progress.currentAyahIndex != null) {
          return l10n.videoStudioProgressPreparingAyahScenes(progress.currentAyahIndex!, progress.totalAyahsCount!);
        }
        return l10n.videoStudioProgressRenderingLine(
          progress.currentLine ?? 1,
          progress.totalLines ?? 1,
          progress.ayahNumber ?? 1,
        );
      case VideoProgressStep.renderingVerse:
        if (progress.totalAyahsCount != null && progress.totalAyahsCount! > 1 && progress.currentAyahIndex != null) {
          return l10n.videoStudioProgressPreparingAyahScenes(progress.currentAyahIndex!, progress.totalAyahsCount!);
        }
        return l10n.videoStudioProgressRenderingVerse(progress.ayahNumber ?? 1);
      case VideoProgressStep.uploadingPayload:
        return l10n.videoStudioProgressUploadingPayload(progress.uploadPercent ?? 0);
      case VideoProgressStep.serverEncoding:
        if (progress.statusMessage.isNotEmpty) {
          return progress.statusMessage;
        }
        return l10n.videoStudioProgressServerMuxing;
      case VideoProgressStep.preparingDownload:
        return l10n.videoStudioProgressPreparingDownload;
      case VideoProgressStep.concatenatingSegments:
        return l10n.videoStudioProgressConcatenating;
      case VideoProgressStep.downloadingAudio:
        return l10n.videoStudioProgressDownloadingAudio;
      case VideoProgressStep.completed:
        return l10n.videoStudioProgressCompleted;
      case VideoProgressStep.failed:
        return VideoStudioErrorHelper.getLocalizedError(
          context,
          progress.errorMessage ?? progress.statusMessage,
        );
      case VideoProgressStep.cancelled:
        return l10n.videoStudioCancelExport;
      case VideoProgressStep.initial:
        return l10n.videoStudioExportPreparing;
    }
  }
}

