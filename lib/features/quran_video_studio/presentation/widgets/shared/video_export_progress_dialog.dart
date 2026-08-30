import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../domain/entities/video_render_progress.dart';

class VideoExportProgressDialog extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isIndeterminate = progress.progress < 0.0;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && progress.isRendering) {
          onCancel();
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
                if (progress.isCompleted)
                  Container(
                    padding: EdgeInsets.all(12.r),
                    decoration: BoxDecoration(
                      color: AppColors.accentGold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check_circle_rounded, color: AppColors.accentGold, size: 36.sp),
                  )
                else if (progress.isFailed)
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
                    child: CircularProgressIndicator(
                      value: progress.progress > 0 ? progress.progress.clamp(0.0, 1.0) : null,
                      strokeWidth: 3.5,
                      color: AppColors.accentGold,
                      backgroundColor: AppColors.accentGold.withValues(alpha: 0.15),
                    ),
                  ),

                SizedBox(height: 14.h),

                Text(
                  progress.isCompleted
                      ? l10n.videoStudioProgressCompleted
                      : progress.isFailed
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
                  _getLocalizedStatusMessage(context, progress),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),

                Builder(
                  builder: (context) {
                    final eta = _getLocalizedEtaMessage(context, progress);
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

                if (progress.isRendering) ...[
                  SizedBox(height: 14.h),
                  LinearProgressIndicator(
                    value: isIndeterminate ? null : progress.progress.clamp(0.0, 1.0),
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
                        Text(
                          '${(progress.progress.clamp(0.0, 1.0) * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accentGold,
                            fontFamily: 'Outfit',
                          ),
                        ),
                        if (progress.renderedSeconds != null &&
                            progress.totalSeconds != null &&
                            progress.totalSeconds! > 0)
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
                                  _formatTime(progress.renderedSeconds!),
                                  _formatTime(progress.totalSeconds!),
                                ),
                                style: TextStyle(
                                  fontSize: 11.5.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                  fontFamily: 'Outfit',
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                  SizedBox(height: 14.h),
                  TextButton(
                    onPressed: onCancel,
                    child: Text(
                      l10n.videoStudioCancelExport,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.red.shade400,
                      ),
                    ),
                  ),
                ] else if (progress.isFailed) ...[
                  SizedBox(height: 18.h),
                  OutlinedButton(
                    onPressed: onDismiss,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accentGold,
                      side: BorderSide(color: AppColors.accentGold),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: Text(l10n.videoStudioClose),
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
      BuildContext context, VideoRenderProgress progress) {
    if (progress.step != VideoProgressStep.serverEncoding) return null;
    if (progress.renderedSeconds == null ||
        progress.totalSeconds == null ||
        progress.renderedSeconds! <= 0) {
      return null;
    }
    final l10n = AppLocalizations.of(context)!;
    final speed = progress.speed ?? 1.0;
    final remainingVideoSec = (progress.totalSeconds! - progress.renderedSeconds!)
        .clamp(0.0, progress.totalSeconds!);
    if (speed > 0.1 && remainingVideoSec > 0.3) {
      final remainingClockSec = (remainingVideoSec / speed).ceil();
      if (remainingClockSec <= 1) {
        return l10n.videoStudioEtaOneSecond;
      } else if (remainingClockSec == 2) {
        return l10n.videoStudioEtaTwoSeconds;
      } else if (remainingClockSec <= 10) {
        return l10n.videoStudioEtaFewSeconds(remainingClockSec);
      } else {
        return l10n.videoStudioEtaManySeconds(remainingClockSec);
      }
    } else {
      return l10n.videoStudioEtaMoments;
    }
  }

  String _getLocalizedStatusMessage(
      BuildContext context, VideoRenderProgress progress) {
    final l10n = AppLocalizations.of(context)!;
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
