import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../domain/entities/video_theme_preset.dart';

/// Theme selector with horizontal luxury theme swatches for styling text, badges, and accents.
class VideoThemeSelectorMobile extends StatelessWidget {
  final VideoThemePreset selectedPreset;
  final ValueChanged<VideoThemePreset> onThemeSelected;

  const VideoThemeSelectorMobile({
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
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 6.h),
        SizedBox(
          height: 42.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: VideoThemePreset.allPresets.length,
            separatorBuilder: (_, _) => SizedBox(width: 8.w),
            itemBuilder: (context, index) {
              final preset = VideoThemePreset.allPresets[index];
              final isSelected = preset.id == selectedPreset.id;

              return GestureDetector(
                onTap: () => onThemeSelected(preset),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: preset.gradientColors.first,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: isSelected ? AppColors.accentGold : preset.borderColor,
                      width: isSelected ? 2.5 : 1,
                    ),
                    boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.accentGold.withValues(alpha: 0.3),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 14.r,
                        height: 14.r,
                        decoration: BoxDecoration(
                          color: preset.accentColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        isEn ? preset.nameEnglish : preset.nameArabic,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: preset.primaryTextColor,
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
