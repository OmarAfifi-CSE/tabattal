import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../domain/entities/video_enums.dart';
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
    final isIndeterminate = progress.progress < 0.0 || (kIsWeb && progress.progress < 1.0);

    return PopScope(
      canPop: progress.isCompleted || progress.isFailed,
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
                      value: progress.progress > 0 ? progress.progress : null,
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
                    fontSize: 12.sp,
                    color: AppColors.textSecondary,
                  ),
                ),

                if (progress.isRendering) ...[
                  SizedBox(height: 14.h),
                  LinearProgressIndicator(
                    value: isIndeterminate ? null : progress.progress,
                    minHeight: 6.h,
                    borderRadius: BorderRadius.circular(8.r),
                    color: AppColors.accentGold,
                    backgroundColor: AppColors.accentGold.withValues(alpha: 0.15),
                  ),
                  if (!isIndeterminate) ...[
                    SizedBox(height: 6.h),
                    Text(
                      '${(progress.progress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accentGold,
                      ),
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

  String _getLocalizedStatusMessage(
      BuildContext context, VideoRenderProgress progress) {
    final l10n = AppLocalizations.of(context)!;
    if (progress.statusMessage.isNotEmpty && !progress.isRendering) {
      return progress.statusMessage;
    }
    switch (progress.phase) {
      case VideoRenderPhase.downloadingAudio:
        return l10n.videoStudioProgressDownloadingAudio;
      case VideoRenderPhase.generatingOverlays:
        return l10n.videoStudioProgressGeneratingOverlays;
      case VideoRenderPhase.encodingVideo:
        return l10n.videoStudioProgressEncoding;
      case VideoRenderPhase.completed:
        return l10n.videoStudioProgressCompleted;
      case VideoRenderPhase.failed:
        return progress.statusMessage.isNotEmpty
            ? progress.statusMessage
            : l10n.videoStudioProgressFailed;
      case VideoRenderPhase.cancelled:
        return l10n.videoStudioCancelExport;
      case VideoRenderPhase.idle:
        return progress.statusMessage.isNotEmpty
            ? progress.statusMessage
            : l10n.videoStudioExportPreparing;
    }
  }
}
