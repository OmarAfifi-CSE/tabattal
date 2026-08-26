import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../l10n/app_localizations.dart';
import '../models/verse_card_theme.dart';

/// Action buttons for Image/FullPage mode (Share Image & Save Image) vs Text mode (Copy Text) with status banner.
class VerseCardActionButtons extends StatelessWidget {
  final ShareFormat selectedFormat;
  final bool isSharing;
  final bool isSaving;
  final bool isExportingVideo;
  final VoidCallback onShare;
  final VoidCallback onSave;
  final VoidCallback onCopyText;
  final VoidCallback? onShareVideo;
  final VoidCallback? onSaveVideo;
  final String? statusMessage;
  final bool isSuccessStatus;

  const VerseCardActionButtons({
    super.key,
    required this.selectedFormat,
    required this.isSharing,
    required this.isSaving,
    this.isExportingVideo = false,
    required this.onShare,
    required this.onSave,
    required this.onCopyText,
    this.onShareVideo,
    this.onSaveVideo,
    this.statusMessage,
    this.isSuccessStatus = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    Widget buildButtons() {
      switch (selectedFormat) {
        case ShareFormat.video:
          return Row(
            key: const ValueKey('video_action_buttons'),
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isExportingVideo ? null : onShareVideo,
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
                  icon: isExportingVideo
                      ? CupertinoActivityIndicator(
                          radius: 8.r,
                          color: Colors.white,
                        )
                      : const Icon(Icons.share_rounded),
                  label: Text(
                    'مشاركة الفيديو',
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
                  onPressed: isExportingVideo ? null : onSaveVideo,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentGold,
                    disabledForegroundColor:
                        AppColors.accentGold.withValues(alpha: 0.85),
                    side: BorderSide(
                      color: AppColors.accentGold.withValues(
                        alpha: isExportingVideo ? 0.85 : 1.0,
                      ),
                      width: 1.5,
                    ),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  icon: isExportingVideo
                      ? CupertinoActivityIndicator(
                          radius: 8.r,
                          color: AppColors.accentGold,
                        )
                      : const Icon(Icons.download_rounded),
                  label: Text(
                    'حفظ الفيديو',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          );
        case ShareFormat.image:
        case ShareFormat.fullPage:
          return Row(
            key: const ValueKey('image_action_buttons'),
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (isSharing || isSaving) ? null : onShare,
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
                  icon: isSharing
                      ? CupertinoActivityIndicator(
                          radius: 8.r,
                          color: Colors.white,
                        )
                      : const Icon(Icons.share_rounded),
                  label: Text(
                    l10n.verseCardShareImage,
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
                  onPressed: (isSaving || isSharing) ? null : onSave,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentGold,
                    disabledForegroundColor:
                        AppColors.accentGold.withValues(alpha: 0.85),
                    side: BorderSide(
                      color: AppColors.accentGold.withValues(
                        alpha: (isSaving || isSharing) ? 0.85 : 1.0,
                      ),
                      width: 1.5,
                    ),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  icon: isSaving
                      ? CupertinoActivityIndicator(
                          radius: 8.r,
                          color: AppColors.accentGold,
                        )
                      : const Icon(Icons.download_rounded),
                  label: Text(
                    l10n.verseCardSaveImage,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          );
        case ShareFormat.text:
          return SizedBox(
            key: const ValueKey('text_action_buttons'),
            width: MediaQuery.sizeOf(context).width,
            child: ElevatedButton.icon(
              onPressed: onCopyText,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGold,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
                elevation: 2,
              ),
              icon: const Icon(Icons.copy_rounded),
              label: Text(
                l10n.verseCardCopyText,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
      }
    }

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
                    vertical: 10.h,
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
                            fontSize: 13.sp,
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

        // Buttons
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: buildButtons(),
        ),
      ],
    );
  }
}
