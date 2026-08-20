import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../l10n/app_localizations.dart';
import '../models/verse_card_theme.dart';

/// Share Format Selector widget (Image, Text, Full Page).
class VerseCardFormatSelector extends StatelessWidget {
  final ShareFormat selectedFormat;
  final ValueChanged<ShareFormat> onFormatChanged;

  const VerseCardFormatSelector({
    super.key,
    required this.selectedFormat,
    required this.onFormatChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const isWeb = kIsWeb;

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.verseCardFormatLabel,
            style: TextStyle(
              fontSize: isWeb ? 14 : 13.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8.h),
          Container(
            width: MediaQuery.sizeOf(context).width,
            decoration: BoxDecoration(
              color: AppColors.surfaceCream,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: AppColors.accentGold.withValues(alpha: 0.4),
              ),
            ),
            padding: EdgeInsets.all(3.r),
            child: Row(
              children: [
                Expanded(
                  child: _FormatOptionTile(
                    label: l10n.verseCardFormatImage,
                    icon: Icons.image_rounded,
                    isSelected: selectedFormat == ShareFormat.image,
                    onTap: () => onFormatChanged(ShareFormat.image),
                  ),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: _FormatOptionTile(
                    label: l10n.verseCardFormatText,
                    icon: Icons.text_snippet_rounded,
                    isSelected: selectedFormat == ShareFormat.text,
                    onTap: () => onFormatChanged(ShareFormat.text),
                  ),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: _FormatOptionTile(
                    label: l10n.verseCardFormatFullPage,
                    icon: Icons.menu_book_rounded,
                    isSelected: selectedFormat == ShareFormat.fullPage,
                    onTap: () => onFormatChanged(ShareFormat.fullPage),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormatOptionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FormatOptionTile({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentGold : Colors.transparent,
          borderRadius: BorderRadius.circular(9.r),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.accentGold.withValues(alpha: 0.3),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14.r,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            SizedBox(width: 4.w),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
