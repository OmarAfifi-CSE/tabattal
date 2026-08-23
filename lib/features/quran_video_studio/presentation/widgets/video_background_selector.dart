import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/video_project_config.dart';
import 'custom_background_modal.dart';

/// Dedicated background selector that cleanly separates Background (Theme Gradient vs Custom Photo)
/// from the Theme Palette styling.
class VideoBackgroundSelector extends StatelessWidget {
  final VideoProjectConfig config;
  final ValueChanged<String?> onCustomImageChanged;
  final ValueChanged<double>? onDimmingChanged;

  const VideoBackgroundSelector({
    super.key,
    required this.config,
    required this.onCustomImageChanged,
    this.onDimmingChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final hasCustomImage = config.customImagePath != null &&
        config.customImagePath!.isNotEmpty &&
        File(config.customImagePath!).existsSync();

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
            if (hasCustomImage)
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
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: !hasCustomImage
                        ? AppColors.accentGold.withValues(alpha: 0.12)
                        : AppColors.surfaceCream,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: !hasCustomImage
                          ? AppColors.accentGold
                          : AppColors.divider,
                      width: !hasCustomImage ? 2.0 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        !hasCustomImage
                            ? Icons.check_circle_rounded
                            : Icons.palette_outlined,
                        size: 16.sp,
                        color: !hasCustomImage
                            ? AppColors.accentGold
                            : AppColors.textSecondary,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        isEn ? 'Card Design' : 'تصميم البطاقة',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight:
                              !hasCustomImage ? FontWeight.bold : FontWeight.w500,
                          color: !hasCustomImage
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 8.w),

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
                    horizontal: 10.w,
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
                        size: 16.sp,
                        color: hasCustomImage
                            ? Colors.white
                            : AppColors.accentGold,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        hasCustomImage
                            ? (isEn ? 'Change Photo' : 'تغيير الصورة')
                            : (isEn ? 'Custom Photo' : 'صورة مخصصة'),
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: hasCustomImage
                              ? FontWeight.bold
                              : FontWeight.w600,
                          color: hasCustomImage
                              ? Colors.white
                              : AppColors.textPrimary,
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
