import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/video_render_progress.dart';

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

    return PopScope(
      canPop: progress.isCompleted || progress.isFailed,
      child: Dialog(
        backgroundColor: AppColors.cardCream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
          side: BorderSide(
            color: AppColors.accentGold.withValues(alpha: 0.3),
            width: 1.5,
          ),
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
                progress.statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.textSecondary,
                ),
              ),

              if (progress.isRendering) ...[
                SizedBox(height: 14.h),
                LinearProgressIndicator(
                  value: progress.progress,
                  minHeight: 6.h,
                  borderRadius: BorderRadius.circular(8.r),
                  color: AppColors.accentGold,
                  backgroundColor: AppColors.accentGold.withValues(alpha: 0.15),
                ),
                SizedBox(height: 6.h),
                Text(
                  '${(progress.progress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentGold,
                  ),
                ),
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
    );
  }
}
