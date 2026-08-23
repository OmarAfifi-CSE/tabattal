import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/video_project_config.dart';
import '../../domain/entities/video_enums.dart';

class VideoOptionsSelector extends StatelessWidget {
  final VideoProjectConfig config;
  final ValueChanged<VideoQuality>? onQualityChanged;
  final ValueChanged<VideoTextDisplayMode>? onDisplayModeChanged;
  final void Function({
    bool? showSurahBadge,
    bool? showReciterName,
    bool? showTafsir,
    bool? showEnglishTranslation,
    bool? showAudioWaveform,
  }) onToggleOption;

  const VideoOptionsSelector({
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
        // 1. Text Display Mode (Kinetic Line-by-Line vs Word Highlight vs Static Full)
        Text(
          l10n.videoStudioDisplayMode,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 6.h),
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
                padding: EdgeInsets.symmetric(horizontal: 3.w),
                child: InkWell(
                  onTap: () => onDisplayModeChanged?.call(mode),
                  borderRadius: BorderRadius.circular(12.r),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 4.w),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accentGold.withValues(alpha: 0.15)
                          : AppColors.accentGold.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.accentGold
                            : AppColors.accentGold.withValues(alpha: 0.2),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          size: 16.sp,
                          color: isSelected ? AppColors.accentGold : AppColors.textSecondary,
                        ),
                        SizedBox(height: 4.h),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? AppColors.accentGold : AppColors.textPrimary,
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

        SizedBox(height: 14.h),

        // 2. Video Quality Selection
        Text(
          l10n.videoStudioQuality,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 6.h),
        Row(
          children: VideoQuality.values.map((quality) {
            final isSelected = config.videoQuality == quality;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 3.w),
                child: InkWell(
                  onTap: () => onQualityChanged?.call(quality),
                  borderRadius: BorderRadius.circular(12.r),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accentGold.withValues(alpha: 0.15)
                          : AppColors.accentGold.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.accentGold
                            : AppColors.accentGold.withValues(alpha: 0.2),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          quality.shortLabel,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? AppColors.accentGold : AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          quality == VideoQuality.uhd4k
                              ? l10n.videoQualityUltra
                              : quality == VideoQuality.fhd1080p
                                  ? l10n.videoQualityHigh
                                  : l10n.videoQualityFast,
                          style: TextStyle(
                            fontSize: 9.5.sp,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected ? AppColors.accentGold : AppColors.textSecondary,
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

        SizedBox(height: 14.h),

        // 3. Display Options Toggles
        Text(
          l10n.videoStudioDisplayOptions,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 6.h),
        Container(
          decoration: BoxDecoration(
            color: AppColors.accentGold.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: AppColors.accentGold.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              _buildSwitchRow(
                title: l10n.videoStudioShowSurahBadge,
                value: config.showSurahBadge,
                onChanged: (val) => onToggleOption(showSurahBadge: val),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _buildSwitchRow(
                title: l10n.videoStudioShowReciterName,
                value: config.showReciterName,
                onChanged: (val) => onToggleOption(showReciterName: val),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _buildSwitchRow(
                title: l10n.videoStudioShowTafsir,
                value: config.showTafsir,
                onChanged: (val) => onToggleOption(showTafsir: val),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _buildSwitchRow(
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
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
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
