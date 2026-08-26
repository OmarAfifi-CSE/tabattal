import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../domain/entities/video_enums.dart';
import '../../../domain/entities/video_project_config.dart';
import '../shared/custom_background_modal.dart';
import '../shared/custom_video_modal.dart';

/// Dedicated background selector that cleanly separates Background (Card Design vs Custom Photo vs Custom Video)
/// from the Theme Palette styling.
class VideoBackgroundSelectorMobile extends StatelessWidget {
  final VideoProjectConfig config;
  final ValueChanged<String?> onCustomImageChanged;
  final ValueChanged<String?>? onCustomVideoChanged;
  final ValueChanged<double>? onDimmingChanged;

  const VideoBackgroundSelectorMobile({
    super.key,
    required this.config,
    required this.onCustomImageChanged,
    this.onCustomVideoChanged,
    this.onDimmingChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final l10n = AppLocalizations.of(context)!;

    final hasCustomImage = config.backgroundType == VideoBackgroundType.customImage &&
        config.customImagePath != null &&
        config.customImagePath!.isNotEmpty &&
        File(config.customImagePath!).existsSync();

    final hasCustomVideo = config.backgroundType == VideoBackgroundType.customVideo &&
        config.customVideoPath != null &&
        config.customVideoPath!.isNotEmpty &&
        File(config.customVideoPath!).existsSync();

    final isDefaultTheme = !hasCustomImage && !hasCustomVideo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isEn ? 'Video Background' : 'خلفية الفيديو',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (hasCustomVideo)
              Text(
                l10n.videoBgCustomVideoActive,
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentGold,
                ),
              )
            else if (hasCustomImage)
              Text(
                isEn ? 'Custom Photo Active' : 'صورة مخصصة نشطة',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentGold,
                ),
              ),
          ],
        ),
        SizedBox(height: 6.h),
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
                    horizontal: 6.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: isDefaultTheme
                        ? AppColors.accentGold.withValues(alpha: 0.12)
                        : AppColors.surfaceCream,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: isDefaultTheme
                          ? AppColors.accentGold
                          : AppColors.divider,
                      width: isDefaultTheme ? 2.0 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isDefaultTheme
                            ? Icons.check_circle_rounded
                            : Icons.palette_outlined,
                        size: 15.sp,
                        color: isDefaultTheme
                            ? AppColors.accentGold
                            : AppColors.textSecondary,
                      ),
                      SizedBox(width: 4.w),
                      Flexible(
                        child: Text(
                          l10n.videoBgCardDesign,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5.sp,
                            fontWeight:
                                isDefaultTheme ? FontWeight.bold : FontWeight.w500,
                            color: isDefaultTheme
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 6.w),

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
                    horizontal: 6.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: hasCustomImage
                        ? AppColors.accentGold.withValues(alpha: 0.15)
                        : AppColors.surfaceCream,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: hasCustomImage
                          ? AppColors.accentGold
                          : AppColors.divider,
                      width: hasCustomImage ? 2.0 : 1.0,
                    ),
                    image: hasCustomImage
                        ? DecorationImage(
                            image: FileImage(File(config.customImagePath!)),
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
                        size: 15.sp,
                        color: hasCustomImage
                            ? Colors.white
                            : AppColors.accentGold,
                      ),
                      SizedBox(width: 4.w),
                      Flexible(
                        child: Text(
                          l10n.videoBgCustomPhoto,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5.sp,
                            fontWeight: hasCustomImage
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: hasCustomImage
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 6.w),

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
                    horizontal: 6.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: hasCustomVideo
                        ? AppColors.accentGold.withValues(alpha: 0.15)
                        : AppColors.surfaceCream,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: hasCustomVideo
                          ? AppColors.accentGold
                          : AppColors.divider,
                      width: hasCustomVideo ? 2.0 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        hasCustomVideo
                            ? Icons.videocam_rounded
                            : Icons.videocam_outlined,
                        size: 15.sp,
                        color: hasCustomVideo
                            ? AppColors.accentGold
                            : AppColors.accentGold,
                      ),
                      SizedBox(width: 4.w),
                      Flexible(
                        child: Text(
                          hasCustomVideo
                              ? l10n.videoBgChangeVideo
                              : l10n.videoBgCustomVideo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5.sp,
                            fontWeight: hasCustomVideo
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: hasCustomVideo
                                ? AppColors.accentGold
                                : AppColors.textPrimary,
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
