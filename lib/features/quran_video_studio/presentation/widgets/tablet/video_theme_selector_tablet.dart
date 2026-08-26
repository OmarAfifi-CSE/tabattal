import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../domain/entities/video_theme_preset.dart';

/// Dedicated tablet theme selector with horizontal luxury theme swatches.
class VideoThemeSelectorTablet extends StatelessWidget {
  final VideoThemePreset selectedPreset;
  final ValueChanged<VideoThemePreset> onThemeSelected;

  const VideoThemeSelectorTablet({
    super.key,
    required this.selectedPreset,
    required this.onThemeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.videoStudioThemeAndColors,
          style: TextStyle(
            fontSize: 16.0.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 6.0.h),
        SizedBox(
          height: 44.0.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: VideoThemePreset.allPresets.length,
            separatorBuilder: (_, _) => SizedBox(width: 8.0.w),
            itemBuilder: (context, index) {
              final preset = VideoThemePreset.allPresets[index];
              final isSelected = preset.id == selectedPreset.id;

              return GestureDetector(
                onTap: () => onThemeSelected(preset),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.0.w,
                    vertical: 6.0.h,
                  ),
                  decoration: BoxDecoration(
                    color: preset.gradientColors.first,
                    borderRadius: BorderRadius.circular(12.0.r),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.accentGold
                          : preset.borderColor,
                      width: isSelected ? 2.0.w : 1.w,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.accentGold.withValues(alpha: 0.3),
                              blurRadius: 6.r,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 13.0.r,
                        height: 13.0.r,
                        decoration: BoxDecoration(
                          color: preset.accentColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 8.0.w),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isEn ? preset.nameEnglish : preset.nameArabic,
                          style: TextStyle(
                            fontSize: 14.0.sp,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: preset.primaryTextColor,
                            height: 1.15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
