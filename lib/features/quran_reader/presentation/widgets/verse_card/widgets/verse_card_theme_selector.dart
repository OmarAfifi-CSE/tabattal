import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../l10n/app_localizations.dart';
import '../models/verse_card_theme.dart';

/// Theme selector with horizontal theme preview chips.
class VerseCardThemeSelector extends StatelessWidget {
  final int selectedThemeIndex;
  final ValueChanged<int> onThemeSelected;

  const VerseCardThemeSelector({
    super.key,
    required this.selectedThemeIndex,
    required this.onThemeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const isWeb = kIsWeb;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.themeAppearanceTitle,
          style: TextStyle(
            fontSize: isWeb ? 14 : 13.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: isWeb ? 8 : 6.h),
        SizedBox(
          height: 42.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: VerseCardTheme.themes.length,
            separatorBuilder: (ctx, idx) => SizedBox(width: 8.w),
            itemBuilder: (context, index) {
              final t = VerseCardTheme.themes[index];
              final isSelected = index == selectedThemeIndex;

              return GestureDetector(
                onTap: () => onThemeSelected(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: t.backgroundColor,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: isSelected ? AppColors.accentGold : t.borderColor,
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
                          color: t.accentColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        t.getLocalizedName(context),
                        style: TextStyle(
                          fontSize: isWeb ? 13 : 12.sp,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: t.primaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: isWeb ? 12 : 10.h),
      ],
    );
  }
}
