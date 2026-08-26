import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../quran_video_studio/domain/entities/video_theme_preset.dart';

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
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isEn ? 'Theme & Accent Palette' : 'المظهر والألوان',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4.0),
        SizedBox(
          height: 34.0,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: VideoThemePreset.allPresets.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6.0),
            itemBuilder: (context, index) {
              final preset = VideoThemePreset.allPresets[index];
              final isSelected = preset.id == selectedPreset.id;

              return GestureDetector(
                onTap: () => onThemeSelected(preset),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10.0,
                    vertical: 4.0,
                  ),
                  decoration: BoxDecoration(
                    color: preset.gradientColors.first,
                    borderRadius: BorderRadius.circular(10.0),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.accentGold
                          : preset.borderColor,
                      width: isSelected ? 2.0 : 1,
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10.0,
                        height: 10.0,
                        decoration: BoxDecoration(
                          color: preset.accentColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5.0),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isEn ? preset.nameEnglish : preset.nameArabic,
                          style: TextStyle(
                            fontSize: 10.0,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
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
