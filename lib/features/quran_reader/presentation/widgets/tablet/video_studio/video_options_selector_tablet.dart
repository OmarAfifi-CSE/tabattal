import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../l10n/app_localizations.dart';
import '../../../../../quran_video_studio/domain/entities/video_enums.dart';
import '../../../../../quran_video_studio/domain/entities/video_project_config.dart';

class VideoOptionsSelectorTablet extends StatelessWidget {
  final VideoProjectConfig config;
  final ValueChanged<VideoQuality>? onQualityChanged;
  final ValueChanged<VideoTextDisplayMode>? onDisplayModeChanged;
  final void Function({
    bool? showSurahBadge,
    bool? showReciterName,
    bool? showCardFrame,
    bool? showTafsir,
    bool? showEnglishTranslation,
    bool? showAudioWaveform,
  }) onToggleOption;

  const VideoOptionsSelectorTablet({
    super.key,
    required this.config,
    this.onQualityChanged,
    this.onDisplayModeChanged,
    required this.onToggleOption,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Text Display Mode (Kinetic Line-by-Line vs Static Full)
        Text(
          l10n.videoStudioDisplayMode,
          style: TextStyle(
            fontSize: 16.0.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 8.0.h),
        Row(
          children: VideoTextDisplayMode.values.map((mode) {
            final isSelected = config.textDisplayMode == mode;
            String label;
            IconData icon;
            switch (mode) {
              case VideoTextDisplayMode.lineByLine:
                label = l10n.videoDisplayModeLineByLine;
                icon = Icons.view_headline_rounded;
                break;
              case VideoTextDisplayMode.staticFull:
                label = l10n.videoDisplayModeStaticFull;
                icon = Icons.menu_book_rounded;
                break;
            }

            return Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.0.w),
                child: InkWell(
                  onTap: () => onDisplayModeChanged?.call(mode),
                  borderRadius: BorderRadius.circular(12.0.r),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(
                      vertical: 10.0.h,
                      horizontal: 8.0.w,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accentGold.withValues(alpha: 0.15)
                          : AppColors.accentGold.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12.0.r),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.accentGold
                            : AppColors.accentGold.withValues(alpha: 0.2),
                        width: isSelected ? 1.5.w : 1.w,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          size: 22.0.sp,
                          color: isSelected
                              ? AppColors.accentGold
                              : AppColors.textSecondary,
                        ),
                        SizedBox(height: 6.0.h),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 14.5.sp,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppColors.accentGold
                                  : AppColors.textPrimary,
                              height: 1.15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        SizedBox(height: 12.0.h),

        // 2. Video Quality Selection
        Text(
          l10n.videoStudioQuality,
          style: TextStyle(
            fontSize: 16.0.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 8.0.h),
        Row(
          children: VideoQuality.values.map((quality) {
            final isSelected = config.videoQuality == quality;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.0.w),
                child: InkWell(
                  onTap: () => onQualityChanged?.call(quality),
                  borderRadius: BorderRadius.circular(12.0.r),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(vertical: 8.0.h),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accentGold.withValues(alpha: 0.15)
                          : AppColors.accentGold.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12.0.r),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.accentGold
                            : AppColors.accentGold.withValues(alpha: 0.2),
                        width: isSelected ? 1.5.w : 1.w,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          quality.shortLabel,
                          style: TextStyle(
                            fontSize: 15.0.sp,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? AppColors.accentGold
                                : AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2.0.h),
                        Text(
                          quality == VideoQuality.uhd4k
                              ? l10n.videoQualityUltra
                              : quality == VideoQuality.fhd1080p
                                  ? l10n.videoQualityHigh
                                  : l10n.videoQualityFast,
                          style: TextStyle(
                            fontSize: 12.0.sp,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? AppColors.accentGold
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        SizedBox(height: 12.0.h),

        // 3. Display Options Toggles
        Text(
          l10n.videoStudioDisplayOptions,
          style: TextStyle(
            fontSize: 16.0.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 8.0.h),
        Container(
          decoration: BoxDecoration(
            color: AppColors.accentGold.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14.0.r),
            border: Border.all(
              color: AppColors.accentGold.withValues(alpha: 0.15),
              width: 1.w,
            ),
          ),
          child: Column(
            children: [
              _buildSwitchRow(
                context: context,
                icon: Icons.crop_free_rounded,
                title: l10n.videoStudioShowCardFrame,
                value: config.showCardFrame,
                onChanged: (val) => onToggleOption(showCardFrame: val),
              ),
              Divider(height: 1.h, indent: 16.w, endIndent: 16.w),
              _buildSwitchRow(
                context: context,
                icon: Icons.bookmark_outline_rounded,
                title: config.textDisplayMode == VideoTextDisplayMode.lineByLine
                    ? (Localizations.localeOf(context).languageCode == 'ar'
                        ? 'إظهار اسم السورة ورقم الآية'
                        : 'Show Surah Name & Ayah Number')
                    : l10n.videoStudioShowSurahBadge,
                value: config.showSurahBadge,
                onChanged: (val) => onToggleOption(showSurahBadge: val),
              ),
              Divider(height: 1.h, indent: 16.w, endIndent: 16.w),
              _buildSwitchRow(
                context: context,
                icon: Icons.record_voice_over_outlined,
                title: l10n.videoStudioShowReciterName,
                value: config.showReciterName,
                onChanged: (val) => onToggleOption(showReciterName: val),
              ),
              Divider(height: 1.h, indent: 16.w, endIndent: 16.w),
              _buildSwitchRow(
                context: context,
                icon: Icons.menu_book_outlined,
                title: l10n.videoStudioShowTafsir,
                value: config.showTafsir,
                onChanged: (val) => onToggleOption(showTafsir: val),
              ),
              Divider(height: 1.h, indent: 16.w, endIndent: 16.w),
              _buildSwitchRow(
                context: context,
                icon: Icons.g_translate_outlined,
                title: l10n.videoStudioShowTranslation,
                value: config.showEnglishTranslation,
                onChanged: (val) => onToggleOption(showEnglishTranslation: val),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.0.w, vertical: 6.0.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20.0.sp,
                color: AppColors.accentGold,
              ),
              SizedBox(width: 10.0.w),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15.0.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.accentGold,
            activeTrackColor: AppColors.accentGold.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}
