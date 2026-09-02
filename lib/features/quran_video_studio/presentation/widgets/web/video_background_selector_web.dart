import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../domain/entities/video_project_config.dart';
import '../shared/custom_background_modal.dart';
import '../shared/custom_video_modal.dart';
import '../shared/video_media_provider.dart';

/// Dedicated web background selector for video studio.
class VideoBackgroundSelectorWeb extends StatelessWidget {
  final VideoProjectConfig config;
  final ValueChanged<String?> onCustomImageChanged;
  final ValueChanged<String?>? onCustomVideoChanged;
  final ValueChanged<double>? onDimmingChanged;

  const VideoBackgroundSelectorWeb({
    super.key,
    required this.config,
    required this.onCustomImageChanged,
    this.onCustomVideoChanged,
    this.onDimmingChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final hasCustomImage = config.hasCustomImage;
    final hasCustomVideo = config.hasCustomVideo;
    final isDefaultTheme = !config.hasCustomMedia;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.videoStudioThemeAndBg,
              style: TextStyle(
                fontSize: 16.0.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (hasCustomVideo)
              Text(
                l10n.videoBgCustomVideoActive,
                style: TextStyle(
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentGold,
                ),
              )
            else if (hasCustomImage)
              Text(
                l10n.videoStudioCustomPhotoActive,
                style: TextStyle(
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentGold,
                ),
              ),
          ],
        ),
        SizedBox(height: 8.0.h),
        Row(
          children: [
            // Option 1: Default Theme Gradient Background
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (hasCustomImage) {
                    onCustomImageChanged(null);
                  }
                  if (hasCustomVideo) {
                    onCustomVideoChanged?.call(null);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.0.w,
                    vertical: 12.0.h,
                  ),
                  decoration: BoxDecoration(
                    color: isDefaultTheme
                        ? AppColors.accentGold.withValues(alpha: 0.12)
                        : AppColors.surfaceCream,
                    borderRadius: BorderRadius.circular(14.0.r),
                    border: Border.all(
                      color: isDefaultTheme
                          ? AppColors.accentGold
                          : AppColors.divider,
                      width: isDefaultTheme ? 2.0.w : 1.0.w,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isDefaultTheme
                            ? Icons.check_circle_rounded
                            : Icons.palette_outlined,
                        size: 20.0.sp,
                        color: isDefaultTheme
                            ? AppColors.accentGold
                            : AppColors.textSecondary,
                      ),
                      SizedBox(width: 8.0.w),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            l10n.videoBgCardDesign,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 14.5.sp,
                              fontWeight: isDefaultTheme
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isDefaultTheme
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              height: 1.15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 8.0.w),

            // Option 2: Custom Photo (Gallery / URL)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  CustomBackgroundModal.show(
                    context,
                    currentImagePath: config.customImagePath,
                    onImageSelected: (path) => onCustomImageChanged(path),
                    onImageRemoved: () => onCustomImageChanged(null),
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.0.w,
                    vertical: 12.0.h,
                  ),
                  decoration: BoxDecoration(
                    color: hasCustomImage
                        ? AppColors.accentGold.withValues(alpha: 0.15)
                        : AppColors.surfaceCream,
                    borderRadius: BorderRadius.circular(14.0.r),
                    border: Border.all(
                      color: hasCustomImage
                          ? AppColors.accentGold
                          : AppColors.divider,
                      width: hasCustomImage ? 2.0.w : 1.0.w,
                    ),
                    image: hasCustomImage
                        ? DecorationImage(
                            image: getCustomImageProvider(config.customImagePath!),
                            fit: BoxFit.cover,
                            colorFilter: ColorFilter.mode(
                              Colors.black.withValues(alpha: 0.45),
                              BlendMode.darken,
                            ),
                          )
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        hasCustomImage
                            ? Icons.edit_rounded
                            : Icons.add_photo_alternate_outlined,
                        size: 20.0.sp,
                        color: hasCustomImage
                            ? Colors.white
                            : AppColors.accentGold,
                      ),
                      SizedBox(width: 8.0.w),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            l10n.videoBgCustomPhoto,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 14.5.sp,
                              fontWeight: hasCustomImage
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: hasCustomImage
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              height: 1.15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 8.0.w),

            // Option 3: Custom Video (Gallery / URL)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  CustomVideoModal.show(
                    context,
                    currentVideoPath: config.customVideoPath,
                    onVideoSelected: (path) => onCustomVideoChanged?.call(path),
                    onVideoRemoved: () => onCustomVideoChanged?.call(null),
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.0.w,
                    vertical: 12.0.h,
                  ),
                  decoration: BoxDecoration(
                    color: hasCustomVideo
                        ? AppColors.accentGold.withValues(alpha: 0.15)
                        : AppColors.surfaceCream,
                    borderRadius: BorderRadius.circular(14.0.r),
                    border: Border.all(
                      color: hasCustomVideo
                          ? AppColors.accentGold
                          : AppColors.divider,
                      width: hasCustomVideo ? 2.0.w : 1.0.w,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        hasCustomVideo
                            ? Icons.videocam_rounded
                            : Icons.videocam_outlined,
                        size: 20.0.sp,
                        color: hasCustomVideo
                            ? AppColors.accentGold
                            : AppColors.accentGold,
                      ),
                      SizedBox(width: 8.0.w),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            hasCustomVideo
                                ? l10n.videoBgChangeVideo
                                : l10n.videoBgCustomVideo,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 14.5.sp,
                              fontWeight: hasCustomVideo
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: hasCustomVideo
                                  ? AppColors.accentGold
                                  : AppColors.textPrimary,
                              height: 1.15,
                            ),
                          ),
                        ),
                      ),
                    ],
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
