import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../l10n/app_localizations.dart';

class VideoActionButtons extends StatelessWidget {
  final bool isExporting;
  final VoidCallback onShareVideo;
  final VoidCallback onSaveVideo;
  final String? statusMessage;
  final bool isSuccessStatus;

  const VideoActionButtons({
    super.key,
    required this.isExporting,
    required this.onShareVideo,
    required this.onSaveVideo,
    this.statusMessage,
    this.isSuccessStatus = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Animated status banner inside sheet
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => SizeTransition(
            sizeFactor: animation,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: statusMessage == null
              ? const SizedBox.shrink()
              : Container(
                  key: ValueKey(statusMessage),
                  margin: EdgeInsets.only(bottom: 10.h),
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: isSuccessStatus
                        ? AppColors.accentGold.withValues(alpha: 0.15)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: isSuccessStatus
                          ? AppColors.accentGold.withValues(alpha: 0.5)
                          : Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSuccessStatus
                            ? Icons.check_circle_rounded
                            : Icons.info_outline_rounded,
                        size: 18.r,
                        color: isSuccessStatus
                            ? AppColors.accentGold
                            : Colors.red,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          statusMessage!,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: isSuccessStatus
                                ? AppColors.textPrimary
                                : Colors.red.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),

        // Action Buttons Row
        if (kIsWeb)
          Row(
            key: const ValueKey('video_action_buttons_web'),
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isExporting ? null : onSaveVideo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentGold,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.accentGold.withValues(alpha: 0.85),
                    disabledForegroundColor:
                        Colors.white.withValues(alpha: 0.9),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    elevation: 2,
                  ),
                  icon: isExporting
                      ? CupertinoActivityIndicator(
                          radius: 8.r,
                          color: Colors.white,
                        )
                      : const Icon(Icons.download_rounded),
                  label: Text(
                    l10n.videoStudioDownloadVideo,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          )
        else
          Row(
            key: const ValueKey('video_action_buttons_native'),
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isExporting ? null : onShareVideo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentGold,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.accentGold.withValues(alpha: 0.85),
                    disabledForegroundColor:
                        Colors.white.withValues(alpha: 0.9),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    elevation: 2,
                  ),
                  icon: isExporting
                      ? CupertinoActivityIndicator(
                          radius: 8.r,
                          color: Colors.white,
                        )
                      : const Icon(Icons.share_rounded),
                  label: Text(
                    l10n.videoStudioShare,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isExporting ? null : onSaveVideo,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentGold,
                    disabledForegroundColor:
                        AppColors.accentGold.withValues(alpha: 0.85),
                    side: BorderSide(
                      color: AppColors.accentGold.withValues(
                        alpha: isExporting ? 0.85 : 1.0,
                      ),
                      width: 1.5,
                    ),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  icon: isExporting
                      ? CupertinoActivityIndicator(
                          radius: 8.r,
                          color: AppColors.accentGold,
                        )
                      : const Icon(Icons.download_rounded),
                  label: Text(
                    l10n.videoStudioSave,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
