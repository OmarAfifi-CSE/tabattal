import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../l10n/app_localizations.dart';

/// Tafsir and Translation toggle options card matching Video Studio options style.
class VerseCardOptionsBar extends StatelessWidget {
  final bool includeTafsir;
  final ValueChanged<bool> onToggleTafsir;
  final bool includeTranslation;
  final ValueChanged<bool> onToggleTranslation;

  const VerseCardOptionsBar({
    super.key,
    required this.includeTafsir,
    required this.onToggleTafsir,
    required this.includeTranslation,
    required this.onToggleTranslation,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.videoStudioDisplayOptions,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
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
                icon: Icons.menu_book_outlined,
                title: l10n.verseCardIncludeTafsir,
                value: includeTafsir,
                onChanged: onToggleTafsir,
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _buildSwitchRow(
                icon: Icons.g_translate_outlined,
                title: l10n.verseCardIncludeTranslation,
                value: includeTranslation,
                onChanged: onToggleTranslation,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchRow({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16.sp,
                color: AppColors.accentGold,
              ),
              SizedBox(width: 8.w),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.sp,
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
