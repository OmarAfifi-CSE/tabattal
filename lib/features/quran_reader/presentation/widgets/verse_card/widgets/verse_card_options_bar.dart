import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../l10n/app_localizations.dart';

/// Tafsir and Translation toggle options row.
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
    const isWeb = kIsWeb;

    return Column(
      children: [
        // Tafsir Toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  size: isWeb ? 16 : 14.r,
                  color: AppColors.accentGold,
                ),
                SizedBox(width: 8.w),
                Text(
                  l10n.verseCardIncludeTafsir,
                  style: TextStyle(
                    fontSize: isWeb ? 14 : 13.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            Transform.scale(
              scale: 0.8,
              child: CupertinoSwitch(
                value: includeTafsir,
                activeTrackColor: AppColors.accentGold,
                onChanged: onToggleTafsir,
              ),
            ),
          ],
        ),

        // Translation Toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.g_translate_outlined,
                  size: isWeb ? 16 : 14.r,
                  color: AppColors.accentGold,
                ),
                SizedBox(width: 8.w),
                Text(
                  l10n.verseCardIncludeTranslation,
                  style: TextStyle(
                    fontSize: isWeb ? 14 : 13.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            Transform.scale(
              scale: 0.8,
              child: CupertinoSwitch(
                value: includeTranslation,
                activeTrackColor: AppColors.accentGold,
                onChanged: onToggleTranslation,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
