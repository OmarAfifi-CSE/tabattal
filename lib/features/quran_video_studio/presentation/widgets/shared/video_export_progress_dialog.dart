import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../domain/entities/video_render_progress.dart';

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
  double _lastProgress = 0.0;

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
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isIndeterminate = widget.progress.progress < 0.0;
    final displayProgress = max(_lastProgress, widget.progress.progress).clamp(0.0, 1.0);
    final displayRenderedSec = widget.progress.renderedSeconds != null
        ? max(_lastRenderedSeconds, widget.progress.renderedSeconds!)
        : _lastRenderedSeconds;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && widget.progress.isRendering) {
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
                  SizedBox(
                    width: 44.r,
                    height: 44.r,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: displayProgress),
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      builder: (context, animValue, _) {
                        return CircularProgressIndicator(
                          value: animValue > 0 ? animValue : null,
                          strokeWidth: 3.5,
                          color: AppColors.accentGold,
                          backgroundColor: AppColors.accentGold.withValues(alpha: 0.15),
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
                    fontWeight: FontWeight.bold,
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

                Builder(
                  builder: (context) {
                    final eta = _getLocalizedEtaMessage(context, widget.progress, displayRenderedSec);
                    if (eta == null) return const SizedBox.shrink();
                    return Padding(
                      padding: EdgeInsets.only(top: 4.h),
                      child: Text(
                        eta,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5.sp,
                          color: AppColors.accentGold.withValues(alpha: 0.95),
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Amiri',
                        ),
                      ),
                    );
                  },
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
                          LinearProgressIndicator(
                            value: isIndeterminate ? null : animValue,
                            minHeight: 6.h,
                            borderRadius: BorderRadius.circular(8.r),
                            color: AppColors.accentGold,
                            backgroundColor: AppColors.accentGold.withValues(alpha: 0.15),
                          ),
                          if (!isIndeterminate) ...[
                            SizedBox(height: 8.h),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                SizedBox(
                                  width: 46.w,
                                  child: Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: Text(
                                      '${(animValue * 100).toInt()}%',
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.accentGold,
                                        fontFamily: 'Outfit',
                                        fontFeatures: const [FontFeature.tabularFigures()],
                                      ),
                                    ),
                                  ),
                                ),
                                if (widget.progress.totalSeconds != null && widget.progress.totalSeconds! > 0)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.movie_creation_outlined,
                                        size: 13.sp,
                                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                                      ),
                                      SizedBox(width: 4.w),
                                      Text(
                                        l10n.videoStudioEncodingProgress(
                                          _formatTime(displayRenderedSec),
                                          _formatTime(widget.progress.totalSeconds!),
                                        ),
                                        style: TextStyle(
                                          fontSize: 11.5.sp,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                          fontFamily: 'Outfit',
                                          fontFeatures: const [FontFeature.tabularFigures()],
                                        ),
                                      ),
                                    ],
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
      BuildContext context, VideoRenderProgress progress, double renderedSec) {
    if (progress.step != VideoProgressStep.serverEncoding) return null;
    final totalSec = progress.totalSeconds;
    final speed = progress.speed;
    if (totalSec == null || totalSec <= 0 || renderedSec <= 0 || speed == null || speed <= 0.05) {
      return null;
    }

    final l10n = AppLocalizations.of(context)!;
    final remainingVideoSec = (totalSec - renderedSec).clamp(0.0, totalSec);

    if (remainingVideoSec <= 0.5) {
      return l10n.videoStudioEtaMoments;
    }

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
      _smoothedRemainingSeconds = (wallDecayed * 0.80) + (instantClockSec * 0.20);
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
      return progress.errorMessage ??
          (progress.statusMessage.isNotEmpty ? progress.statusMessage : l10n.videoStudioProgressFailed);
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
        return progress.errorMessage ?? (progress.statusMessage.isNotEmpty ? progress.statusMessage : l10n.videoStudioProgressFailed);
      case VideoProgressStep.cancelled:
        return l10n.videoStudioCancelExport;
      case VideoProgressStep.initial:
        return l10n.videoStudioExportPreparing;
    }
  }
}

